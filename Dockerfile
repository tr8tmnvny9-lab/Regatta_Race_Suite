# ── Build stage ────────────────────────────────────────────────────────────────
FROM rust:1.77-slim-bookworm AS builder

# Install build dependencies (openssl needed by reqwest)
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Cache dependencies separately (faster rebuilds on source-only changes)
COPY Cargo.toml Cargo.lock ./
COPY packages/ packages/
COPY backend-rust/Cargo.toml backend-rust/Cargo.toml

# Dummy main to pre-compile dependencies
RUN mkdir -p backend-rust/src && echo "fn main(){}" > backend-rust/src/main.rs
RUN cargo build --release --package regatta-backend 2>/dev/null || true
RUN rm -f target/release/deps/regatta_backend*

# Build real binary
COPY backend-rust/src/ backend-rust/src/
RUN cargo build --release --package regatta-backend

# ── Runtime stage (~25 MB) ────────────────────────────────────────────────────
FROM debian:bookworm-slim

# curl   — required for Fly.io HEALTHCHECK
# ca-certificates — required for HTTPS/TLS (Supabase, Fly.io)
# libssl3 — OpenSSL runtime for reqwest TLS
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Non-root user for security
RUN useradd --no-create-home --shell /bin/false regatta

WORKDIR /app

COPY --from=builder /build/target/release/regatta-backend ./regatta-backend
RUN chmod +x ./regatta-backend

# Persistent volume mount point (Fly.io: audit.jsonl + state.json)
RUN mkdir -p /data && chown regatta:regatta /data

USER regatta

EXPOSE 3001
EXPOSE 5555/udp

# Fly.io restarts if /health returns non-200
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -sf http://localhost:3001/health || exit 1

ENV RUST_LOG=info
ENV BACKEND_MODE=cloud
ENV PORT=3001
ENV BINDADDR=0.0.0.0

CMD ["./regatta-backend"]
