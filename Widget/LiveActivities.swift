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
                            .padding(.horizontal, 6)
                        parts.progressBar
                            .padding(.horizontal, 6)
                            .tint(.blue)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    parts.mainButton
                }
            } compactLeading: {
                Image("BambuSpoolWhite")
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .clipped()
                    .padding(.trailing, 2)
            } compactTrailing: {
                parts.compactIndicator
            } minimal: {
                parts.compactIndicator
            }
        }
    }
}

struct SpoolActivityView: View {
    let state: SpoolActivityAttributes.ContentState

    var body: some View {
        let parts = ActivityParts(state: state)
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

    var isError: Bool { state.deviceState == .autoStop }
    var isPaused: Bool { state.deviceState == .paused }
    var isDone: Bool { state.deviceState == .done }

    var stopButton: some View {
        CircleIntentButton(intent: StopMotorIntent(), systemImage: "xmark", padding: 6, tint: .red)
    }

    /// Resume after a pause or auto-stop, dismiss when done, pause while running.
    @ViewBuilder var mainButton: some View {
        if isError || isPaused {
            CircleIntentButton(intent: StartMotorIntent(), systemImage: "play.fill", padding: 5.7, nudgeRight: 2.3, tint: .blue)
        } else if isDone {
            CircleIntentButton(intent: StopMotorIntent(), systemImage: "checkmark", padding: 6, tint: .blue)
        } else {
            CircleIntentButton(intent: PauseMotorIntent(), systemImage: "pause.fill", padding: 7, tint: .blue)
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
                Text("\(Int(state.progress.rounded()))%")
                    .monospacedDigit()
            }
            Spacer()
            let remaining = state.remainingTime ?? 0
            Text(String(format: "-%02d:%02d", remaining / 60, remaining % 60))
                .monospacedDigit()
        }
    }

    var progressBar: some View {
        ProgressView(value: state.progress / 100.0)
            .progressViewStyle(CustomProgressStyle(isError: isError, isDone: isDone, isPaused: isPaused))
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder var compactIndicator: some View {
        if isError {
            Image(systemName: "exclamationmark.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)
                .foregroundColor(.red)
        } else if isDone {
            Image(systemName: "checkmark.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)
                .foregroundColor(.green)
        } else {
            ThickCircularProgressView(progress: state.progress / 100.0, color: isPaused ? .orange : .blue)
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
        .tint(tint)
    }
}

struct ThickCircularProgressView: View {
    var progress: Double
    var lineWidth: CGFloat = 3
    var color: Color = .blue

    var body: some View {
        ZStack {
            Circle()
                .stroke(color == .orange ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0.0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(1.5)
        .scaledToFit()
        .contentShape(Circle())
        .animation(.default, value: progress)
    }
}

struct CustomProgressStyle: ProgressViewStyle {
    var isError: Bool
    var isDone: Bool = false
    var isPaused: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            let progress = CGFloat(configuration.fractionCompleted ?? 0.0)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(isError ? Color.red.opacity(0.2) : isPaused ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))

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
