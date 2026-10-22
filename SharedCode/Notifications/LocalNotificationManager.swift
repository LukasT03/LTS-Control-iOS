import AppIntents
import Foundation
import UIKit
import UserNotifications

@MainActor
final class LocalNotificationManager {
    static let shared = LocalNotificationManager()
    private let autoStopCategory = "RESPOOLER_AUTOSTOP"
    private let enabledKey = "NotificationsEnabled"

    private init() {
        UserDefaults.standard.register(defaults: [enabledKey: false])
        let start = UNNotificationAction(identifier: "START_ACTION", title: NSLocalizedString("Respooler starten", comment: "Start motor action"), options: [])
        let cat = UNNotificationCategory(identifier: autoStopCategory, actions: [start], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
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
        content.body = NSLocalizedString("Der Spulvorgang wurde erfolgreich fertiggestellt.", comment: "Notification body when Respooler is done")
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
        content.body = NSLocalizedString("Der Respooler hat automatisch angehalten. Überprüfe, ob der Motor blockiert ist.", comment: "Notification body when Auto-Stop")
        content.sound = .default
        content.categoryIdentifier = autoStopCategory
        let request = UNNotificationRequest(identifier: "spool-autostop",
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
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
