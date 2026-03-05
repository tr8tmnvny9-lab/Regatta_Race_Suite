-- 001_aurora_schema.sql
-- Run this against your Amazon Aurora Serverless v2 PostgreSQL database.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Heartbeat & Session Management
CREATE TABLE IF NOT EXISTS race_sessions (
    session_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    race_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_director_heartbeat TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Note: The CloudSyncManager uses this to push a heartbeat every 5s.
-- The Standby Mac / Trackers can query this: 
-- `SELECT extract(epoch from (now() - last_director_heartbeat)) > 10 as is_dead`

-- 2. Immutable Audit Log Chain
CREATE TABLE IF NOT EXISTS audit_log (
    log_id BIGSERIAL PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES race_sessions(session_id),
    block_seq BIGINT NOT NULL,
    prev_hash VARCHAR(64) NOT NULL,
    block_hash VARCHAR(64) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(session_id, block_seq),
    UNIQUE(block_hash)
);

-- Strict Invariant: No Updates or Deletes on Audit Log
CREATE RULE prevent_audit_update AS ON UPDATE TO audit_log DO INSTEAD NOTHING;
CREATE RULE prevent_audit_delete AS ON DELETE TO audit_log DO INSTEAD NOTHING;


-- 3. Live State Snapshots (Media Portal / Trackers)
CREATE TABLE IF NOT EXISTS race_snapshots (
    session_id UUID PRIMARY KEY REFERENCES race_sessions(session_id),
    raw_state JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
