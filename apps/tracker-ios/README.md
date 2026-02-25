# apps/tracker-ios — Regatta Tracker (iOS/iPadOS)

> **Status: Phase 4 — Planned** (Replaces regatta-tracker-ios/ Expo stub)
> Stack: Native Swift + SwiftUI + CoreLocation + CoreMotion + CoreBluetooth
> Target: iOS 17+ / iPadOS 17+

## What goes here

Native Swift app for sailors. Shows the real-time start line, distance-to-line in centimeters, countdown, flags, and OCS alerts.

### Architecture
```
RegattaTracker.xcodeproj/
RegattaTracker/
  ├── App.swift                    ← SwiftUI entry + scene setup
  ├── Connection/
  │   ├── ConnectionManager.swift  ← LAN (Bonjour) → Cloud → Offline
  │   ├── BonjournDiscovery.swift  ← Discover _regatta._tcp. on LAN
  │   └── OfflineBuffer.swift      ← SQLite track-update buffer
  ├── BLE/
  │   ├── UWBNodeClient.swift      ← CBCentralManager, scan + connect
  │   ├── GATTCharacteristics.swift ← PositionStream, Commands
  │   └── PositionParser.swift     ← Parse NodePosition2D from BLE notify
  ├── Location/
  │   ├── LocationManager.swift    ← CoreLocation GPS (fallback)
  │   └── MotionManager.swift      ← CoreMotion heading + pitch
  ├── Views/
  │   ├── StartLineView.swift      ← Main HUD: DTL, countdown, flags
  │   ├── CountdownView.swift      ← T-5:00 countdown display
  │   ├── FlagView.swift           ← Active flag display
  │   ├── OCSOverlayView.swift     ← Full-screen red OCS flash
  │   ├── JoinView.swift           ← QR code scanner, session join
  │   └── TabletLayoutView.swift   ← iPad split: HUD + tactical chart
  ├── Haptics/
  │   └── HapticManager.swift      ← Gun, OCS, countdown haptic patterns
  └── Models/
      ├── RaceState.swift          ← Local Swift model mapped from WebSocket
      └── BoatPosition.swift       ← UWB fused position + CoreLocation
```

## Build prerequisites
- Xcode 15+
- Apple Developer account (device testing requires physical device)
- Physical iPhone/iPad for BLE + CoreLocation testing

## Phase 4 tasks
See `docs/v2_transformation_plan.md` §4 for the full task breakdown.
