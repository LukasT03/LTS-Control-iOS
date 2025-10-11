import AppIntents
import Foundation
import Darwin

private let notif = "group.ltscontrol.motorRequest"

public struct StopMotorIntent: AppIntent {
    public init() {}

    public static var title: LocalizedStringResource = "Respooler stoppen"

    public func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: "group.ltscontrol")
        sharedDefaults?.set(true, forKey: "stopMotorRequested")
        sharedDefaults?.synchronize()
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: notif as CFString),
            nil,
            nil,
            true)
        print("StopMotorIntent wurde ausgelöst (via App Group)")
        return .result()
    }
}
