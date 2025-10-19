import Foundation
import CoreBluetooth
import UserNotifications
import AppIntents
import UIKit

private func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

@MainActor
@Observable
class SSIDList {
    var availableSSIDs: [String]? = nil
}

@MainActor
@Observable
class DeviceStatus {
    var hasFilament: Bool = false
    var progress: Double? = nil
    var remainingTime: Int? = nil
    var chipTemperature: Int? = nil
    var wifiSSID: String? = nil
    var wifiConnected: Bool? = nil
    var wifiLastResult: Bool? = nil
    var firmwareVersion: String? = UserDefaults.standard.string(forKey: "boardFirmwareVersion")
    var boardVersion: String? = UserDefaults.standard.string(forKey: "boardVersion")
    var otaSuccess: Bool? = nil
    var wifiConnectionResult: Bool? = nil
    var isFanOn: Bool = false

    var speedPercent: Int = UserDefaults.standard.integer(forKey: "speedPercent")
    var jingleStyle: Int = UserDefaults.standard.integer(forKey: "jingleStyle")
    var ledBrightness: Int = UserDefaults.standard.integer(forKey: "ledBrightness")
    var fanSpeed: Int = UserDefaults.standard.integer(forKey: "fanSpeed")
    var fanAlways: Bool = UserDefaults.standard.object(forKey: "fanAlways") as? Bool ?? false
    var useFilamentSensor: Bool = UserDefaults.standard.object(forKey: "useFilamentSensor") as? Bool ?? true
    var directionReversed: Bool = UserDefaults.standard.object(forKey: "directionReversed") as? Bool ?? false
    var motorStrength: Int = UserDefaults.standard.integer(forKey: "motorStrength")
    var torqueLimit: Int = UserDefaults.standard.integer(forKey: "torqueLimit")
    var highSpeed: Bool = UserDefaults.standard.object(forKey: "highSpeed") as? Bool ?? false
    var durationAt80: Int = UserDefaults.standard.integer(forKey: "durationAt80")
    var targetWeight: Int = UserDefaults.standard.integer(forKey: "targetWeight")

    init() {
        if speedPercent == 0 { speedPercent = 85 }
        if jingleStyle == 0 { jingleStyle = 0 }
        if ledBrightness == 0 { ledBrightness = 50 }
        if fanSpeed == 0 { fanSpeed = 60 }
        if motorStrength == 0 { motorStrength = 100 }
        if torqueLimit == 0 { torqueLimit = 0 }
        if durationAt80 == 0 { durationAt80 = 895 }
        if targetWeight == 0 { targetWeight = 0 }
    }

    func saveSettings() {
        UserDefaults.standard.set(speedPercent, forKey: "speedPercent")
        UserDefaults.standard.set(jingleStyle, forKey: "jingleStyle")
        UserDefaults.standard.set(ledBrightness, forKey: "ledBrightness")
        UserDefaults.standard.set(fanSpeed, forKey: "fanSpeed")
        UserDefaults.standard.set(fanAlways, forKey: "fanAlways")
        UserDefaults.standard.set(useFilamentSensor, forKey: "useFilamentSensor")
        UserDefaults.standard.set(directionReversed, forKey: "directionReversed")
        UserDefaults.standard.set(motorStrength, forKey: "motorStrength")
        UserDefaults.standard.set(torqueLimit, forKey: "torqueLimit")
        UserDefaults.standard.set(highSpeed, forKey: "highSpeed")
        UserDefaults.standard.set(durationAt80, forKey: "durationAt80")
        UserDefaults.standard.set(targetWeight, forKey: "targetWeight")
        if let boardVersion {
            UserDefaults.standard.set(boardVersion, forKey: "boardVersion")
        } else {
            UserDefaults.standard.removeObject(forKey: "boardVersion")
        }
        if let firmwareVersion {
            UserDefaults.standard.set(firmwareVersion, forKey: "boardFirmwareVersion")
        }
    }
}

@MainActor
@Observable
class BLEManager: NSObject {
    static let shared = BLEManager()
    
    var isConnected = false
    var status = DeviceStatus()
    var ssidList = SSIDList()
    var isScanningForSSIDs: Bool = false
    var didInitialSync: Bool = false
    @MainActor var showOTAAlert: Bool = false
    @MainActor var deviceStateText: String = L("state.disconnected")
    @MainActor var deviceState: DeviceState = .idle
    @MainActor var isIdleState: Bool { deviceState == .idle }
    @MainActor var isRunningState: Bool { deviceState == .running }
    @MainActor var isPausedState: Bool { deviceState == .paused }
    @MainActor var isUpdatingState: Bool { deviceState == .updating }
    @MainActor var isAutoStopState: Bool { deviceState == .autoStop }
    @MainActor var isDoneState: Bool { deviceState == .done }

    private var didPersistBoardVersionThisSession: Bool = false
    private var lastDisconnectAt: Date? = nil
    private var previousDeviceState: DeviceState = .idle

    private let sharedDefaults = UserDefaults(suiteName: "group.ltscontrol")
    private let motorRequestNotification = "group.ltscontrol.motorRequest"

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var statusCharacteristic: CBCharacteristic?
    
    private let serviceUUID = CBUUID(string: "9E05D06D-68A7-4E1F-A503-AE26713AC101")
    private let statusCharUUID = CBUUID(string: "7CB2F1B4-7E3F-43D2-8C92-DF58C9A7B1A8")
    private var temperatureHistory: [Int] = []
    private var pendingConnectUUID: UUID?

    private var lastLocalSettingChange: [String: Date] = [:]
    private var expectedEchoInt: [String: Int] = [:]
    private let localEchoWindow: TimeInterval = 1.2
    private var lastRemoteSPD: Int? = nil
    private var lastRemoteSPDTimestamp: Date = .distantPast
    private var remoteSPDRepeatCount: Int = 0
    private let remoteSPDDebounceInterval: TimeInterval = 0.12
    private let remoteSPDDebounceRounds: Int = 2
    private var wifiStatusHoldUntil: Date? = nil
    private var pendingWiFiConnected: Bool? = nil
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            { (_, observer, _, _, _) in
                guard let observer else { return }
                let manager = Unmanaged<BLEManager>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.handleMotorRequested(Notification(name: Notification.Name("DarwinMotor")))
                }
            },
            motorRequestNotification as CFString,
            nil,
            .deliverImmediately)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMotorRequested(_:)),
            name: UserDefaults.didChangeNotification,
            object: sharedDefaults)
        if let uuidString = UserDefaults.standard.string(forKey: "lastPeripheralUUID"),
           let uuid = UUID(uuidString: uuidString) {
            pendingConnectUUID = uuid
        }
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func connectToDevice(with uuid: UUID) {
        pendingConnectUUID = uuid
        didPersistBoardVersionThisSession = false
        if centralManager.state == .poweredOn {
            if let p = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first {
                peripheral = p
                p.delegate = self
                centralManager.connect(p, options: nil)
            } else {
                centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
            }
        }
    }
    
    func disconnect() {
        guard let peripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        self.peripheral = nil
        UserDefaults.standard.removeObject(forKey: "lastPeripheralUUID")
        pendingConnectUUID = nil
        didPersistBoardVersionThisSession = false
    }
    
    func sendPacket(cmd: String? = nil, settings: [String: Any]? = nil) {
        var payload: [String: Any] = [:]
        if let cmd = cmd { payload["CMD"] = cmd }
        if let settings = settings { payload["SET"] = settings }
        #if DEBUG
        print("Sende BLE-Paket: \(payload)")
        #endif
        guard let peripheral, let c = statusCharacteristic,
              let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else { return }
        peripheral.writeValue(data, for: c, type: .withResponse)
    }
    
    func startMotor() { sendPacket(cmd: "START") }
    func stopMotor()  { sendPacket(cmd: "STOP") }
    func pauseMotor() { sendPacket(cmd: "PAUSE") }
    func triggerOTAUpdate() { sendPacket(cmd: "OTA") }
    func sendWiFiSSID(_ ssid: String) { sendPacket(settings: ["WIFI_SSID": ssid]) }
    func sendWiFiPassword(_ password: String) { sendPacket(settings: ["WIFI_PASS": password]) }
    func triggerWiFiConnect() { sendPacket(cmd: "WIFI_CONNECT") }
    func triggerWiFiScan() {
        Task { @MainActor in self.isScanningForSSIDs = true }
        sendPacket(cmd: "WIFI_SCAN")
    }
}

nonisolated(unsafe) extension BLEManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            if central.state == .poweredOn {
                if let uuid = pendingConnectUUID {
                    connectToDevice(with: uuid)
                } else {
                    central.scanForPeripherals(withServices: [serviceUUID], options: nil)
                }
            }
        }
    }
    func centralManager(_ central: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            if let uuid = pendingConnectUUID, p.identifier == uuid {
                central.stopScan()
                peripheral = p
                peripheral?.delegate = self
                central.connect(p, options: nil)
            }
        }
    }
    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        Task { @MainActor in
            p.discoverServices([serviceUUID])
            if let name = p.name, !name.isEmpty {
                if self.status.boardVersion != name || !self.didPersistBoardVersionThisSession {
                    self.status.boardVersion = name
                    self.status.saveSettings()
                    self.didPersistBoardVersionThisSession = true
                }
            }
            self.isConnected = true
            self.deviceState = .idle
            self.deviceStateText = L("state.idle")
            self.ssidList.availableSSIDs = nil
            UserDefaults.standard.set(p.identifier.uuidString, forKey: "lastPeripheralUUID")
            self.didInitialSync = false
            if self.status.firmwareVersion == nil,
               let cachedFW = UserDefaults.standard.string(forKey: "boardFirmwareVersion"),
               !cachedFW.isEmpty {
                self.status.firmwareVersion = cachedFW
            }
            self.wifiStatusHoldUntil = Date().addingTimeInterval(2)
            self.status.wifiConnected = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                self.wifiStatusHoldUntil = nil
                if let pending = self.pendingWiFiConnected {
                    self.status.wifiConnected = pending
                    self.pendingWiFiConnected = nil
                }
            }
        }
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        Task { @MainActor in
            peripheral = nil
            self.lastDisconnectAt = Date()
            self.didPersistBoardVersionThisSession = false
            self.isConnected = false
            self.deviceState = .idle
            self.deviceStateText = L("state.disconnected")
            self.status.progress = 0.0
            self.status.remainingTime = nil
            self.status.hasFilament = false
            self.status.chipTemperature = nil
            self.status.wifiSSID = nil
            self.status.wifiConnected = nil
            self.status.wifiLastResult = nil
            self.status.wifiConnectionResult = nil
            self.status.isFanOn = false
            self.pendingWiFiConnected = nil
            self.temperatureHistory.removeAll()
            self.ssidList.availableSSIDs = nil
            LiveActivityManager.shared.sync(
                state: self.deviceState,
                isConnected: self.isConnected,
                progress: self.status.progress,
                remainingTime: self.status.remainingTime
            )
            self.isScanningForSSIDs = false
            self.showOTAAlert = self.status.otaSuccess != nil
            if let uuid = self.pendingConnectUUID {
                let delay: TimeInterval
                if let last = self.lastDisconnectAt, Date().timeIntervalSince(last) < 3 {
                    delay = 3.0
                } else {
                    delay = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.connectToDevice(with: uuid)
                }
            }
        }
    }
    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            guard let service = p.services?.first(where: { $0.uuid == serviceUUID }) else { return }
            p.discoverCharacteristics([statusCharUUID], for: service)
        }
    }
    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let c = service.characteristics?.first(where: { $0.uuid == statusCharUUID }) {
                statusCharacteristic = c
                p.setNotifyValue(true, for: c)
            }
        }
    }
    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard let data = c.value else { return }
            processIncomingData(data)
        }
    }
}

extension BLEManager {
    private func mapSTAT(_ code: String) -> String {
        switch code {
        case "I": return L("state.idle")
        case "R": return L("state.running")
        case "P": return L("state.paused")
        case "U": return L("state.updating")
        case "A": return L("state.autoStop")
        case "D": return L("state.done")
        default: return String(format: NSLocalizedString("state.unknown_format", comment: ""), code)
        }
    }

    @MainActor
    private func mapSTATState(_ code: String) -> DeviceState {
        switch code {
        case "I": return .idle
        case "R": return .running
        case "P": return .paused
        case "U": return .updating
        case "A": return .autoStop
        case "D": return .done
        default: return deviceState
        }
    }

    @MainActor
    private func processIncomingData(_ data: Data) {
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            handleIncoming(dict)
            return
        }
        if let string = String(data: data, encoding: .utf8),
           let jsonData = string.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            handleIncoming(dict)
            return
        }
    }

    @MainActor
    private func handleIncoming(_ dict: [String: Any]) {
        if let ssids = dict["SSID_LIST"] as? [String] {
            self.isScanningForSSIDs = false
            self.ssidList.availableSSIDs = ssids
            #if DEBUG
            print("[BLEManager] SSID-Liste empfangen: \(ssids)")
            #endif
            return
        }
        if let stat = dict["STAT"] as? [String: Any] {
            self.updateStatus(from: stat)
            return
        }
        self.updateStatus(from: dict)
    }

    @MainActor
    private func updateStatus(from dict: [String: Any]) {
        if let code = dict["STAT"] as? String {
            Task { @MainActor in
                let newState = self.mapSTATState(code)
                self.deviceStateText = self.mapSTAT(code)
                if newState != self.deviceState {
                    if newState == .done {
                        LocalNotificationManager.shared.notifyDone()
                    } else if newState == .autoStop, self.deviceState == .running {
                        LocalNotificationManager.shared.notifyAutoStop()
                    }
                    self.previousDeviceState = self.deviceState
                    self.deviceState = newState
                } else {
                    self.deviceState = newState
                }
            }
        }
        guard isConnected else { return }
        if !didInitialSync {
            didInitialSync = true
        }
        status.hasFilament = (dict["HAS_FIL"] as? Bool) ?? status.hasFilament
        if let useFil = dict["USE_FIL"] as? Bool {
            let t = lastLocalSettingChange["useFilamentSensor"] ?? .distantPast
            let age = Date().timeIntervalSince(t)
            if age > 0.5 {
                status.useFilamentSensor = useFil
            }
        }
        status.progress = (dict["PROG"] as? Double) ?? status.progress
        status.remainingTime = (dict["REM"] as? Int) ?? status.remainingTime
        if let spd = dict["SPD"] as? Int {
            let now = Date()
            let t = lastLocalSettingChange["speedPercent"] ?? .distantPast
            let age = now.timeIntervalSince(t)

            if age <= localEchoWindow {
                if let expected = expectedEchoInt["speedPercent"], expected == spd {
                    status.speedPercent = spd
                    expectedEchoInt.removeValue(forKey: "speedPercent")
                    lastRemoteSPD = spd
                    lastRemoteSPDTimestamp = now
                    remoteSPDRepeatCount = 0
                }
            } else {
                if lastRemoteSPD == spd {
                    if now.timeIntervalSince(lastRemoteSPDTimestamp) >= remoteSPDDebounceInterval {
                        remoteSPDRepeatCount += 1
                        lastRemoteSPDTimestamp = now
                    }
                } else {
                    lastRemoteSPD = spd
                    lastRemoteSPDTimestamp = now
                    remoteSPDRepeatCount = 1
                }

                if remoteSPDRepeatCount >= remoteSPDDebounceRounds {
                    status.speedPercent = spd
                    expectedEchoInt.removeValue(forKey: "speedPercent")
                    remoteSPDRepeatCount = 0
                }
            }
        }
        if let temp = dict["TEMP"] as? Int {
            temperatureHistory.append(temp)
            if temperatureHistory.count > 10 { temperatureHistory.removeFirst() }
            status.chipTemperature = Int(Double(temperatureHistory.reduce(0, +)) / Double(temperatureHistory.count))
        }
        status.wifiSSID = dict["WIFI_SSID"] as? String
        if let incomingWiFiOK = dict["WIFI_OK"] as? Bool {
            if let until = wifiStatusHoldUntil, Date() < until {
                status.wifiConnected = false
                pendingWiFiConnected = incomingWiFiOK
            } else {
                status.wifiConnected = incomingWiFiOK
                pendingWiFiConnected = nil
            }
        }
        status.wifiLastResult = dict["WIFI_RESULT"] as? Bool
        if let otaOK = dict["OTA_OK"] as? Bool {
            #if DEBUG
            print("[BLEManager] OTA_OK empfangen: \(otaOK)")
            #endif
            status.otaSuccess = otaOK
            Task { @MainActor in
                self.showOTAAlert = true
            }
        }
        status.firmwareVersion = dict["FW"] as? String

        if let connResult = dict["WIFI_CONN_RESULT"] as? Bool {
            status.wifiConnectionResult = connResult
        }

        if let jin = dict["JIN"] as? Int {
            let t = lastLocalSettingChange["jingleStyle"] ?? .distantPast
            let age = Date().timeIntervalSince(t)
            if age > 0.5 {
                status.jingleStyle = jin
            }
        }
        if let led = dict["LED"] as? Int {
            let t = lastLocalSettingChange["ledBrightness"] ?? .distantPast
            let age = Date().timeIntervalSince(t)
            if age > 0.5 {
                status.ledBrightness = led
            }
        }
        if let fan_spd = dict["FAN_SPD"] as? Int {
            let t = lastLocalSettingChange["fanSpeed"] ?? .distantPast
            let age = Date().timeIntervalSince(t)
            if age > 0.5 {
                status.fanSpeed = fan_spd
            }
        }
        if let fan_on = dict["FAN_ON"] as? Bool {
            status.isFanOn = fan_on
        }
        if let fan_alw = dict["FAN_ALW"] as? Bool {
            let t = lastLocalSettingChange["fanAlways"] ?? .distantPast
            let age = Date().timeIntervalSince(t)
            if age > 0.5 {
                status.fanAlways = fan_alw
            }
        }
        if let dir = dict["DIR"] as? Bool {
            let t = lastLocalSettingChange["directionReversed"] ?? .distantPast
            let age = Date().timeIntervalSince(t)
            if age > 0.5 {
                status.directionReversed = dir
            }
        }
        if let pow = dict["POW"] as? Int {
            let t = lastLocalSettingChange["motorStrength"] ?? .distantPast
            let age = Date().timeIntervalSince(t)
            if age > 0.5 {
                status.motorStrength = pow
            }
        }
        if let trq = dict["TRQ"] as? Int {
            let t = lastLocalSettingChange["torqueLimit"] ?? .distantPast
            let age = Date().timeIntervalSince(t)
            if age > 0.5 {
                status.torqueLimit = trq
            }
        }
        if let hs = dict["HS"] as? Bool {
            let t = lastLocalSettingChange["highSpeed"] ?? .distantPast
            let age = Date().timeIntervalSince(t)
            if age > 0.5 {
                status.highSpeed = hs
            }
        }
        if let dur = dict["DUR"] as? Int {
            let t = lastLocalSettingChange["durationAt80"] ?? .distantPast
            let age = Date().timeIntervalSince(t)
            if age > 0.5 {
                status.durationAt80 = dur
            }
        }
        if let wgt = dict["WGT"] as? Int {
            let t = lastLocalSettingChange["targetWeight"] ?? .distantPast
            let age = Date().timeIntervalSince(t)
            if age > 0.5 {
                status.targetWeight = wgt
            }
        }
        Task { @MainActor in
            self.syncLiveActivity()
        }
        status.saveSettings()
    }
}

@MainActor
final class LocalNotificationManager {
    static let shared = LocalNotificationManager()
    private let autoStopCategory = "RESPOOLER_AUTOSTOP"
    private init() {
        UserDefaults.standard.register(defaults: [enabledKey: false])
        let start = UNNotificationAction(identifier: "START_ACTION", title: NSLocalizedString("Respooler starten", comment: "Start motor action"), options: [])
        let cat = UNNotificationCategory(identifier: autoStopCategory, actions: [start], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }

    private let enabledKey = "NotificationsEnabled"

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        if enabled {
            requestAuthorizationIfNeeded()
        }
    }

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            }
        }
    }

    func ensureAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .denied:
                completion(false)
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion(granted)
                }
            @unknown default:
                completion(false)
            }
        }
    }

    func notifyDone() {
        guard isEnabled else { return }
        if UIApplication.shared.applicationState == .active {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Respooler fertig!", comment: "Notification title when Respooler is done")
        content.body  = NSLocalizedString("Der Spulvorgang wurde erfolgreich fertiggestellt.", comment: "Notification body when Respooler is done")
        content.sound = .default
        let request = UNNotificationRequest(identifier: "spool-done",
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func notifyAutoStop() {
        guard isEnabled else { return }
        if UIApplication.shared.applicationState == .active {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Fehler: Auto-Stopp!", comment: "Notification title when Auto-Stop")
        content.body  = NSLocalizedString("Der Respooler hat automatisch angehalten. Überprüfe, ob der Motor blockiert ist.", comment: "Notification body when Auto-Stop")
        content.sound = .default
        content.categoryIdentifier = autoStopCategory
        let request = UNNotificationRequest(identifier: "spool-autostop",
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

extension BLEManager {
    func clearOtaStatus() {
        status.otaSuccess = nil
        Task { @MainActor in
            self.showOTAAlert = false
        }
    }
}

extension BLEManager {
    func setLED(_ brightness: Int) {
        guard didInitialSync else { return }
        sendPacket(settings: ["LED": brightness])
        status.ledBrightness = brightness
        lastLocalSettingChange["ledBrightness"] = Date()
        status.saveSettings()
    }
    
    func setFanSpeed(_ fanSpeed: Int) {
        guard didInitialSync, fanSpeed >= 10 else { return }
        sendPacket(settings: ["FAN_SPD": fanSpeed])
        status.fanSpeed = fanSpeed
        lastLocalSettingChange["fanSpeed"] = Date()
        status.saveSettings()
    }
    
    func setFanAlways(_ fanAlways: Bool) {
        guard didInitialSync else { return }
        sendPacket(settings: ["FAN_ALW": fanAlways ? 1 : 0])
        status.fanAlways = fanAlways
        lastLocalSettingChange["fanAlways"] = Date()
        status.saveSettings()
    }

    func setUseFilamentSensor(_ use: Bool) {
        guard didInitialSync else { return }
        sendPacket(settings: ["USE_FIL": use ? 1 : 0])
        status.useFilamentSensor = use
        lastLocalSettingChange["useFilamentSensor"] = Date()
        status.saveSettings()
    }

    func setDirectionReversed(_ reversed: Bool) {
        guard didInitialSync else { return }
        sendPacket(settings: ["DIR": reversed ? 1 : 0])
        status.directionReversed = reversed
        lastLocalSettingChange["directionReversed"] = Date()
        status.saveSettings()
    }

    func setMotorStrength(_ strength: Int) {
        guard didInitialSync else { return }
        sendPacket(settings: ["POW": strength])
        status.motorStrength = strength
        lastLocalSettingChange["motorStrength"] = Date()
        status.saveSettings()
    }

    func setTorqueLimit(_ limit: Int) {
        guard didInitialSync else { return }
        sendPacket(settings: ["TRQ": limit])
        status.torqueLimit = limit
        lastLocalSettingChange["torqueLimit"] = Date()
        status.saveSettings()
    }
    
    func setTargetWeight(_ target: Int) {
        guard didInitialSync else { return }
        sendPacket(settings: ["WGT": target])
        status.targetWeight = target
        lastLocalSettingChange["targetWeight"] = Date()
        status.saveSettings()
    }

    func setHighSpeed(_ enabled: Bool) {
        guard didInitialSync else { return }
        sendPacket(settings: ["HS": enabled ? 1 : 0])
        status.highSpeed = enabled
        lastLocalSettingChange["highSpeed"] = Date()
        status.saveSettings()
    }

    func setDurationAt80(_ duration: Int) {
        guard didInitialSync else { return }
        sendPacket(settings: ["DUR": duration])
        status.durationAt80 = duration
        lastLocalSettingChange["durationAt80"] = Date()
        status.saveSettings()
    }

    func setJingleStyle(_ style: Int) {
        guard didInitialSync else { return }
        sendPacket(settings: ["JIN": style])
        status.jingleStyle = style
        lastLocalSettingChange["jingleStyle"] = Date()
        status.saveSettings()
    }

    func setSpeedPercent(_ percent: Int) {
        guard didInitialSync else { return }
        sendPacket(settings: ["SPD": percent])
        status.speedPercent = percent
        expectedEchoInt["speedPercent"] = percent
        lastLocalSettingChange["speedPercent"] = Date()
        status.saveSettings()
    }
}

extension BLEManager {
    @MainActor
    fileprivate func syncLiveActivity() {
        LiveActivityManager.shared.sync(
            state: self.deviceState,
            isConnected: self.isConnected,
            progress: self.status.progress,
            remainingTime: self.status.remainingTime
        )
    }
}

extension BLEManager {
    @MainActor
    @objc func handleMotorRequested(_ notification: Notification) {
        if sharedDefaults?.bool(forKey: "startMotorRequested") == true {
            sharedDefaults?.set(false, forKey: "startMotorRequested")
            sharedDefaults?.synchronize()
            startMotor()
        }
        if sharedDefaults?.bool(forKey: "stopMotorRequested") == true {
            sharedDefaults?.set(false, forKey: "stopMotorRequested")
            sharedDefaults?.synchronize()
            stopMotor()
        }
        if sharedDefaults?.bool(forKey: "pauseMotorRequested") == true {
            sharedDefaults?.set(false, forKey: "pauseMotorRequested")
            sharedDefaults?.synchronize()
            pauseMotor()
        }
    }
}

nonisolated extension BLEManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in
            completionHandler([.banner, .list, .sound])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            switch response.actionIdentifier {
            case "START_ACTION":
                _ = try? await StartMotorIntent().perform()
            default:
                break
            }
            completionHandler()
        }
    }
}
