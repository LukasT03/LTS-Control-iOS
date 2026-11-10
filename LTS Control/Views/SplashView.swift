import SwiftUI

struct SplashView: View {
    @Environment(AccessorySessionManager.self) private var accessorySessionManager
    @Environment(\.isSplitLayout) private var isSplitLayout

    /// The unfolded iPhone Duo.
    private var isWidePhone: Bool { UIDevice.current.userInterfaceIdiom == .phone && isSplitLayout }

    var body: some View {
        // Spacing modeled on Apple's own welcome screens (e.g. Fitness): content hangs from the top,
        // fixed gaps instead of spacers, rows and button share the same side margin.
        // Where the height runs short (e.g. on the folded iPhone Duo) the icon shrinks, text and the gap to the button stay.
        VStack(spacing: 0) {
            Image("AppIconSquare")
                .resizable()
                // Smooth downscaling of the large image, otherwise its edges come out jagged.
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: 130, maxHeight: 130)
                .shadow(color: Color.black.opacity(0.1), radius: 12)
                // Same margins as the text, so both center on the same width next to iPhone Duo's vertical bar.
                .horizontalPadding(40)
                .layoutPriority(1)

            Text("Willkommen bei LTS Control")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
                .horizontalPadding(40)
                .layoutPriority(2)

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
            // On the unfolded iPhone Duo Apple keeps the rows about as narrow as the button.
            .frame(maxWidth: isWidePhone ? 440 : nil)
            .padding(.top, 30)
            .horizontalPadding(40)
            .layoutPriority(2)

            Spacer(minLength: 24)
        }
        .padding(.top, 48)
        .sheetBottomButton {
            Button {
                accessorySessionManager.showAccessoryPicker()
            } label: {
                Text("Respooler verbinden")
                    .frame(maxWidth: .infinity)
            }
        }
        // The plain system background, white or dark gray, instead of the sheet's default material.
        .presentationBackground(.background)
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
