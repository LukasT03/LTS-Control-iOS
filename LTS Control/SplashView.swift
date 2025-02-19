import SwiftUI

// Hilfs-Konstante für die Wunschfarbe (#010080)
private let customBlue = Color(red: 1.0/255.0, green: 0.0, blue: 128.0/255.0)

struct SplashView: View {
    @StateObject private var accessorySetupManager = AccessorySetupManager()

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                Spacer()
                
                // Logo über der Überschrift
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                
                Spacer()
                
                // Begrüßungstext
                HStack {
                    Text("Willkommen bei LTS Control")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(minHeight: 100)
                
                Spacer()
                
                // Feature-Liste mit Icons
                VStack(alignment: .leading, spacing: 22) {
                    FeatureRow(
                        icon: "wrench",
                        title: "Funktion",
                        description: "Um das Respooler Control Board mit der App zu steuern, musst du es zuerst mit deinem iPhone verbinden."
                    )
                    FeatureRow(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "Verbinden",
                        description: "Stelle sicher, dass das Control Board eingeschaltet ist und starte die Kopplung über den Button unten."
                    )

                }
                .padding(.leading, 28)
                .padding(.trailing, 42)
                
                Spacer()
                Spacer()
        
                
                // Nativer Button für die Verbindung
                Button(action: {
                    accessorySetupManager.showAccessoryPicker()
                }) {
                    Text("Control Board verbinden").frame(minWidth: 0, maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 320 : .infinity)
                        .fontWeight(.semibold)
                }.buttonStyle(.borderedProminent)
                .controlSize(.large)
                .cornerRadius(14)
                .tint(customBlue)
                .padding(.horizontal, 24)
                Spacer()
                Spacer()

            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color(.systemBackground))
            .onAppear {
                accessorySetupManager.activateSession()
            }
        }
    }
}

/// FeatureRow mit Icon und Text, wobei das Icon vertikal zentriert zum Text ausgerichtet ist.
struct FeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 35, height: 35)
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

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView()
    }
}
