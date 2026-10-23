import SwiftUI

struct ContentView: View {
    @Environment(BLEManager.self) private var bleManager
    @Environment(LayoutModel.self) private var layoutModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showSplashView: Bool
    @State private var pillSectionHeight: CGFloat = 108
    @AppStorage("temperatureInFahrenheit") private var showFahrenheit = false
    /// Slider position; follows the board's speed unless the user is dragging.
    @State private var localSpeedPercent: Double = 85
    @State private var isEditingSpeed: Bool = false
    @State private var hasAppeared = false
    @State private var enableStartupAnimations = false

    private var displayedSpeed: Int { Int(localSpeedPercent.rounded(.down)) }

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
                    controlSection()
                }
                .onChange(of: bleManager.status.speedPercent, initial: true) {
                    syncSpeedFromBoard()
                }
                .onChange(of: bleManager.isConnected) { _, isConnected in
                    if isConnected {
                        showSplashView = false
                        syncSpeedFromBoard()
                    }
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

                Text(LocalizedStringKey(bleManager.deviceStateKey))
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
    
    /// Echo filtering happens in `BLEManager`, so the board's value can be taken as is.
    private func syncSpeedFromBoard() {
        let boardSpeed = bleManager.status.speedPercent
        guard !isEditingSpeed, displayedSpeed != boardSpeed else { return }
        localSpeedPercent = Double(boardSpeed)
    }

    @ViewBuilder
    private func controlSection() -> some View {
        let useFilamentSensor = bleManager.status.useFilamentSensor
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
                        if !editing && bleManager.isConnected {
                            bleManager.setSpeedPercent(displayedSpeed)
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
                Text("\(displayedSpeed) %")
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
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
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
        let fanOn = bleManager.isConnected && bleManager.status.isFanOn
        let fanSpeed = bleManager.status.fanSpeed
        let isCtrBoardV3 = (bleManager.status.boardVersion == "CtrBoard V3")

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
