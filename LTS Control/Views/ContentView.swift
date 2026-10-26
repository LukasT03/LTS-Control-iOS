import SwiftUI

struct ContentView: View {
    @Environment(BLEManager.self) private var bleManager
    @Environment(\.isSplitLayout) private var isSplitLayout
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

    private var chipTemperature: Int? {
        bleManager.isConnected ? bleManager.status.chipTemperature : nil
    }

    private var isTemperatureCritical: Bool { (chipTemperature ?? 0) >= 65 }

    private var tempIcon: String { isTemperatureCritical ? "thermometer.high" : "thermometer.medium" }

    private var tempColor: Color {
        guard chipTemperature != nil else { return .primary }
        return isTemperatureCritical ? .red : .green
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
                // If the window is too short even without the spool, the controls slide down behind the tab bar
                // instead of pushing the pills under the title.
                .frame(maxHeight: .infinity, alignment: .top)
                // With the controls' own 12 pt that's 20 pt, the side margin on iPhone Duo.
                .replacingHomeIndicatorInset(with: 8)
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
            .frame(maxHeight: UIDevice.current.userInterfaceIdiom == .pad ? 820 : .infinity)
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
        // Padded outside, so the grid measures the width the pills actually get.
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    pillSectionHeight.wrappedValue = geo.size.width > 698 ? 50 : 108
                }
                .onChange(of: geo.size.width) { _, newWidth in
                    pillSectionHeight.wrappedValue = newWidth > 698 ? 50 : 108
                }

            let isWide = geo.size.width > 698

            Group {
                let hSpacing: CGFloat = 12
                let vSpacing: CGFloat = 8
                let targetColumns: CGFloat = isWide ? 4 : 2
                let minCellWidth = (geo.size.width - ((targetColumns - 1) * hSpacing)) / targetColumns

                let columns = [GridItem(.adaptive(minimum: max(0, minCellWidth), maximum: max(0, minCellWidth)), spacing: hSpacing, alignment: .center)]

                LazyVGrid(columns: columns, alignment: .center, spacing: vSpacing) {
                    VerbindungPill()
                    TemperaturPill()
                    FilamentPill()
                    LuefterPill()
                }
            }
            .zIndex(1)
            .animation(enableStartupAnimations ? .snappy(duration: 0.2) : nil, value: isWide)
        }
        .horizontalPadding()
        .frame(height: pillSectionHeight.wrappedValue)
    }

    @ViewBuilder
    private func spoolSection() -> some View {
        let isWide = pillSectionHeight == 50
        // In short windows the spool gives its space to the controls instead of shrinking to nothing.
        ViewThatFits(in: .vertical) {
            SpoolWithGradientView()
                .frame(maxWidth: 350, minHeight: 60)
                .padding(isSplitLayout ? 40 : 24)
                .scaleEffect(isWide ? 1.0 : 0.96)
                .animation(enableStartupAnimations ? .snappy(duration: 0.2) : nil, value: isWide)
            Color.clear
                .frame(idealHeight: 0)
        }
        .frame(maxWidth: .infinity)
        .ignoresVerticalBar(isSplitLayout)
        .layoutPriority(1)
    }

    @ViewBuilder
    private func statusProgressSection() -> some View {
        VStack {
            HStack {
                Group {
                    if bleManager.deviceState == .autoStop {
                        Text("Fehler!")
                    } else if bleManager.deviceState == .running || bleManager.deviceState == .paused {
                        Text(verbatim: "\(Int((bleManager.status.progress ?? 0).rounded())) %")
                    } else {
                        Text(verbatim: " ")
                    }
                }
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
        .ignoresVerticalBar(isSplitLayout)
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
                // A tick for every percent while dragging, not when the board reports a new value.
                .sensoryFeedback(.selection, trigger: displayedSpeed) { _, _ in isEditingSpeed }
                // The hidden "100 %" reserves the widest value at any text size, so the slider keeps its length.
                Text("\(100) %")
                    .hidden()
                    .overlay(alignment: .trailing) {
                        // Passing the value lets the digits roll up or down depending on the direction.
                        // No animation before the view is on screen, so the stored value is just there on launch.
                        Text("\(displayedSpeed) %")
                            .contentTransition(.numericText(value: Double(displayedSpeed)))
                            .animation(hasAppeared ? .snappy : nil, value: displayedSpeed)
                    }
                    .monospacedDigit()
                    .foregroundColor(.gray)
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
        // Under the bar the system margin is 0, so the controls take the other side's.
        .horizontalPadding(isSymmetric: isSplitLayout)
        .frame(maxWidth:.infinity)
        .ignoresVerticalBar(isSplitLayout)
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
                    guard let temp = chipTemperature else { return "–" }
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
    .environment(\.locale, .init(identifier: "en"))
}
#endif


