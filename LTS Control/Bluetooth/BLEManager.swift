import Foundation
import CoreBluetooth
import Observation
import os

private let log = Logger(subsystem: "LTS-Design.LTS-Control", category: "Bluetooth")

/// Connection to the Respooler board. The board notifies its status as JSON,
/// the app sends `{"CMD": …}` for commands and `{"SET": {…}}` for settings.
@MainActor
@Observable
final class BLEManager: NSObject {
    static let shared = BLEManager()

    static let serviceUUID = CBUUID(string: "9E05D06D-68A7-4E1F-A503-AE26713AC101")
    private static let characteristicUUID = CBUUID(string: "7CB2F1B4-7E3F-43D2-8C92-DF58C9A7B1A8")
    private static let stateCodes: [String: DeviceState] = [
        "I": .idle, "R": .running, "P": .paused, "U": .updating, "A": .autoStop, "D": .done,
    ]

    var isConnected = false
    var deviceState: DeviceState = .idle
    var status = DeviceStatus()
    var availableSSIDs: [String]? = nil
    var isScanningForSSIDs = false
    var didInitialSync = false
    var showOTAAlert = false

    /// Key in Localizable.xcstrings. Views resolve it with `LocalizedStringKey`, so it follows the
    /// SwiftUI locale like all other texts (`NSLocalizedString` would ignore it, e.g. in previews).
    var deviceStateKey: String {
        isConnected ? "state.\(deviceState.rawValue)" : "state.disconnected"
    }

    var needsBoardVariantSelection: Bool {
        status.didReceiveBoardVariant && status.boardVariant == .unknown
    }

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var pendingConnectUUID: UUID?

    private var temperatureHistory: [Int] = []
    /// Time of the last local change per wire key. Board values inside the echo window are ignored
    /// so a control doesn't jump back while the board hasn't applied the change yet.
    private var lastLocalChange: [String: Date] = [:]
    private var expectedSpeedEcho: Int?
    private var remoteSpeedCandidate: (value: Int, since: Date)?
    /// Wi‑Fi is shown as disconnected for 2 s after connecting; the board's value is applied afterwards.
    private var isHoldingWiFiStatus = false
    private var pendingWiFiConnected: Bool?

    private let sharedDefaults = UserDefaults(suiteName: MotorCommand.appGroup)

    override init() {
        super.init()
        observeMotorRequests()
        if let uuidString = UserDefaults.standard.string(forKey: "lastPeripheralUUID") {
            pendingConnectUUID = UUID(uuidString: uuidString)
        }
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func connectToDevice(with uuid: UUID) {
        pendingConnectUUID = uuid
        guard centralManager.state == .poweredOn else {
            log.info("Connect \(uuid, privacy: .public) deferred, Bluetooth state \(self.centralManager.state.rawValue, privacy: .public)")
            return
        }
        if let p = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first {
            log.info("Connect \(uuid, privacy: .public) (known peripheral, state \(p.state.rawValue, privacy: .public))")
            connect(p)
        } else {
            log.info("Connect \(uuid, privacy: .public): not known yet, scanning")
            centralManager.scanForPeripherals(withServices: [Self.serviceUUID])
        }
    }

    /// Disconnects and stops reconnecting, e.g. after the accessory was removed.
    func forgetBoard() {
        log.info("Forget board")
        pendingConnectUUID = nil
        UserDefaults.standard.removeObject(forKey: "lastPeripheralUUID")
        if let peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        resetLiveState()
        status.firmwareVersion = nil
        status.boardVersion = nil
        UserDefaults.standard.removeObject(forKey: "boardFirmwareVersion")
        status.save()
    }

    /// Clears everything that is only valid while connected.
    func resetLiveState() {
        isConnected = false
        deviceState = .idle
        status.resetLiveValues()
        temperatureHistory.removeAll()
        pendingWiFiConnected = nil
        availableSSIDs = nil
        isScanningForSSIDs = false
        showOTAAlert = status.otaSuccess != nil
        syncLiveActivity()
    }

    private func connect(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
        centralManager.connect(p)
    }
}

// MARK: - Commands

extension BLEManager {
    func startMotor() { sendPacket(cmd: MotorCommand.start.rawValue) }
    func stopMotor() { sendPacket(cmd: MotorCommand.stop.rawValue) }
    func pauseMotor() { sendPacket(cmd: MotorCommand.pause.rawValue) }
    func triggerOTAUpdate() { sendPacket(cmd: "OTA") }
    func triggerWiFiConnect() { sendPacket(cmd: "WIFI_CONNECT") }
    func sendWiFiSSID(_ ssid: String) { sendPacket(settings: ["WIFI_SSID": ssid]) }
    func sendWiFiPassword(_ password: String) { sendPacket(settings: ["WIFI_PASS": password]) }

    func triggerWiFiScan() {
        isScanningForSSIDs = true
        sendPacket(cmd: "WIFI_SCAN")
    }

    /// Commands from intents can arrive while the app is still connecting, e.g. right after the system
    /// launched it in the background, so they wait up to 10 s for the connection.
    func perform(_ command: MotorCommand) async {
        let deadline = Date().addingTimeInterval(10)
        while characteristic == nil, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
        sendPacket(cmd: command.rawValue)
    }

    func clearOtaStatus() {
        status.otaSuccess = nil
        showOTAAlert = false
    }

    private func sendPacket(cmd: String? = nil, settings: [String: Any]? = nil) {
        var payload: [String: Any] = [:]
        payload["CMD"] = cmd
        payload["SET"] = settings
        #if DEBUG
        print("Sende BLE-Paket: \(payload)")
        #endif
        guard let peripheral, let characteristic,
              let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
}

// MARK: - Settings

extension BLEManager {
    func setLED(_ value: Int) { setSetting("LED", value, \.ledBrightness) }
    func setFanAlways(_ on: Bool) { setSetting("FAN_ALW", on, \.fanAlways) }
    func setUseFilamentSensor(_ on: Bool) { setSetting("USE_FIL", on, \.useFilamentSensor) }
    func setDirectionReversed(_ on: Bool) { setSetting("DIR", on, \.directionReversed) }
    func setMotorStrength(_ value: Int) { setSetting("POW", value, \.motorStrength) }
    func setTorqueLimit(_ value: Int) { setSetting("TRQ", value, \.torqueLimit) }
    func setTargetWeight(_ value: Int) { setSetting("WGT", value, \.targetWeight) }
    func setHighSpeed(_ on: Bool) { setSetting("HS", on, \.highSpeed) }
    func setDurationAt80(_ seconds: Int) { setSetting("DUR", seconds, \.durationAt80) }
    func setJingleStyle(_ style: Int) { setSetting("JIN", style, \.jingleStyle) }
    func setServoAngleR(_ angle: Int) { setSetting("SV_R", angle.clamped(to: 0...180), \.servoAngleR) }
    func setServoAngleL(_ angle: Int) { setSetting("SV_L", angle.clamped(to: 0...180), \.servoAngleL) }
    func setServoStepMm(_ mm: Double) { setSetting("SV_STP", mm.clamped(to: 0.05...20), \.servoStepMm) }

    func setFanSpeed(_ value: Int) {
        guard value >= 10 else { return }
        setSetting("FAN_SPD", value, \.fanSpeed)
    }

    func setSpeedPercent(_ percent: Int) {
        guard didInitialSync else { return }
        expectedSpeedEcho = percent
        setSetting("SPD", percent, \.speedPercent)
    }

    func setServoHome(_ side: String) {
        let side = side.uppercased()
        guard side == "L" || side == "R" else { return }
        setSetting("SV_HOME", side, \.servoHome)
    }

    func setBoardVariant(_ variant: BoardVariant) {
        guard didInitialSync else { return }
        status.didReceiveBoardVariant = true
        setSetting("VAR", variant, \.boardVariant, wireValue: variant.rawValue)
    }

    func servoGoto(_ target: String) {
        let target = target.uppercased()
        guard didInitialSync, ["L", "R", "HOME"].contains(target) else { return }
        sendPacket(settings: ["SV_GOTO": target])
    }

    private func setSetting<T>(
        _ key: String,
        _ value: T,
        _ keyPath: ReferenceWritableKeyPath<DeviceStatus, T>,
        wireValue: Any? = nil
    ) {
        guard didInitialSync else { return }
        var wire: Any = wireValue ?? value
        if let bool = value as? Bool { wire = bool ? 1 : 0 } // the firmware expects booleans as 0/1
        sendPacket(settings: [key: wire])
        status[keyPath: keyPath] = value
        lastLocalChange[key] = Date()
        status.save()
    }
}

// MARK: - Incoming status

extension BLEManager {
    private func handleIncoming(_ data: Data) {
        guard let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        if let ssids = dict["SSID_LIST"] as? [String] {
            isScanningForSSIDs = false
            availableSSIDs = ssids
        } else {
            updateStatus(from: dict["STAT"] as? [String: Any] ?? dict)
        }
    }

    /// Most packets contain the full status, but some (e.g. `OTA_OK`, `WIFI_CONN_RESULT`)
    /// only a single key, so values are only updated for keys that are present.
    private func updateStatus(from dict: [String: Any]) {
        if let code = dict["STAT"] as? String, let newState = Self.stateCodes[code], newState != deviceState {
            if newState == .done {
                LocalNotificationManager.shared.notifyDone()
            } else if newState == .autoStop, deviceState == .running {
                LocalNotificationManager.shared.notifyAutoStop()
            }
            deviceState = newState
        }
        guard isConnected else { return }
        didInitialSync = true

        if let v = dict["HAS_FIL"] as? Bool { status.hasFilament = v }
        if let v = dict["PROG"] as? Double { status.progress = v }
        if let v = dict["REM"] as? Int { status.remainingTime = v }
        if let v = dict["FAN_ON"] as? Bool { status.isFanOn = v }
        if let v = dict["WIFI_CONN_RESULT"] as? Bool { status.wifiConnectionResult = v }
        if dict.keys.contains("WIFI_SSID") { status.wifiSSID = dict["WIFI_SSID"] as? String }
        if let ok = dict["WIFI_OK"] as? Bool {
            if isHoldingWiFiStatus { pendingWiFiConnected = ok } else { status.wifiConnected = ok }
        }
        if let temp = dict["TEMP"] as? Int {
            // Averaged over the last 10 values, the raw chip temperature jumps around.
            temperatureHistory = Array((temperatureHistory + [temp]).suffix(10))
            status.chipTemperature = temperatureHistory.reduce(0, +) / temperatureHistory.count
        }
        if let ok = dict["OTA_OK"] as? Bool {
            status.otaSuccess = ok
            showOTAAlert = true
        }
        if let fw = dict["FW"] as? String {
            status.firmwareVersion = fw
            clearVariantIfLegacyFirmware()
        }
        if dict.keys.contains("VAR"), !isInEchoWindow("VAR") {
            status.didReceiveBoardVariant = true
            status.boardVariant = BoardVariant(fromWireValue: dict["VAR"])
        }
        if let speed = dict["SPD"] as? Int {
            applyRemoteSpeed(speed)
        }
        applySetting(dict, "USE_FIL", \.useFilamentSensor)
        applySetting(dict, "JIN", \.jingleStyle)
        applySetting(dict, "LED", \.ledBrightness)
        applySetting(dict, "FAN_SPD", \.fanSpeed)
        applySetting(dict, "FAN_ALW", \.fanAlways)
        applySetting(dict, "DIR", \.directionReversed)
        applySetting(dict, "POW", \.motorStrength)
        applySetting(dict, "TRQ", \.torqueLimit)
        applySetting(dict, "HS", \.highSpeed)
        applySetting(dict, "DUR", \.durationAt80)
        applySetting(dict, "WGT", \.targetWeight)
        applySetting(dict, "SV_R", \.servoAngleR)
        applySetting(dict, "SV_L", \.servoAngleL)
        applySetting(dict, "SV_STP", \.servoStepMm)
        if let home = (dict["SV_HOME"] as? String)?.uppercased(), home == "L" || home == "R" {
            applySetting(["SV_HOME": home], "SV_HOME", \.servoHome)
        }

        syncLiveActivity()
        status.save()
    }

    private func applySetting<T: Equatable>(_ dict: [String: Any], _ key: String, _ keyPath: ReferenceWritableKeyPath<DeviceStatus, T>) {
        guard let value = dict[key] as? T, !isInEchoWindow(key), status[keyPath: keyPath] != value else { return }
        status[keyPath: keyPath] = value
    }

    /// After a local change only the echo of that value is accepted. Otherwise a new speed must be
    /// reported twice at least 0.12 s apart, which filters short glitches while the motor ramps.
    private func applyRemoteSpeed(_ speed: Int) {
        let now = Date()
        if isInEchoWindow("SPD", 1.2) {
            guard speed == expectedSpeedEcho else { return }
            expectedSpeedEcho = nil
            remoteSpeedCandidate = (speed, now)
            status.speedPercent = speed
        } else if let candidate = remoteSpeedCandidate, candidate.value == speed {
            if now.timeIntervalSince(candidate.since) >= 0.12, status.speedPercent != speed {
                expectedSpeedEcho = nil
                status.speedPercent = speed
            }
        } else {
            remoteSpeedCandidate = (speed, now)
        }
    }

    private func isInEchoWindow(_ key: String, _ window: TimeInterval = 0.5) -> Bool {
        Date().timeIntervalSince(lastLocalChange[key] ?? .distantPast) <= window
    }

    /// Firmware ≤ 1.1.2 never sends VAR, so a cached Pro/Standard variant must not stick.
    private func clearVariantIfLegacyFirmware() {
        guard let fw = status.firmwareVersion, FirmwareVersion.compare(fw, "1.1.2") != .orderedDescending,
              status.boardVariant != .unknown || status.didReceiveBoardVariant else { return }
        status.boardVariant = .unknown
        status.didReceiveBoardVariant = false
    }

    private func syncLiveActivity() {
        LiveActivityManager.shared.sync(
            state: deviceState,
            isConnected: isConnected,
            progress: status.progress,
            remainingTime: status.remainingTime
        )
    }

    private func holdWiFiStatus() {
        isHoldingWiFiStatus = true
        status.wifiConnected = false
        Task {
            try? await Task.sleep(for: .seconds(2))
            isHoldingWiFiStatus = false
            if let pending = pendingWiFiConnected {
                status.wifiConnected = pending
                pendingWiFiConnected = nil
            }
        }
    }
}

// MARK: - CoreBluetooth

// The central runs on the main queue, so every callback arrives on the main actor.
extension BLEManager: @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn, let uuid = pendingConnectUUID {
            connectToDevice(with: uuid)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard p.identifier == pendingConnectUUID else { return }
        central.stopScan()
        connect(p)
    }

    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        log.info("Connected to \(p.identifier, privacy: .public) (\(p.name ?? "–", privacy: .public))")
        p.discoverServices([Self.serviceUUID])
        if let name = p.name, !name.isEmpty {
            status.boardVersion = name
        }
        isConnected = true
        deviceState = .idle
        didInitialSync = false
        availableSSIDs = nil
        UserDefaults.standard.set(p.identifier.uuidString, forKey: "lastPeripheralUUID")
        clearVariantIfLegacyFirmware()
        status.save()
        holdWiFiStatus()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        log.info("Disconnected from \(p.identifier, privacy: .public): \(error?.localizedDescription ?? "no error", privacy: .public)")
        peripheral = nil
        characteristic = nil
        resetLiveState()
        reconnectLater()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        log.error("Failed to connect to \(p.identifier, privacy: .public): \(error?.localizedDescription ?? "no error", privacy: .public)")
        peripheral = nil
        reconnectLater()
    }

    private func reconnectLater() {
        guard let uuid = pendingConnectUUID else { return }
        Task {
            try? await Task.sleep(for: .seconds(3))
            connectToDevice(with: uuid)
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = p.services?.first(where: { $0.uuid == Self.serviceUUID }) else { return }
        p.discoverCharacteristics([Self.characteristicUUID], for: service)
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let c = service.characteristics?.first(where: { $0.uuid == Self.characteristicUUID }) else {
            log.error("Status characteristic not found")
            return
        }
        log.info("Ready, subscribing to status")
        characteristic = c
        p.setNotifyValue(true, for: c)
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        if let data = c.value { handleIncoming(data) }
    }
}

// MARK: - Requests from the widget extension

// Fallback for intents performed in the widget extension, see `MotorCommand.run()`.
extension BLEManager {
    private func observeMotorRequests() {
        // Requests left over from while the app wasn't running are stale.
        for command in MotorCommand.allCases {
            sharedDefaults?.removeObject(forKey: command.requestKey)
        }
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let manager = Unmanaged<BLEManager>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { manager.handleMotorRequests() }
            },
            MotorCommand.requestNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func handleMotorRequests() {
        for command in MotorCommand.allCases where sharedDefaults?.bool(forKey: command.requestKey) == true {
            sharedDefaults?.set(false, forKey: command.requestKey)
            Task { await perform(command) }
        }
    }
}
