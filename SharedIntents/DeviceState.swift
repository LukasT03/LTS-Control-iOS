import Foundation

public enum DeviceState: String, Codable, Hashable {
    case idle
    case running
    case paused
    case updating
    case autoStop
    case done
}
