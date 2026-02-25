# Regatta Suite — v2

> A fully mobile, cloud-resilient, protest-proof race management system for competitive sailing.

## Products

| Product | Path | Stack | Status |
|---|---|---|---|
| **Regatta Pro** (Mac) | `apps/regatta-mac/` | SwiftUI + embedded Rust sidecar | 🔨 Planned |
| **Regatta Tracker** (iOS/iPadOS) | `apps/tracker-ios/` | Swift + CoreLocation + BLE GATT | 🔨 Planned |
| **Backend** (local + cloud) | `backend-rust/` | Rust (Axum + socketioxide) | ✅ Active |
| **Frontend** (web/browser) | `frontend/` | React + Vite (current) | ✅ Active |
| **UWB Firmware** | `apps/uwb-firmware/` | C/Rust on STM32/nRF5340 | 🔨 Planned |

## Packages

| Package | Path | Purpose |
|---|---|---|
| `@regatta/core` | `regatta-core/` | Shared types, socket engine |
| `uwb-types` | `packages/uwb-types/` | Shared UWB packet structs (Rust + C header) |

## Architecture

See [`docs/architecture.md`](docs/architecture.md) for full diagrams covering:
- Current system (browser-based)
- Cloud v2 target (Fly.io + Supabase)
- UWB Hive-Mind Swarm Positioning System
- Failover / "Mac falls overboard" scenario

## Running Locally (current v1)

```bash
# Backend
cd backend-rust && cargo run

# Frontend
cd frontend && npm run dev
```

Open http://localhost:3000, select **Race Director**, click Connect.

## v2 Transformation Plan

See [`docs/v2_transformation_plan.md`](docs/v2_transformation_plan.md) — 8 phases, ~200 tasks.

## Core Invariants (validation_protocol.json)

1. Olympic-level precision — ≤1 cm absolute positioning at start line
2. Protest-proof auditability — SHA-256 chained audit log for every critical event
3. Cloud resilience — full race state recoverable in <10 s after device failure
4. Native-first — Regatta Pro = native macOS, Regatta Tracker = native iOS/iPadOS
5. UWB Hive mesh — self-organizing, waterproof, 100–300 nodes
6. Ubiquiti 5 GHz WiFi backbone per regatta
7. Three synchronized products that interoperate seamlessly
8. Zero data loss, zero race interruption under real sailing conditions
9. Intuitive UX for high-pressure race officers and sailors
