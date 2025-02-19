import Foundation
import AccessorySetupKit
import CoreBluetooth
import UIKit

class AccessorySetupManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isConnected: Bool = false
    
    // MARK: - Private Properties
    private var accessorySession: ASAccessorySession?
    private var centralManager: CBCentralManager?
    private var targetPeripheral: CBPeripheral?
    
    // Konstanten
    private let storedAccessoryKey = "storedAccessoryIdentifier"
    private let ServiceUUID = CBUUID(string: "12345678-1234-1234-1234-1234567890AB")
    private let CharacteristicUUID = CBUUID(string: "87654321-4321-4321-4321-BA0987654321")

    // MARK: - Initialization
    override init() {
        super.init()
        initializeSession()
        initializeBluetooth()
    }

    // MARK: - Accessory Session Management
    func activateSession() {
        if accessorySession == nil {
            initializeSession()
        }
    }

    private func initializeSession() {
        accessorySession = ASAccessorySession()
        accessorySession?.activate(on: DispatchQueue.main, eventHandler: { [weak self] event in
            guard let self = self else { return }
            switch event.eventType {
            case .activated:
                self.restorePreviousConnection()
            case .accessoryAdded:
                if let accessory = event.accessory {
                    DispatchQueue.main.async { self.isConnected = true }
                    self.saveAccessory(accessory)
                    self.connectToAccessory(accessory)
                }
            case .accessoryRemoved, .accessoryChanged, .invalidated:
                DispatchQueue.main.async { self.isConnected = false }
            default:
                break
            }
        })
    }

    func showAccessoryPicker() {
        guard let accessorySession = accessorySession else {
            initializeSession()
            return
        }
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothServiceUUID = ServiceUUID
        
        let displayItem = ASPickerDisplayItem(
            name: "LTS Control Board",
            productImage: UIImage(named: "RespoolerBright")!,
            descriptor: descriptor
        )
        
        accessorySession.showPicker(for: [displayItem], completionHandler: { error in
        })
    }

    func forgetAccessory() {
        UserDefaults.standard.removeObject(forKey: storedAccessoryKey)
        
        if let peripheral = targetPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        centralManager?.stopScan()
        targetPeripheral = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
        }
        
        if let accessory = accessorySession?.accessories.first {
            accessorySession?.removeAccessory(accessory, completionHandler: { _ in })
        }
        
        accessorySession = nil
        initializeSession()
    }

    private func initializeBluetooth() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }

    private func saveAccessory(_ accessory: ASAccessory) {
        if let bluetoothIdentifier = accessory.bluetoothIdentifier?.uuidString {
            UserDefaults.standard.set(bluetoothIdentifier, forKey: storedAccessoryKey)
        }
    }

    private func restorePreviousConnection() {
        guard let storedUUIDString = UserDefaults.standard.string(forKey: storedAccessoryKey),
              let storedUUID = UUID(uuidString: storedUUIDString) else { return }
        initializeBluetooth()
        if let peripheral = centralManager?.retrievePeripherals(withIdentifiers: [storedUUID]).first {
            targetPeripheral = peripheral
            centralManager?.connect(peripheral, options: nil)
        } else {
            scanForAccessory()
        }
    }

    private func scanForAccessory() {
        centralManager?.stopScan()
        centralManager?.scanForPeripherals(withServices: [ServiceUUID], options: nil)
    }

    private func connectToAccessory(_ accessory: ASAccessory) {
        guard let bluetoothIdentifier = accessory.bluetoothIdentifier else { return }
        initializeBluetooth()
        if let peripheral = centralManager?.retrievePeripherals(withIdentifiers: [bluetoothIdentifier]).first {
            targetPeripheral = peripheral
            centralManager?.connect(peripheral, options: nil)
            UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
        }
    }
}

// MARK: - CoreBluetooth Integration

extension AccessorySetupManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            restorePreviousConnection()
        } else {
            DispatchQueue.main.async {
                self.isConnected = false
            }
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        targetPeripheral = peripheral
        centralManager?.stopScan()
        centralManager?.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { self.isConnected = true }
        peripheral.delegate = self
        peripheral.discoverServices([ServiceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
        scanForAccessory()
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics([CharacteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == CharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
}
