import Foundation
import UIKit
import UserNotifications

private let startActionID = "START_ACTION"

@MainActor
final class LocalNotificationManager: NSObject {
    static let shared = LocalNotificationManager()

    private let autoStopCategory = "RESPOOLER_AUTOSTOP"
    private let enabledKey = "NotificationsEnabled"

    private override init() {
        super.init()
        UserDefaults.standard.register(defaults: [enabledKey: false])
        let start = UNNotificationAction(identifier: startActionID, title: NSLocalizedString("Respooler starten", comment: "Start motor action"), options: [])
        let category = UNNotificationCategory(identifier: autoStopCategory, actions: [start], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = self
    }

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
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion(granted)
                }
            default:
                completion(false)
            }
        }
    }

    func notifyDone() {
        post(
            id: "spool-done",
            title: NSLocalizedString("Respooler fertig!", comment: "Notification title when Respooler is done"),
            body: NSLocalizedString("Der Spulvorgang wurde erfolgreich fertiggestellt.", comment: "Notification body when Respooler is done")
        )
    }

    func notifyAutoStop() {
        post(
            id: "spool-autostop",
            title: NSLocalizedString("Fehler: Auto-Stopp!", comment: "Notification title when Auto-Stop"),
            body: NSLocalizedString("Der Respooler hat automatisch angehalten. Überprüfe, ob der Motor blockiert ist.", comment: "Notification body when Auto-Stop"),
            category: autoStopCategory
        )
    }

    /// Only notifies while the app is in the background; in the foreground the UI already shows the state.
    private func post(id: String, title: String, body: String, category: String? = nil) {
        guard isEnabled, UIApplication.shared.applicationState != .active else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let category { content.categoryIdentifier = category }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}

extension LocalNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == startActionID else { return }
        await MainActor.run { BLEManager.shared.startMotor() }
    }
}
