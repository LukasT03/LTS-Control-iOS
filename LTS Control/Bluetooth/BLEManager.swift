import Foundation
import CoreBluetooth
import Observation

private func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

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

    var deviceStateText: String {
        isConnected ? L("state.\(deviceState.rawValue)") : L("state.disconnected")
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

    private let sharedDefaults = UserDefaults(suiteName: "group.ltscontrol")

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
        guard centralManager.state == .poweredOn else { return }
        if let p = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first {
            connect(p)
        } else {
            centralManager.scanForPeripherals(withServices: [Self.serviceUUID])
        }
    }

    /// Disconnects and stops reconnecting, e.g. after the accessory was removed.
    func forgetBoard() {
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
    func startMotor() { sendPacket(cmd: "START") }
    func stopMotor() { sendPacket(cmd: "STOP") }
    func pauseMotor() { sendPacket(cmd: "PAUSE") }
    func triggerOTAUpdate() { sendPacket(cmd: "OTA") }
    func triggerWiFiConnect() { sendPacket(cmd: "WIFI_CONNECT") }
    func sendWiFiSSID(_ ssid: String) { sendPacket(settings: ["WIFI_SSID": ssid]) }
    func sendWiFiPassword(_ password: String) { sendPacket(settings: ["WIFI_PASS": password]) }

    func triggerWiFiScan() {
        isScanningForSSIDs = true
        sendPacket(cmd: "WIFI_SCAN")
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
        guard let fw = status.firmwareVersion, Self.isVersion(fw, atMost: [1, 1, 2]),
              status.boardVariant != .unknown || status.didReceiveBoardVariant else { return }
        status.boardVariant = .unknown
        status.didReceiveBoardVariant = false
    }

    /// Accepts "1.2.0", "v1.2.0" or "1.2"; non-numeric characters are ignored.
    private static func isVersion(_ version: String, atMost max: [Int]) -> Bool {
        let parts = version.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
        return !max.lexicographicallyPrecedes((parts + [0, 0, 0]).prefix(3))
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

// The central runs on the main queue, so every callback is already on the main actor.
extension BLEManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            if central.state == .poweredOn, let uuid = pendingConnectUUID {
                connectToDevice(with: uuid)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        MainActor.assumeIsolated {
            guard p.identifier == pendingConnectUUID else { return }
            central.stopScan()
            connect(p)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        MainActor.assumeIsolated {
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
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            peripheral = nil
            characteristic = nil
            resetLiveState()
            guard let uuid = pendingConnectUUID else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                connectToDevice(with: uuid)
            }
        }
    }

    nonisolated func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            guard let service = p.services?.first(where: { $0.uuid == Self.serviceUUID }) else { return }
            p.discoverCharacteristics([Self.characteristicUUID], for: service)
        }
    }

    nonisolated func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            guard let c = service.characteristics?.first(where: { $0.uuid == Self.characteristicUUID }) else { return }
            characteristic = c
            p.setNotifyValue(true, for: c)
        }
    }

    nonisolated func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        MainActor.assumeIsolated {
            if let data = c.value { handleIncoming(data) }
        }
    }
}

// MARK: - Requests from widgets, Live Activities and Shortcuts

// The intents run in other processes; they set a flag in the App Group and post a Darwin notification.
extension BLEManager {
    private static let motorRequestNotification = "group.ltscontrol.motorRequest"

    private func observeMotorRequests() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let manager = Unmanaged<BLEManager>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { manager.handleMotorRequests() }
            },
            Self.motorRequestNotification as CFString,
            nil,
            .deliverImmediately
        )
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: sharedDefaults, queue: .main) { _ in
            MainActor.assumeIsolated { self.handleMotorRequests() }
        }
    }

    private func handleMotorRequests() {
        let requests: [(key: String, action: @MainActor () -> Void)] = [
            ("startMotorRequested", startMotor),
            ("stopMotorRequested", stopMotor),
            ("pauseMotorRequested", pauseMotor),
        ]
        for request in requests where sharedDefaults?.bool(forKey: request.key) == true {
            sharedDefaults?.set(false, forKey: request.key)
            request.action()
        }
    }
}
