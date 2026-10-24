import SwiftUI

struct InstructionsView: View {
    private static let reconnectURL = URL(string: "ltscontrol://reconnect")!

    @Environment(AccessorySessionManager.self) private var accessorySessionManager
    @Environment(LayoutModel.self) private var layoutModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        InstructionsRow(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "Verbindung herstellen",
                            description: "Achte darauf, dass das Respooler Board eingeschaltet ist und die aktuelle Firmware installiert wurde. [Verbindung erneut starten](ltscontrol://reconnect)"
                        )
                        
                        InstructionsRow(
                            icon: "arrow.down.circle",
                            title: "Board Firmware",
                            description: "Für OTA-Updates muss das Board mit dem lokalen WLAN verbunden sein. Alternativ dazu kann auch der Web Flasher auf der LTS Design Webseite genutzt werden."
                        )
                        .padding(.top, 26)
                        
                        InstructionsRow(
                            icon: "exclamationmark.triangle",
                            title: "Motorstärke",
                            description: "Passe die Motorstärke an, wenn der Motor heiß wird oder vibriert. Auch ein schwaches Netzteil kann die Stärke beeinflussen."
                        )
                        .padding(.top, 26)
                        
                        InstructionsRow(
                            icon: "stop.circle",
                            title: "Auto-Stopp",
                            description: "Die Empfindlichkeit hängt vom Netzteil ab. Wenn der Motor zu oft stoppt, verringere die Empfindlichkeit in den Einstellungen."
                        )
                        .padding(.top, 26)
                        
                        InstructionsRow(
                            icon: "chevron.left.forwardslash.chevron.right",
                            title: "GitHub",
                            description: "Der Quellcode sowie alle weiteren Dateien sind Open Source und können auf [GitHub](https://github.com/LukasT03/LTS-Respooler) heruntergeladen werden."
                        )
                        .padding(.top, 26)
                        
                        InstructionsRow(
                            icon: "exclamationmark.bubble",
                            title: "Feedback",
                            description: "Sende bei Fragen, Problemen oder Anregungen gerne eine E-Mail an info@lts-design.com."
                        )
                        .padding(.top, 26)

                        InstructionsRow(icon: "building.2", title: "Impressum", description: imprint)
                        .padding(.top, 26)
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                    .padding(.trailing, 20)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.bottom, layoutModel.isCompactWidth ? 0 : 16)
                }
                // In-app links like "Verbindung erneut starten"; all other links open as usual.
                .environment(\.openURL, OpenURLAction { url in
                    guard url == Self.reconnectURL else { return .systemAction }
                    accessorySessionManager.showAccessoryPicker()
                    return .handled
                })
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("Hinweise")
            .toolbar {
                SheetCloseButton()
            }
        }
    }
}

extension InstructionsView {
    /// Markdown would turn the mail address into a link; in the imprint it's plain text.
    private var imprint: Text {
        var text = AttributedString(localized: "LTS Design\nHeiligenbornstraße 23\n01219 Dresden, Deutschland\ninfo@lts-design.com\n© 2026 LTS Design")
        text.link = nil
        return Text(text)
    }
}

struct InstructionsRow: View {
    let icon: String
    let title: LocalizedStringKey
    let description: Text

    init(icon: String, title: LocalizedStringKey, description: LocalizedStringKey) {
        self.init(icon: icon, title: title, description: Text(description))
    }

    init(icon: String, title: LocalizedStringKey, description: Text) {
        self.icon = icon
        self.title = title
        self.description = description
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 28)
                .padding(.top, 4)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .bold()
                description
                    .foregroundColor(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if DEBUG
#Preview("Instructions") {
    InstructionsView()
        .environment(AccessorySessionManager())
}
#endif
