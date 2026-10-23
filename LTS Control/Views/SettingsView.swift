import SwiftUI

struct SettingsView: View {
    @AppStorage("temperatureInFahrenheit") private var showFahrenheit = false
    @AppStorage("LiveActivityEnabled") private var liveActivitiesOn: Bool = true
    @AppStorage("NotificationsEnabled") private var notificationsOn: Bool = false
    @Environment(BLEManager.self) private var bleManager

    private var status: DeviceStatus { bleManager.status }

    private var stateIconName: String {
        if !bleManager.isConnected { return "antenna.radiowaves.left.and.right.slash.circle" }
        switch bleManager.deviceState {
        case .running: return "play.circle"
        case .paused: return "pause.circle"
        case .updating: return "arrow.trianglehead.2.clockwise.rotate.90.circle"
        case .done: return "checkmark.circle"
        case .autoStop: return "exclamationmark.circle"
        case .idle: return "power.circle"
        }
    }

    private var stateIconColor: Color {
        if !bleManager.isConnected { return .primary }
        switch bleManager.deviceState {
        case .running, .done: return .green
        case .paused: return .orange
        case .updating: return .indigo
        case .autoStop: return .red
        case .idle: return .ltsBlue
        }
    }

    private var boardVariantText: String {
        status.boardVariant == .pro ? "Respooler Pro" : "Respooler V4"
    }

    /// Updates the value locally right away and sends it to the board.
    private func binding<T>(_ keyPath: ReferenceWritableKeyPath<DeviceStatus, T>, _ send: @escaping (T) -> Void) -> Binding<T> {
        Binding(
            get: { status[keyPath: keyPath] },
            set: { status[keyPath: keyPath] = $0; send($0) }
        )
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: stateIconName)
                        .foregroundStyle(stateIconColor)
                        .font(.system(size: 23.5))
                        .frame(width: 28, height: 28)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(.default, value: bleManager.deviceState)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Status")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(bleManager.deviceStateText)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .pillStyle()
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section(header: Text("Konfiguration"), footer: Text("Wenn der Sensor deaktiviert ist, wird nicht auf den Verlust von Filament reagiert.")) {
                Picker("Ton bei Fertigstellung", selection: binding(\.jingleStyle, bleManager.setJingleStyle)) {
                    Text("Aus").tag(0)
                    Text("Einfach").tag(1)
                    Text("Glissando").tag(2)
                    Text("Star Wars").tag(3)
                }
                Stepper(value: binding(\.ledBrightness, bleManager.setLED), in: 0...100, step: 10) {
                    Text("LED Helligkeit: \(status.ledBrightness) %")
                        .monospacedDigit()
                }
                AdaptiveDetailRow(title: "Respool-Menge", value: RespoolAmountView.title(for: status.targetWeight)) {
                    RespoolAmountView(targetWeight: binding(\.targetWeight, bleManager.setTargetWeight))
                }
                Toggle("Filament Sensor nutzen", isOn: binding(\.useFilamentSensor, bleManager.setUseFilamentSensor))
                    .tint(.ltsBlue)
            }

            Section(header: Text("Motor"), footer: Text("Der Auto-Stopp stoppt den Motor bei Widerstand.")) {
                Toggle("Richtung umkehren", isOn: binding(\.directionReversed, bleManager.setDirectionReversed))
                    .tint(.ltsBlue)
                Stepper(value: binding(\.motorStrength, bleManager.setMotorStrength), in: 80...120, step: 10) {
                    Text("Stärke: \(status.motorStrength) %")
                        .monospacedDigit()
                }
                Picker("Auto-Stopp Empfindlichkeit", selection: binding(\.torqueLimit, bleManager.setTorqueLimit)) {
                    Text("Aus").tag(0)
                    Text("Gering").tag(1)
                    Text("Mittel").tag(2)
                    Text("Hoch").tag(3)
                }
                .disabled(status.highSpeed)
            }

            Section(footer: Text("Der High-Speed Modus erhöht die Geschwindigkeit des Motors. Auto-Stopp ist dabei nicht verfügbar.")) {
                Toggle("High-Speed", isOn: binding(\.highSpeed, bleManager.setHighSpeed))
                    .tint(.ltsBlue)
            }

            if status.boardVariant == .pro {
                Section(header: Text("Servo"), footer: Text("Wähle aus, auf welcher Seite die Startposition der Filamentführung ist.")) {
                    AdaptiveDetailRow(title: "Endpositionen kalibrieren") {
                        ServoCalibrationView()
                    }
                    Stepper(value: binding(\.servoStepMm, bleManager.setServoStepMm), in: 0.50...4.00, step: 0.01) {
                        Text("Schrittweite: \(status.servoStepMm, format: .number.precision(.fractionLength(2))) mm")
                            .monospacedDigit()
                    }
                    Picker("", selection: binding(\.servoHome, bleManager.setServoHome)) {
                        Text("Links").tag("L")
                        Text("Rechts").tag("R")
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section(header: Text("Lüfter"), footer: Text("Der Lüfter schaltet sich standardmäßig 10 Sekunden nach stoppen des Respoolers aus.")) {
                Stepper(value: binding(\.fanSpeed, bleManager.setFanSpeed), in: 10...100, step: 10) {
                    Text("Geschwindigkeit: \(status.fanSpeed) %")
                        .monospacedDigit()
                }
                Toggle("Lüfter immer an", isOn: binding(\.fanAlways, bleManager.setFanAlways))
                    .tint(.ltsBlue)
                Picker("", selection: $showFahrenheit) {
                    Text("Celsius").tag(false)
                    Text("Fahrenheit").tag(true)
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Kalibrierung"), footer: Text("Für genauere Zeitangaben bzw. Respool-Mengen die benötigte Dauer für eine 1\u{00A0}kg Spule bei 80\u{00A0}% Geschwindigkeit messen und hier anpassen.")) {
                Stepper(value: binding(\.durationAt80, bleManager.setDurationAt80), in: 5...2000, step: 5) {
                    Text("Dauer: \(status.durationAt80 / 60)m \(status.durationAt80 % 60)s")
                        .monospacedDigit()
                }
            }

            Section(header: Text("App"), footer: Text("Erhalte Push-Benachrichtigungen, wenn der Respooler stoppt oder fertig ist.")) {
                Toggle("Live-Aktivitäten", isOn: $liveActivitiesOn)
                    .onChange(of: liveActivitiesOn) { _, newValue in
                        LiveActivityManager.shared.setEnabled(newValue)
                    }
                    .tint(.ltsBlue)
                Toggle("Benachrichtigungen", isOn: $notificationsOn)
                    .onChange(of: notificationsOn) { _, newValue in
                        guard newValue else {
                            LocalNotificationManager.shared.setEnabled(false)
                            return
                        }
                        Task {
                            let granted = await LocalNotificationManager.shared.ensureAuthorization()
                            if !granted { notificationsOn = false }
                            LocalNotificationManager.shared.setEnabled(granted)
                        }
                    }
                    .task {
                        if notificationsOn { _ = await LocalNotificationManager.shared.ensureAuthorization() }
                    }
                    .tint(.ltsBlue)
            }

            if status.boardVariant != .unknown {
                Section {
                    AdaptiveDetailRow(title: "Variante", value: boardVariantText) {
                        BoardVariantView(isInitialSelection: false)
                    }
                }
            }
        }
    }
}

private struct ServoCalibrationView: View {
    @Environment(BLEManager.self) private var bleManager
    @State private var side: String = "L"

    private var currentAngle: Int {
        side == "L" ? bleManager.status.servoAngleL : bleManager.status.servoAngleR
    }

    private struct ArrowButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(UIColor.secondarySystemFill))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color(UIColor.separator).opacity(0.35), lineWidth: 0.5)
                )
                .opacity(configuration.isPressed ? 0.7 : 1.0)
        }
    }

    /// The servo angle grows to the left, so the left arrow increases it.
    private func adjustAngle(by delta: Int) {
        let newAngle = currentAngle + delta
        guard (0...180).contains(newAngle) else { return }
        if side == "L" {
            bleManager.status.servoAngleL = newAngle
            bleManager.setServoAngleL(newAngle)
        } else {
            bleManager.status.servoAngleR = newAngle
            bleManager.setServoAngleR(newAngle)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func arrowButton(_ systemName: String, delta: Int) -> some View {
        let isAtLimit = !(0...180).contains(currentAngle + delta)
        return Button {
            adjustAngle(by: delta)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 18))
                .foregroundStyle(isAtLimit ? Color.secondary : Color.primary)
                .frame(minWidth: 44, minHeight: 22)
        }
        .buttonStyle(ArrowButtonStyle())
        .disabled(isAtLimit)
    }

    var body: some View {
        List {
            Section {
                Picker("", selection: $side) {
                    Text("Linke Seite").tag("L")
                    Text("Rechte Seite").tag("R")
                }
                .pickerStyle(.segmented)
                .onChange(of: side) { _, newValue in
                    bleManager.servoGoto(newValue)
                }
                HStack(spacing: 12) {
                    arrowButton("chevron.left", delta: 1)
                    Spacer()
                    Text("Winkel: \(currentAngle)°")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                    Spacer()
                    arrowButton("chevron.right", delta: -1)
                }
                .frame(maxWidth: .infinity)
            } footer: {
                Text("Stelle die Endanschläge links und rechts so ein, dass die Filamentführung gerade so die Seiten berührt.")
            }
        }
        .onAppear {
            side = bleManager.status.servoHome == "L" ? "L" : "R"
            bleManager.servoGoto(side)
        }
        .onDisappear {
            bleManager.servoGoto("HOME")
        }
    }
}

private struct RespoolAmountView: View {
    @Binding var targetWeight: Int

    /// Wire values of the board's `WGT` setting.
    static func title(for weight: Int) -> String {
        switch weight {
        case 1: return NSLocalizedString("1,0 kg", comment: "Respool Amount option: 1.0 kg")
        case 2: return NSLocalizedString("0,5 kg", comment: "Respool Amount option: 0.5 kg")
        case 3: return NSLocalizedString("0,25 kg", comment: "Respool Amount option: 0.25 kg")
        default: return NSLocalizedString("Gesamte Spule", comment: "Respool Amount option: entire spool")
        }
    }

    private func option(_ weight: Int) -> some View {
        HStack {
            Text(Self.title(for: weight))
            Spacer()
            if targetWeight == weight {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.ltsBlue)
                    .fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if targetWeight != weight { targetWeight = weight }
        }
    }

    var body: some View {
        List {
            Section(footer: Text("Der Respooler stoppt anhand des Filament Sensors, sobald die obere Spule leer ist. Empfohlen, wenn Filament zwischen zwei 1\u{00A0}kg Spulen übertragen wird.")) {
                option(0)
            }

            Section(footer:
                Text("""
                    \( NSLocalizedString("Der Respooler stoppt anhand der übertragenen Menge. Empfohlen, wenn die obere Spule größer als 1\u{00A0}kg ist.", comment: "Respool Amount explanatory footer for fixed weights") )

                    Das Stoppen funktioniert auf Basis des dynamisch berechneten Fortschritts. Die Genauigkeit kann je nach Material variieren.
                    """)
            ) {
                ForEach([1, 2, 3], id: \.self, content: option)
            }
        }
    }
}

#if DEBUG
#Preview("Settings") {
    NavigationStack {
        SettingsView()
            .environment(BLEManager())
            .environment(LayoutModel())
    }
}
#endif
