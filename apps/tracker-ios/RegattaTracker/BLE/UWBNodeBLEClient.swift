// UWBNodeBLEClient.swift
// CoreBluetooth GATT client for the UWB positioning node.
//
// The UWB node broadcasts a BLE service with:
//   PositionStream characteristic — notify at 20 Hz, contains NodePosition2D
//   Commands characteristic — write-only: burst mode, mark designation, log dump
//
// Position data decoded here becomes the primary source of truth for the HUD.
// CoreLocation GPS is the fallback when BLE is unavailable.
//
// Core Invariant #1: 1 cm accuracy — UWB GATT stream provides cm-level DTL
// Core Invariant #4: Native iOS — CoreBluetooth, not a JS bridge

import CoreBluetooth
import Combine
import OSLog

private let log = Logger(subsystem: "com.regatta.tracker", category: "BLE")

// ─── GATT UUIDs (must match firmware constants in apps/uwb-firmware/) ─────────

enum UWBGATTUUIDs {
    static let service         = CBUUID(string: "BC2F4CC6-AAEF-4351-9034-D66268E328F0")
    static let positionStream  = CBUUID(string: "BC2F4CC6-AAEF-4351-9034-D66268E328F1")
    static let rawMeasurements = CBUUID(string: "BC2F4CC6-AAEF-4351-9034-D66268E328F2")
    static let commands        = CBUUID(string: "BC2F4CC6-AAEF-4351-9034-D66268E328F3")
}

// ─── Decoded position from BLE notify ────────────────────────────────────────

struct UWBPosition {
    let nodeId: UInt32
    let xLineM: Float      // along start line (MarkA→MarkB)
    let yLineM: Float      // perpendicular (positive = OCS side)
    let vxLineMps: Float
    let vyLineMps: Float
    let headingDeg: Float
    let fixQuality: UInt8
    let batchMode: Bool

    var dtlCm: Float { yLineM * 100.0 }
    var isOCS: Bool { yLineM > 0.10 && fixQuality >= 60 }

    // Parse from raw BLE notification data (binary struct matching uwb_types.h NodePosition2D)
    init?(data: Data) {
        // Expected: 4+4+4+4+4+4+1+1 = 26 bytes
        guard data.count >= 26 else { return nil }
        var offset = 0
        func readUInt32() -> UInt32 {
            let v = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
            offset += 4; return v
        }
        func readFloat() -> Float {
            let v = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Float.self) }
            offset += 4; return v
        }
        func readUInt8() -> UInt8 {
            let v = data[offset]; offset += 1; return v
        }
        nodeId      = readUInt32()
        xLineM      = readFloat()
        yLineM      = readFloat()
        vxLineMps   = readFloat()
        vyLineMps   = readFloat()
        headingDeg  = readFloat()
        fixQuality  = readUInt8()
        batchMode   = readUInt8() != 0
    }
}

// ─── Commands ─────────────────────────────────────────────────────────────────

enum UWBCommand: UInt8 {
    case enableBurstMode  = 0x01
    case disableBurstMode = 0x02
    case setMarkA         = 0x10
    case setMarkB         = 0x11
    case triggerLogDump   = 0x20
}

// ─── BLE Client ───────────────────────────────────────────────────────────────

final class UWBNodeBLEClient: NSObject, ObservableObject {
    @Published var position: UWBPosition?
    @Published var nodeId: UInt32?
    @Published var rssi: Int = 0
    @Published var state: BLEState = .idle
    @Published var fixQuality: UInt8 = 0

    enum BLEState: Equatable {
        case idle, scanning, connecting, connected, disconnected
    }

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var positionChar: CBCharacteristic?
    private var commandsChar: CBCharacteristic?

    override init() {
        super.init()
    }

    func start() {
        central = CBCentralManager(delegate: self, queue: .main,
                                   options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    // ─── API ──────────────────────────────────────────────────────────────────

    func sendCommand(_ command: UWBCommand) {
        guard let p = peripheral, let char = commandsChar else { return }
        let data = Data([command.rawValue])
        p.writeValue(data, for: char, type: .withResponse)
        log.info("BLE: sent command \(command.rawValue)")
    }

    func enableBurstMode() { sendCommand(.enableBurstMode) }
    func disableBurstMode() { sendCommand(.disableBurstMode) }
}

// ─── CBCentralManagerDelegate ─────────────────────────────────────────────────

extension UWBNodeBLEClient: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            log.info("BLE: powered on — scanning for UWB node")
            state = .scanning
            central.scanForPeripherals(withServices: [UWBGATTUUIDs.service],
                                       options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        case .poweredOff:
            log.warning("BLE: powered off")
            state = .idle
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                         advertisementData: [String: Any], rssi RSSI: NSNumber) {
        log.info("BLE: discovered UWB node: \(peripheral.identifier)")
        self.peripheral = peripheral
        self.rssi = RSSI.intValue
        state = .connecting
        central.stopScan()
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log.info("BLE: connected to \(peripheral.identifier)")
        state = .connected
        peripheral.delegate = self
        peripheral.discoverServices([UWBGATTUUIDs.service])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log.warning("BLE: disconnected — rescanning")
        state = .disconnected
        position = nil
        // Auto-reconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.state = .scanning
            central.scanForPeripherals(withServices: [UWBGATTUUIDs.service])
        }
    }
}

// ─── CBPeripheralDelegate ─────────────────────────────────────────────────────

extension UWBNodeBLEClient: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == UWBGATTUUIDs.service {
            peripheral.discoverCharacteristics(
                [UWBGATTUUIDs.positionStream, UWBGATTUUIDs.commands],
                for: service
            )
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        for char in chars {
            switch char.uuid {
            case UWBGATTUUIDs.positionStream:
                positionChar = char
                peripheral.setNotifyValue(true, for: char)  // Subscribe to 20 Hz stream
                log.info("BLE: subscribed to PositionStream at 20 Hz")
            case UWBGATTUUIDs.commands:
                commandsChar = char
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == UWBGATTUUIDs.positionStream,
              let data = characteristic.value,
              let pos = UWBPosition(data: data) else { return }
        // Main thread — @Published triggers SwiftUI update
        position = pos
        fixQuality = pos.fixQuality
        if let n = nodeId, n != pos.nodeId { return }
        nodeId = pos.nodeId
    }
}
