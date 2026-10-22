enum BoardVariant: String, Codable {
    case unknown = "UNK"
    case standard = "STD"
    case pro = "PRO"

    init(fromWireValue value: Any?) {
        if let s = value as? String {
            let up = s.uppercased()
            if up == "PRO" { self = .pro; return }
            if up == "STD" { self = .standard; return }
            self = .unknown
            return
        }
        if let i = value as? Int {
            if i == 2 { self = .pro; return }
            if i == 1 { self = .standard; return }
            self = .unknown
            return
        }
        if let d = value as? Double {
            let i = Int(d.rounded())
            if i == 2 { self = .pro; return }
            if i == 1 { self = .standard; return }
            self = .unknown
            return
        }
        self = .unknown
    }
}
