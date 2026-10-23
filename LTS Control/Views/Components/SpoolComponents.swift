import SwiftUI

struct RotatingTimelapseIcon: View {
    @Environment(BLEManager.self) private var bleManager

    @State private var rotation: Double = 0
    @State private var angularVelocity: Double = 0
    @State private var dragStartOffset: Double? = nil
    @State private var lastDragTime: Date? = nil
    @State private var lastDragAngle: Double? = nil
    @State private var lastUpdate: Date = .now
    private let maxMotorSpeed: Double = 5
    private let motorAcceleration: Double = 0.01
    private let motorDeceleration: Double = 0.05
    private let friction: Double = 0.98

    /// The timeline only runs while the spool moves; at rest it would redraw at 120 fps for nothing.
    private var isResting: Bool {
        bleManager.deviceState != .running && dragStartOffset == nil && abs(angularVelocity) < 0.01
    }

    var body: some View {
        GeometryReader { geo in
            let spoolRadius = min(geo.size.width, geo.size.height) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let deadZoneRadius = spoolRadius * 0.25

            TimelineView(.animation(minimumInterval: 1.0 / 120.0, paused: isResting)) { context in
                ZStack {
                    Image("BambuSpool")
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .rotationEffect(.degrees(rotation))
                        .frame(width: geo.size.width, height: geo.size.height)

                    Circle()
                        .fill(Color.clear)
                        .frame(width: deadZoneRadius * 2, height: deadZoneRadius * 2)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let dx = value.location.x - center.x
                            let dy = value.location.y - center.y
                            let distance = sqrt(dx * dx + dy * dy)
                            guard distance >= deadZoneRadius else {
                                dragStartOffset = nil
                                return
                            }
                            let currentFingerAngle = atan2(dy, dx) * 180 / .pi

                            if let startOffset = dragStartOffset {
                                rotation = currentFingerAngle + startOffset
                                if let lastTime = lastDragTime, let lastAngle = lastDragAngle {
                                    let dt = Date().timeIntervalSince(lastTime)
                                    if dt > 0 {
                                        var deltaAngle = currentFingerAngle - lastAngle
                                        if deltaAngle > 180 { deltaAngle -= 360 }
                                        if deltaAngle < -180 { deltaAngle += 360 }
                                        angularVelocity = deltaAngle
                                    }
                                }
                                lastDragTime = Date()
                                lastDragAngle = currentFingerAngle
                            } else {
                                dragStartOffset = rotation - currentFingerAngle
                                lastDragTime = Date()
                                lastDragAngle = currentFingerAngle
                                angularVelocity = 0
                            }
                        }
                        .onEnded { _ in
                            dragStartOffset = nil
                            lastDragTime = nil
                            lastDragAngle = nil
                        }
                )
                .onChange(of: context.date) {
                    guard dragStartOffset == nil else {
                        lastUpdate = context.date
                        return
                    }

                    // Capped so the spool doesn't jump after the timeline was paused.
                    let dt = min(context.date.timeIntervalSince(lastUpdate), 1.0 / 30.0)
                    lastUpdate = context.date

                    let targetSpeed = bleManager.deviceState == .running ? maxMotorSpeed : 0.0
                    let smoothing = (targetSpeed > angularVelocity) ? motorAcceleration : motorDeceleration
                    angularVelocity += (targetSpeed - angularVelocity) * smoothing
                    angularVelocity *= friction
                    if targetSpeed == 0 && abs(angularVelocity) < 0.01 { angularVelocity = 0 }

                    let clampedVelocity = angularVelocity.clamped(to: -15...15)
                    rotation += clampedVelocity * dt * 60.0
                    rotation = rotation.truncatingRemainder(dividingBy: 360)
                }
            }
        }
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

struct SpoolWithGradientView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let startRadius = size / 2
            let endRadius = size / 1.47 - (isPad ? 0 : 10)
            ZStack {
                RadialGradient(
                    gradient: Gradient(colors: [
                        colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : .white.opacity(0.5),
                        .clear
                    ]),
                    center: .center,
                    startRadius: startRadius,
                    endRadius: endRadius
                )
                .frame(width: size * 1.6, height: size * 1.6)
                .clipped()
                .allowsHitTesting(false)

                ZStack {
                    RotatingTimelapseIcon()
                        .frame(width: size, height: size)
                    Circle()
                        .frame(width: size / 3.55)
                        .compositingGroup()
                        .blendMode(.destinationOut)
                }
                .frame(width: size, height: size)
                .compositingGroup()
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

struct CustomProgressStyle: ProgressViewStyle {
    @Environment(\.colorScheme) var colorScheme
    var isError: Bool = false
    var isDone: Bool = false
    var isPaused: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            let progress = CGFloat(configuration.fractionCompleted ?? 0.0)
            let isError = self.isError && progress > 0
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 7)
                    .fill({
                        if isError { return Color.red.opacity(0.2) }
                        if isPaused { return Color.orange.opacity(0.2) }
                        return Color.gray.opacity(0.2)
                    }())
                    .animation(.default, value: isError)
                    .animation(.default, value: isPaused)
                    .animation(.default, value: progress)

                Rectangle()
                    .fill({
                        if isError { return Color.red }
                        if isDone { return Color.green }
                        if isPaused { return Color.orange }
                        return Color.ltsBlue
                    }())
                    .frame(width: geometry.size.width * progress)
                    .animation(.default, value: isError)
                    .animation(.default, value: isDone)
                    .animation(.default, value: isPaused)
                    .animation(.default, value: progress)
            }
            .frame(height: 14)
            .mask(
                RoundedRectangle(cornerRadius: 7)
                    .frame(width: geometry.size.width, height: 14)
            )
            .animation(.default, value: progress)
        }
    }
}

struct PillStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(height: 40, alignment: .center)
            .padding(.leading, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .frame(height: 50)
            .contentShape(Capsule())
    }
}

extension View {
    func pillStyle() -> some View {
        self.modifier(PillStyle())
    }

    /// Shows pills as a bare List row. The row is at least as tall as the List's minimum row height
    /// (52 pt on iOS 26), so the 50 pt pills are pinned to its top instead of being centered,
    /// which puts them exactly where the pills in the control tab are.
    func pillListRow() -> some View {
        self
            .frame(maxHeight: .infinity, alignment: .top)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
    }
}
