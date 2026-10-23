import SwiftUI

struct SplashView: View {
    @Environment(AccessorySessionManager.self) private var accessorySessionManager

    var body: some View {
        let content = VStack {
            Spacer(minLength: 60)

            Image("AppIconSquare")
                .resizable()
                .scaledToFit()
                .frame(width: 130)
                .shadow(color: Color.black.opacity(0.1), radius: 12)

            Spacer()

            Text("Willkommen bei LTS Control")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .frame(maxWidth: 500)

            Spacer()

            VStack(alignment: .leading, spacing: 27) {
                FeatureRow(
                    icon: "gearshape",
                    title: "Funktion",
                    description: "Um das Respooler Board mit der App zu steuern, musst du es zuerst mit deinem \(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone") verbinden."
                )
                FeatureRow(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Verbinden",
                    description: "Stelle sicher, dass das Board eingeschaltet ist und starte die Kopplung über den Button unten."
                )
            }
            .padding(.leading, 30)
            .padding(.trailing, 42)

            Spacer()
        }
        .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 480 : 393)

        // Same bottom button as the Onyx sign-in screen.
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .bottom) {
                connectButton
                    .buttonStyle(.glassProminent)
                    .buttonSizing(.flexible)
                    .padding(.horizontal, 36)
                    // The iPad sheet has no bottom safe area, so the button would touch the edge.
                    .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? 36 : 0)
            }
        } else {
            content.safeAreaInset(edge: .bottom) {
                connectButton
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 36)
                    .padding(.bottom)
            }
        }
    }

    private var connectButton: some View {
        Button {
            accessorySessionManager.showAccessoryPicker()
        } label: {
            Text("Respooler verbinden")
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .fontWeight(.semibold)
    }
}

#Preview {
    SplashView()
        .environment(AccessorySessionManager())
}

struct FeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
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
