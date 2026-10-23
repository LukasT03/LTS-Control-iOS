import Foundation
import AccessorySetupKit
import CoreBluetooth
import os
import UIKit

private let log = Logger(subsystem: "LTS-Design.LTS-Control", category: "AccessorySetup")

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
            log.info("Event \(event.eventType.rawValue, privacy: .public), accessory \(event.accessory?.bluetoothIdentifier?.uuidString ?? "–", privacy: .public)")
            // Whether the board is connected is decided by CoreBluetooth alone. Events like
            // .accessoryChanged also arrive while the board stays connected.
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
            case .accessoryRemoved:
                // Also fires when the Respooler is removed in the iOS Settings app.
                UserDefaults.standard.removeObject(forKey: Self.storedAccessoryKey)
                canConnect = true
                BLEManager.shared.forgetBoard()
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
                log.error("Accessory removal cancelled or failed: \(error, privacy: .public)")
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
