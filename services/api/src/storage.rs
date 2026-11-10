use crate::{Memory, User};
use serde::Deserialize;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use sqlx::{PgPool, Row, postgres::PgPoolOptions};
use std::{collections::HashMap, path::Path, time::Duration};

#[derive(Clone)]
pub struct Store {
    pub pool: PgPool,
}

fn token_hash(token: &str) -> String {
    format!("{:x}", Sha256::digest(token.as_bytes()))
}

impl Store {
    pub async fn google_challenge(&self, token: &str, nonce: &str) -> crate::ApiResult<String> {
        // Reuse a valid challenge so multiple tabs do not invalidate each other.
        let value = sqlx::query_scalar("UPDATE sessions SET google_login_nonce=CASE WHEN google_nonce_expires_at>NOW() THEN google_login_nonce ELSE $2 END,google_nonce_expires_at=CASE WHEN google_nonce_expires_at>NOW() THEN google_nonce_expires_at ELSE NOW()+INTERVAL '30 minutes' END WHERE token_hash=$1 AND expires_at>NOW() RETURNING google_login_nonce")
            .bind(token_hash(token)).bind(nonce).fetch_optional(&self.pool).await?;
        value.ok_or_else(|| {
            crate::error(
                axum::http::StatusCode::UNAUTHORIZED,
                "画面を再読み込みしてください。",
            )
        })
    }
    pub async fn linked(&self, user_id: &str) -> Result<bool, sqlx::Error> {
        sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM auth_identities WHERE user_id=$1::uuid AND provider='google')")
            .bind(user_id)
            .fetch_one(&self.pool)
            .await
    }

    /// First login claims this guest; subsequent logins always restore the existing account.
    /// Row locks serialize competing claims of a guest or a Google subject.
    pub async fn google_login(
        &self,
        uid: &str,
        guest_id: &str,
        old_token: &str,
        new_token: &str,
        nonce: &str,
    ) -> crate::ApiResult<User> {
        let mut tx = self.pool.begin().await?;
        // Lock the UID namespace before the user row to serialize simultaneous first logins.
        sqlx::query("SELECT pg_advisory_xact_lock(hashtextextended($1,0))")
            .bind(format!("google:{uid}"))
            .execute(&mut *tx)
            .await?;
        sqlx::query("SELECT id FROM users WHERE id=$1::uuid FOR UPDATE")
            .bind(guest_id)
            .fetch_one(&mut *tx)
            .await?;
        // Consume the session-bound nonce in this transaction. A token from a different
        // browser, an expired challenge, or a replay after session rotation is rejected.
        let consumed = sqlx::query("UPDATE sessions SET google_login_nonce=NULL,google_nonce_expires_at=NULL WHERE token_hash=$1 AND user_id=$2::uuid AND expires_at>NOW() AND google_login_nonce=$3 AND google_nonce_expires_at>NOW()")
            .bind(token_hash(old_token)).bind(guest_id).bind(nonce).execute(&mut *tx).await?;
        if consumed.rows_affected() != 1 {
            return Err(crate::error(
                axum::http::StatusCode::UNAUTHORIZED,
                "ログインの有効時間が切れました。画面を再読み込みしてやり直してください。",
            ));
        }
        let existing: Option<String> = sqlx::query_scalar(
            "SELECT user_id::text FROM auth_identities WHERE provider='google' AND subject=$1",
        )
        .bind(uid)
        .fetch_optional(&mut *tx)
        .await?;
        let user_id = if let Some(user_id) = existing {
            user_id
        } else {
            let linked: bool = sqlx::query_scalar(
                "SELECT EXISTS(SELECT 1 FROM auth_identities WHERE user_id=$1::uuid AND provider='google')",
            )
            .bind(guest_id)
            .fetch_one(&mut *tx)
            .await?;
            if linked {
                return Err(crate::error(
                    axum::http::StatusCode::CONFLICT,
                    "別のGoogleアカウントを使うには、先にログアウトしてください。",
                ));
            }
            sqlx::query("INSERT INTO auth_identities(provider,subject,user_id) VALUES('google',$1,$2::uuid)")
                .bind(uid).bind(guest_id).execute(&mut *tx).await?;
            // Previously issued guest cookies must not retain access to the claimed account.
            sqlx::query("DELETE FROM sessions WHERE user_id=$1::uuid")
                .bind(guest_id)
                .execute(&mut *tx)
                .await?;
            guest_id.to_owned()
        };
        sqlx::query("DELETE FROM sessions WHERE token_hash=$1")
            .bind(token_hash(old_token))
            .execute(&mut *tx)
            .await?;
        sqlx::query("INSERT INTO sessions(token_hash,user_id,expires_at) VALUES($1,$2::uuid,NOW()+INTERVAL '7 days')")
            .bind(token_hash(new_token)).bind(&user_id).execute(&mut *tx).await?;
        let user = sqlx::query_as::<_, User>("SELECT u.id::text AS id,u.name,u.artist,u.song,u.color,u.visible,u.event_id,u.music_track AS music,u.tracks,u.favorite_track_id FROM user_profiles u WHERE u.id=$1::uuid")
            .bind(&user_id).fetch_one(&mut *tx).await?;
        tx.commit().await?;
        Ok(user)
    }

    pub async fn delete_session(&self, token: &str) -> Result<(), sqlx::Error> {
        sqlx::query("DELETE FROM sessions WHERE token_hash=$1")
            .bind(token_hash(token))
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn connect(url: &str) -> Result<Self, sqlx::Error> {
        Ok(Self {
            pool: PgPoolOptions::new()
                .max_connections(10)
                .acquire_timeout(Duration::from_secs(5))
                .connect(url)
                .await?,
        })
    }
    pub async fn migrate(&self) -> Result<(), sqlx::migrate::MigrateError> {
        sqlx::migrate!().run(&self.pool).await
    }
    pub async fn events(&self) -> Result<Value, sqlx::Error> {
        let rows = sqlx::query("SELECT * FROM events ORDER BY sort_order, id")
            .fetch_all(&self.pool)
            .await?;
        Ok(Value::Array(rows.iter().map(|r| json!({
            "id":r.get::<String,_>("id"),"name":r.get::<String,_>("name"),"subtitle":r.get::<String,_>("subtitle"),
            "date":r.get::<String,_>("date_label"),"venue":r.get::<String,_>("venue"),"artist":r.get::<String,_>("artist"),
            "song":r.get::<String,_>("song"),"time":r.get::<String,_>("time_label"),"color":r.get::<String,_>("color")
        })).collect()))
    }
    pub async fn session_user(&self, token: &str) -> Result<Option<User>, sqlx::Error> {
        sqlx::query_as::<_, User>("SELECT u.id::text AS id,u.name,u.artist,u.song,u.color,u.visible,u.event_id,u.music_track AS music,u.tracks,u.favorite_track_id FROM user_profiles u JOIN sessions s ON s.user_id=u.id WHERE s.token_hash=$1 AND s.expires_at>NOW()")
            .bind(token_hash(token)).fetch_optional(&self.pool).await
    }
    pub async fn create_session(&self, user: &User, token: &str) -> Result<(), sqlx::Error> {
        let mut tx = self.pool.begin().await?;
        sqlx::query(
            "INSERT INTO users(id,name,artist,song,color,visible) VALUES($1::uuid,$2,$3,$4,$5,$6)",
        )
        .bind(&user.id)
        .bind(&user.name)
        .bind(&user.artist)
        .bind(&user.song)
        .bind(&user.color)
        .bind(user.visible)
        .execute(&mut *tx)
        .await?;
        sqlx::query("INSERT INTO sessions(token_hash,user_id) VALUES($1,$2::uuid)")
            .bind(token_hash(token))
            .bind(&user.id)
            .execute(&mut *tx)
            .await?;
        tx.commit().await
    }
    pub async fn update_profile(&self, user: &User) -> Result<(), sqlx::Error> {
        let mut tx = self.pool.begin().await?;
        sqlx::query("UPDATE users SET name=$2,artist=$3,song=$4,color=$5,visible=$6,music_track=$7,favorite_track_id=$8,updated_at=NOW() WHERE id=$1::uuid")
            .bind(&user.id).bind(&user.name).bind(&user.artist).bind(&user.song).bind(&user.color).bind(user.visible).bind(&user.music).bind(user.favorite_track_id).execute(&mut *tx).await?;
        sqlx::query("DELETE FROM user_tracks WHERE user_id=$1::uuid")
            .bind(&user.id)
            .execute(&mut *tx)
            .await?;
        for (position, track) in user.tracks.iter().enumerate() {
            sqlx::query("INSERT INTO user_tracks(user_id,track_id,track,position) VALUES($1::uuid,$2,$3,$4)")
                .bind(&user.id).bind(track.track_id).bind(sqlx::types::Json(track)).bind(position as i16).execute(&mut *tx).await?;
        }
        if !user.visible {
            sqlx::query("DELETE FROM memories WHERE person_id=$1::uuid")
                .bind(&user.id)
                .execute(&mut *tx)
                .await?;
        }
        tx.commit().await
    }
    pub async fn import_json(&self, path: &Path) -> Result<Value, Box<dyn std::error::Error>> {
        #[derive(Default, Deserialize)]
        #[serde(default)]
        struct Legacy {
            users: HashMap<String, User>,
            sessions: HashMap<String, String>,
            memories: Vec<Memory>,
        }
        let legacy: Legacy = serde_json::from_slice(&tokio::fs::read(path).await?)?;
        let mut tx = self.pool.begin().await?;
        let (mut users, mut sessions, mut memories) = (0, 0, 0);
        for user in legacy.users.values() {
            users += sqlx::query("INSERT INTO users(id,name,artist,song,color,visible,event_id) VALUES($1::uuid,$2,$3,$4,$5,$6,$7) ON CONFLICT DO NOTHING")
                .bind(&user.id).bind(&user.name).bind(&user.artist).bind(&user.song).bind(&user.color).bind(user.visible).bind(&user.event_id).execute(&mut *tx).await?.rows_affected();
            if let Some(event) = &user.event_id {
                sqlx::query("INSERT INTO event_participants(event_id,user_id) VALUES($1,$2::uuid) ON CONFLICT DO NOTHING").bind(event).bind(&user.id).execute(&mut *tx).await?;
            }
        }
        for (token, uid) in &legacy.sessions {
            sessions += sqlx::query("INSERT INTO sessions(token_hash,user_id) VALUES($1,$2::uuid) ON CONFLICT DO NOTHING").bind(token_hash(token)).bind(uid).execute(&mut *tx).await?.rows_affected();
        }
        for m in &legacy.memories {
            memories += sqlx::query("INSERT INTO memories(id,user_id,person_id,event_id,occurred_at,level,favorite) SELECT $1::uuid,a.id,b.id,$4,to_timestamp($5::bigint::double precision/1000.0),$6,$7 FROM users a,users b WHERE a.id=$2::uuid AND b.id=$3::uuid AND a.visible AND b.visible ON CONFLICT DO NOTHING")
                .bind(&m.id).bind(&m.user_id).bind(&m.person.id).bind(&m.event_id).bind(m.at as i64).bind(m.level as i16).bind(m.favorite).execute(&mut *tx).await?.rows_affected();
        }
        tx.commit().await?;
        Ok(json!({"users":users,"sessions":sessions,"memories":memories}))
    }
}
