import Foundation
import ActivityKit

/// Shows a Live Activity while the Respooler is running, paused or stopped, and ends it when idle or disconnected.
@MainActor
final class LiveActivityManager {
    typealias ContentState = SpoolActivityAttributes.ContentState

    static let shared = LiveActivityManager()

    private let enabledKey = "LiveActivityEnabled"
    /// `Activity` isn't Sendable, so only its ID is kept and the activity is looked up where it's used.
    private var currentActivityID: String?
    private var lastContent: ContentState?

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    private init() {
        UserDefaults.standard.register(defaults: [enabledKey: true])
        let leftovers = Set(Activity<SpoolActivityAttributes>.activities.map(\.id))
        Task { await Self.endActivities { leftovers.contains($0) } }
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
        let content = ContentState(deviceState: state, progress: progress ?? 0, remainingTime: remainingTime)
        if let id = currentActivityID {
            guard content != lastContent else { return }
            lastContent = content
            Task { await Self.updateActivity(id, to: content) }
        } else if state == .running, ActivityAuthorizationInfo().areActivitiesEnabled {
            guard let activity = try? Activity.request(
                attributes: SpoolActivityAttributes(),
                content: ActivityContent(state: content, staleDate: nil)
            ) else { return }
            let id = activity.id
            currentActivityID = id
            lastContent = content
            Task { await Self.endActivities { $0 != id } }
        }
    }

    private func endCurrentActivity() {
        guard let id = currentActivityID else { return }
        currentActivityID = nil
        lastContent = nil
        Task { await Self.endActivities { $0 == id } }
    }

    private nonisolated static func updateActivity(_ id: String, to content: ContentState) async {
        for activity in Activity<SpoolActivityAttributes>.activities where activity.id == id {
            await activity.update(ActivityContent(state: content, staleDate: nil))
        }
    }

    private nonisolated static func endActivities(where shouldEnd: @Sendable (String) -> Bool) async {
        for activity in Activity<SpoolActivityAttributes>.activities where shouldEnd(activity.id) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
