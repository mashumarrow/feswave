//! End-to-end auth test with real PostgreSQL and a test-only signing key cache.
//! The release/debug application has no fake-token or emulator bypass.
use super::*;
use jsonwebtoken::{Algorithm, EncodingKey, Header, encode};

fn token(uid: &str, nonce: &str) -> String {
    let mut header = Header::new(Algorithm::RS256);
    header.kid = Some("test-key".into());
    let seconds = now() / 1000;
    encode(&header, &json!({"sub":uid,"aud":"test-client.apps.googleusercontent.com","iss":"https://accounts.google.com","exp":seconds+3600,"iat":seconds,"nonce":nonce}), &EncodingKey::from_rsa_pem(include_bytes!("../test/fixtures/auth-test-private.pem")).unwrap()).unwrap()
}

async fn challenge(client: &reqwest::Client, base: &str, cookie: &str) -> String {
    let response = client
        .post(format!("{base}/auth/challenge"))
        .header("X-Feswave-Auth", "1")
        .header("Cookie", cookie)
        .json(&json!({}))
        .send()
        .await
        .unwrap();
    assert_eq!(response.status(), 200);
    response.json::<Value>().await.unwrap()["nonce"]
        .as_str()
        .unwrap()
        .to_owned()
}

fn cookie(response: &reqwest::Response) -> String {
    response
        .headers()
        .get("set-cookie")
        .unwrap()
        .to_str()
        .unwrap()
        .split(';')
        .next()
        .unwrap()
        .to_owned()
}

#[tokio::test]
async fn google_login_links_restores_rotates_and_logout_revokes_access() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let env: HashMap<String, String> = dotenvy::from_path_iter(root.join(".env"))
        .ok()
        .into_iter()
        .flatten()
        .filter_map(Result::ok)
        .collect();
    let database_url = std::env::var("TEST_DATABASE_URL")
        .or_else(|_| std::env::var("DATABASE_URL"))
        .unwrap_or_else(|_| {
            env.get("DATABASE_URL")
                .expect("Start PostgreSQL and configure DATABASE_URL before running tests")
                .clone()
        });
    let admin = sqlx::PgPool::connect(&database_url).await.unwrap();
    let schema = format!("feswave_test_{}", Uuid::new_v4().simple());
    // The identifier consists solely of our fixed prefix and a generated UUID.
    sqlx::query(sqlx::AssertSqlSafe(format!("CREATE SCHEMA {schema}")))
        .execute(&admin)
        .await
        .unwrap();
    let mut url = reqwest::Url::parse(&database_url).unwrap();
    url.query_pairs_mut()
        .append_pair("options", &format!("-csearch_path={schema}"));
    let store = Store::connect(url.as_str()).await.unwrap();
    store.migrate().await.unwrap();
    let (updates, _) = broadcast::channel(128);
    let app = Arc::new(App {
        inner: Mutex::new(Inner {
            users: HashMap::new(),
            reactions: HashMap::new(),
            clients: HashMap::new(),
            last_window: window_id(now()),
        }),
        updates,
        events: store.events().await.unwrap(),
        store: store.clone(),
        public_dir: root.join("public"),
        music: MusicService::new().unwrap(),
        auth: auth::GoogleAuth::for_tests().await,
        cookie_secure: true,
    });
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let base = format!("http://{}/api", listener.local_addr().unwrap());
    let server = tokio::spawn(async move { axum::serve(listener, router(app)).await.unwrap() });
    let test_store = store.clone();
    // Catch assertion failures in a separate task so cleanup also runs on failure.
    let result = tokio::spawn(async move {
        let client = reqwest::Client::new();
        let session = client.get(format!("{base}/session")).send().await.unwrap();
        let guest_cookie = cookie(&session);
        let guest: Value = session.json().await.unwrap();
        let uid = guest["user"]["id"].as_str().unwrap();
        assert_eq!(guest["account"]["google"], false);
        let mut user = test_store
            .session_user(guest_cookie.strip_prefix("feswave=").unwrap())
            .await
            .unwrap()
            .unwrap();
        user.name = "引き継ぐプロフィール".into();
        // Use a stored, trusted track snapshot so this test needs no iTunes network call.
        let track = MusicTrack {
            track_id: 123,
            artist_name: "Artist".into(),
            track_name: "Favorite".into(),
            collection_name: "Album".into(),
            artwork_url: None,
            track_url: "https://music.apple.com/jp/album/123".into(),
        };
        user.music = Some(sqlx::types::Json(track.clone()));
        user.tracks = sqlx::types::Json(vec![track]);
        user.favorite_track_id = Some(123);
        test_store.update_profile(&user).await.unwrap();
        let nonce = challenge(&client, &base, &guest_cookie).await;
        assert_eq!(
            challenge(&client, &base, &guest_cookie).await,
            nonce,
            "Tabs should reuse a valid challenge"
        );
        let wrong_nonce = client
            .post(format!("{base}/auth/google"))
            .header("X-Feswave-Auth", "1")
            .header("Cookie", &guest_cookie)
            .json(&json!({"idToken":token("google-one", "wrong-browser")}))
            .send()
            .await
            .unwrap();
        assert_eq!(wrong_nonce.status(), 401);
        sqlx::query("UPDATE sessions SET google_nonce_expires_at=NOW()-INTERVAL '1 minute'")
            .execute(&test_store.pool)
            .await
            .unwrap();
        let expired = client
            .post(format!("{base}/auth/google"))
            .header("X-Feswave-Auth", "1")
            .header("Cookie", &guest_cookie)
            .json(&json!({"idToken":token("google-one", &nonce)}))
            .send()
            .await
            .unwrap();
        assert_eq!(expired.status(), 401);
        let nonce = challenge(&client, &base, &guest_cookie).await;
        let login = || {
            client
                .post(format!("{base}/auth/google"))
                .header("X-Feswave-Auth", "1")
                .header("Cookie", &guest_cookie)
                .json(&json!({"idToken":token("google-one", &nonce)}))
        };
        let rejected = client
            .post(format!("{base}/auth/google"))
            .header("Cookie", &guest_cookie)
            .json(&json!({"idToken":token("google-one", &nonce)}))
            .send()
            .await
            .unwrap();
        assert_eq!(rejected.status(), 403);
        assert_eq!(
            login()
                .header("Origin", "https://attacker.example")
                .send()
                .await
                .unwrap()
                .status(),
            403
        );
        assert_eq!(
            client
                .post(format!("{base}/auth/google"))
                .header("Cookie", &guest_cookie)
                .header("X-Feswave-Auth", "1")
                .json(&json!({"idToken":"forged"}))
                .send()
                .await
                .unwrap()
                .status(),
            401
        );
        let response = login().send().await.unwrap();
        assert_eq!(response.status(), 200);
        assert!(
            response.headers()["set-cookie"]
                .to_str()
                .unwrap()
                .contains("; Secure")
        );
        let account_cookie = cookie(&response);
        assert_ne!(guest_cookie, account_cookie);
        let data: Value = response.json().await.unwrap();
        assert_eq!(data["user"]["id"], uid);
        assert_eq!(data["user"]["name"], "引き継ぐプロフィール");
        assert_eq!(data["user"]["favoriteTrackId"], 123);
        assert_eq!(data["user"]["tracks"].as_array().unwrap().len(), 1);
        assert!(
            test_store
                .session_user(guest_cookie.strip_prefix("feswave=").unwrap())
                .await
                .unwrap()
                .is_none()
        );
        let linked: Value = client
            .get(format!("{base}/session"))
            .header("Cookie", &account_cookie)
            .send()
            .await
            .unwrap()
            .json()
            .await
            .unwrap();
        assert_eq!(linked["account"]["google"], true);
        // A second browser restores this account, rather than replacing it with a new guest.
        let second = client.get(format!("{base}/session")).send().await.unwrap();
        let second_cookie = cookie(&second);
        let second_nonce = challenge(&client, &base, &second_cookie).await;
        let replay = client
            .post(format!("{base}/auth/google"))
            .header("X-Feswave-Auth", "1")
            .header("Cookie", &second_cookie)
            .json(&json!({"idToken":token("google-one", &nonce)}))
            .send()
            .await
            .unwrap();
        assert_eq!(
            replay.status(),
            401,
            "A token issued for another browser must be rejected"
        );
        let restored = client
            .post(format!("{base}/auth/google"))
            .header("X-Feswave-Auth", "1")
            .header("Cookie", &second_cookie)
            .json(&json!({"idToken":token("google-one", &second_nonce)}))
            .send()
            .await
            .unwrap();
        assert_eq!(restored.status(), 200);
        let restored_cookie = cookie(&restored);
        assert_eq!(restored.json::<Value>().await.unwrap()["user"]["id"], uid);
        let conflict_nonce = challenge(&client, &base, &restored_cookie).await;
        let conflict = client
            .post(format!("{base}/auth/google"))
            .header("X-Feswave-Auth", "1")
            .header("Cookie", &restored_cookie)
            .json(&json!({"idToken":token("google-two", &conflict_nonce)}))
            .send()
            .await
            .unwrap();
        assert_eq!(conflict.status(), 409);
        let logout = client
            .post(format!("{base}/auth/logout"))
            .header("X-Feswave-Auth", "1")
            .header("Cookie", &restored_cookie)
            .json(&json!({}))
            .send()
            .await
            .unwrap();
        assert_eq!(logout.status(), 200);
        assert!(
            logout.headers()["set-cookie"]
                .to_str()
                .unwrap()
                .contains("Max-Age=0")
        );
        assert!(
            test_store
                .session_user(restored_cookie.strip_prefix("feswave=").unwrap())
                .await
                .unwrap()
                .is_none()
        );
        // Logout only revokes this browser; another logged-in browser is retained.
        assert!(
            test_store
                .session_user(account_cookie.strip_prefix("feswave=").unwrap())
                .await
                .unwrap()
                .is_some()
        );
        let fresh: Value = client
            .get(format!("{base}/session"))
            .header("Cookie", &restored_cookie)
            .send()
            .await
            .unwrap()
            .json()
            .await
            .unwrap();
        assert_ne!(fresh["user"]["id"], uid);
        assert_eq!(fresh["account"]["google"], false);
    })
    .await;
    server.abort();
    let _ = server.await;
    store.pool.close().await;
    sqlx::query(sqlx::AssertSqlSafe(format!("DROP SCHEMA {schema} CASCADE")))
        .execute(&admin)
        .await
        .unwrap();
    admin.close().await;
    result.unwrap();
}
