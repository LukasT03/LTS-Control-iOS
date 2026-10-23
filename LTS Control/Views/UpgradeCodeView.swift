import SwiftUI

struct UpgradeCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            InstructionsRow(
                icon: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90",
                title: "Keine Updates mehr",
                description: "Da das V3 Control Board nur in begrenzter Stückzahl verkauft wurde und nicht alle Funktionen unterstützt, wird es dafür **keine weiteren Firmware-Updates** mehr geben.\n\nAlle momentan vorhandenen Funktionen bleiben bestehen."
            )
            
            InstructionsRow(
                icon: "tag",
                title: "Rabatt Code",
                description: "Wenn du **kostenlos** das neue Control Board V4 erhalten möchtest, kannst du den folgenden Code dafür im Store anwenden, sobald es verfügbar ist."
            )
            .padding(.top, 26)
            
            HStack{
                Text("CBV4-FREE")
                    .font(.title)
                    .textSelection(.enabled)
                Spacer()
                if didCopy {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.primary)
                        .font(.system(size: 22))
                        .frame(width: 30)
                        .contentTransition(.symbolEffect(.replace))
                } else {
                    Button {
                        UIPasteboard.general.string = "CBV4-FREE"
                        withAnimation {
                            didCopy = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                didCopy = false
                            }
                        }
                    } label: {
                        Image(systemName: "document.on.document")
                            .font(.system(size: 22))
                            .tint(.primary)
                            .frame(width: 30)
                    }
                }
            }
            .padding(.horizontal)
            .background(Capsule()
                .fill(Color(UIColor.tertiarySystemFill))
                .frame(height: 50)
            )
            .padding(.leading, 20)
            .padding(.top, 40)
            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)
        .padding(.trailing, 20)
        .navigationTitle("Neues Control Board")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    if #available(iOS 26.0, *) {
                        Image(systemName: "xmark")
                    } else {
                        Text("Schließen")
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        UpgradeCodeView()
    }
}
