import SwiftUI

/// Picks Standard or Pro. As initial selection (after connecting a board without a stored variant)
/// it needs an explicit "Speichern"; in the settings a tap applies the variant right away.
struct BoardVariantView: View {
    @Environment(BLEManager.self) private var bleManager
    @Environment(\.dismiss) private var dismiss

    let isInitialSelection: Bool

    @State private var selected: BoardVariant? = nil

    private func variantOption(_ variant: BoardVariant, title: String, imageName: String) -> some View {
        Button {
            selected = variant
            if !isInitialSelection {
                bleManager.status.boardVariant = variant
                bleManager.setBoardVariant(variant)
            }
        } label: {
            VStack(spacing: 10) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 115)

                Text(title)

                Image(systemName: selected == variant ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(selected == variant ? Color.ltsBlue : Color.secondary)
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
                    variantOption(.standard, title: "Respooler V4", imageName: "Respooler")
                    variantOption(.pro, title: "Respooler Pro", imageName: "RespoolerPro")
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
            } footer: {
                if isInitialSelection {
                    Text("Wähle die Variante deines Respoolers. Abhängig davon werden dir die verfügbaren Einstellungen angezeigt. Die Auswahl wird auf dem Board gespeichert und kann jederzeit in den Einstellungen geändert werden.")
                } else {
                    Text("Wähle die Variante deines Respoolers. Abhängig davon werden dir die verfügbaren Einstellungen angezeigt. Die Auswahl wird auf dem Board gespeichert.")
                }
            }

            if isInitialSelection {
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
        }
        .navigationTitle(isInitialSelection ? "Variante wählen" : "Variante")
        .navigationBarTitleDisplayMode(isInitialSelection ? .large : .inline)
        .onAppear {
            switch bleManager.status.boardVariant {
            case .pro: selected = .pro
            case .standard: selected = .standard
            case .unknown: selected = isInitialSelection ? nil : .standard
            }
        }
    }
}

#Preview {
    NavigationStack {
        BoardVariantView(isInitialSelection: true)
    }
    .environment(BLEManager.shared)
}
