import SwiftUI

struct BoardVariantSelectionView: View {
    @Environment(BLEManager.self) private var bleManager
    @Environment(\.dismiss) private var dismiss

    @State private var selected: BoardVariant? = nil

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
                    }

                    variantOption(
                        title: "Respooler Pro",
                        imageName: "RespoolerPro",
                        isSelected: selected == .pro
                    ) {
                        selected = .pro
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
            } footer: {
                Text("Wähle die Variante deines Respoolers. Abhängig davon werden dir die verfügbaren Einstellungen angezeigt. Die Auswahl wird auf dem Board gespeichert und kann jederzeit in den Einstellungen geändert werden.")
            }

            Section {
                Button {
                    if let selected {
                        bleManager.setBoardVariant(selected)
                        dismiss()
                    }
                } label: {
                    Text("Speichern")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(selected == nil)
            }
        }
        .navigationTitle("Variante wählen")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            switch bleManager.status.boardVariant {
            case .pro:
                selected = .pro
            case .standard:
                selected = .standard
            default:
                selected = nil
            }
        }
    }
}

#Preview {
    NavigationStack {
        BoardVariantSelectionView()
    }
    .environment(BLEManager.shared)
}
