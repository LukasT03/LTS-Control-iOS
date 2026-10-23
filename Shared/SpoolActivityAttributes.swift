import ActivityKit
import Foundation

struct SpoolActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        var deviceState: DeviceState
        var progress: Double
        var remainingTime: Int?
    }
}
