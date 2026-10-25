import SwiftUI

struct SplashView: View {
    @Environment(AccessorySessionManager.self) private var accessorySessionManager

    var body: some View {
        // Spacing modeled on Apple's own welcome screens (e.g. Fitness): content hangs from the top,
        // fixed gaps instead of spacers, rows and button share the same side margin.
        VStack(spacing: 0) {
            Image("AppIconSquare")
                .resizable()
                .scaledToFit()
                .frame(width: 130)
                .shadow(color: Color.black.opacity(0.1), radius: 12)

            Text("Willkommen bei LTS Control")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.top, 24)

            VStack(spacing: 20) {
                FeatureRow(
                    icon: "play.circle",
                    title: "Respooler steuern",
                    description: "Starte, pausiere und stoppe den Spulvorgang und passe die Geschwindigkeit jederzeit an."
                )
                FeatureRow(
                    icon: "bell.badge",
                    title: "Status verfolgen",
                    description: "Behalte Fortschritt und Restzeit mit Live-Aktivitäten und Benachrichtigungen im Blick."
                )
                FeatureRow(
                    icon: "slider.horizontal.3",
                    title: "Genau einstellen",
                    description: "Passe Motorstärke, Auto-Stopp, Lüfter und mehr an deinen Respooler an."
                )
            }
            .padding(.top, 30)

            Spacer(minLength: 0)
        }
        .padding(.top, 48)
        .padding(.horizontal, 40)
        .sheetBottomButton {
            Button {
                accessorySessionManager.showAccessoryPicker()
            } label: {
                Text("Respooler verbinden")
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    SplashView()
        .environment(AccessorySessionManager())
}

/// Feature row in the style of Apple's welcome screens: the icon is centered on the title
/// and the first line of the description.
struct FeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        HStack(alignment: .featureIcon, spacing: 13) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .fontWeight(.semibold)
                    .alignmentGuide(.featureIcon) { $0[.bottom] }
                Text(description)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension VerticalAlignment {
    enum FeatureIcon: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d[VerticalAlignment.center] }
    }

    static let featureIcon = VerticalAlignment(FeatureIcon.self)
}
