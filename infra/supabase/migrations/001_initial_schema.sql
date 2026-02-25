-- Migration: 001_initial_schema.sql
-- Regatta Suite v2 — Initial Supabase PostgreSQL schema
-- Run via: supabase db push or supabase migration up

-- Extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ── Organizations (clubs / racing authorities) ────────────────────────────────
create table organizations (
    id          uuid primary key default uuid_generate_v4(),
    name        text not null,
    slug        text unique not null,     -- e.g. "royal-yacht-club"
    created_at  timestamptz not null default now()
);

-- ── Race Sessions ─────────────────────────────────────────────────────────────
create table race_sessions (
    id              uuid primary key default uuid_generate_v4(),
    org_id          uuid not null references organizations(id) on delete cascade,
    name            text not null,       -- e.g. "2026 Spring Series Race 3"
    status          text not null default 'IDLE'
                        check (status in ('IDLE','ACTIVE','FINISHED','ARCHIVED')),
    created_at      timestamptz not null default now(),
    finished_at     timestamptz,
    last_director_heartbeat timestamptz   -- used for failover detection
);

create index on race_sessions(org_id, status);

-- ── Race State Snapshots (append-only, Realtime enabled) ─────────────────────
-- Every state-update from the backend appends a new row.
-- Clients reconnecting query: SELECT * FROM race_snapshots WHERE session_id = $1 ORDER BY created_at DESC LIMIT 1
create table race_snapshots (
    id          bigserial primary key,
    session_id  uuid not null references race_sessions(id) on delete cascade,
    snapshot    jsonb not null,          -- full RaceState JSON
    created_at  timestamptz not null default now()
);

create index on race_snapshots(session_id, created_at desc);

-- Enable Supabase Realtime on race_snapshots
alter publication supabase_realtime add table race_snapshots;

-- ── Teams ─────────────────────────────────────────────────────────────────────
create table teams (
    id          uuid primary key,
    session_id  uuid not null references race_sessions(id) on delete cascade,
    name        text not null,
    club        text not null default '',
    skipper     text not null,
    crew_members text[] not null default array[]::text[],
    status      text not null default 'ACTIVE'
                    check (status in ('ACTIVE','DNS','DNF','WITHDRAWN')),
    created_at  timestamptz not null default now()
);

create index on teams(session_id);

-- ── Flights ───────────────────────────────────────────────────────────────────
create table flights (
    id              uuid primary key,
    session_id      uuid not null references race_sessions(id) on delete cascade,
    flight_number   int not null,
    group_label     text not null,
    status          text not null default 'SCHEDULED'
                        check (status in ('SCHEDULED','IN_PROGRESS','COMPLETED')),
    created_at      timestamptz not null default now()
);

create index on flights(session_id);

-- ── Pairings (boat ↔ team per flight) ────────────────────────────────────────
create table pairings (
    id          uuid primary key,
    session_id  uuid not null references race_sessions(id) on delete cascade,
    flight_id   uuid not null references flights(id) on delete cascade,
    boat_id     text not null,
    team_id     uuid not null references teams(id) on delete cascade
);

create index on pairings(session_id, flight_id);

-- ── Penalties ─────────────────────────────────────────────────────────────────
create table penalties (
    id          uuid primary key default uuid_generate_v4(),
    session_id  uuid not null references race_sessions(id) on delete cascade,
    boat_id     text not null,
    type        text not null,
    timestamp   bigint not null,   -- Unix ms
    created_at  timestamptz not null default now()
);

create index on penalties(session_id);

-- ── Course Definitions (named, reusable) ─────────────────────────────────────
create table course_definitions (
    id          uuid primary key default uuid_generate_v4(),
    org_id      uuid not null references organizations(id) on delete cascade,
    session_id  uuid references race_sessions(id) on delete set null,
    name        text not null default 'Unnamed Course',
    course_json jsonb not null,
    created_at  timestamptz not null default now()
);

-- ── Saved Procedures (named, reusable) ───────────────────────────────────────
create table procedures (
    id              uuid primary key default uuid_generate_v4(),
    org_id          uuid not null references organizations(id) on delete cascade,
    name            text not null,
    graph_json      jsonb not null,
    created_at      timestamptz not null default now()
);

-- ── Immutable Audit Log (protest-proof, SHA-256 chained) ─────────────────────
-- NO DELETE, NO UPDATE permitted via RLS.
-- Each row is one AuditBlock (see packages/uwb-types/src/lib.rs).
create table audit_log (
    id              bigserial primary key,
    session_id      uuid not null references race_sessions(id),
    block_seq       bigint not null,
    event_type      text not null,
    timestamp_ms    bigint not null,
    prev_hash       text not null,   -- SHA-256 of previous block (hex)
    payload_json    text not null,   -- serialized event payload
    block_hash      text not null,   -- SHA-256(prev_hash+timestamp+event_type+payload)
    created_at      timestamptz not null default now(),
    unique(session_id, block_seq)
);

create index on audit_log(session_id, block_seq);

-- ─────────────────────────────────────────────────────────────────────────────
-- Row Level Security (RLS)
-- ─────────────────────────────────────────────────────────────────────────────

alter table organizations      enable row level security;
alter table race_sessions      enable row level security;
alter table race_snapshots     enable row level security;
alter table teams              enable row level security;
alter table flights            enable row level security;
alter table pairings           enable row level security;
alter table penalties          enable row level security;
alter table course_definitions enable row level security;
alter table procedures         enable row level security;
alter table audit_log          enable row level security;

-- Backend service role bypasses RLS (SUPABASE_SERVICE_KEY)
-- All policies below apply to authenticated users (anon key)

-- Organizations: any authenticated user can read their own org
create policy "org_read" on organizations
    for select using (auth.uid() is not null);

-- Race sessions: read if in org (simplified — extend with org membership table)
create policy "session_read" on race_sessions
    for select using (auth.uid() is not null);

-- Audit log: READ ONLY for all authenticated users, no insert/update/delete from client
create policy "audit_read" on audit_log
    for select using (auth.uid() is not null);
-- Insert only via service role (backend) — no client-side insert policy

-- Snapshots: read for authenticated users
create policy "snapshot_read" on race_snapshots
    for select using (auth.uid() is not null);
