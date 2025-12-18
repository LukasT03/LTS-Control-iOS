import SwiftUI

struct BoardVariantSettingsView: View {
    @Environment(BLEManager.self) private var bleManager

    @State private var selected: BoardVariant = .standard

    @ViewBuilder
    private func variantOption(
        title: String,
        imageName: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 115)

                Text(title)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.ltsBlue : Color.secondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 20) {
                    variantOption(
                        title: "Respooler V4",
                        imageName: "Respooler",
                        isSelected: selected == .standard
                    ) {
                        selected = .standard
                        bleManager.status.boardVariant = .standard
                        bleManager.setBoardVariant(.standard)
                    }

                    variantOption(
                        title: "Respooler Pro",
                        imageName: "RespoolerPro",
                        isSelected: selected == .pro
                    ) {
                        selected = .pro
                        bleManager.status.boardVariant = .pro
                        bleManager.setBoardVariant(.pro)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
            } footer: {
                Text("Wähle die Variante deines Respoolers. Abhängig davon werden dir die verfügbaren Einstellungen angezeigt. Die Auswahl wird auf dem Board gespeichert.")
            }
        }
        .navigationTitle("Variante")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selected = (bleManager.status.boardVariant == .pro) ? .pro : .standard
        }
    }
}

#Preview {
    NavigationStack {
        BoardVariantSettingsView()
    }
    .environment(BLEManager.shared)
}
