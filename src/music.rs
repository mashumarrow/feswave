use crate::{ApiResult, bad, error};
use axum::http::StatusCode;
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    time::{Duration, Instant},
};
use tokio::sync::Mutex;

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MusicTrack {
    pub track_id: i64,
    pub artist_name: String,
    pub track_name: String,
    pub collection_name: String,
    pub artwork_url: Option<String>,
    pub track_url: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct AppleTrack {
    kind: Option<String>,
    track_id: Option<i64>,
    artist_name: Option<String>,
    track_name: Option<String>,
    collection_name: Option<String>,
    artwork_url100: Option<String>,
    track_view_url: Option<String>,
}
#[derive(Deserialize)]
struct AppleResponse {
    results: Vec<AppleTrack>,
}

fn apple_url(value: &str, artwork: bool) -> Option<String> {
    let mut url = reqwest::Url::parse(value).ok()?;
    if url.scheme() == "http" {
        url.set_scheme("https").ok()?;
    }
    if url.scheme() != "https"
        || !url.username().is_empty()
        || url.password().is_some()
        || url.port().is_some()
    {
        return None;
    }
    let host = url.host_str()?;
    let allowed = if artwork {
        host.ends_with(".mzstatic.com")
    } else {
        host == "music.apple.com" || host == "itunes.apple.com"
    };
    allowed.then(|| url.to_string())
}
impl AppleTrack {
    fn normalize(self) -> Option<MusicTrack> {
        if self.kind.as_deref() != Some("song") {
            return None;
        }
        let track_id = self.track_id.filter(|id| *id > 0)?;
        Some(MusicTrack {
            track_id,
            artist_name: self.artist_name?,
            track_name: self.track_name?,
            collection_name: self.collection_name.unwrap_or_default(),
            artwork_url: self.artwork_url100.and_then(|s| apple_url(&s, true)),
            track_url: apple_url(&self.track_view_url?, false)?,
        })
    }
}

#[derive(Default)]
struct Cache {
    searches: HashMap<String, (Instant, Vec<MusicTrack>)>,
    tracks: HashMap<i64, (Instant, MusicTrack)>,
    last_request: Option<Instant>,
}
pub struct MusicService {
    client: reqwest::Client,
    cache: Mutex<Cache>,
    base_url: String,
}
impl MusicService {
    pub fn new() -> Result<Self, reqwest::Error> {
        Ok(Self {
            client: reqwest::Client::builder()
                .connect_timeout(Duration::from_secs(3))
                .timeout(Duration::from_secs(8))
                .redirect(reqwest::redirect::Policy::limited(3))
                .user_agent("FESWAVE/0.2")
                .build()?,
            cache: Mutex::new(Cache::default()),
            base_url: "https://itunes.apple.com".into(),
        })
    }
    pub async fn search(&self, term: &str) -> ApiResult<Vec<MusicTrack>> {
        let term = term.trim();
        if term.is_empty() {
            return Ok(vec![]);
        }
        if term.chars().count() > 100 {
            return Err(bad("検索キーワードは100文字以内で入力してください"));
        }
        let key = term.to_lowercase();
        let mut cache = self.cache.lock().await;
        if let Some((time, tracks)) = cache.searches.get(&key) {
            if time.elapsed() < Duration::from_secs(900) {
                return Ok(tracks.clone());
            }
        }
        let tracks = self
            .fetch(
                &mut cache,
                "search",
                &[
                    ("term", term.to_string()),
                    ("country", "JP".into()),
                    ("media", "music".into()),
                    ("entity", "song".into()),
                    ("limit", "12".into()),
                    ("lang", "ja_jp".into()),
                ],
            )
            .await?;
        cache
            .searches
            .retain(|_, (time, _)| time.elapsed() < Duration::from_secs(900));
        if cache.searches.len() >= 128 {
            cache.searches.clear();
        }
        cache.searches.insert(key, (Instant::now(), tracks.clone()));
        Ok(tracks)
    }
    pub async fn lookup(&self, id: i64) -> ApiResult<MusicTrack> {
        if id <= 0 {
            return Err(bad("曲を選び直してください"));
        }
        let mut cache = self.cache.lock().await;
        if let Some((time, track)) = cache.tracks.get(&id) {
            if time.elapsed() < Duration::from_secs(900) {
                return Ok(track.clone());
            }
        }
        self.fetch(
            &mut cache,
            "lookup",
            &[("id", id.to_string()), ("country", "JP".into())],
        )
        .await?
        .into_iter()
        .find(|t| t.track_id == id)
        .ok_or_else(|| bad("この曲は見つかりませんでした。別の曲を選んでください"))
    }
    async fn fetch(
        &self,
        cache: &mut Cache,
        path: &str,
        params: &[(&str, String)],
    ) -> ApiResult<Vec<MusicTrack>> {
        // Apple's documented limit is approximately 20 requests/minute. Cached selections do not consume a request.
        if cache
            .last_request
            .is_some_and(|t| t.elapsed() < Duration::from_millis(3100))
        {
            return Err(error(
                StatusCode::TOO_MANY_REQUESTS,
                "少し待ってから、もう一度検索してください",
            ));
        }
        cache.last_request = Some(Instant::now());
        let failure = || {
            error(
                StatusCode::BAD_GATEWAY,
                "iTunesに接続できませんでした。時間をおいて再検索するか、手入力で登録してください",
            )
        };
        let response = self
            .client
            .get(format!("{}/{path}", self.base_url))
            .query(params)
            .send()
            .await
            .map_err(|_| failure())?
            .error_for_status()
            .map_err(|_| failure())?;
        if response.content_length().is_some_and(|len| len > 1_000_000) {
            return Err(failure());
        }
        let response: AppleResponse = response.json().await.map_err(|_| failure())?;
        let mut seen = std::collections::HashSet::new();
        let tracks: Vec<_> = response
            .results
            .into_iter()
            .filter_map(AppleTrack::normalize)
            .filter(|track| seen.insert(track.track_id))
            .take(12)
            .collect();
        cache
            .tracks
            .retain(|_, (time, _)| time.elapsed() < Duration::from_secs(900));
        if cache.tracks.len() > 1536 {
            cache.tracks.clear();
        }
        for track in &tracks {
            cache
                .tracks
                .insert(track.track_id, (Instant::now(), track.clone()));
        }
        Ok(tracks)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[tokio::test]
    async fn search_normalizes_japanese_metadata_and_reuses_cache() {
        use axum::{Json, Router, routing::get};
        use std::sync::{
            Arc,
            atomic::{AtomicUsize, Ordering},
        };
        let hits = Arc::new(AtomicUsize::new(0));
        let counter = hits.clone();
        let router=Router::new().route("/search",get(move || {
            counter.fetch_add(1,Ordering::SeqCst);
            async { Json(serde_json::json!({"results":[{"kind":"song","trackId":123,"artistName":"アーティスト","trackName":"好きな曲","collectionName":"アルバム","artworkUrl100":"https://is1-ssl.mzstatic.com/image/cover.jpg","trackViewUrl":"https://music.apple.com/jp/album/123?app=itunes"},{"kind":"song","trackId":123,"artistName":"duplicate","trackName":"duplicate","trackViewUrl":"https://music.apple.com/jp/album/123"}]})) }
        }));
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let address = listener.local_addr().unwrap();
        let server = tokio::spawn(async move {
            axum::serve(listener, router).await.unwrap();
        });
        let mut service = MusicService::new().unwrap();
        service.base_url = format!("http://{address}");
        let tracks = service.search("テスト").await.unwrap();
        assert_eq!(tracks.len(), 1);
        assert_eq!(tracks[0].track_name, "好きな曲");
        assert_eq!(
            tracks[0].artwork_url.as_deref(),
            Some("https://is1-ssl.mzstatic.com/image/cover.jpg")
        );
        assert_eq!(service.search("テスト").await.unwrap()[0].track_id, 123);
        assert_eq!(
            service.lookup(123).await.unwrap().collection_name,
            "アルバム"
        );
        assert_eq!(hits.load(Ordering::SeqCst), 1);
        server.abort();
    }
    #[test]
    fn rejects_unsafe_urls_and_non_songs() {
        assert!(apple_url("javascript:alert(1)", false).is_none());
        assert!(apple_url("https://music.apple.com.evil.example/track", false).is_none());
        assert!(apple_url("https://example.com/cover.jpg", true).is_none());
        assert!(apple_url("https://x.mzstatic.com@evil.example/x", true).is_none());
        assert_eq!(
            apple_url("https://is1-ssl.mzstatic.com/image/cover.jpg", true).unwrap(),
            "https://is1-ssl.mzstatic.com/image/cover.jpg"
        );
        let entry: AppleTrack =
            serde_json::from_value(serde_json::json!({"kind":"music-video","trackId":1})).unwrap();
        assert!(entry.normalize().is_none());
    }
    #[tokio::test]
    async fn cached_lookup_validation_and_upstream_failure() {
        let mut service = MusicService::new().unwrap();
        let track = MusicTrack {
            track_id: 1,
            artist_name: "artist".into(),
            track_name: "track".into(),
            collection_name: "album".into(),
            artwork_url: None,
            track_url: "https://music.apple.com/jp/album/1".into(),
        };
        service
            .cache
            .lock()
            .await
            .tracks
            .insert(1, (Instant::now(), track));
        assert_eq!(service.lookup(1).await.unwrap().track_name, "track");
        assert!(service.search("").await.unwrap().is_empty());
        assert_eq!(
            service.search(&"a".repeat(101)).await.unwrap_err().0,
            StatusCode::BAD_REQUEST
        );
        assert!(service.lookup(0).await.is_err());
        service.base_url = "http://127.0.0.1:1".into();
        assert_eq!(
            service.search("offline").await.unwrap_err().0,
            StatusCode::BAD_GATEWAY
        );
        assert_eq!(
            service.search("again").await.unwrap_err().0,
            StatusCode::TOO_MANY_REQUESTS
        );
    }
}
