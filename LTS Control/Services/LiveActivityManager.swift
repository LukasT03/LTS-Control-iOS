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

    /// The board sends its status twice a second. The activity only updates when something visible changes:
    /// the state, the whole percent, or the board's estimate by more than this.
    private let endDateTolerance: TimeInterval = 2

    func sync(state: DeviceState, isConnected: Bool, progress: Double?, remainingTime: Int?) {
        guard isEnabled, isConnected, state != .idle else {
            endCurrentActivity()
            return
        }
        let content = Self.content(state: state, progress: progress, remainingTime: remainingTime)
        if let id = currentActivityID {
            guard !looksLikeLastContent(content) else { return }
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

    /// The end date moves a little with every packet, so it only counts as changed beyond the tolerance.
    private func looksLikeLastContent(_ content: ContentState) -> Bool {
        guard let last = lastContent, last.deviceState == content.deviceState,
              last.progress == content.progress, last.remainingTime == content.remainingTime else { return false }
        switch (last.endDate, content.endDate) {
        case (nil, nil): return true
        case let (lastEnd?, end?): return abs(lastEnd.timeIntervalSince(end)) < endDateTolerance
        default: return false
        }
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
