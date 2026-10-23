import AppIntents
import Foundation

/// Motor commands that widgets, the Live Activity, Shortcuts and notifications can trigger.
enum MotorCommand: String, CaseIterable {
    case start = "START"
    case stop = "STOP"
    case pause = "PAUSE"

    static let appGroup = "group.ltscontrol"
    static let requestNotification = "group.ltscontrol.motorRequest"

    /// App Group flag for handing the command from the widget extension to the app.
    var requestKey: String {
        switch self {
        case .start: "startMotorRequested"
        case .stop: "stopMotorRequested"
        case .pause: "pauseMotorRequested"
        }
    }

    /// Live Activity intents are performed in the app process (the system launches the app if needed),
    /// so the command goes straight to the board. Should one ever run in the widget extension,
    /// it's handed to the app via the App Group and a Darwin notification.
    func run() async {
        #if WIDGET_EXTENSION
        UserDefaults(suiteName: Self.appGroup)?.set(true, forKey: requestKey)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(Self.requestNotification as CFString),
            nil,
            nil,
            true
        )
        #else
        await BLEManager.shared.perform(self)
        #endif
    }
}

struct StartMotorIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Respooler starten"

    func perform() async throws -> some IntentResult {
        await MotorCommand.start.run()
        return .result()
    }
}

struct StopMotorIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Respooler stoppen"

    func perform() async throws -> some IntentResult {
        await MotorCommand.stop.run()
        return .result()
    }
}

struct PauseMotorIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Respooler pausieren"

    func perform() async throws -> some IntentResult {
        await MotorCommand.pause.run()
        return .result()
    }
}
