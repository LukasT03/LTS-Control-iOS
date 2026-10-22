import Foundation
import Observation

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
    var boardVariant: BoardVariant = BoardVariant(rawValue: UserDefaults.standard.string(forKey: "boardVariant") ?? "UNK") ?? .unknown
    var didReceiveBoardVariant: Bool = false
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
    var servoAngleR: Int = UserDefaults.standard.integer(forKey: "servoAngleR")
    var servoAngleL: Int = UserDefaults.standard.integer(forKey: "servoAngleL")
    var servoStepMm: Double = UserDefaults.standard.double(forKey: "servoStepMm")
    var servoHome: String = UserDefaults.standard.string(forKey: "servoHome") ?? "R"

    init() {
        if speedPercent == 0 { speedPercent = 85 }
        if jingleStyle == 0 { jingleStyle = 0 }
        if ledBrightness == 0 { ledBrightness = 50 }
        if fanSpeed == 0 { fanSpeed = 60 }
        if motorStrength == 0 { motorStrength = 100 }
        if torqueLimit == 0 { torqueLimit = 0 }
        if durationAt80 == 0 { durationAt80 = 895 }
        if targetWeight == 0 { targetWeight = 0 }
        if servoAngleR == 0 { servoAngleR = 5 }
        if servoAngleL == 0 { servoAngleL = 175 }
        if servoStepMm == 0 { servoStepMm = 1.75 }
        if servoHome != "R" && servoHome != "L" { servoHome = "R" }
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
        UserDefaults.standard.set(servoAngleR, forKey: "servoAngleR")
        UserDefaults.standard.set(servoAngleL, forKey: "servoAngleL")
        UserDefaults.standard.set(servoStepMm, forKey: "servoStepMm")
        UserDefaults.standard.set(servoHome, forKey: "servoHome")
        UserDefaults.standard.set(boardVariant.rawValue, forKey: "boardVariant")
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
