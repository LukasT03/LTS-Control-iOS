import SwiftUI
import WidgetKit
import ActivityKit

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
            SpoolActivityView(context: context)
        } dynamicIsland: { context in
            let isError = (context.state.deviceState.rawValue == "autoStop")
            let isPaused = (context.state.deviceState.rawValue == "paused")
            let isDone = (context.state.deviceState.rawValue == "done")
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if isPaused {
                        Button(intent: StopMotorIntent()) {
                            Image(systemName: "xmark")
                                .resizable()
                                .padding(6)
                                .scaledToFit()
                                .frame(height: 52)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .frame(width: 52, height: 52)
                        .tint(.red)
                    } else {
                        Image("BambuSpoolWhite")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 52)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        HStack {
                            if isError {
                                Text("Auto-Stopp!")
                                    .foregroundColor(.red)
                            } else if isPaused {
                                Text("Pausiert")
                            } else if context.state.deviceState.rawValue == "done" {
                                Text("Fertig!")
                            } else {
                                Text("\(Int((context.state.progress).rounded()))%")
                                    .monospacedDigit()
                            }
                        Spacer()
                            
                        let remaining = context.state.remainingTime ?? 0
                        let minutes = remaining / 60
                        let seconds = remaining % 60
                        Text(String(format: "-%02d:%02d", minutes, seconds))
                            .monospacedDigit()
                    
                        }
                        .padding(.horizontal, 6)
                        
                        ProgressView(value: context.state.progress / 100.0)
                            .progressViewStyle(CustomProgressStyle(
                                isError: isError,
                                isDone: context.state.deviceState.rawValue == "done",
                                isPaused: isPaused
                            ))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 6)
                            .tint(.blue)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if isError {
                        Button(intent: StartMotorIntent()) {
                            Image(systemName: "play.fill")
                                .resizable()
                                .padding(5.7)
                                .padding(.leading, 2.3)
                                .padding(.trailing, -2.3)
                                .scaledToFit()
                                .frame(height: 52)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .frame(width: 52, height: 52)
                        .tint(.blue)
                    } else if isPaused {
                        Button(intent: StartMotorIntent()) {
                            Image(systemName: "play.fill")
                                .resizable()
                                .padding(5.7)
                                .padding(.leading, 2.3)
                                .padding(.trailing, -2.3)
                                .scaledToFit()
                                .frame(height: 52)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .frame(width: 52, height: 52)
                        .tint(.blue)
                    } else if isDone {
                        Button(intent: StopMotorIntent()) {
                            Image(systemName: "checkmark")
                                .resizable()
                                .padding(6)
                                .scaledToFit()
                                .frame(height: 52)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .frame(width: 52, height: 52)
                        .tint(.blue)
                    } else {
                        Button(intent: PauseMotorIntent()) {
                            Image(systemName: "pause.fill")
                                .resizable()
                                .padding(7)
                                .scaledToFit()
                                .frame(height: 52)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .frame(width: 52, height: 52)
                        .tint(.blue)
                    }
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
                if isError {
                    Image(systemName: "exclamationmark.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 23, height: 23)
                        .foregroundColor(.red)
                } else if isPaused {
                    ThickCircularProgressView(progress: context.state.progress / 100.0, color: .orange)
                } else if isDone {
                    Image(systemName: "checkmark.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 23, height: 23)
                        .foregroundColor(.green)
                } else {
                    ThickCircularProgressView(progress: context.state.progress / 100.0)
                }
            } minimal: {
                if isError {
                    Image(systemName: "exclamationmark.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 23, height: 23)
                        .foregroundColor(.red)
                } else if isPaused {
                    ThickCircularProgressView(progress: context.state.progress / 100.0, color: .orange)
                } else if isDone {
                    Image(systemName: "checkmark.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 23, height: 23)
                        .foregroundColor(.green)
                } else {
                    ThickCircularProgressView(progress: context.state.progress / 100.0)
                }
            }
        }
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

struct SpoolActivityView: View {
    let context: ActivityViewContext<SpoolActivityAttributes>

    var body: some View {
        let isError = (context.state.deviceState.rawValue == "autoStop")
        let isPaused = (context.state.deviceState.rawValue == "paused")
        let isDone = (context.state.deviceState.rawValue == "done")
        HStack(spacing: 12) {
            if isPaused {
                Button(intent: StopMotorIntent()) {
                    Image(systemName: "xmark")
                        .resizable()
                        .padding(6)
                        .scaledToFit()
                        .frame(height: 52)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .frame(width: 52, height: 52)
                .tint(.red)
                .padding(.leading, 14)
            } else {
                Image("BambuSpoolWhite")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .padding(.leading, 14)
            }
            
            if isError {
                Button(intent: StartMotorIntent()) {
                    Image(systemName: "play.fill")
                        .resizable()
                        .padding(5.7)
                        .padding(.leading, 2.3)
                        .padding(.trailing, -2.3)
                        .scaledToFit()
                        .frame(height: 52)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .frame(width: 52, height: 52)
                .tint(.blue)
            } else if isPaused {
                Button(intent: StartMotorIntent()) {
                    Image(systemName: "play.fill")
                        .resizable()
                        .padding(5.7)
                        .padding(.leading, 2.3)
                        .padding(.trailing, -2.3)
                        .scaledToFit()
                        .frame(height: 52)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .frame(width: 52, height: 52)
                .tint(.blue)
            } else if isDone {
                Button(intent: StopMotorIntent()) {
                    Image(systemName: "checkmark")
                        .resizable()
                        .padding(6)
                        .scaledToFit()
                        .frame(height: 52)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .frame(width: 52, height: 52)
                .tint(.blue)
            } else {
                Button(intent: PauseMotorIntent()) {
                    Image(systemName: "pause.fill")
                        .resizable()
                        .padding(7)
                        .scaledToFit()
                        .frame(height: 52)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .frame(width: 52, height: 52)
                .tint(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                HStack {
                    if isError {
                        Text("Auto-Stopp!")
                            .foregroundColor(.red)
                    } else if isPaused {
                        Text("Pausiert")
                    } else if context.state.deviceState.rawValue == "done" {
                        Text("Fertig!")
                    } else {
                        Text("\(Int((context.state.progress).rounded()))%")
                            .monospacedDigit()
                    }
                Spacer()
                    
                let remaining = context.state.remainingTime ?? 0
                let minutes = remaining / 60
                let seconds = remaining % 60
                Text(String(format: "-%02d:%02d", minutes, seconds))
                    .monospacedDigit()
            
                }
                
                ProgressView(value: context.state.progress / 100.0)
                    .progressViewStyle(CustomProgressStyle(
                        isError: isError,
                        isDone: context.state.deviceState.rawValue == "done",
                        isPaused: isPaused
                    ))
                    .frame(maxWidth: .infinity)
                Spacer()
            }

            Spacer()
        }
        .padding(.vertical, 12)
    }
}

struct CustomProgressStyle: ProgressViewStyle {
    var isError: Bool
    var isDone: Bool = false
    var isPaused: Bool = false
    @Environment(\.colorScheme) var colorScheme
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            let progress = CGFloat(configuration.fractionCompleted ?? 0.0)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill({
                        if isError { return Color.red.opacity(0.2) }
                        if isPaused { return Color.orange.opacity(0.2) }
                        return Color.gray.opacity(0.2)
                    }())

                Rectangle()
                    .fill({
                        if isError { return Color.red }
                        if isDone { return Color.green }
                        if isPaused { return Color.orange }
                        return Color.blue
                    }())
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
