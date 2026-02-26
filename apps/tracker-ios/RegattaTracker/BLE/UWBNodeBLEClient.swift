import Foundation
import CoreBluetooth
import Combine

class UWBNodeBLEClient: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isConnected = false
    @Published var signalStrength: Int = 0
    @Published var dtlCm: Double? = nil
    
    private var centralManager: CBCentralManager!
    private var uwbNode: CBPeripheral?
    
    // Mock UUIDs for Regatta UWB Node
    let serviceUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-1234-56789ABCDEF0")
    let positionCharUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-1234-56789ABCDEF1")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func start() {
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            start()
        } else {
            isConnected = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.uwbNode = peripheral
        self.uwbNode?.delegate = self
        self.signalStrength = RSSI.intValue
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        self.dtlCm = nil
        start() // Try to reconnect
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([positionCharUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == positionCharUUID {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        // Parse mock packet: [x_line: f32, y_line: f32, ... ]
        // For now, mock DTL (Distance To Line) extraction
        if data.count >= 8 {
            let yLine = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: Float32.self) }
            DispatchQueue.main.async {
                self.dtlCm = Double(yLine) * 100.0 // meters to cm
            }
        }
    }
}
