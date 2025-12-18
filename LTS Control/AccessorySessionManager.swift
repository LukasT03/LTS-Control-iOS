import Foundation
import AccessorySetupKit
import UIKit
import CoreBluetooth

@MainActor
@Observable
final class AccessorySessionManager: NSObject {
    static let shared = AccessorySessionManager()

    var canConnect: Bool = UserDefaults.standard.string(forKey: "storedAccessoryIdentifier") == nil
    var lastSelectedUUID: UUID?

    private let storedAccessoryKey = "storedAccessoryIdentifier"
    private var accessorySession: ASAccessorySession?
    private let pickerImage = UIImage(named: "Respooler") ?? UIImage()
    private let pickerImagePro = UIImage(named: "RespoolerPro") ?? UIImage()

    override init() {
        super.init()
        self.canConnect = UserDefaults.standard.string(forKey: storedAccessoryKey) == nil
        initializeSession()
    }

    private func initializeSession() {
        accessorySession = ASAccessorySession()
        accessorySession?.activate(on: DispatchQueue.main, eventHandler: { [weak self] event in
            guard let self else { return }
            switch event.eventType {
            case .activated:
                self.restorePreviousConnection()
            case .accessoryAdded:
                if let accessory = event.accessory {
                    self.saveAccessory(accessory)
                    self.connectToAccessory(accessory)
                    DispatchQueue.main.async { BLEManager.shared.isConnected = true }
                }
            case .accessoryRemoved, .accessoryChanged, .invalidated:
                DispatchQueue.main.async {
                    let ble = BLEManager.shared
                    ble.isConnected = false
                    ble.deviceState = .idle
                    ble.deviceStateText = self.L("state.disconnected")
                    ble.status.progress = 0.0
                    ble.status.remainingTime = nil
                    ble.status.hasFilament = false
                    ble.status.chipTemperature = nil
                    ble.status.wifiSSID = nil
                    ble.status.wifiConnected = nil
                    ble.status.wifiLastResult = nil
                    ble.status.wifiConnectionResult = nil
                    ble.status.isFanOn = false
                    ble.ssidList.availableSSIDs = nil
                    ble.isScanningForSSIDs = false
                    ble.showOTAAlert = ble.status.otaSuccess != nil
                    LiveActivityManager.shared.sync(
                        state: ble.deviceState,
                        isConnected: ble.isConnected,
                        progress: ble.status.progress,
                        remainingTime: ble.status.remainingTime
                    )
                }
            default:
                break
            }
        })
    }

    func showAccessoryPicker() {
        guard let accessorySession else {
            initializeSession()
            return
        }

        let serviceUUID = CBUUID(string: "9E05D06D-68A7-4E1F-A503-AE26713AC101")

        let stdDescriptor = ASDiscoveryDescriptor()
        stdDescriptor.bluetoothServiceUUID = serviceUUID
        stdDescriptor.bluetoothCompanyIdentifier = ASBluetoothCompanyIdentifier(rawValue: 0xFFFF)
        stdDescriptor.bluetoothManufacturerDataBlob = Data([0x01])
        stdDescriptor.bluetoothManufacturerDataMask = Data([0xFF])

        let proDescriptor = ASDiscoveryDescriptor()
        proDescriptor.bluetoothServiceUUID = serviceUUID
        proDescriptor.bluetoothCompanyIdentifier = ASBluetoothCompanyIdentifier(rawValue: 0xFFFF)
        proDescriptor.bluetoothManufacturerDataBlob = Data([0x02])
        proDescriptor.bluetoothManufacturerDataMask = Data([0xFF])

        let stdItem = ASPickerDisplayItem(
            name: "LTS Respooler",
            productImage: pickerImage,
            descriptor: stdDescriptor
        )

        let proItem = ASPickerDisplayItem(
            name: "LTS Respooler Pro",
            productImage: pickerImagePro,
            descriptor: proDescriptor
        )

        accessorySession.showPicker(for: [proItem, stdItem], completionHandler: { _ in })
    }

    func forgetAccessoryWithPolling() {
        guard let accessory = accessorySession?.accessories.first else { return }
        accessorySession?.removeAccessory(accessory) { error in
            if error == nil {
                Task { @MainActor in
                    UserDefaults.standard.removeObject(forKey: self.storedAccessoryKey)
                    self.clearConnectionState()
                    self.pollAccessoryRemoved(retries: 0)
                }
            } else {
                print("Accessory removal cancelled or failed: \(error!)")
            }
        }
    }

    private func saveAccessory(_ accessory: ASAccessory) {
        if let uuid = accessory.bluetoothIdentifier?.uuidString {
            UserDefaults.standard.set(uuid, forKey: storedAccessoryKey)
            self.canConnect = false
            UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
        }
    }

    private func restorePreviousConnection() {
        guard let storedUUIDString = UserDefaults.standard.string(forKey: storedAccessoryKey),
              let storedUUID = UUID(uuidString: storedUUIDString) else { return }
        lastSelectedUUID = storedUUID
        self.canConnect = false
        BLEManager.shared.connectToDevice(with: storedUUID)
    }

    private func connectToAccessory(_ accessory: ASAccessory) {
        guard let bluetoothIdentifier = accessory.bluetoothIdentifier else { return }
        lastSelectedUUID = bluetoothIdentifier
        BLEManager.shared.connectToDevice(with: bluetoothIdentifier)
    }

    private var centralManager: CBCentralManager?
    private var targetPeripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?
    
    private func L(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func pollAccessoryRemoved(retries: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let stillStored = UserDefaults.standard.string(forKey: self.storedAccessoryKey) != nil
            if !stillStored {
                self.canConnect = true
            } else if retries < 6 {
                self.pollAccessoryRemoved(retries: retries + 1)
            } else {
                self.canConnect = false
            }
        }
    }

    private func clearConnectionState() {
        if let peripheral = targetPeripheral { centralManager?.cancelPeripheralConnection(peripheral) }
        centralManager?.stopScan()
        targetPeripheral = nil
        txCharacteristic = nil
        DispatchQueue.main.async {
            let ble = BLEManager.shared
            ble.isConnected = false
            ble.deviceState = .idle
            ble.deviceStateText = self.L("state.disconnected")
            ble.status.progress = 0.0
            ble.status.remainingTime = nil
            ble.status.hasFilament = false
            ble.status.chipTemperature = nil
            ble.status.wifiSSID = nil
            ble.status.wifiConnected = nil
            ble.status.wifiLastResult = nil
            ble.status.firmwareVersion = nil
            ble.status.boardVersion = nil
            UserDefaults.standard.removeObject(forKey: "boardVersion")
            UserDefaults.standard.removeObject(forKey: "boardFirmwareVersion")
            ble.status.wifiConnectionResult = nil
            ble.status.isFanOn = false
            ble.ssidList.availableSSIDs = nil
            ble.isScanningForSSIDs = false
            ble.showOTAAlert = ble.status.otaSuccess != nil
            ble.status.saveSettings()
            LiveActivityManager.shared.sync(
                state: ble.deviceState,
                isConnected: ble.isConnected,
                progress: ble.status.progress,
                remainingTime: ble.status.remainingTime
            )
            self.canConnect = UserDefaults.standard.string(forKey: self.storedAccessoryKey) == nil
        }
        accessorySession = nil
        initializeSession()
    }
}
