//! cloud_sync.rs
//! 
//! Manages connection and state mirroring to Amazon Aurora PostgreSQL Serverless v2.
//! Satisfies AWS Phase 1 requirement: Establish the "RegattaPro CloudVM" resilient center.
//! 
//! Features:
//! 1. PostgreSQL Connection Pool via `sqlx`
//! 2. Heartbeat failover (updates `last_director_heartbeat` continuously)
//! 3. Realtime state push (upserts `state.json` into Aurora for Juror/Media Portal consumption)

use std::sync::Arc;
use tokio::sync::RwLock;
use sqlx::postgres::PgPoolOptions;
use sqlx::{Pool, Postgres};
use redis::AsyncCommands;
use tracing::{info, warn, debug};
use std::time::Duration;
use uuid::Uuid;

use crate::state::RaceState;
use crate::audit::AuditBlock;

pub struct CloudSyncManager {
    pool: Pool<Postgres>,
    redis_client: Option<redis::Client>,
    session_id: String,
}

impl CloudSyncManager {
    /// Connects to Amazon Aurora and ElastiCache (if provided)
    pub async fn connect(db_url: &str, redis_url: Option<String>, session_id: String) -> Result<Self, sqlx::Error> {
        info!("☁️ Connecting to Amazon Aurora: {}", session_id);
        
        let pool = PgPoolOptions::new()
            .max_connections(5)
            .acquire_timeout(Duration::from_secs(5))
            .connect(db_url)
            .await?;

        let redis_client = if let Some(url) = redis_url {
            info!("🔴 Connecting to Amazon ElastiCache (Redis PUB/SUB)");
            redis::Client::open(url).ok()
        } else {
            None
        };
            
        Ok(Self { pool, redis_client, session_id })
    }

    /// Background task: Pings the DB every 5 seconds to assert the Local Primary is alive.
    /// If the SNPN bubble goes down, this heartbeat stops, and Trackers fallback to Cloud Primary.
    pub async fn run_heartbeat_loop(self: Arc<Self>) {
        let mut interval = tokio::time::interval(Duration::from_secs(5));
        loop {
            interval.tick().await;
            
            let query_result = sqlx::query(
                r#"
                UPDATE race_sessions 
                SET last_director_heartbeat = NOW() 
                WHERE session_id = $1
                "#
            )
            .bind(Uuid::parse_str(&self.session_id).unwrap_or_default())
            .execute(&self.pool)
            .await;

            match query_result {
                Ok(_) => debug!("❤️ Aurora Heartbeat OK"),
                Err(e) => warn!("Aurora Heartbeat Failed: {e}"),
            }
        }
    }

    /// Background task: Syncs the high-speed local telemetry state to Aurora every 2 seconds.
    pub async fn run_state_sync_loop(self: Arc<Self>, shared_state: Arc<RwLock<RaceState>>) {
        let mut interval = tokio::time::interval(Duration::from_secs(2));
        loop {
            interval.tick().await;

            let state_json = {
                let s = shared_state.read().await;
                match serde_json::to_value(&*s) {
                    Ok(val) => val,
                    Err(e) => {
                        warn!("Failed to serialize state for Aurora sync: {e}");
                        continue;
                    }
                }
            };

            let query_result = sqlx::query(
                r#"
                INSERT INTO race_snapshots (session_id, raw_state)
                VALUES ($1, $2)
                ON CONFLICT (session_id) 
                DO UPDATE SET raw_state = EXCLUDED.raw_state, updated_at = NOW()
                "#
            )
            .bind(Uuid::parse_str(&self.session_id).unwrap_or_default())
            .bind(state_json)
            .execute(&self.pool)
            .await;

            if let Err(e) = query_result {
                warn!("Aurora State Sync Failed: {e}");
            }

            // AWS ElastiCache Horizontal Scaling: Broadcast state to other Fargate instances
            if let Some(client) = &self.redis_client {
                if let Ok(mut con) = client.get_multiplexed_async_connection().await {
                    let channel = format!("regatta_state_{}", self.session_id);
                    let payload = serde_json::to_string(&state_json).unwrap_or_default();
                    if let Err(e) = con.publish::<_, _, ()>(channel, payload).await {
                        warn!("Redis Pub/Sub Sync Failed: {e}");
                    }
                }
            }
        }
    }

    /// Writes an immutable Audit Block natively to Aurora.
    /// This satisfies the Invariant: "No component is permitted UPDATE or DELETE access."
    pub async fn push_audit_block(&self, block: &AuditBlock) {
        let payload = match serde_json::to_value(&block) {
            Ok(v) => v,
            Err(_) => return,
        };

        let query_result = sqlx::query(
            r#"
            INSERT INTO audit_log (session_id, block_seq, prev_hash, block_hash, event_type, payload)
            VALUES ($1, $2, $3, $4, $5, $6)
            "#
        )
        .bind(Uuid::parse_str(&self.session_id).unwrap_or_default())
        .bind(block.block_seq as i64)
        .bind(&block.prev_hash)
        .bind(&block.block_hash)
        .bind(block.event_type.to_string())
        .bind(payload)
        .execute(&self.pool)
        .await;

        if let Err(e) = query_result {
            warn!("Aurora Audit Push Failed: {e}");
        }
    }
}
