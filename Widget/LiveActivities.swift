import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents

@main
struct SpoolWidgets: WidgetBundle {
    var body: some Widget {
        SpoolWidget()
        SimpleButtonWidget()
    }
}

struct SpoolWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SpoolActivityAttributes.self) { context in
            SpoolActivityView(state: context.state)
        } dynamicIsland: { context in
            let parts = ActivityParts(state: context.state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if parts.isPaused {
                        parts.stopButton
                    } else {
                        Image("BambuSpoolWhite")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 52)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        parts.statusRow
                        parts.progressBar
                    }
                    .padding(.horizontal, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    parts.mainButton
                }
            } compactLeading: {
                parts.compactSpool
                    .modifier(CameraClearance(edge: .trailing))
            } compactTrailing: {
                parts.compactIndicator
                    .modifier(CameraClearance(edge: .leading))
            } minimal: {
                // A circle of its own, away from the camera.
                parts.compactIndicator
            }
        }
    }
}

struct SpoolActivityView: View {
    let state: SpoolActivityAttributes.ContentState

    var body: some View {
        let parts = ActivityParts(state: state, onLockScreen: true)
        HStack(spacing: 12) {
            Group {
                if parts.isPaused {
                    parts.stopButton
                } else {
                    Image("BambuSpoolWhite")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 52)
                }
            }
            .padding(.leading, 14)

            parts.mainButton

            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                parts.statusRow
                parts.progressBar
                Spacer()
            }

            Spacer()
        }
        .padding(.vertical, 12)
    }
}

/// Building blocks shared by the Lock Screen view and the Dynamic Island.
private struct ActivityParts {
    let state: SpoolActivityAttributes.ContentState
    var onLockScreen = false

    var isError: Bool { state.deviceState == .autoStop }
    var isPaused: Bool { state.deviceState == .paused }
    var isDone: Bool { state.deviceState == .done }

    var stopButton: some View {
        CircleIntentButton(intent: StopMotorIntent(), systemImage: "xmark", padding: 6, tint: .red, boostsFill: onLockScreen)
    }

    /// Resume after a pause or auto-stop, dismiss when done, pause while running.
    @ViewBuilder var mainButton: some View {
        if isError || isPaused {
            CircleIntentButton(intent: StartMotorIntent(), systemImage: "play.fill", padding: 5.7, nudgeRight: 2.3, tint: .blue, boostsFill: onLockScreen)
        } else if isDone {
            CircleIntentButton(intent: StopMotorIntent(), systemImage: "checkmark", padding: 6, tint: .blue, boostsFill: onLockScreen)
        } else {
            CircleIntentButton(intent: PauseMotorIntent(), systemImage: "pause.fill", padding: 7, tint: .blue, boostsFill: onLockScreen)
        }
    }

    var statusRow: some View {
        HStack {
            if isError {
                Text("Auto-Stopp!")
                    .foregroundColor(.red)
            } else if isPaused {
                Text("Pausiert")
            } else if isDone {
                Text("Fertig!")
            } else {
                Text("\(state.progress)%")
                    .monospacedDigit()
            }
            Spacer()
            remainingTimeText
                .monospacedDigit()
        }
    }

    /// Running, iOS counts down to the end date by itself, without an update every second.
    @ViewBuilder private var remainingTimeText: some View {
        if let endDate = state.endDate, endDate > .now {
            Text("-\(timerInterval: Date.now...endDate, countsDown: true)")
                .multilineTextAlignment(.trailing)
        } else {
            let remaining = state.remainingTime ?? 0
            Text(String(format: "-%02d:%02d", remaining / 60, remaining % 60))
        }
    }

    var progressBar: some View {
        ProgressView(value: Double(state.progress) / 100)
            .progressViewStyle(CustomProgressStyle(isError: isError, isDone: isDone, isPaused: isPaused))
            .frame(maxWidth: .infinity)
    }

    /// Both compact views share one fixed size: the island lays them out side by side on iPhone
    /// and stacked on iPhone Duo, and a view without its own size would fill whatever space it gets.
    private static let compactSize: CGFloat = 22

    var compactSpool: some View {
        Image("BambuSpoolWhite")
            .resizable()
            .scaledToFit()
            .frame(width: Self.compactSize, height: Self.compactSize)
    }

    var compactIndicator: some View {
        Group {
            if isError {
                Image(systemName: "exclamationmark.circle")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.red)
            } else if isDone {
                Image(systemName: "checkmark.circle")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.green)
            } else {
                ThickCircularProgressView(progress: Double(state.progress) / 100, color: isPaused ? .orange : .blue)
            }
        }
        .frame(width: Self.compactSize, height: Self.compactSize)
    }
}

/// Keeps a compact view clear of the camera on its inner side, so its outer side stays concentric with the island.
/// Not while the island is limited in width (shared with other Live Activities), where the system spaces it itself.
private struct CameraClearance: ViewModifier {
    private static let length: CGFloat = 2
    let edge: Edge.Set

    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content.modifier(LimitedWidthAware(edge: edge))
        } else {
            content.padding(edge, Self.length)
        }
    }

    @available(iOS 27, *)
    private struct LimitedWidthAware: ViewModifier {
        @Environment(\.isDynamicIslandLimitedInWidth) private var isLimitedInWidth
        let edge: Edge.Set

        func body(content: Content) -> some View {
            content.padding(edge, isLimitedInWidth ? 0 : CameraClearance.length)
        }
    }
}

private struct CircleIntentButton<Intent: AppIntent>: View {
    let intent: Intent
    let systemImage: String
    let padding: CGFloat
    /// Optical centering for asymmetric symbols like "play.fill".
    var nudgeRight: CGFloat = 0
    let tint: Color
    var boostsFill = false

    var body: some View {
        Button(intent: intent) {
            Image(systemName: systemImage)
                .resizable()
                .padding(padding)
                .padding(.leading, nudgeRight)
                .padding(.trailing, -nudgeRight)
                .scaledToFit()
                .frame(height: 52)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .frame(width: 52, height: 52)
        .background {
            // iOS 27 renders the bordered fill too faint on the Lock Screen.
            if #available(iOS 27, *), boostsFill {
                Circle().fill(tint.opacity(0.15))
            }
        }
        .tint(tint)
    }
}

struct ThickCircularProgressView: View {
    var progress: Double
    var lineWidth: CGFloat = 3
    var color: Color = .blue

    var body: some View {
        // Inset by half the line width, so the ring stays inside the view's frame.
        let ring = Circle().inset(by: lineWidth / 2)
        ZStack {
            ring
                .stroke(color == .orange ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2), lineWidth: lineWidth)

            ring
                .trim(from: 0.0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.default, value: progress)
    }
}

struct CustomProgressStyle: ProgressViewStyle {
    var isError: Bool
    var isDone: Bool = false
    var isPaused: Bool = false

    /// iOS 27 renders translucent fills on the Lock Screen much fainter, so the track needs more opacity there
    /// to look like the system's own Live Activity buttons.
    private var trackColor: Color {
        if #available(iOS 27, *) {
            if isError { return Color.red.opacity(0.35) }
            if isPaused { return Color.orange.opacity(0.35) }
            return Color.blue.opacity(0.35)
        }
        if isError { return Color.red.opacity(0.2) }
        if isPaused { return Color.orange.opacity(0.2) }
        return Color.gray.opacity(0.2)
    }

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            let progress = CGFloat(configuration.fractionCompleted ?? 0.0)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(trackColor)

                Rectangle()
                    .fill(isError ? Color.red : isDone ? Color.green : isPaused ? Color.orange : Color.blue)
                    .frame(width: geometry.size.width * progress)
            }
            .frame(height: 10)
            .mask(
                RoundedRectangle(cornerRadius: 5)
                    .frame(width: geometry.size.width, height: 10)
            )
            .animation(.default, value: progress)
        }
    }
}
