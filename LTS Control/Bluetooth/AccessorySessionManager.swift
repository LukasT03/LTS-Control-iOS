import Foundation
import AccessorySetupKit
import CoreBluetooth
import UIKit

/// Pairs the Respooler via AccessorySetupKit and hands its Bluetooth identifier to `BLEManager`.
@MainActor
@Observable
final class AccessorySessionManager: NSObject {
    static let shared = AccessorySessionManager()

    private static let storedAccessoryKey = "storedAccessoryIdentifier"

    var canConnect = UserDefaults.standard.string(forKey: storedAccessoryKey) == nil

    private var accessorySession: ASAccessorySession?

    override init() {
        super.init()
        initializeSession()
    }

    private func initializeSession() {
        let session = ASAccessorySession()
        session.activate(on: DispatchQueue.main) { [weak self] event in
            guard let self else { return }
            switch event.eventType {
            case .activated:
                restorePreviousConnection()
            case .accessoryAdded:
                guard let accessory = event.accessory, let uuid = accessory.bluetoothIdentifier else { return }
                UserDefaults.standard.set(uuid.uuidString, forKey: Self.storedAccessoryKey)
                UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
                canConnect = false
                BLEManager.shared.connectToDevice(with: uuid)
                BLEManager.shared.isConnected = true
            case .accessoryRemoved, .accessoryChanged, .invalidated:
                BLEManager.shared.resetLiveState()
            default:
                break
            }
        }
        accessorySession = session
    }

    func showAccessoryPicker() {
        guard let accessorySession else {
            initializeSession()
            return
        }
        let items = [
            pickerItem(name: "LTS Respooler Pro", imageName: "RespoolerPro", manufacturerData: 0x02),
            pickerItem(name: "LTS Respooler", imageName: "Respooler", manufacturerData: 0x01),
        ]
        accessorySession.showPicker(for: items) { _ in }
    }

    func forgetAccessory() {
        guard let accessorySession, let accessory = accessorySession.accessories.first else { return }
        accessorySession.removeAccessory(accessory) { error in
            if let error {
                print("Accessory removal cancelled or failed: \(error)")
                return
            }
            Task { @MainActor in
                UserDefaults.standard.removeObject(forKey: Self.storedAccessoryKey)
                BLEManager.shared.forgetBoard()
                self.canConnect = true
                self.initializeSession()
            }
        }
    }

    private func restorePreviousConnection() {
        guard let stored = UserDefaults.standard.string(forKey: Self.storedAccessoryKey),
              let uuid = UUID(uuidString: stored) else { return }
        canConnect = false
        BLEManager.shared.connectToDevice(with: uuid)
    }

    /// Standard and Pro boards advertise the same service and differ in the manufacturer data byte.
    private func pickerItem(name: String, imageName: String, manufacturerData: UInt8) -> ASPickerDisplayItem {
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothServiceUUID = BLEManager.serviceUUID
        descriptor.bluetoothCompanyIdentifier = ASBluetoothCompanyIdentifier(rawValue: 0xFFFF)
        descriptor.bluetoothManufacturerDataBlob = Data([manufacturerData])
        descriptor.bluetoothManufacturerDataMask = Data([0xFF])
        return ASPickerDisplayItem(name: name, productImage: UIImage(named: imageName) ?? UIImage(), descriptor: descriptor)
    }
}
