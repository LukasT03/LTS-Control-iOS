import SwiftUI

struct SettingsView: View {
    @AppStorage("temperatureInFahrenheit") private var showFahrenheit = false
    @AppStorage("LiveActivityEnabled") private var liveActivitiesOn: Bool = true
    @AppStorage("NotificationsEnabled") private var notificationsOn: Bool = false
    @Environment(BLEManager.self) private var bleManager
    @Environment(LayoutModel.self) private var layoutModel
    @State private var showRespoolAmount = false
    @State private var showServoCalibration = false
    @State private var showBoardVariantSelection = false
    
    private var stateIconName: String {
        if !bleManager.isConnected { return "antenna.radiowaves.left.and.right.slash.circle" }
        switch bleManager.deviceState {
        case .running:
            return "play.circle"
        case .paused:
            return "pause.circle"
        case .updating:
            return "arrow.trianglehead.2.clockwise.rotate.90.circle"
        case .done:
            return "checkmark.circle"
        case .autoStop:
            return "exclamationmark.circle"
        case .idle:
            return "power.circle"
        }
    }

    private var stateIconColor: Color {
        if !bleManager.isConnected { return .primary }
        switch bleManager.deviceState {
        case .running:
            return .green
        case .paused:
            return .orange
        case .updating:
            return .indigo
        case .done:
            return .green
        case .autoStop:
            return .red
        case .idle:
            return .ltsBlue
        }
    }

    private var targetWeightText: String {
        switch bleManager.status.targetWeight {
        case 0:
            return NSLocalizedString("Gesamte Spule", comment: "Respool Amount label: entire spool")
        case 1:
            return NSLocalizedString("1,0 kg", comment: "Respool Amount label: 1.0 kg")
        case 2:
            return NSLocalizedString("0,5 kg", comment: "Respool Amount label: 0.5 kg")
        case 3:
            return NSLocalizedString("0,25 kg", comment: "Respool Amount label: 0.25 kg")
        default:
            return NSLocalizedString("Gesamte Spule", comment: "Respool Amount label: entire spool")
        }
    }

    private var boardVariantText: String {
        switch bleManager.status.boardVariant {
        case .standard:
            return "Respooler V4"
        case .pro:
            return "Respooler Pro"
        default:
            return "–"
        }
    }

    var body: some View {
        VStack {
            List {
            Section {
                HStack(spacing: 12) {
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
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                
                Section(
                    header: Text("Konfiguration"), footer: Text("Wenn der Sensor deaktiviert ist, wird nicht auf den Verlust von Filament reagiert.")) {
                        Picker(
                            "Ton bei Fertigstellung",
                            selection: Binding(
                                get: { bleManager.status.jingleStyle },
                                set: { new in
                                    bleManager.status.jingleStyle = new
                                    bleManager.setJingleStyle(new)
                                }
                            )
                        ) {
                            Text("Aus").tag(0)
                            Text("Einfach").tag(1)
                            Text("Glissando").tag(2)
                            Text("Star Wars").tag(3)
                        }
                        Stepper(
                            value: Binding(
                                get: { bleManager.status.ledBrightness },
                                set: { new in
                                    bleManager.status.ledBrightness = new
                                    bleManager.setLED(new)
                                }
                            ),
                            in: 0...100,
                            step: 10
                        ) {
                            Text("LED Helligkeit: \(bleManager.status.ledBrightness) %")
                                .monospacedDigit()
                        }
                        
                        if layoutModel.isCompactWidth {
                            NavigationLink {
                                RespoolAmountView(
                                    targetWeight: Binding(
                                        get: { bleManager.status.targetWeight },
                                        set: { new in
                                            bleManager.status.targetWeight = new
                                            bleManager.setTargetWeight(new)
                                        }
                                    )
                                )
                                .navigationTitle("Respool-Menge")
                                .navigationBarTitleDisplayMode(.inline)
                            } label: {
                                HStack {
                                    Text("Respool-Menge")
                                    Spacer()
                                    Text(targetWeightText)
                                        .foregroundColor(.gray)
                                }
                                .contentShape(Rectangle())
                            }
                        } else {
                            Button {
                                showRespoolAmount = true
                            } label: {
                                HStack {
                                    Text("Respool-Menge")
                                    Spacer()
                                    Text(targetWeightText)
                                        .foregroundColor(.secondary)
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                        .font(.system(size: 14))
                                        .fontWeight(.semibold)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Toggle(
                            "Filament Sensor nutzen",
                            isOn: Binding(
                                get: { bleManager.status.useFilamentSensor },
                                set: { new in
                                    bleManager.status.useFilamentSensor = new
                                    bleManager.setUseFilamentSensor(new)
                                }
                            )
                        )
                        .tint(.ltsBlue)
                    }

                Section(header: Text("Motor"), footer: Text("Der Auto-Stopp stoppt den Motor bei Widerstand.")
                    ) {
                        Toggle(
                            "Richtung umkehren",
                            isOn: Binding(
                                get: { bleManager.status.directionReversed },
                                set: { new in
                                    bleManager.status.directionReversed = new
                                    bleManager.setDirectionReversed(new)
                                }
                            )
                        )
                        .tint(.ltsBlue)
                        Stepper(
                            value: Binding(
                                get: { bleManager.status.motorStrength },
                                set: { new in
                                    bleManager.status.motorStrength = new
                                    bleManager.setMotorStrength(new)
                                }
                            ),
                            in: 80...120,
                            step: 10
                        ) {
                            Text("Stärke: \(bleManager.status.motorStrength) %")
                                .monospacedDigit()
                        }
                        Picker(
                            "Auto-Stopp Empfindlichkeit",
                            selection: Binding(
                                get: { bleManager.status.torqueLimit },
                                set: { new in
                                    bleManager.status.torqueLimit = new
                                    bleManager.setTorqueLimit(new)
                                }
                            )
                        ) {
                            Text("Aus").tag(0)
                            Text("Gering").tag(1)
                            Text("Mittel").tag(2)
                            Text("Hoch").tag(3)
                        }
                        .disabled(bleManager.status.highSpeed)
                    }
                
                Section(footer: Text("Der High-Speed Modus erhöht die Geschwindigkeit des Motors. Auto-Stopp ist dabei nicht verfügbar.")
                    ) {
                        Toggle(
                            "High-Speed",
                            isOn: Binding(
                                get: { bleManager.status.highSpeed },
                                set: { new in
                                    bleManager.status.highSpeed = new
                                    bleManager.setHighSpeed(new)
                                }
                            )
                        )
                        .tint(.ltsBlue)
                    }
                
                if bleManager.status.boardVariant == .pro {
                    Section(header: Text("Servo"), footer: Text("Wähle aus, auf welcher Seite die Startposition der Filamentführung ist.")) {
                    if layoutModel.isCompactWidth {
                        NavigationLink {
                            ServoCalibrationView()
                                .navigationTitle("Endpositionen kalibrieren")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            Text("Endpositionen kalibrieren")
                        }
                    } else {
                        Button {
                            showServoCalibration = true
                        } label: {
                            HStack {
                                Text("Endpositionen kalibrieren")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                                    .font(.system(size: 14))
                                    .fontWeight(.semibold)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Stepper(
                        value: Binding(
                            get: { bleManager.status.servoStepMm },
                            set: { new in
                                bleManager.status.servoStepMm = new
                                bleManager.setServoStepMm(new)
                            }
                        ),
                        in: 0.50...4.00,
                        step: 0.01
                    ) {
                        Text("Schrittweite: \(bleManager.status.servoStepMm, format: .number.precision(.fractionLength(2))) mm")
                            .monospacedDigit()
                    }

                    Picker(
                        "",
                        selection: Binding(
                            get: { bleManager.status.servoHome },
                            set: { new in
                                bleManager.status.servoHome = new
                                bleManager.setServoHome(new)
                            }
                        )
                    ) {
                        Text("Links").tag("L")
                        Text("Rechts").tag("R")
                    }
                    .pickerStyle(.segmented)
                    }
                }

                Section(header: Text("Lüfter"), footer: Text("Der Lüfter schaltet sich standardmäßig 10 Sekunden nach stoppen des Respoolers aus.")
                ){
                    Stepper(
                        value: Binding(
                            get: { bleManager.status.fanSpeed },
                            set: { new in
                                bleManager.status.fanSpeed = new
                                bleManager.setFanSpeed(new)
                            }
                        ),
                        in: 10...100,
                        step: 10
                    ) {
                        Text("Geschwindigkeit: \(bleManager.status.fanSpeed) %")
                            .monospacedDigit()
                    }
                    Toggle(
                        "Lüfter immer an",
                        isOn: Binding(
                            get: { bleManager.status.fanAlways },
                            set: { new in
                                bleManager.status.fanAlways = new
                                bleManager.setFanAlways(new)
                            }
                        )
                    )
                    .tint(.ltsBlue)
                    Picker("", selection: $showFahrenheit) {
                        Text("Celsius").tag(false)
                        Text("Fahrenheit").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Kalibrierung"), footer: Text("Für genauere Zeitangaben bzw. Respool-Mengen die benötigte Dauer für eine 1\u{00A0}kg Spule bei 80\u{00A0}% Geschwindigkeit messen und hier anpassen.")
                    ) {
                    Stepper(
                        value: Binding(
                            get: { bleManager.status.durationAt80 },
                            set: { new in
                                bleManager.status.durationAt80 = new
                                bleManager.setDurationAt80(new)
                            }
                        ),
                        in: 5...2000,
                        step: 5
                    ) {
                        let value = bleManager.status.durationAt80
                        Text("Dauer: \(value / 60)m \(value % 60)s")
                            .monospacedDigit()
                    }
                }
                
                Section(header: Text("App"), footer: Text("Erhalte Push-Benachrichtigungen, wenn der Respooler stoppt oder fertig ist.")
                ) {
                    Toggle(
                        "Live-Aktivitäten",
                        isOn: $liveActivitiesOn
                    )
                    .onChange(of: liveActivitiesOn) { _, newValue in
                        LiveActivityManager.shared.setEnabled(newValue)
                    }
                    .tint(.ltsBlue)
                    Toggle(
                        "Benachrichtigungen",
                        isOn: $notificationsOn
                    )
                    .onChange(of: notificationsOn) { _, newValue in
                        if newValue {
                            LocalNotificationManager.shared.ensureAuthorization { granted in
                                DispatchQueue.main.async {
                                    if granted {
                                        LocalNotificationManager.shared.setEnabled(true)
                                    } else {
                                        notificationsOn = false
                                        LocalNotificationManager.shared.setEnabled(false)
                                    }
                                }
                            }
                        } else {
                            LocalNotificationManager.shared.setEnabled(false)
                        }
                    }
                    .onAppear {
                        if notificationsOn { LocalNotificationManager.shared.requestAuthorizationIfNeeded() }
                    }
                    .tint(.ltsBlue)
                }

                if bleManager.status.boardVariant == .pro || bleManager.status.boardVariant == .standard {
                    Section {
                        if layoutModel.isCompactWidth {
                            NavigationLink {
                                BoardVariantSettingsView()
                            } label: {
                                HStack {
                                    Text("Variante")
                                    Spacer()
                                    Text(boardVariantText)
                                        .foregroundColor(.gray)
                                }
                                .contentShape(Rectangle())
                            }
                        } else {
                            Button {
                                showBoardVariantSelection = true
                            } label: {
                                HStack {
                                    Text("Variante")
                                    Spacer()
                                    Text(boardVariantText)
                                        .foregroundColor(.secondary)
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                        .font(.system(size: 14))
                                        .fontWeight(.semibold)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showRespoolAmount) {
            NavigationStack {
                RespoolAmountView(
                    targetWeight: Binding(
                        get: { bleManager.status.targetWeight },
                        set: { new in
                            bleManager.status.targetWeight = new
                            bleManager.setTargetWeight(new)
                        }
                    )
                )
                .navigationTitle("Respool-Menge")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showRespoolAmount = false
                        } label: {
                            if #available(iOS 26.0, *) {
                                Image(systemName: "xmark")
                            } else {
                                Text("Schließen")
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showServoCalibration) {
            NavigationStack {
                ServoCalibrationView()
                    .navigationTitle("Endpositionen kalibrieren")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showServoCalibration = false
                            } label: {
                                if #available(iOS 26.0, *) {
                                    Image(systemName: "xmark")
                                } else {
                                    Text("Schließen")
                                }
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showBoardVariantSelection) {
            NavigationStack {
                BoardVariantSettingsView()
                    .navigationTitle("Variante")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showBoardVariantSelection = false
                            } label: {
                                if #available(iOS 26.0, *) {
                                    Image(systemName: "xmark")
                                } else {
                                    Text("Schließen")
                                }
                            }
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
    private func lightHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                Section {
                    HStack(spacing: 12) {
                        Button {
                            guard currentAngle < 180 else { return }
                            let newAngle = currentAngle + 1
                            if side == "L" {
                                bleManager.status.servoAngleL = newAngle
                                bleManager.setServoAngleL(newAngle)
                            } else {
                                bleManager.status.servoAngleR = newAngle
                                bleManager.setServoAngleR(newAngle)
                            }
                            lightHaptic()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18))
                                .foregroundStyle(currentAngle >= 180 ? Color.secondary : Color.primary)
                                .frame(minWidth: 44, minHeight: 22)
                        }
                        .buttonStyle(ArrowButtonStyle())
                        .disabled(currentAngle >= 180)

                        Spacer()

                        Text("Winkel: \(currentAngle)°")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)

                        Spacer()

                        Button {
                            guard currentAngle > 0 else { return }
                            let newAngle = currentAngle - 1
                            if side == "L" {
                                bleManager.status.servoAngleL = newAngle
                                bleManager.setServoAngleL(newAngle)
                            } else {
                                bleManager.status.servoAngleR = newAngle
                                bleManager.setServoAngleR(newAngle)
                            }
                            lightHaptic()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18))
                                .foregroundStyle(currentAngle <= 0 ? Color.secondary : Color.primary)
                                .frame(minWidth: 44, minHeight: 22)
                        }
                        .buttonStyle(ArrowButtonStyle())
                        .disabled(currentAngle <= 0)
                    }
                    .frame(maxWidth: .infinity)
                }
            } footer: {
                Text("Stelle die Endanschläge links und rechts so ein, dass die Filamentführung gerade so die Seiten berührt.")
            }
        }
        .onAppear {
            let home = bleManager.status.servoHome.uppercased()
            if home == "L" || home == "R" {
                side = home
            } else {
                side = "R"
            }
            bleManager.servoGoto(side)
        }
        .onDisappear {
            bleManager.servoGoto("HOME")
        }
    }
}

private struct RespoolAmountView: View {
    @Binding var targetWeight: Int

    private let entireOption: (title: String, tag: Int) = (
        NSLocalizedString("Gesamte Spule", comment: "Respool Amount option: entire spool"),
        0
    )
    private let weightOptions: [(title: String, tag: Int)] = [
        (NSLocalizedString("1,0 kg", comment: "Respool Amount option: 1.0 kg"), 1),
        (NSLocalizedString("0,5 kg", comment: "Respool Amount option: 0.5 kg"), 2),
        (NSLocalizedString("0,25 kg", comment: "Respool Amount option: 0.25 kg"), 3)
    ]

    var body: some View {
        List {
            Section(footer: Text("Der Respooler stoppt anhand des Filament Sensors, sobald die obere Spule leer ist. Empfohlen, wenn Filament zwischen zwei 1\u{00A0}kg Spulen übertragen wird.")) {
                HStack {
                    Text(entireOption.title)
                    Spacer()
                    if targetWeight == entireOption.tag {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.ltsBlue)
                            .fontWeight(.semibold)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if targetWeight != entireOption.tag {
                        targetWeight = entireOption.tag
                    }
                }
            }

            Section(footer:
                Text("""
                    \( NSLocalizedString("Der Respooler stoppt anhand der übertragenen Menge. Empfohlen, wenn die obere Spule größer als 1\u{00A0}kg ist.", comment: "Respool Amount explanatory footer for fixed weights") )

                    Das Stoppen funktioniert auf Basis des dynamisch berechneten Fortschritts. Die Genauigkeit kann je nach Material variieren.
                    """)
            ) {
                ForEach(weightOptions, id: \.tag) { opt in
                    HStack {
                        Text(opt.title)
                        Spacer()
                        if targetWeight == opt.tag {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.ltsBlue)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if targetWeight != opt.tag {
                            targetWeight = opt.tag
                        }
                    }
                }
            }
        }
        .navigationTitle("Respool-Menge")
        .navigationBarTitleDisplayMode(.inline)
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


