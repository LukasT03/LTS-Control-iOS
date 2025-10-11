import ActivityKit
import Foundation

struct SpoolActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var deviceState: DeviceState
        var progress: Double
        var remainingTime: Int?
    }
}
