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

    /// The board sends its status twice a second, with the remaining time in whole seconds. The end date only moves
    /// when its estimate shifts by more than this, so the countdown runs evenly through the updates for each percent.
    private let endDateTolerance: TimeInterval = 2

    func sync(state: DeviceState, isConnected: Bool, progress: Double?, remainingTime: Int?) {
        guard isEnabled, isConnected, state != .idle else {
            endCurrentActivity()
            return
        }
        var content = Self.content(state: state, progress: progress, remainingTime: remainingTime)
        if let lastEnd = lastContent?.endDate, let end = content.endDate,
           abs(lastEnd.timeIntervalSince(end)) < endDateTolerance {
            content.endDate = lastEnd
        }
        if let id = currentActivityID {
            guard content != lastContent else { return }
            lastContent = content
            Task { await Self.updateActivity(id, to: content) }
        } else if state == .running, ActivityAuthorizationInfo().areActivitiesEnabled {
            guard let activity = try? Activity.request(
                attributes: SpoolActivityAttributes(),
                content: Self.activityContent(content)
            ) else { return }
            let id = activity.id
            currentActivityID = id
            lastContent = content
            Task { await Self.endActivities { $0 != id } }
        }
    }

    /// While running, the countdown runs to the end date on its own. Other states show the remaining time as is.
    private static func content(state: DeviceState, progress: Double?, remainingTime: Int?) -> ContentState {
        let percent = Int((progress ?? 0).rounded())
        guard state == .running, let remainingTime else {
            return ContentState(deviceState: state, progress: percent, remainingTime: remainingTime)
        }
        return ContentState(deviceState: state, progress: percent, endDate: .now.addingTimeInterval(TimeInterval(remainingTime)))
    }

    /// A running activity whose end date passed a minute ago without news from the board is out of date.
    private nonisolated static func activityContent(_ content: ContentState) -> ActivityContent<ContentState> {
        ActivityContent(state: content, staleDate: content.endDate?.addingTimeInterval(60))
    }

    private func endCurrentActivity() {
        guard let id = currentActivityID else { return }
        currentActivityID = nil
        lastContent = nil
        Task { await Self.endActivities { $0 == id } }
    }

    private nonisolated static func updateActivity(_ id: String, to content: ContentState) async {
        for activity in Activity<SpoolActivityAttributes>.activities where activity.id == id {
            await activity.update(activityContent(content))
        }
    }

    private nonisolated static func endActivities(where shouldEnd: @Sendable (String) -> Bool) async {
        for activity in Activity<SpoolActivityAttributes>.activities where shouldEnd(activity.id) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
