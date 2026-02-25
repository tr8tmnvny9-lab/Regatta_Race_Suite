# Regatta Suite — Developer Commands
# Install: brew install just

# ── Development ────────────────────────────────────────────────────────────────

# Start backend (Rust) + frontend (React) in parallel
dev:
    #!/usr/bin/env bash
    trap 'kill 0' SIGINT
    (cd backend-rust && cargo run) &
    (cd frontend && npm run dev) &
    wait

# Start backend only
backend:
    cd backend-rust && cargo run

# Start frontend only
frontend:
    cd frontend && npm run dev

# ── Type checking ─────────────────────────────────────────────────────────────

# Check all TypeScript
typecheck:
    cd frontend && npx tsc --noEmit
    cd regatta-core && npx tsc --noEmit

# Check all Rust
check:
    cd backend-rust && cargo check --all-targets

# Lint Rust
lint:
    cd backend-rust && cargo clippy --all-targets --all-features -- -D warnings

# Lint + format Rust
fmt:
    cd backend-rust && cargo fmt --all

# ── Testing ───────────────────────────────────────────────────────────────────

# Run all Rust tests
test:
    cd backend-rust && cargo test --all-targets

# Run backend tests with output
test-verbose:
    cd backend-rust && cargo test --all-targets -- --nocapture

# ── Build ─────────────────────────────────────────────────────────────────────

# Build Rust backend for Apple Silicon (for Mac app sidecar)
build-mac:
    cd backend-rust && cargo build --release --target aarch64-apple-darwin
    @echo "✅ Binary: backend-rust/target/aarch64-apple-darwin/release/regatta-backend"

# Build Rust backend for Intel Mac
build-mac-intel:
    cd backend-rust && cargo build --release --target x86_64-apple-darwin

# Build universal binary (fat binary, both architectures)
build-universal:
    just build-mac
    just build-mac-intel
    lipo -create \
        backend-rust/target/aarch64-apple-darwin/release/regatta-backend \
        backend-rust/target/x86_64-apple-darwin/release/regatta-backend \
        -output backend-rust/target/release/regatta-backend-universal
    @echo "✅ Universal binary: backend-rust/target/release/regatta-backend-universal"

# Build frontend production bundle
build-frontend:
    cd frontend && npm run build

# ── Git ────────────────────────────────────────────────────────────────────────

# Quick push: add all, commit with message, push
push message:
    git add -A
    git commit -m "{{message}}"
    git push

# ── Utilities ─────────────────────────────────────────────────────────────────

# Install all npm dependencies
install:
    cd regatta-core && npm install
    cd frontend && npm install

# Clean all build artifacts
clean:
    cd backend-rust && cargo clean
    cd frontend && rm -rf dist node_modules/.vite
    @echo "✅ Cleaned"

# Show current git status
status:
    git status --short && git log --oneline -5
