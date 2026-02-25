# ── Build stage ────────────────────────────────────────────────────────────────
FROM rust:1.77-slim-bookworm AS builder

WORKDIR /build

# Cache dependencies separately (layer caching)
COPY Cargo.toml Cargo.lock ./
COPY packages/ packages/
COPY backend-rust/Cargo.toml backend-rust/Cargo.toml

# Create dummy main to cache deps build
RUN mkdir -p backend-rust/src && echo "fn main(){}" > backend-rust/src/main.rs
RUN cargo build --release --package regatta-backend 2>/dev/null || true
RUN rm -f target/release/deps/regatta_backend*

# Build real source
COPY backend-rust/src/ backend-rust/src/
RUN cargo build --release --package regatta-backend

# ── Runtime stage ──────────────────────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN useradd --no-create-home --shell /bin/false regatta

WORKDIR /app

COPY --from=builder /build/target/release/regatta-backend ./regatta-backend
RUN chmod +x ./regatta-backend

# Data directory for persistent volume mount
RUN mkdir -p /data && chown regatta:regatta /data

USER regatta

EXPOSE 3001
EXPOSE 5555/udp

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:3001/health || exit 1

ENV RUST_LOG=info
ENV BACKEND_MODE=cloud
ENV PORT=3001
ENV BINDADDR=0.0.0.0

CMD ["./regatta-backend"]
