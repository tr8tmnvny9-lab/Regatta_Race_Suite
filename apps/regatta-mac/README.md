# apps/regatta-mac — Regatta Pro (macOS)

> **Status: Phase 3 — Planned**
> Stack: SwiftUI + embedded Rust sidecar + WKWebView
> Target: macOS 14+ (Sonoma), Apple Silicon + Intel universal binary

## What goes here

This directory will contain the native macOS application for race directors.

### Architecture
```
RegattaPro.xcodeproj/        ← Xcode project
RegattaPro/
  ├── App.swift               ← SwiftUI entry point + sidecar lifecycle
  ├── ContentView.swift       ← WKWebView wrapping frontend/dist/
  ├── SidecarManager.swift    ← Launch/monitor embedded Rust backend
  ├── UDPListener.swift       ← Receive UWB MeasurementPackets on :5555
  ├── ConnectionManager.swift ← LAN → Cloud failover
  ├── MenuBarController.swift ← NSStatusItem + native menus
  ├── NotificationManager.swift ← OCS, sequence start, recall alerts
  └── Resources/
      └── regatta-backend     ← Compiled Rust binary (aarch64-apple-darwin)
```

## Build prerequisites
- Xcode 15+
- Apple Developer account (for code signing)
- `just build-mac` to compile the embedded Rust sidecar

## Phase 3 tasks
See `docs/v2_transformation_plan.md` §3 for the full task breakdown.
