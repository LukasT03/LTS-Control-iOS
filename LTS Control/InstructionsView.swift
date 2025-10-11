import SwiftUI

struct InstructionsView: View {
    @Environment(AccessorySessionManager.self) private var accessorySessionManager
    @Environment(LayoutModel.self) private var layoutModel
    @Environment(\.dismiss) private var dismiss

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
                            description: "Achte darauf, dass das Respooler Board eingeschaltet ist und die aktuelle Firmware installiert wurde."
                        )
                        Button(action: {
                            accessorySessionManager.showAccessoryPicker()
                        }) {
                            Text("Verbindung erneut starten")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 48)
                        
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
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                    .padding(.trailing, 20)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.bottom, layoutModel.isCompactWidth ? 0 : 16)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("Hinweise")
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
}

struct InstructionsRow: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

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
                Text(description)
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
