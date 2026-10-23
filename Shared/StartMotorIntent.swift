import AppIntents
import Foundation
import Darwin

private let notif = "group.ltscontrol.motorRequest"

public struct StartMotorIntent: AppIntent {
    public init() {}

    public static var title: LocalizedStringResource = "Respooler starten"

    public func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: "group.ltscontrol")
        sharedDefaults?.set(true, forKey: "startMotorRequested")
        sharedDefaults?.synchronize()
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: notif as CFString),
            nil,
            nil,
            true)
        print("StartMotorIntent wurde ausgelöst (via App Group)")
        return .result()
    }
}
