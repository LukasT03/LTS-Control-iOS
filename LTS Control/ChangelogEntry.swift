import SwiftUI
import Foundation

struct ChangelogEntry: Identifiable, Hashable, Codable {
    var id: String { version }
    let version: String
    let items: [String]
}

@MainActor
final class FirmwareChangelogViewModel: ObservableObject {
    @Published var entries: [ChangelogEntry] = []
    @Published var isLoading = false
    @Published var error: String? = nil

    let sourceURL: URL

    init(sourceURL: URL = URL(string: "https://download.lts-design.com/Firmware/README.md")!) {
        self.sourceURL = sourceURL
    }

    private let cacheKey = "FirmwareChangelog.cache.v1"

    func loadCached() {
        if let data = UserDefaults.standard.data(forKey: cacheKey) {
            if let cached = try? JSONDecoder().decode([ChangelogEntry].self, from: data), !cached.isEmpty {
                self.entries = cached
            }
        }
    }

    private func saveCache(_ entries: [ChangelogEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    func load() async {
        error = nil
        isLoading = true
        defer { isLoading = false }
        do {
            var request = URLRequest(url: sourceURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let text = String(decoding: data, as: UTF8.self)
            let parsed = Self.parseChangelog(from: text)
            self.entries = parsed
            if parsed.isEmpty {
                throw NSError(domain: "ChangelogParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Keine Daten gefunden."])
            } else {
                saveCache(parsed)
            }
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }

    static func parseChangelog(from text: String) -> [ChangelogEntry] {
        enum State { case none, inVersion(String, [String]) }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var entries: [ChangelogEntry] = []
        var state: State = .none

        func commit(_ state: inout State) {
            if case let .inVersion(v, items) = state, !v.isEmpty, !items.isEmpty {
                entries.append(ChangelogEntry(version: v, items: items))
            }
            state = .none
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("### ") {
                commit(&state)
                var version = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                if version.first == "v" || version.first == "V" {
                    version.removeFirst()
                    version = version.trimmingCharacters(in: .whitespaces)
                }
                state = .inVersion(version, [])
                continue
            }

            if let bullet = Self.extractBullet(from: line) {
                switch state {
                case .inVersion(let v, var items):
                    items.append(bullet)
                    state = .inVersion(v, items)
                case .none:
                    break
                }
                continue
            }
        }
        commit(&state)
        return entries
    }

    private static func extractBullet(from line: String) -> String? {
        let markers: [Character] = ["-", "*", "•", "–", "—"]
        guard let first = line.first, markers.contains(first) else { return nil }
        let afterMarker = line.dropFirst().trimmingCharacters(in: .whitespaces)
        return afterMarker.isEmpty ? nil : afterMarker
    }
}

struct FirmwareChangelogView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: FirmwareChangelogViewModel
    @AppStorage("FirmwareChangelog.entriesSignature") private var storedEntriesSignature: Int = 0
    @State private var shouldAnimate = false
    @State private var fadeVisible = true
    @AppStorage("FirmwareChangelog.hasSeenEntries") private var hasSeenEntries: Bool = false

    init(sourceURL: URL = URL(string: "https://download.lts-design.com/Firmware/README.md")!) {
        _vm = StateObject(wrappedValue: FirmwareChangelogViewModel(sourceURL: sourceURL))
    }

    private func stableSignature(_ entries: [ChangelogEntry]) -> Int {
        var hash: UInt64 = 1469598103934665603
        let prime: UInt64 = 1099511628211
        for e in entries {
            for b in e.version.utf8 { hash = (hash ^ UInt64(b)) &* prime }
            for item in e.items { for b in item.utf8 { hash = (hash ^ UInt64(b)) &* prime } }
        }
        return Int(truncatingIfNeeded: hash)
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            if let error = vm.error, vm.entries.isEmpty {
                VStack(spacing: 18) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                        .font(.system(size: 33))
                    Text("Konnte nicht geladen werden.")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text(error)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !vm.entries.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(vm.entries.enumerated()), id: \.element.id) { idx, entry in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(entry.version)
                                    .font(.headline)
                                    .bold()

                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(entry.items, id: \.self) { bullet in
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text("•")
                                            Text(bullet)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.trailing, 20)
                            .padding(.vertical, 16)

                            if idx < vm.entries.count - 1 {
                                Divider()
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .opacity(shouldAnimate ? (fadeVisible ? 1 : 0) : 1)
            }
        }
        .onChange(of: vm.entries) { oldValue, newValue in
            let newSig = stableSignature(newValue)
            let firstAppearance = oldValue.isEmpty && !newValue.isEmpty
            let firstEver = (storedEntriesSignature == 0 && !hasSeenEntries)
            let isNewComparedToStored = (storedEntriesSignature != 0 && newSig != storedEntriesSignature)

            let should = (firstAppearance && firstEver) || isNewComparedToStored
            shouldAnimate = should
            storedEntriesSignature = newSig
            hasSeenEntries = true

            if should {
                fadeVisible = false
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        fadeVisible = true
                    }
                }
            } else {
                fadeVisible = true
            }
        }
        .onAppear {
            if storedEntriesSignature == 0 && !hasSeenEntries {
                shouldAnimate = true
                fadeVisible = false
            }
            vm.loadCached()
            Task { await vm.load() }
        }
        .navigationTitle("Versionsverlauf")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    if #available(iOS 26, *) {
                        Image(systemName: "xmark")
                    } else {
                        Text("Schließen")
                    }
                }
            }
        }
    }
}

