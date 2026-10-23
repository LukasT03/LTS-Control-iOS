import Foundation

enum BoardVariant: String, Codable {
    case unknown = "UNK"
    case standard = "STD"
    case pro = "PRO"

    /// The board sends the variant as "STD"/"PRO" or, on some firmware versions, as 1/2.
    init(fromWireValue value: Any?) {
        switch value {
        case let string as String:
            self = BoardVariant(rawValue: string.uppercased()) ?? .unknown
        case let number as NSNumber where number.doubleValue.rounded() == 1:
            self = .standard
        case let number as NSNumber where number.doubleValue.rounded() == 2:
            self = .pro
        default:
            self = .unknown
        }
    }
}
