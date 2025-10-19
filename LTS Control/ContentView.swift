import SwiftUI
import ActivityKit

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

    var body: some View {
        GeometryReader { geo in
            let spoolRadius = min(geo.size.width, geo.size.height) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let deadZoneRadius = spoolRadius * 0.25

            TimelineView(.animation(minimumInterval: 1.0 / 120.0)) { context in
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
                    DispatchQueue.main.async {
                        guard dragStartOffset == nil else {
                            lastUpdate = context.date
                            return
                        }

                        let dt = context.date.timeIntervalSince(lastUpdate)
                        lastUpdate = context.date

                        let targetSpeed = bleManager.deviceState == .running ? maxMotorSpeed : 0.0
                        let smoothing = (targetSpeed > angularVelocity) ? motorAcceleration : motorDeceleration
                        angularVelocity += (targetSpeed - angularVelocity) * smoothing
                        angularVelocity *= friction

                        let clampedVelocity = angularVelocity.clamped(to: -15...15)
                        rotation += clampedVelocity * dt * 60.0
                        rotation = rotation.truncatingRemainder(dividingBy: 360)
                    }
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
            let endRadius   = size / 1.47 - (isPad ? 0 : 10)
            ZStack {
                RadialGradient(
                    gradient: Gradient(colors: [
                        colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : .white.opacity(0.5),
                        .clear
                    ]),
                    center: .center,
                    startRadius: startRadius,
                    endRadius:   endRadius
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

struct ContentView: View {
    @Environment(BLEManager.self) private var bleManager
    @Environment(LayoutModel.self) private var layoutModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showSplashView: Bool
    @State private var pillSectionHeight: CGFloat = 108
    @AppStorage("useFilamentSensor") private var useFilamentSensor: Bool = true
    @AppStorage("temperatureInFahrenheit") private var showFahrenheit = false
    @State private var motorStartTime: Date = .distantPast
    @State private var localSpeedPercent: Double = 85
    @AppStorage("lastLocalSpeedExact") private var lastLocalSpeedExact: Double = 85
    @State private var userAdjustedSpeed: Bool = false
    @State private var isEditingSpeed: Bool = false
    @State private var hasAppeared = false
    @State private var enableStartupAnimations = false
    @State private var ignoreSpeedSyncUntil: Date = .distantPast
    @State private var displayedSpeedInt: Int = 85
    @State private var lastSentSpeedInt: Int? = nil
    @State private var awaitingEcho: Bool = false

    private var tempIcon: String {
        if bleManager.isConnected, let temp = bleManager.status.chipTemperature {
            return temp >= 65 ? "thermometer.high" : "thermometer.medium"
        } else {
            return "thermometer.medium"
        }
    }

    private var tempColor: Color {
        if bleManager.isConnected, let temp = bleManager.status.chipTemperature {
            return temp >= 65 ? .red : .green
        } else {
            return .primary
        }
    }

    private var isTemperatureCritical: Bool {
        if bleManager.isConnected, let temp = bleManager.status.chipTemperature {
            return temp >= 65
        } else {
            return false
        }
    }

    var body: some View {
        ZStack{
            VStack {
                ZStack{
                    Color(UIColor.systemGroupedBackground)
                    Color(
                        colorScheme == .dark ? .clear : .blue
                    ).opacity(colorScheme == .dark ? 1.0 : 0.05)
                }
                Spacer()
                Color(UIColor.secondarySystemGroupedBackground)
            }
            .ignoresSafeArea()
            ZStack {
                backgroundGradient()
                VStack {
                    pillSection(pillSectionHeight: $pillSectionHeight)
                    spoolSection()
                    statusProgressSection()
                    controlSection(
                        motorSpeed: $localSpeedPercent,
                        isError: false,
                        useFilamentSensor: useFilamentSensor
                    )
                }
                .onAppear {
                    localSpeedPercent = lastLocalSpeedExact
                    displayedSpeedInt = Int(lastLocalSpeedExact.rounded(.down))
                }
                .task(id: bleManager.status.speedPercent) {
                    if !isEditingSpeed && Date() >= ignoreSpeedSyncUntil && bleManager.isConnected {
                        let deviceInt = bleManager.status.speedPercent

                        if awaitingEcho {
                            if let last = lastSentSpeedInt, deviceInt == last {
                                displayedSpeedInt = deviceInt
                                awaitingEcho = false
                                lastSentSpeedInt = nil
                            } else {
                                localSpeedPercent = Double(deviceInt)
                                displayedSpeedInt = deviceInt
                                lastLocalSpeedExact = Double(deviceInt)
                                userAdjustedSpeed = false
                                awaitingEcho = false
                                lastSentSpeedInt = nil
                            }
                        } else {
                            if deviceInt != displayedSpeedInt {
                                localSpeedPercent = Double(deviceInt)
                                displayedSpeedInt = deviceInt
                                lastLocalSpeedExact = Double(deviceInt)
                                userAdjustedSpeed = false
                            }
                        }
                    }
                }
                .onChange(of: localSpeedPercent) { _, newValue in
                    if isEditingSpeed {
                        displayedSpeedInt = Int(newValue.rounded(.down))
                    }
                }
                .onChange(of: bleManager.isConnected) { _, newValue in
                    if newValue {
                        showSplashView = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                            guard bleManager.isConnected, !isEditingSpeed else { return }
                            let deviceInt = bleManager.status.speedPercent
                            if deviceInt != displayedSpeedInt {
                                localSpeedPercent = Double(deviceInt)
                                displayedSpeedInt = deviceInt
                                lastLocalSpeedExact = Double(deviceInt)
                                userAdjustedSpeed = false
                            }
                        }
                    }
                    awaitingEcho = false
                    lastSentSpeedInt = nil
                    ignoreSpeedSyncUntil = .distantPast
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    enableStartupAnimations = true
                }
            }
            .frame(minWidth: !layoutModel.isCompactWidth ? 364 : nil, maxHeight: UIDevice.current.userInterfaceIdiom == .pad ? 820 : .infinity)
            .ignoresSafeArea(.keyboard)
        }
    }

    @ViewBuilder
    private func backgroundGradient() -> some View {
        ZStack {
            GeometryReader { geo in
                let fadeHeight: CGFloat = colorScheme == .dark ? 220 : 110
                let colorHeight: CGFloat = 90
                let gradientEnd = 1.0 - (colorHeight / geo.size.height)
                let fadeStart = gradientEnd - (fadeHeight / geo.size.height)

                let midColor = Color(UIColor.systemGroupedBackground)
                let bottomColor = Color(UIColor.secondarySystemGroupedBackground)

                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: midColor, location: 0.0),
                        .init(color: midColor, location: fadeStart),
                        .init(color: bottomColor, location: gradientEnd),
                        .init(color: bottomColor, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(
                            color: Color(
                                colorScheme == .dark ? .clear : .blue
                            ).opacity(colorScheme == .dark ? 1.0 : 0.05),
                            location: 0.0
                        ),
                        .init(color: .clear, location: fadeStart - 0.001),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func pillSection(pillSectionHeight: Binding<CGFloat>) -> some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    pillSectionHeight.wrappedValue = geo.size.width > 730 ? 50 : 108
                }
                .onChange(of: geo.size.width) { _, newWidth in
                    pillSectionHeight.wrappedValue = newWidth > 730 ? 50 : 108
                }

            let isWide = geo.size.width > 730

            Group {
                let horizontalPadding: CGFloat = 16
                let hSpacing: CGFloat = 12
                let vSpacing: CGFloat = 8
                let targetColumns: CGFloat = isWide ? 4 : 2
                let minCellWidth = (geo.size.width - (2 * horizontalPadding) - ((targetColumns - 1) * hSpacing)) / targetColumns

                let columns = [GridItem(.adaptive(minimum: max(0, minCellWidth), maximum: max(0, minCellWidth)), spacing: hSpacing, alignment: .center)]

                LazyVGrid(columns: columns, alignment: .center, spacing: vSpacing) {
                    VerbindungPill()
                    TemperaturPill()
                    FilamentPill()
                    LuefterPill()
                }
            }
            .padding(.horizontal)
            .zIndex(1)
            .animation(enableStartupAnimations ? .snappy(duration: 0.2) : nil, value: isWide)
        }
        .frame(height: pillSectionHeight.wrappedValue)
    }

    @ViewBuilder
    private func spoolSection() -> some View {
        let isWide = pillSectionHeight == 50
        SpoolWithGradientView()
            .frame(maxWidth: 350)
            .padding(!layoutModel.isCompactWidth ? 40 : 24)
            .layoutPriority(1)
            .scaleEffect(isWide ? 1.0 : 0.96)
            .animation(enableStartupAnimations ? .snappy(duration: 0.2) : nil, value: isWide)
    }

    @ViewBuilder
    private func statusProgressSection() -> some View {
        VStack {
            HStack {
                Text({
                    if bleManager.deviceState == .autoStop {
                        return "Fehler!"
                    } else if bleManager.deviceState == .running || bleManager.deviceState == .paused {
                        return "\(Int((bleManager.status.progress ?? 0).rounded())) %"
                    } else {
                        return " "
                    }
                }())
                .frame(width: 70, alignment: .leading)
                .foregroundColor(bleManager.deviceState == .autoStop ? .red : .primary)
                .monospacedDigit()

                Spacer()

                Text(bleManager.deviceStateText)
                    .id(bleManager.deviceState)
                    .id(bleManager.isConnected)
                    .transition(.opacity.combined(with: .scale))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                Spacer()

                Text({
                    let showTime = (bleManager.deviceState == .running || bleManager.deviceState == .autoStop || bleManager.deviceState == .paused)
                    guard showTime else { return " " }
                    let t = max(0, bleManager.status.remainingTime ?? 0)
                    return String(format: "-%02d:%02d", t / 60, t % 60)
                }())
                .frame(width: 70, alignment: .trailing)
                .monospacedDigit()
            }
            .id("statusBar")
            .animation(.default, value: bleManager.deviceState)
            .animation(.default, value: bleManager.isConnected)

            ProgressView(value: (bleManager.status.progress ?? 0.0) / 100.0)
                .progressViewStyle(CustomProgressStyle(
                    isError: bleManager.deviceState == .autoStop,
                    isDone:  bleManager.deviceState == .done,
                    isPaused: bleManager.deviceState == .paused
                ))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 20)
        .padding(.horizontal, 45)
    }
    
    @ViewBuilder
    private func controlSection(
        motorSpeed: Binding<Double>,
        isError: Bool,
        useFilamentSensor: Bool
    ) -> some View {
        VStack {
            HStack {
                ZStack {
                    if bleManager.deviceState == .running {
                        Button(action: {
                            bleManager.pauseMotor()
                        }) {
                            Text("Pause")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .controlSize(.large)
                        .disabled(!bleManager.isConnected)
                        .id("pauseButton")
                        .transition(.opacity)
                    } else {
                        Button(action: {
                            motorStartTime = Date()
                            bleManager.startMotor()
                        }) {
                            Text("Start")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .controlSize(.large)
                        .disabled((useFilamentSensor && !(bleManager.status.hasFilament)) || !bleManager.isConnected || bleManager.deviceState == .updating)
                        .animation(.default, value: useFilamentSensor)
                        .animation(.default, value: bleManager.status.hasFilament)
                        .animation(.default, value: bleManager.isConnected)
                        .id("startButton")
                        .transition(.opacity)
                    }
                }
                .animation(.default, value: bleManager.deviceState)

                Spacer(minLength: 14)

                Button(action: {
                    bleManager.stopMotor()
                }) {
                    Text("Stopp")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)
                .disabled(!bleManager.isConnected || bleManager.deviceState == .updating)
                .animation(.default, value: bleManager.isConnected)
            }

            Divider()
                .padding(.vertical, 3)

            HStack {
                Slider(
                    value: $localSpeedPercent,
                    in: 50...100,
                    onEditingChanged: { editing in
                        isEditingSpeed = editing
                        if editing { userAdjustedSpeed = true }
                        if !editing {
                            let spd = Int(localSpeedPercent.rounded(.down))
                            if bleManager.isConnected {
                                bleManager.sendPacket(settings: ["SPD": spd])
                                ignoreSpeedSyncUntil = Date().addingTimeInterval(1.2)
                                lastSentSpeedInt = spd
                                awaitingEcho = true
                            } else {
                                awaitingEcho = false
                                lastSentSpeedInt = nil
                            }
                            lastLocalSpeedExact = localSpeedPercent
                            userAdjustedSpeed = true
                            displayedSpeedInt = spd
                        }
                    }
                )
                .animation((hasAppeared && !isEditingSpeed) ? .easeInOut(duration: 0.2) : nil, value: localSpeedPercent)
                .onAppear {
                    DispatchQueue.main.async {
                        hasAppeared = true
                    }
                }
                .accentColor(.secondary)
                Text("\(displayedSpeedInt) %")
                    .monospacedDigit()
                    .foregroundColor(.gray)
                    .frame(width: 51, alignment: .trailing)
            }
            .frame(height: 40)
        }
        .padding(11)
        .background(
            Group {
                if #available(iOS 26, *) {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                }
            }
        )
        .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? 4 : 12)
        .padding(.horizontal)
        .frame(maxWidth:.infinity)
        .zIndex(1)
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
}

extension ContentView {
    @ViewBuilder
    private func VerbindungPill() -> some View {
        HStack(spacing: 8) {
            Image(systemName: bleManager.isConnected
                  ? "antenna.radiowaves.left.and.right"
                  : "antenna.radiowaves.left.and.right.slash")
                .foregroundStyle(bleManager.isConnected ? .cyan : Color.primary)
                .font(.system(size: 22))
                .frame(width: 28, height: 27, alignment: .bottom)
                .contentTransition(.symbolEffect(.replace))
                .animation(.default, value: bleManager.isConnected)
            VStack(alignment: .leading, spacing: 0) {
                Text("Verbindung")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(bleManager.isConnected ? "Verbunden" : "Getrennt")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .pillStyle()
    }

    @ViewBuilder
    private func FilamentPill() -> some View {
        HStack(spacing: 8) {
            Image(systemName: bleManager.status.hasFilament && bleManager.isConnected ? "checkmark.circle" : "xmark.circle")
                .foregroundStyle(bleManager.status.hasFilament && bleManager.isConnected ? .purple : Color.primary)
                .font(.system(size: 23.5))
                .frame(width: 28, height: 28)
                .contentTransition(.symbolEffect(.replace))
                .animation(.default, value: bleManager.status.hasFilament)
                .animation(.default, value: bleManager.isConnected)
            VStack(alignment: .leading, spacing: 0) {
                Text("Filament")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(bleManager.status.hasFilament && bleManager.isConnected ? "Erkannt" : "Nicht erkannt")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .pillStyle()
    }

    @ViewBuilder
    private func TemperaturPill() -> some View {
        HStack(spacing: 8) {
            Image(systemName: tempIcon)
                .foregroundStyle(tempColor)
                .font(.system(size: 22))
                .frame(width: 28, height: 28)
                .symbolEffect(.wiggle, value: isTemperatureCritical)
                .animation(.default, value: bleManager.status.chipTemperature)
            VStack(alignment: .leading, spacing: 0) {
                Text("Temperatur")
                    .font(.headline)
                    .foregroundColor(.primary)
                let tempText: String = {
                    guard bleManager.isConnected, let temp = bleManager.status.chipTemperature else { return "–" }
                    return showFahrenheit
                        ? String(format: "%.0f °F", Double(temp) * 9 / 5 + 32)
                        : "\(temp) °C"
                }()
                Text("Chip: \(tempText)")
                    .monospacedDigit()
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .pillStyle()
    }

    @ViewBuilder
    private func LuefterPill() -> some View {
        let fanOn = BLEManager.shared.isConnected && BLEManager.shared.status.isFanOn
        let fanSpeed = BLEManager.shared.status.fanSpeed
        let isCtrBoardV3 = (BLEManager.shared.status.boardVersion == "CtrBoard V3")

        HStack(spacing: 8) {
            Image(systemName: isCtrBoardV3 ? "fan.slash" : (fanOn ? "fan" : "fan.slash"))
                .foregroundStyle(isCtrBoardV3 ? Color.secondary : (fanOn ? Color.ltsBlue : Color.primary))
                .font(.system(size: 22))
                .frame(width: 28, height: 28)
                .contentTransition(.symbolEffect(.replace))
                .animation(.default, value: fanOn)
                .animation(.default, value: isCtrBoardV3)

            VStack(alignment: .leading, spacing: 0) {
                Text("Lüfter")
                    .font(.headline)
                    .foregroundColor(isCtrBoardV3 ? .secondary : .primary)

                if isCtrBoardV3 {
                    Text("Nicht unterstützt")
                        .monospacedDigit()
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text(fanOn ? "An: \(fanSpeed) %" : "Aus")
                        .monospacedDigit()
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .pillStyle()
    }
}

#if DEBUG
#Preview {
    ContentView(
        showSplashView: .constant(false)
    )
    .environment(BLEManager.shared)
    .environment(LayoutModel())
    .environment(\.locale, .init(identifier: "en"))
}
#endif

