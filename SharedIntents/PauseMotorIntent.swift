import AppIntents
import Foundation
import Darwin

private let notif = "group.ltscontrol.motorRequest"

public struct PauseMotorIntent: AppIntent {
    public init() {}

    public static var title: LocalizedStringResource = "Respooler pausieren"

    public func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: "group.ltscontrol")
        sharedDefaults?.set(true, forKey: "pauseMotorRequested")
        sharedDefaults?.synchronize()
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: notif as CFString),
            nil,
            nil,
            true)
        print("PauseMotorIntent wurde ausgelöst (via App Group)")
        return .result()
    }
}
