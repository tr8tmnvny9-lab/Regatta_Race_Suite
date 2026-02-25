# apps/uwb-firmware — UWB Node Firmware

> **Status: Phase 5 — Planned**
> Stack: C / Rust (no_std) on STM32U5 or nRF5340 + Qorvo DW3720
> Target: custom PCB, IP67 marine enclosure

## What goes here

Firmware for the waterproof UWB ranging nodes worn by each boat. 
All nodes are identical hardware; software designation (MarkA/MarkB/Boat) is set at runtime.

### Architecture
```
uwb-firmware/
  ├── Cargo.toml              ← no_std Rust crate (or CMake for C)
  ├── src/
  │   ├── main.rs             ← Boot, task scheduler, superframe loop
  │   ├── uwb_mac.rs          ← TDMA superframe manager (50ms slots)
  │   ├── ds_twr.rs           ← DS-TWR ranging (128-symbol STS)
  │   ├── pdoa.rs             ← PDoA dual-antenna angle computation
  │   ├── cir_parser.rs       ← CIR first-path extraction, SNR, NLOS
  │   ├── clock_sync.rs       ← Distributed clock offset via beacons
  │   ├── ekf_6dof.rs         ← 6-DoF EKF [p,q,v,bias_gyro,bias_accel]
  │   ├── aes_ccm.rs          ← AES-128-CCM packet encrypt/decrypt
  │   ├── wifi_relay.rs       ← UDP multicast MeasurementPacket :5555
  │   ├── ble_gatt.rs         ← BLE GATT server → iPhone PositionStream
  │   ├── sd_logger.rs        ← microSD append-only SHA-256 chained log
  │   └── power_mgmt.rs       ← Sleep modes, wake-on-motion
  └── memory.x                ← Linker script for target MCU
```

## Hardware target
- UWB SoC: Qorvo DW3720 (or DW3110)
- MCU: STM32U5 or nRF5340
- IMU: BMI088 or ICM-42688 @ 400 Hz
- WiFi: ESP32-S3 or nRF7002 (802.11ax)
- Battery: LiPo 3.7V 2000mAh (~8h runtime)
- Housing: IP67 marine enclosure

## Phase 5 tasks
See `docs/v2_transformation_plan.md` §5 for the full task breakdown.
