import Foundation
import ActivityKit

@MainActor
final class LiveActivityManager {
    private let enabledDefaultsKey = "LiveActivityEnabled"
    static let shared = LiveActivityManager()

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledDefaultsKey)
    }

    private var currentActivity: Activity<SpoolActivityAttributes>?
    private var lastState: DeviceState = .idle
    private var lastIsConnected: Bool = false

    private init() {
        UserDefaults.standard.register(defaults: [enabledDefaultsKey: true])
        Task { @MainActor in
            await endAllExistingActivities(reason: "App launch cleanup")
        }
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.isEnabled == false {
                    await self.endAllExistingActivities(reason: "Disabled by user")
                }
            }
        }
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledDefaultsKey)
        if enabled == false {
            Task { @MainActor in
                await endAllExistingActivities(reason: "Disabled by user")
            }
        }
    }

    func sync(
        state: DeviceState,
        isConnected: Bool,
        progress: Double?,
        remainingTime: Int?
    ) {
        lastState = state
        lastIsConnected = isConnected

        if isEnabled == false {
            Task { @MainActor in
                await endCurrentActivity(reason: "Disabled by user")
            }
            return
        }

        let shouldStart = (state == .running && currentActivity == nil)
        let shouldStop  = (state == .idle) || (isConnected == false)

        if shouldStop {
            Task { await endCurrentActivity(reason: stopReason(for: state, isConnected: isConnected)) }
            return
        }

        if shouldStart {
            Task { @MainActor in
                await startActivity(
                    state: state,
                    isConnected: isConnected,
                    progress: progress,
                    remainingTime: remainingTime
                )
            }
            return
        }

        Task { @MainActor in
            await updateActivity(
                state: state,
                isConnected: isConnected,
                progress: progress,
                remainingTime: remainingTime
            )
        }
    }
    
    func forceEndAllActivities() {
        Task { @MainActor in
            await endAllExistingActivities(reason: "Forced cleanup")
        }
    }

    private func startActivity(
        state: DeviceState,
        isConnected: Bool,
        progress: Double?,
        remainingTime: Int?
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, isEnabled else {
            return
        }

        await endAllExistingActivities(reason: "Ensure single activity")

        let content = SpoolActivityAttributes.ContentState(
            deviceState: state,
            progress: progress ?? 0.0,
            remainingTime: remainingTime
        )

        do {
            let activity = try Activity.request(
                attributes: SpoolActivityAttributes(),
                content: .init(state: content, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = activity
        } catch {
        }
    }

    private func updateActivity(
        state: DeviceState,
        isConnected: Bool,
        progress: Double?,
        remainingTime: Int?
    ) async {
        guard let activity = currentActivity else { return }

        let newContent = SpoolActivityAttributes.ContentState(
            deviceState: state,
            progress: progress ?? 0.0,
            remainingTime: remainingTime
        )

        await activity.update(ActivityContent(state: newContent, staleDate: nil))
    }

    private func endCurrentActivity(reason: String) async {
        guard let activity = currentActivity else { return }
        currentActivity = nil
        await end(activity: activity, reason: reason)
    }

    private func endAllExistingActivities(reason: String) async {
        let all = Activity<SpoolActivityAttributes>.activities
        guard all.isEmpty == false else { return }
        for act in all {
            await end(activity: act, reason: reason)
        }
        currentActivity = nil
    }

    private func end(activity: Activity<SpoolActivityAttributes>, reason: String) async {
        let finalState = activity.content.state
        await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
    }

    private func stopReason(for state: DeviceState, isConnected: Bool) -> String {
        if !isConnected { return "Disconnected" }
        if state == .idle { return "Back to idle" }
        return "Stop condition"
    }

    private func clamped01(_ value: Double?) -> Double? {
        guard let v = value else { return nil }
        if v.isNaN || v.isInfinite { return nil }
        return max(0.0, min(1.0, v))
    }
}
