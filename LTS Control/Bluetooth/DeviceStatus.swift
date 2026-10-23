import Foundation
import Observation

/// Last known state of the board. Settings and board info are cached in UserDefaults
/// so the UI shows sensible values before the board has sent its first status.
@MainActor
@Observable
final class DeviceStatus {
    private static let store: UserDefaults = {
        UserDefaults.standard.register(defaults: [
            "speedPercent": 85,
            "ledBrightness": 50,
            "fanSpeed": 60,
            "useFilamentSensor": true,
            "motorStrength": 100,
            "durationAt80": 895,
            "servoAngleR": 5,
            "servoAngleL": 175,
            "servoStepMm": 1.75,
            "servoHome": "R",
        ])
        return .standard
    }()

    // Live values, only valid while connected
    var hasFilament = false
    var progress: Double? = nil
    var remainingTime: Int? = nil
    var chipTemperature: Int? = nil
    var wifiSSID: String? = nil
    var wifiConnected: Bool? = nil
    var wifiConnectionResult: Bool? = nil
    var isFanOn = false
    var otaSuccess: Bool? = nil

    // Board info
    var firmwareVersion = store.string(forKey: "boardFirmwareVersion")
    var boardVersion = store.string(forKey: "boardVersion")
    var boardVariant = BoardVariant(rawValue: store.string(forKey: "boardVariant") ?? "") ?? .unknown
    var didReceiveBoardVariant = false

    // Settings mirrored from the board
    var speedPercent = store.integer(forKey: "speedPercent")
    var jingleStyle = store.integer(forKey: "jingleStyle")
    var ledBrightness = store.integer(forKey: "ledBrightness")
    var fanSpeed = store.integer(forKey: "fanSpeed")
    var fanAlways = store.bool(forKey: "fanAlways")
    var useFilamentSensor = store.bool(forKey: "useFilamentSensor")
    var directionReversed = store.bool(forKey: "directionReversed")
    var motorStrength = store.integer(forKey: "motorStrength")
    var torqueLimit = store.integer(forKey: "torqueLimit")
    var highSpeed = store.bool(forKey: "highSpeed")
    var durationAt80 = store.integer(forKey: "durationAt80")
    var targetWeight = store.integer(forKey: "targetWeight")
    var servoAngleR = store.integer(forKey: "servoAngleR")
    var servoAngleL = store.integer(forKey: "servoAngleL")
    var servoStepMm = store.double(forKey: "servoStepMm")
    var servoHome = store.string(forKey: "servoHome") ?? "R"

    @ObservationIgnored private var lastSaved: NSDictionary?

    /// Writes the cached values, but only if something changed since the last save.
    func save() {
        var values: [String: Any] = [
            "speedPercent": speedPercent,
            "jingleStyle": jingleStyle,
            "ledBrightness": ledBrightness,
            "fanSpeed": fanSpeed,
            "fanAlways": fanAlways,
            "useFilamentSensor": useFilamentSensor,
            "directionReversed": directionReversed,
            "motorStrength": motorStrength,
            "torqueLimit": torqueLimit,
            "highSpeed": highSpeed,
            "durationAt80": durationAt80,
            "targetWeight": targetWeight,
            "servoAngleR": servoAngleR,
            "servoAngleL": servoAngleL,
            "servoStepMm": servoStepMm,
            "servoHome": servoHome,
            "boardVariant": boardVariant.rawValue,
        ]
        values["boardVersion"] = boardVersion
        values["boardFirmwareVersion"] = firmwareVersion

        let snapshot = NSDictionary(dictionary: values)
        guard snapshot != lastSaved else { return }
        lastSaved = snapshot

        for (key, value) in values {
            Self.store.set(value, forKey: key)
        }
        if boardVersion == nil {
            Self.store.removeObject(forKey: "boardVersion")
        }
    }

    func resetLiveValues() {
        hasFilament = false
        progress = 0
        remainingTime = nil
        chipTemperature = nil
        wifiSSID = nil
        wifiConnected = nil
        wifiConnectionResult = nil
        isFanOn = false
    }
}
