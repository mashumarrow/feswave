mod reactions;
mod storage;
use storage::Store;

use axum::{
    Json, Router,
    extract::{DefaultBodyLimit, Path, Request, State},
    http::{HeaderMap, HeaderValue, StatusCode, header},
    middleware::{self, Next},
    response::{
        IntoResponse, Response,
        sse::{Event, KeepAlive, Sse},
    },
    routing::{get, patch, post, put},
};
use reactions::{Reaction, WINDOW_MS, strength, window_id};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{
    collections::{HashMap, HashSet},
    convert::Infallible,
    path::PathBuf,
    sync::Arc,
    time::{Duration, SystemTime, UNIX_EPOCH},
};
use tokio::sync::{Mutex, broadcast};
use uuid::Uuid;

fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}

fn id() -> String {
    Uuid::new_v4().to_string()
}

fn clean(value: &str, length: usize) -> String {
    value.trim().chars().take(length).collect()
}

#[derive(Clone, Serialize, Deserialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
struct User {
    id: String,
    name: String,
    artist: String,
    song: String,
    color: String,
    visible: bool,
    event_id: Option<String>,
}

#[derive(Clone, Serialize, Deserialize)]
struct PublicUser {
    id: String,
    name: String,
    artist: String,
    song: String,
    color: String,
}

impl User {
    fn public(&self) -> PublicUser {
        PublicUser {
            id: self.id.clone(),
            name: self.name.clone(),
            color: self.color.clone(),
            artist: if self.visible {
                self.artist.clone()
            } else {
                String::new()
            },
            song: if self.visible {
                self.song.clone()
            } else {
                String::new()
            },
        }
    }
}

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Memory {
    id: String,
    user_id: String,
    event_id: String,
    at: u64,
    level: u8,
    person: PublicUser,
    favorite: bool,
}

struct LiveConnection {
    user_id: String,
}

struct Inner {
    users: HashMap<String, User>,
    reactions: HashMap<String, Reaction>,
    clients: HashMap<String, LiveConnection>,
    sides: HashMap<String, (Side, u64)>,
    last_window: u64,
}

struct App {
    inner: Mutex<Inner>,
    updates: broadcast::Sender<()>,
    store: Store,
    rssi_center_db: Option<f64>,
    events: Value,
    public_dir: PathBuf,
}

type Shared = Arc<App>;

#[derive(Debug)]
struct ApiError(StatusCode, String);

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (self.0, Json(json!({ "error": self.1 }))).into_response()
    }
}

fn error(status: StatusCode, text: &str) -> ApiError {
    ApiError(status, text.into())
}

fn bad(text: &str) -> ApiError {
    error(StatusCode::BAD_REQUEST, text)
}

type ApiResult<T> = Result<T, ApiError>;

impl From<sqlx::Error> for ApiError {
    fn from(error: sqlx::Error) -> Self {
        eprintln!("Database operation failed: {error}");
        self::error(
            StatusCode::SERVICE_UNAVAILABLE,
            "DBへの接続に問題が発生しました。もう一度お試しください。",
        )
    }
}

impl App {
    fn notify(&self) {
        let _ = self.updates.send(());
    }
}

async fn authenticated(headers: &HeaderMap, store: &Store) -> ApiResult<User> {
    let token = headers
        .get(header::COOKIE)
        .and_then(|v| v.to_str().ok())
        .and_then(|cookies| {
            cookies
                .split(';')
                .find_map(|item| item.trim().strip_prefix("feswave="))
        });

    if let Some(token) = token.filter(|t| t.len() <= 128) {
        if let Some(user) = store.session_user(token).await? {
            return Ok(user);
        }
    }

    Err(error(
        StatusCode::UNAUTHORIZED,
        "再読み込みして接続してください",
    ))
}

async fn session(State(app): State<Shared>, headers: HeaderMap) -> ApiResult<Response> {
    let mut inner = app.inner.lock().await;

    let (user, cookie) = match authenticated(&headers, &app.store).await {
        Ok(user) => (user, None),
        Err(e) if e.0 == StatusCode::UNAUTHORIZED => {
            let user = User {
                id: id(),
                name: String::new(),
                artist: "YOASOBI".into(),
                song: "群青".into(),
                color: "pink".into(),
                visible: false,
                event_id: None,
            };

            let token = id();
            app.store.create_session(&user, &token).await?;

            (
                user,
                Some(format!(
                    "feswave={token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=31536000"
                )),
            )
        }
        Err(e) => return Err(e),
    };

    inner.users.insert(user.id.clone(), user.clone());

    let mut response =
        Json(json!({"user":user,"events":app.events,"rssiCenterDb":app.rssi_center_db}))
            .into_response();

    if let Some(cookie) = cookie {
        response
            .headers_mut()
            .insert(header::SET_COOKIE, HeaderValue::from_str(&cookie).unwrap());
    }

    Ok(response)
}

#[derive(Deserialize)]
struct ProfileInput {
    name: String,
    #[serde(default)]
    artist: String,
    #[serde(default)]
    song: String,
    #[serde(default)]
    color: String,
    #[serde(default)]
    visible: bool,
}

async fn profile(
    State(app): State<Shared>,
    headers: HeaderMap,
    Json(input): Json<ProfileInput>,
) -> ApiResult<Json<User>> {
    let mut inner = app.inner.lock().await;
    let mut user = authenticated(&headers, &app.store).await?;

    let name = clean(&input.name, 20);
    if name.is_empty() {
        return Err(bad("ニックネームを入力してください"));
    }

    user.name = name;
    user.artist = clean(&input.artist, 60);
    user.song = clean(&input.song, 60);
    user.color = if ["pink", "blue", "purple", "orange"].contains(&input.color.as_str()) {
        input.color
    } else {
        "pink".into()
    };
    user.visible = input.visible;

    app.store.update_profile(&user).await?;
    inner.users.insert(user.id.clone(), user.clone());
    app.notify();

    Ok(Json(user))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct JoinInput {
    event_id: String,
}

async fn join_event(
    State(app): State<Shared>,
    headers: HeaderMap,
    Json(input): Json<JoinInput>,
) -> ApiResult<Json<Value>> {
    let mut inner = app.inner.lock().await;
    let mut user = authenticated(&headers, &app.store).await?;

    if user.name.is_empty() {
        return Err(bad("プロフィールを登録してください"));
    }

    if !app.store.event_exists(&input.event_id).await? {
        return Err(bad("イベントを選んでください"));
    }

    if user
        .event_id
        .as_deref()
        .is_some_and(|event_id| event_id != input.event_id.as_str())
    {
        return Err(error(
            StatusCode::CONFLICT,
            "参加後にイベントを変更することはできません",
        ));
    }

    app.store.join(&user.id, &input.event_id).await?;

    if user.event_id.as_deref() != Some(input.event_id.as_str()) {
        inner.reactions.retain(|_, r| r.user_id != user.id);
        inner.sides.remove(&user.id);
    }

    user.event_id = Some(input.event_id.clone());
    inner.users.insert(user.id.clone(), user);
    app.notify();

    Ok(Json(json!({"eventId":input.event_id})))
}

async fn settle(app: &App, inner: &mut Inner, time: u64) -> ApiResult<()> {
    let window = window_id(time);

    if window == inner.last_window {
        return Ok(());
    }

    let completed: Vec<_> = inner
        .reactions
        .values()
        .filter(|r| r.window < window)
        .cloned()
        .collect();

    let mut memories = Vec::new();

    for i in 0..completed.len() {
        for j in i + 1..completed.len() {
            let a = &completed[i];
            let b = &completed[j];

            if !reactions::matches(a, b) {
                continue;
            }

            if !inner.users.get(&a.user_id).is_some_and(|u| u.visible)
                || !inner.users.get(&b.user_id).is_some_and(|u| u.visible)
            {
                continue;
            }

            for (me, other) in [(a, b), (b, a)] {
                memories.push(Memory {
                    id: id(),
                    user_id: me.user_id.clone(),
                    event_id: me.event_id.clone(),
                    at: (me.window + 1) * WINDOW_MS,
                    level: strength(me.taps),
                    person: inner.users[&other.user_id].public(),
                    favorite: false,
                });
            }
        }
    }

    // Only discard the aggregation window after the database transaction commits.
    app.store.insert_memories(&memories).await?;
    inner.reactions.retain(|_, r| r.window >= window);
    inner.last_window = window;
    inner
        .sides
        .retain(|_, (_, seen)| time.saturating_sub(*seen) < 65_000);
    app.notify();

    Ok(())
}

async fn react(State(app): State<Shared>, headers: HeaderMap) -> ApiResult<Json<Value>> {
    let mut inner = app.inner.lock().await;
    let user = authenticated(&headers, &app.store).await?;

    let event_id = user
        .event_id
        .clone()
        .ok_or_else(|| bad("イベントに参加してください"))?;

    let uid = user.id.clone();
    inner.users.insert(uid.clone(), user);

    let time = now();
    settle(&app, &mut inner, time).await?;

    let window = window_id(time);
    let key = format!("{window}:{uid}");

    let reaction = inner.reactions.entry(key).or_insert(Reaction {
        user_id: uid,
        event_id,
        window,
        taps: 0,
        last_tap: 0,
    });

    if time.saturating_sub(reaction.last_tap) < 60 || reaction.taps >= 80 {
        return Err(error(
            StatusCode::TOO_MANY_REQUESTS,
            "少し待ってタップしてください",
        ));
    }

    reaction.taps += 1;
    reaction.last_tap = time;

    let response = json!({
        "taps": reaction.taps,
        "level": strength(reaction.taps),
        "windowEnds": (window + 1) * WINDOW_MS
    });

    app.notify();

    Ok(Json(response))
}

#[derive(Clone, Copy, Deserialize, Serialize)]
#[serde(rename_all = "lowercase")]
enum Side {
    Left,
    Right,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct PositionInput {
    event_id: String,
    side: Option<Side>,
}

async fn position(
    State(app): State<Shared>,
    headers: HeaderMap,
    Json(input): Json<PositionInput>,
) -> ApiResult<Json<Value>> {
    if app.rssi_center_db.is_none() {
        return Err(bad("会場測位は無効です"));
    }
    let mut inner = app.inner.lock().await;
    let user = authenticated(&headers, &app.store).await?;
    if user.event_id.as_deref() != Some(&input.event_id) {
        return Err(bad("イベントが一致しません"));
    }
    if let Some(side) = input.side {
        inner.sides.insert(user.id, (side, now()));
    } else {
        inner.sides.remove(&user.id);
    }
    app.notify();
    Ok(Json(json!({})))
}

fn snapshot(inner: &Inner, uid: &str) -> Value {
    let event_id = inner
        .users
        .get(uid)
        .and_then(|u| u.event_id.as_deref())
        .unwrap_or("");

    let time = now();
    let window = window_id(time);

    let online: HashSet<_> = inner
        .clients
        .values()
        .map(|c| &c.user_id)
        .filter(|id| {
            inner
                .users
                .get(*id)
                .is_some_and(|u| u.event_id.as_deref() == Some(event_id))
        })
        .collect();

    let mut users: Vec<_> = online.into_iter().collect();
    users.sort();

    let participants: Vec<_> = users
        .into_iter()
        .filter_map(|id| {
            let u = inner.users.get(id)?;

            let taps = inner
                .reactions
                .get(&format!("{window}:{id}"))
                .map_or(0, |r| r.taps);

            let mut value = serde_json::to_value(u.public()).ok()?;
            value["taps"] = json!(taps);
            value["level"] = json!(strength(taps));
            value["side"] = json!(
                inner
                    .sides
                    .get(id)
                    .filter(|(_, seen)| time.saturating_sub(*seen) < 65_000)
                    .map(|(side, _)| side)
            );

            Some(value)
        })
        .collect();

    json!({
        "eventId": event_id,
        "serverTime": time,
        "count": participants.len(),
        "participants": participants
    })
}

// The guard is dropped even when a browser disconnects while the stream is waiting.
struct ConnectionGuard {
    app: Shared,
    connection_id: String,
}

impl Drop for ConnectionGuard {
    fn drop(&mut self) {
        let app = self.app.clone();
        let id = self.connection_id.clone();

        tokio::spawn(async move {
            app.inner.lock().await.clients.remove(&id);
            app.notify();
        });
    }
}

async fn stream(State(app): State<Shared>, headers: HeaderMap) -> ApiResult<Response> {
    let mut inner = app.inner.lock().await;
    let user = authenticated(&headers, &app.store).await?;

    let uid = user.id.clone();
    inner.users.insert(uid.clone(), user);

    if inner.users[&uid].event_id.is_none() {
        return Err(bad("先にイベントに参加してください"));
    }

    let connection_id = id();

    inner.clients.insert(
        connection_id.clone(),
        LiveConnection {
            user_id: uid.clone(),
        },
    );

    let mut updates = app.updates.subscribe();
    let initial = snapshot(&inner, &uid).to_string();

    app.notify();
    drop(inner);

    let guard = ConnectionGuard {
        app: app.clone(),
        connection_id,
    };

    let output = async_stream::stream! {
        let _guard = guard;
        yield Ok::<_, Infallible>(Event::default().data(initial));

        loop {
            match updates.recv().await {
                Ok(()) | Err(broadcast::error::RecvError::Lagged(_)) => {
                    let value = snapshot(&*app.inner.lock().await, &uid).to_string();
                    yield Ok(Event::default().data(value));
                }
                Err(broadcast::error::RecvError::Closed) => break,
            }
        }
    };

    Ok(Sse::new(output)
        .keep_alive(KeepAlive::new().interval(Duration::from_secs(15)))
        .into_response())
}

async fn memories(State(app): State<Shared>, headers: HeaderMap) -> ApiResult<Json<Vec<Memory>>> {
    let user = authenticated(&headers, &app.store).await?;
    Ok(Json(app.store.memories(&user.id).await?))
}

#[derive(Deserialize)]
struct FavoriteInput {
    favorite: bool,
}

async fn favorite(
    State(app): State<Shared>,
    headers: HeaderMap,
    Path(memory_id): Path<String>,
    Json(input): Json<FavoriteInput>,
) -> ApiResult<Json<Memory>> {
    let user = authenticated(&headers, &app.store).await?;

    if Uuid::parse_str(&memory_id).is_err() {
        return Err(error(StatusCode::NOT_FOUND, "メモリが見つかりません"));
    }

    app.store
        .favorite(&user.id, &memory_id, input.favorite)
        .await?
        .map(Json)
        .ok_or_else(|| error(StatusCode::NOT_FOUND, "メモリが見つかりません"))
}

async fn static_file(State(app): State<Shared>, req: Request) -> Response {
    if req.method() != "GET" && req.method() != "HEAD" {
        return StatusCode::METHOD_NOT_ALLOWED.into_response();
    }

    let (file, content_type) = match req.uri().path() {
        "/" => ("index.html", "text/html; charset=utf-8"),
        "/venue-position.js" => ("venue-position.js", "text/javascript; charset=utf-8"),
        "/app.js" => ("app.js", "text/javascript; charset=utf-8"),
        "/styles.css" => ("styles.css", "text/css; charset=utf-8"),
        "/app-shell.css" => ("app-shell.css", "text/css; charset=utf-8"),
        "/favicon.svg" => ("favicon.svg", "image/svg+xml"),
        _ => return StatusCode::NOT_FOUND.into_response(),
    };

    match tokio::fs::read(app.public_dir.join(file)).await {
        Ok(data) => ([(header::CONTENT_TYPE, content_type)], data).into_response(),
        Err(_) => (StatusCode::NOT_FOUND, "Build frontend first: npm run build").into_response(),
    }
}

async fn security(State(app): State<Shared>, req: Request, next: Next) -> Response {
    if let Some(origin) = req
        .headers()
        .get(header::ORIGIN)
        .and_then(|v| v.to_str().ok())
    {
        let host = req
            .headers()
            .get(header::HOST)
            .and_then(|v| v.to_str().ok())
            .unwrap_or("");

        if origin != format!("http://{host}") && origin != format!("https://{host}") {
            return error(StatusCode::FORBIDDEN, "同じサイトから操作してください").into_response();
        }
    }

    let mut response = next.run(req).await;

    for (key, value) in [
        ("cache-control", "no-store"),
        ("x-content-type-options", "nosniff"),
        ("referrer-policy", "same-origin"),
        (
            "content-security-policy",
            if app.rssi_center_db.is_some() {
                "default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' http://192.168.4.1; script-src 'self'; base-uri 'none'; frame-ancestors 'none'"
            } else {
                "default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; script-src 'self'; base-uri 'none'; frame-ancestors 'none'"
            },
        ),
    ] {
        response.headers_mut().insert(
            axum::http::HeaderName::from_static(key),
            HeaderValue::from_static(value),
        );
    }

    response
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    dotenvy::from_path(root.join(".env")).ok();

    let database_url = std::env::var("DATABASE_URL").map_err(
        |_| "DATABASE_URLが未設定です。.env.exampleを.envへコピーしてDBを起動してください。",
    )?;

    let store = Store::connect(&database_url)
        .await
        .map_err(|_| "PostgreSQLに接続できません。DBの起動とDATABASE_URLを確認してください。")?;

    store.migrate().await?;

    let args: Vec<String> = std::env::args().collect();

    if args.get(1).is_some_and(|arg| arg == "--import-json") {
        let source = args.get(2).ok_or("Usage: feswave --import-json <path>")?;
        let counts = store.import_json(std::path::Path::new(source)).await?;
        println!("Imported legacy JSON: {counts}");
        return Ok(());
    }

    let users = store.users().await?;
    let events = store.events().await?;
    let (updates, _) = broadcast::channel(128);

    let rssi_center_db = std::env::var("FESWAVE_RSSI_CENTER_DB")
        .ok()
        .map(|s| s.parse::<f64>())
        .transpose()?;
    if rssi_center_db.is_some_and(|v| !v.is_finite()) {
        return Err("Invalid FESWAVE_RSSI_CENTER_DB".into());
    }
    let app = Arc::new(App {
        rssi_center_db,
        inner: Mutex::new(Inner {
            users,
            reactions: HashMap::new(),
            clients: HashMap::new(),
            sides: HashMap::new(),
            last_window: window_id(now()),
        }),
        updates,
        store,
        events,
        public_dir: root.join("public"),
    });

    let ticker = app.clone();

    tokio::spawn(async move {
        let mut tick = tokio::time::interval(Duration::from_millis(250));

        loop {
            tick.tick().await;
            let mut inner = ticker.inner.lock().await;

            if let Err(e) = settle(&ticker, &mut inner, now()).await {
                eprintln!("Settlement failed: {e:?}");
            }
        }
    });

    let router = Router::new()
        .route("/api/session", get(session))
        .route("/api/profile", put(profile))
        .route("/api/join", post(join_event))
        .route("/api/position", put(position))
        .route("/api/react", post(react))
        .route("/api/stream", get(stream))
        .route("/api/memories", get(memories))
        .route("/api/memories/{id}", patch(favorite))
        .fallback(static_file)
        .layer(DefaultBodyLimit::max(8192))
        .layer(middleware::from_fn_with_state(app.clone(), security))
        .with_state(app);

    let host = std::env::var("HOST").unwrap_or_else(|_| "127.0.0.1".into());
    let port = std::env::var("PORT").unwrap_or_else(|_| "3000".into());

    let listener = tokio::net::TcpListener::bind(format!("{host}:{port}")).await?;
    println!("FESWAVE (Rust + PostgreSQL) is ready: http://localhost:{port}");

    axum::serve(listener, router)
        .with_graceful_shutdown(async {
            let _ = tokio::signal::ctrl_c().await;
        })
        .await?;

    Ok(())
}
