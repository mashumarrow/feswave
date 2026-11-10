mod auth;
mod music;
mod storage;
use music::{MusicService, MusicTrack};
use storage::Store;

use axum::{
    Json, Router,
    extract::{DefaultBodyLimit, Query, Request, State},
    http::{HeaderMap, HeaderValue, StatusCode, header},
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::{get, post, put},
};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{
    collections::HashSet,
    path::PathBuf,
    sync::Arc,
    time::{SystemTime, UNIX_EPOCH},
};
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
    #[serde(default)]
    music: Option<sqlx::types::Json<MusicTrack>>,
    #[serde(default)]
    tracks: sqlx::types::Json<Vec<MusicTrack>>,
    #[serde(default)]
    favorite_track_id: Option<i64>,
}

#[derive(Clone, Serialize, Deserialize)]
struct PublicUser {
    id: String,
    name: String,
    artist: String,
    song: String,
    color: String,
    #[serde(default)]
    music: Option<sqlx::types::Json<MusicTrack>>,
    #[serde(default)]
    tracks: sqlx::types::Json<Vec<MusicTrack>>,
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

struct App {
    store: Store,
    events: Value,
    music: MusicService,
    auth: auth::GoogleAuth,
    cookie_secure: bool,
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

fn session_token(headers: &HeaderMap) -> Option<&str> {
    headers
        .get(header::COOKIE)
        .and_then(|v| v.to_str().ok())
        .and_then(|cookies| {
            cookies
                .split(';')
                .find_map(|item| item.trim().strip_prefix("feswave="))
        })
        .filter(|t| t.len() <= 128)
}

async fn authenticated(headers: &HeaderMap, store: &Store) -> ApiResult<User> {
    let token = session_token(headers);

    if let Some(token) = token {
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
                music: None,
                tracks: sqlx::types::Json(vec![]),
                favorite_track_id: None,
            };

            let token = id();
            app.store.create_session(&user, &token).await?;

            (user, Some(session_cookie(&app, &token, 31536000)))
        }
        Err(e) => return Err(e),
    };

    let linked = app.store.linked(&user.id).await?;
    let mut response = Json(json!({"user":user,"events":app.events,"account":{"google":linked},"google":app.auth.config})).into_response();

    if let Some(cookie) = cookie {
        response
            .headers_mut()
            .insert(header::SET_COOKIE, HeaderValue::from_str(&cookie).unwrap());
    }

    Ok(response)
}

fn session_cookie(app: &App, token: &str, age: u64) -> String {
    format!(
        "feswave={token}; HttpOnly; SameSite=Strict; Path=/; Max-Age={age}{}",
        if app.cookie_secure { "; Secure" } else { "" }
    )
}

fn auth_request(headers: &HeaderMap) -> ApiResult<()> {
    // Non-simple header forces cross-origin browser requests through a CORS preflight.
    if headers.get("x-feswave-auth").and_then(|v| v.to_str().ok()) != Some("1") {
        return Err(error(
            StatusCode::FORBIDDEN,
            "同じサイトのログイン画面から操作してください",
        ));
    }
    Ok(())
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct GoogleLoginInput {
    id_token: String,
}

async fn google_challenge(State(app): State<Shared>, headers: HeaderMap) -> ApiResult<Json<Value>> {
    auth_request(&headers)?;
    authenticated(&headers, &app.store).await?;
    if app.auth.config.is_none() {
        return Err(error(
            StatusCode::SERVICE_UNAVAILABLE,
            "Googleログインは準備中です。",
        ));
    }
    let nonce = app
        .store
        .google_challenge(session_token(&headers).unwrap_or_default(), &id())
        .await?;
    Ok(Json(json!({"nonce":nonce})))
}

async fn google_login(
    State(app): State<Shared>,
    headers: HeaderMap,
    Json(input): Json<GoogleLoginInput>,
) -> ApiResult<Response> {
    auth_request(&headers)?;
    let guest = authenticated(&headers, &app.store).await?;
    let claims = app.auth.verify(&input.id_token).await?;
    let token = id();
    let old_token = session_token(&headers).unwrap_or_default();
    let user = app
        .store
        .google_login(&claims.sub, &guest.id, old_token, &token, &claims.nonce)
        .await?;
    let mut response = Json(json!({"user":user})).into_response();
    response.headers_mut().insert(
        header::SET_COOKIE,
        HeaderValue::from_str(&session_cookie(&app, &token, 604800)).unwrap(),
    );
    Ok(response)
}

async fn logout(State(app): State<Shared>, headers: HeaderMap) -> ApiResult<Response> {
    auth_request(&headers)?;
    if let Some(token) = session_token(&headers) {
        app.store.delete_session(token).await?;
    }
    let mut response = Json(json!({"ok":true})).into_response();
    response.headers_mut().insert(
        header::SET_COOKIE,
        HeaderValue::from_str(&session_cookie(&app, "", 0)).unwrap(),
    );
    Ok(response)
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
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
    #[serde(default)]
    track_id: Option<i64>,
    #[serde(default)]
    track_ids: Option<Vec<i64>>,
    #[serde(default)]
    favorite_track_id: Option<i64>,
}

async fn profile(
    State(app): State<Shared>,
    headers: HeaderMap,
    Json(input): Json<ProfileInput>,
) -> ApiResult<Json<User>> {
    let previous = authenticated(&headers, &app.store).await?;
    let name = clean(&input.name, 20);
    if name.is_empty() {
        return Err(bad("ニックネームを入力してください"));
    }
    // Accept the old one-song request as well as the new collection request.
    let (track_ids, favorite_id) = match input.track_ids {
        Some(ids) => (ids, input.favorite_track_id),
        None => (input.track_id.into_iter().collect(), input.track_id),
    };
    validate_tracks(&track_ids, favorite_id)?;
    // Catalog requests happen outside the live-state lock so a slow search never blocks reactions.
    let mut tracks = Vec::new();
    for track_id in track_ids {
        let existing = previous
            .tracks
            .iter()
            .find(|track| track.track_id == track_id)
            .or_else(|| {
                previous
                    .music
                    .as_ref()
                    .map(|track| &track.0)
                    .filter(|track| track.track_id == track_id)
            });
        tracks.push(if let Some(track) = existing {
            track.clone()
        } else {
            app.music.lookup(track_id).await?
        });
    }
    let music = favorite_id
        .and_then(|id| tracks.iter().find(|track| track.track_id == id).cloned())
        .map(sqlx::types::Json);
    let mut user = authenticated(&headers, &app.store).await?;
    user.name = name;
    user.artist = clean(&input.artist, 60);
    user.song = clean(&input.song, 60);
    if let Some(track) = &music {
        user.artist = clean(&track.artist_name, 60);
        user.song = clean(&track.track_name, 60);
    }
    user.music = music;
    user.tracks = sqlx::types::Json(tracks);
    user.favorite_track_id = favorite_id;
    user.color = if ["pink", "blue", "purple", "orange"].contains(&input.color.as_str()) {
        input.color
    } else {
        "pink".into()
    };
    user.visible = input.visible;

    app.store.update_profile(&user).await?;

    Ok(Json(user))
}

fn validate_tracks(ids: &[i64], favorite: Option<i64>) -> ApiResult<()> {
    if ids.len() > 20 {
        return Err(bad("好きな曲は20曲まで登録できます"));
    }
    let unique: HashSet<_> = ids.iter().collect();
    if unique.len() != ids.len() || ids.iter().any(|id| *id <= 0) {
        return Err(bad("曲が重複しているか、曲IDが正しくありません"));
    }
    if ids.is_empty() && favorite.is_some()
        || !ids.is_empty() && !favorite.is_some_and(|id| ids.contains(&id))
    {
        return Err(bad("登録した曲の中から一番のお気に入りを1曲選んでください"));
    }
    Ok(())
}

#[cfg(test)]
mod profile_tests {
    use super::*;
    #[test]
    fn favorite_must_belong_to_a_unique_collection() {
        assert!(validate_tracks(&[], None).is_ok());
        assert!(validate_tracks(&[1, 2], Some(2)).is_ok());
        for (ids, primary) in [
            (vec![1, 1], Some(1)),
            (vec![1, 2], Some(3)),
            (vec![1], None),
            (vec![], Some(1)),
            (vec![-1], Some(-1)),
        ] {
            assert!(validate_tracks(&ids, primary).is_err());
        }
        assert!(validate_tracks(&(1..=20).collect::<Vec<_>>(), Some(1)).is_ok());
        assert!(validate_tracks(&(1..=21).collect::<Vec<_>>(), Some(1)).is_err());
    }
}

#[derive(Deserialize)]
struct MusicQuery {
    term: String,
}
async fn search_music(
    State(app): State<Shared>,
    headers: HeaderMap,
    Query(query): Query<MusicQuery>,
) -> ApiResult<Json<Value>> {
    authenticated(&headers, &app.store).await?;
    Ok(Json(
        json!({"results":app.music.search(&query.term).await?}),
    ))
}

async fn security(req: Request, next: Next) -> Response {
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
        ("referrer-policy", "strict-origin-when-cross-origin"),
        ("cross-origin-opener-policy", "same-origin-allow-popups"),
        (
            "content-security-policy",
            "default-src 'self'; style-src 'self' 'unsafe-inline' https://accounts.google.com/gsi/style; img-src 'self' data: https://*.mzstatic.com https://accounts.google.com; connect-src 'self' https://accounts.google.com/gsi/; script-src 'self' https://accounts.google.com/gsi/client; frame-src https://accounts.google.com/gsi/; base-uri 'none'; frame-ancestors 'none'; object-src 'none'",
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

    let events = store.events().await?;
    let app = Arc::new(App {
        store,
        events,
        music: MusicService::new()?,
        auth: auth::GoogleAuth::new(auth::GoogleConfig::from_env()?)?,
        cookie_secure: std::env::var("COOKIE_SECURE").is_ok_and(|v| v == "true"),
    });

    let router = router(app);

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

fn router(app: Shared) -> Router {
    Router::new()
        .route("/api/session", get(session))
        .route("/api/auth/google", post(google_login))
        .route("/api/auth/challenge", post(google_challenge))
        .route("/api/auth/logout", post(logout))
        .route("/api/profile", put(profile))
        .route("/api/music/search", get(search_music))
        .layer(DefaultBodyLimit::max(16384))
        .layer(middleware::from_fn(security))
        .with_state(app)
}

#[cfg(test)]
mod auth_tests;
