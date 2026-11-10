use crate::{ApiResult, error, now};
use axum::http::StatusCode;
use jsonwebtoken::{Algorithm, DecodingKey, Validation, decode, decode_header, jwk::JwkSet};
use serde::{Deserialize, Serialize};
use std::time::{Duration, Instant};
use tokio::sync::Mutex;

const KEYS_URL: &str = "https://www.googleapis.com/oauth2/v3/certs";

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GoogleConfig {
    pub client_id: String,
}

impl GoogleConfig {
    pub fn from_env() -> Result<Option<Self>, String> {
        let client_id = std::env::var("GOOGLE_CLIENT_ID")
            .unwrap_or_default()
            .trim()
            .to_owned();
        if client_id.is_empty() {
            return Ok(None);
        }
        if !client_id.ends_with(".apps.googleusercontent.com")
            || !client_id
                .bytes()
                .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'.')
        {
            return Err(
                "GOOGLE_CLIENT_IDにWebアプリ用のOAuthクライアントIDを設定してください。".into(),
            );
        }
        Ok(Some(Self { client_id }))
    }
}

struct KeyCache {
    keys: JwkSet,
    expires: Instant,
}

pub struct GoogleAuth {
    pub config: Option<GoogleConfig>,
    client: reqwest::Client,
    cache: Mutex<Option<KeyCache>>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Claims {
    pub sub: String,
    aud: String,
    iss: String,
    exp: u64,
    iat: u64,
    pub nonce: String,
    #[serde(default)]
    azp: Option<String>,
}

fn invalid() -> crate::ApiError {
    error(
        StatusCode::UNAUTHORIZED,
        "Googleログインを確認できません。もう一度ログインしてください。",
    )
}

fn verify(token: &str, keys: &JwkSet, client_id: &str) -> ApiResult<Claims> {
    let header = decode_header(token).map_err(|_| invalid())?;
    if header.alg != Algorithm::RS256 {
        return Err(invalid());
    }
    let kid = header.kid.ok_or_else(invalid)?;
    let jwk = keys.find(&kid).ok_or_else(invalid)?;
    let key = DecodingKey::from_jwk(jwk).map_err(|_| invalid())?;
    let mut validation = Validation::new(Algorithm::RS256);
    validation.leeway = 0;
    validation.set_audience(&[client_id]);
    validation.set_issuer(&["https://accounts.google.com", "accounts.google.com"]);
    let claims = decode::<Claims>(token, &key, &validation)
        .map_err(|_| invalid())?
        .claims;
    let seconds = now() / 1000;
    if claims.sub.is_empty()
        || claims.sub.chars().count() > 128
        || claims.iat > seconds
        || seconds.saturating_sub(claims.iat) > 300
        || claims.nonce.is_empty()
        || claims.nonce.len() > 128
        || claims.azp.as_deref().is_some_and(|azp| azp != client_id)
    {
        return Err(invalid());
    }
    Ok(claims)
}

impl GoogleAuth {
    #[cfg(test)]
    pub async fn for_tests() -> Self {
        let config = GoogleConfig {
            client_id: "test-client.apps.googleusercontent.com".into(),
        };
        let auth = Self::new(Some(config)).unwrap();
        *auth.cache.lock().await = Some(KeyCache {
            keys: serde_json::from_str(include_str!("../test/fixtures/auth-test-jwks.json"))
                .unwrap(),
            expires: Instant::now() + Duration::from_secs(300),
        });
        auth
    }
    pub fn new(config: Option<GoogleConfig>) -> Result<Self, reqwest::Error> {
        Ok(Self {
            config,
            client: reqwest::Client::builder()
                .timeout(Duration::from_secs(10))
                .build()?,
            cache: Mutex::new(None),
        })
    }

    pub async fn verify(&self, token: &str) -> ApiResult<Claims> {
        let config = self.config.as_ref().ok_or_else(|| {
            error(
                StatusCode::SERVICE_UNAVAILABLE,
                "Googleログインは未設定です。管理者がOAuthクライアントIDを設定してください。",
            )
        })?;
        if token.len() > 12000 {
            return Err(invalid());
        }
        // Reject bad headers before any network request. Cached unknown kids are rejected
        // until Google's cache expires; attacker-controlled kids cannot trigger downloads.
        let header = decode_header(token).map_err(|_| invalid())?;
        if header.alg != Algorithm::RS256 || header.kid.is_none() {
            return Err(invalid());
        }
        let mut cache = self.cache.lock().await;
        if cache.as_ref().is_none_or(|c| c.expires <= Instant::now()) {
            let unavailable = || {
                error(
                    StatusCode::SERVICE_UNAVAILABLE,
                    "Googleの認証情報を取得できません。しばらくしてからお試しください。",
                )
            };
            let response = self
                .client
                .get(KEYS_URL)
                .send()
                .await
                .map_err(|_| unavailable())?
                .error_for_status()
                .map_err(|_| unavailable())?;
            let ttl = response
                .headers()
                .get("cache-control")
                .and_then(|h| h.to_str().ok())
                .and_then(|h| {
                    h.split(',')
                        .find_map(|s| s.trim().strip_prefix("max-age=")?.parse::<u64>().ok())
                })
                .unwrap_or(300)
                .clamp(1, 86400);
            let keys = response.json::<JwkSet>().await.map_err(|_| unavailable())?;
            *cache = Some(KeyCache {
                keys,
                expires: Instant::now() + Duration::from_secs(ttl),
            });
        }
        verify(token, &cache.as_ref().unwrap().keys, &config.client_id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use jsonwebtoken::{EncodingKey, Header, encode};

    fn keys() -> JwkSet {
        serde_json::from_str(include_str!("../test/fixtures/auth-test-jwks.json")).unwrap()
    }
    fn claims() -> Claims {
        let seconds = now() / 1000;
        Claims {
            sub: "google-sub-123".into(),
            aud: "test-client.apps.googleusercontent.com".into(),
            iss: "https://accounts.google.com".into(),
            exp: seconds + 3600,
            iat: seconds - 1,
            nonce: "test-nonce".into(),
            azp: None,
        }
    }
    fn token(claims: &Claims, kid: Option<&str>) -> String {
        let mut header = Header::new(Algorithm::RS256);
        header.kid = kid.map(str::to_owned);
        encode(
            &header,
            claims,
            &EncodingKey::from_rsa_pem(include_bytes!("../test/fixtures/auth-test-private.pem"))
                .unwrap(),
        )
        .unwrap()
    }

    #[test]
    fn accepts_only_valid_recent_google_tokens_for_this_client() {
        let valid = claims();
        assert_eq!(
            verify(
                &token(&valid, Some("test-key")),
                &keys(),
                "test-client.apps.googleusercontent.com"
            )
            .unwrap()
            .sub,
            valid.sub
        );
        let mut invalid_claims = Vec::new();
        let mut value = valid.clone();
        value.exp = now() / 1000 - 1;
        invalid_claims.push(value);
        let mut value = valid.clone();
        value.aud = "another-project".into();
        invalid_claims.push(value);
        let mut value = valid.clone();
        value.iss = "https://securetoken.google.com/other-project".into();
        invalid_claims.push(value);
        let mut value = valid.clone();
        value.sub.clear();
        invalid_claims.push(value);
        let mut value = valid.clone();
        value.sub = "x".repeat(129);
        invalid_claims.push(value);
        let mut value = valid.clone();
        value.iat = now() / 1000 + 60;
        invalid_claims.push(value);
        let mut value = valid.clone();
        value.nonce.clear();
        invalid_claims.push(value);
        let mut value = valid.clone();
        value.iat = now() / 1000 - 301;
        invalid_claims.push(value);
        let mut value = valid.clone();
        value.azp = Some("another-client".into());
        invalid_claims.push(value);
        for value in invalid_claims {
            assert!(
                verify(
                    &token(&value, Some("test-key")),
                    &keys(),
                    "test-client.apps.googleusercontent.com"
                )
                .is_err(),
                "Accepted invalid claims: {value:?}"
            );
        }
    }

    #[test]
    fn rejects_tampered_tokens_unknown_keys_and_algorithm_confusion() {
        let valid = claims();
        for kid in [None, Some("untrusted-key")] {
            assert!(
                verify(
                    &token(&valid, kid),
                    &keys(),
                    "test-client.apps.googleusercontent.com"
                )
                .is_err()
            );
        }
        let signed = token(&valid, Some("test-key"));
        let parts: Vec<_> = signed.split('.').collect();
        // A syntactically valid but modified signature must never pass verification.
        let fake = format!("{}.{}.{}", parts[0], parts[1], "A".repeat(parts[2].len()));
        assert!(verify(&fake, &keys(), "test-client.apps.googleusercontent.com").is_err());
        let hs = encode(
            &Header::new(Algorithm::HS256),
            &valid,
            &EncodingKey::from_secret(b"not-a-google-key"),
        )
        .unwrap();
        assert!(verify(&hs, &keys(), "test-client.apps.googleusercontent.com").is_err());
    }

    #[tokio::test]
    async fn uses_cached_google_keys_and_disabled_auth_never_accepts_tokens() {
        let config = GoogleConfig {
            client_id: "test-client.apps.googleusercontent.com".into(),
        };
        let auth = GoogleAuth::new(Some(config)).unwrap();
        *auth.cache.lock().await = Some(KeyCache {
            keys: keys(),
            expires: Instant::now() + Duration::from_secs(300),
        });
        assert!(
            auth.verify(&token(&claims(), Some("test-key")))
                .await
                .is_ok()
        );
        assert!(
            auth.verify(&token(&claims(), Some("unknown")))
                .await
                .is_err()
        );
        let disabled = GoogleAuth::new(None).unwrap();
        assert_eq!(
            disabled.verify("anything").await.unwrap_err().0,
            StatusCode::SERVICE_UNAVAILABLE
        );
    }
}
