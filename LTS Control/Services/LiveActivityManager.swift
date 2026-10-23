import Foundation
import ActivityKit

/// Shows a Live Activity while the Respooler is running, paused or stopped, and ends it when idle or disconnected.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private let enabledKey = "LiveActivityEnabled"
    private var currentActivity: Activity<SpoolActivityAttributes>?
    private var lastContent: SpoolActivityAttributes.ContentState?

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    private init() {
        UserDefaults.standard.register(defaults: [enabledKey: true])
        endAll(Activity<SpoolActivityAttributes>.activities)
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        if !enabled { endCurrentActivity() }
    }

    func sync(state: DeviceState, isConnected: Bool, progress: Double?, remainingTime: Int?) {
        guard isEnabled, isConnected, state != .idle else {
            endCurrentActivity()
            return
        }
        let content = SpoolActivityAttributes.ContentState(deviceState: state, progress: progress ?? 0, remainingTime: remainingTime)
        if let activity = currentActivity {
            guard content != lastContent else { return }
            lastContent = content
            Task { await activity.update(ActivityContent(state: content, staleDate: nil)) }
        } else if state == .running, ActivityAuthorizationInfo().areActivitiesEnabled {
            let leftovers = Activity<SpoolActivityAttributes>.activities
            currentActivity = try? Activity.request(
                attributes: SpoolActivityAttributes(),
                content: ActivityContent(state: content, staleDate: nil)
            )
            lastContent = content
            endAll(leftovers)
        }
    }

    private func endCurrentActivity() {
        guard let activity = currentActivity else { return }
        currentActivity = nil
        lastContent = nil
        endAll([activity])
    }

    private func endAll(_ activities: [Activity<SpoolActivityAttributes>]) {
        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
