use crate::{Memory, PublicUser, User};
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
    pub async fn users(&self) -> Result<HashMap<String, User>, sqlx::Error> {
        let users = sqlx::query_as::<_, User>("SELECT u.id::text AS id,u.name,u.artist,u.song,u.color,u.visible,u.event_id FROM users u")
            .fetch_all(&self.pool)
            .await?;
        Ok(users.into_iter().map(|u| (u.id.clone(), u)).collect())
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
        sqlx::query_as::<_, User>("SELECT u.id::text AS id,u.name,u.artist,u.song,u.color,u.visible,u.event_id FROM users u JOIN sessions s ON s.user_id=u.id WHERE s.token_hash=$1 AND s.expires_at>NOW()")
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
        sqlx::query("UPDATE users SET name=$2,artist=$3,song=$4,color=$5,visible=$6,updated_at=NOW() WHERE id=$1::uuid")
            .bind(&user.id).bind(&user.name).bind(&user.artist).bind(&user.song).bind(&user.color).bind(user.visible).execute(&mut *tx).await?;
        if !user.visible {
            sqlx::query("DELETE FROM memories WHERE person_id=$1::uuid")
                .bind(&user.id)
                .execute(&mut *tx)
                .await?;
        }
        tx.commit().await
    }
    pub async fn event_exists(&self, id: &str) -> Result<bool, sqlx::Error> {
        sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM events WHERE id=$1)")
            .bind(id)
            .fetch_one(&self.pool)
            .await
    }
    pub async fn join(&self, uid: &str, event_id: &str) -> Result<(), sqlx::Error> {
        let mut tx = self.pool.begin().await?;
        sqlx::query("UPDATE users SET event_id=$2,updated_at=NOW() WHERE id=$1::uuid")
            .bind(uid)
            .bind(event_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("INSERT INTO event_participants(event_id,user_id) VALUES($1,$2::uuid) ON CONFLICT DO NOTHING").bind(event_id).bind(uid).execute(&mut *tx).await?;
        tx.commit().await
    }
    pub async fn insert_memories(&self, memories: &[Memory]) -> Result<(), sqlx::Error> {
        if memories.is_empty() {
            return Ok(());
        }
        let mut tx = self.pool.begin().await?;
        for m in memories {
            // Lock profiles before checking consent so a concurrent revocation cannot leave a new memory behind.
            let consenting = sqlx::query("SELECT id FROM users WHERE id IN ($1::uuid,$2::uuid) AND visible ORDER BY id FOR UPDATE")
                .bind(&m.user_id).bind(&m.person.id).fetch_all(&mut *tx).await?;
            if consenting.len() != 2 {
                continue;
            }
            sqlx::query("INSERT INTO memories(id,user_id,person_id,event_id,occurred_at,level,favorite) VALUES($1::uuid,$2::uuid,$3::uuid,$4,to_timestamp($5::bigint::double precision/1000.0),$6,$7) ON CONFLICT(user_id,person_id,event_id,occurred_at) DO NOTHING")
                .bind(&m.id).bind(&m.user_id).bind(&m.person.id).bind(&m.event_id).bind(m.at as i64).bind(m.level as i16).bind(m.favorite).execute(&mut *tx).await?;
        }
        tx.commit().await
    }
    pub async fn memories(&self, uid: &str) -> Result<Vec<Memory>, sqlx::Error> {
        let rows = sqlx::query("SELECT m.id::text AS id,m.user_id::text AS user_id,m.event_id,(EXTRACT(EPOCH FROM m.occurred_at)*1000)::bigint AS at_ms,m.level,m.favorite,u.id::text AS person_id,u.name,u.artist,u.song,u.color FROM memories m JOIN users u ON u.id=m.person_id WHERE m.user_id=$1::uuid AND u.visible ORDER BY m.occurred_at DESC,m.id")
            .bind(uid).fetch_all(&self.pool).await?;
        Ok(rows
            .iter()
            .map(|r| Memory {
                id: r.get("id"),
                user_id: r.get("user_id"),
                event_id: r.get("event_id"),
                at: r.get::<i64, _>("at_ms") as u64,
                level: r.get::<i16, _>("level") as u8,
                favorite: r.get("favorite"),
                person: PublicUser {
                    id: r.get("person_id"),
                    name: r.get("name"),
                    artist: r.get("artist"),
                    song: r.get("song"),
                    color: r.get("color"),
                },
            })
            .collect())
    }
    pub async fn favorite(
        &self,
        uid: &str,
        memory_id: &str,
        favorite: bool,
    ) -> Result<Option<Memory>, sqlx::Error> {
        let changed =
            sqlx::query("UPDATE memories SET favorite=$3 WHERE id=$1::uuid AND user_id=$2::uuid")
                .bind(memory_id)
                .bind(uid)
                .bind(favorite)
                .execute(&self.pool)
                .await?;
        if changed.rows_affected() == 0 {
            return Ok(None);
        }
        Ok(self
            .memories(uid)
            .await?
            .into_iter()
            .find(|m| m.id == memory_id))
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
