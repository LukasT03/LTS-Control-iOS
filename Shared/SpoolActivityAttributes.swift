import ActivityKit
import Foundation

struct SpoolActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        var deviceState: DeviceState
        /// Whole percent, so the activity changes once per percent instead of with every status packet.
        var progress: Int
        /// While running: when the respool should finish. The countdown runs from it on its own.
        var endDate: Date?
        /// Otherwise: the remaining time in seconds, shown as is.
        var remainingTime: Int?
    }
}
