import SwiftUI

struct InstructionsView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Spacer()
                Spacer()
                InstructionsRow(
                    icon: "wrench",
                    title: "Funktion",
                    description: "Um das Respooler Control Board mit der App zu steuern, musst du es mit deinem iPhone über BLE verbinden."
                )
                Spacer()
                InstructionsRow(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Verbinden",
                    description: "Stelle sicher, dass das Control Board eingeschaltet ist und starte die Kopplung in den Einstellungen."
                )
                Spacer()
                InstructionsRow(
                    icon: "antenna.radiowaves.left.and.right.slash",
                    title: "Gerät entfernen",
                    description: "Um erneut eine Verbidung herzustellen, entferne das gemerkte Gerät zunächst über den Button in den Einstellungen."
                )
                Spacer()
                InstructionsRow(
                    icon: "dumbbell",
                    title: "Motor-Stärke",
                    description: "Falls dein Motor zu heiß wird oder vibriert, passe die Stärke über den Slider in den Einstellungen an."
                )
                Spacer()
                Spacer()
            }
            
            .padding(.leading, 28)
            .padding(.trailing, 40)
            .navigationTitle("Hinweise") // Überschrift
            .navigationBarTitleDisplayMode(.inline) // Überschrift inline
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                    presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct InstructionsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            InstructionsView(
            )
        }
    }
}

struct InstructionsRow: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 28)
                .padding(.top, 5)
                .fontWeight(.semibold)
            VStack(alignment: .leading) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .foregroundColor(.gray)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
