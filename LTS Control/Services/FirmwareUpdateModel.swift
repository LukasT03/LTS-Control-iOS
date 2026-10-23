import Foundation
import Observation

/// Latest board firmware published on GitHub Pages, cached for offline use.
@MainActor
@Observable
final class FirmwareUpdateModel {
    private static let url = URL(string: "https://respooler.lts-design.com/Firmware/latest_board_firmware.txt")!
    private static let cacheKey = "latestBoardFirmwareVersion"

    private(set) var latestVersion = UserDefaults.standard.string(forKey: cacheKey)

    func isUpdateAvailable(for current: String?) -> Bool {
        guard let latestVersion, let current else { return false }
        return FirmwareVersion.compare(latestVersion, current) == .orderedDescending
    }

    func refresh() async {
        // GitHub Pages caches for several minutes, the query parameter bypasses that.
        var components = URLComponents(url: Self.url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
        var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let version = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !version.isEmpty else { return }
        latestVersion = version
        UserDefaults.standard.set(version, forKey: Self.cacheKey)
    }
}

enum FirmwareVersion {
    /// Compares dotted versions numerically, so "1.10" is newer than "1.9".
    /// Non-digits (e.g. a leading "v") are ignored and missing parts count as 0.
    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let lhs = parts(a), rhs = parts(b)
        for i in 0..<max(lhs.count, rhs.count) {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    private static func parts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    }
}
