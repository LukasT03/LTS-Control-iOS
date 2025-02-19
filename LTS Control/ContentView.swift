import SwiftUI

private let customBlue = Color(red: 1.0/255.0, green: 0.0, blue: 128.0/255.0)

struct RotatingTimelapseIcon: View {
    @Binding var isRotating: Bool
    @State private var rotation: Double = 0
    @State private var currentSpeed: Double = 0

    private let maxSpeed: Double = 1.5
    private let acceleration: Double = 0.01
    private let deceleration: Double = 0.05
    private let timer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Image(systemName: "timelapse")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(customBlue)
            .frame(alignment: .center)
            .padding(.bottom, 3)
            .padding(.vertical, getDeviceSpecificPadding())
            .rotationEffect(Angle.degrees(rotation), anchor: .center)
            .onReceive(timer) { _ in
                if isRotating {
                    if currentSpeed < maxSpeed {
                        currentSpeed = min(maxSpeed, currentSpeed + acceleration)
                    }
                } else {
                    if currentSpeed > 0 {
                        currentSpeed = max(0, currentSpeed - deceleration)
                    }
                }

                if currentSpeed > 0 {
                    rotation += currentSpeed
                    if rotation >= 360 {
                        rotation -= 360
                    }
                }
            }
    }
}

struct ContentView: View {
    @StateObject private var accessorySetupManager = AccessorySetupManager()
    @Binding var showSplashView: Bool

    @State public var CurrentState: LocalizedStringKey = "Nicht verbunden"
    @State private var filamentDetected: Bool = false // Filamentstatus
    @AppStorage("motorSpeed") private var motorSpeed: Double = 80.0
    @State private var isMotorRunning: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section(header: Text("Status")) {
                    HStack {
                        HStack {
                            Label {
                                Text("Verbindung")
                            } icon: {
                                Image(systemName: accessorySetupManager.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                                    .frame(height: 28, alignment: .bottom)
                                    .foregroundColor(accessorySetupManager.isConnected ? .blue : Color.primary)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }
                        Spacer()
                        Text(accessorySetupManager.isConnected ? "Verbunden" : "Getrennt")
                            .foregroundColor(.gray)
                            .animation(.default, value: accessorySetupManager.isConnected)
                    }

                    HStack {
                        HStack {
                            Label("Filament", systemImage: filamentDetected ? "checkmark.circle" : "xmark.circle")
                                .contentTransition(.symbolEffect(.replace))
                                .accentColor(filamentDetected ? .green : Color.primary)
                        }
                        Spacer()
                        Text(filamentDetected ? "Erkannt" : "Nicht erkannt")
                            .foregroundColor(.gray)
                            .animation(.default, value: filamentDetected)
                    }
                }
            }
            .frame(height: 160)
            .listStyle(InsetGroupedListStyle())
            .scrollDisabled(true)

            VStack(spacing: 0) {
                ZStack {
                    Color(UIColor.systemGroupedBackground)
                        .edgesIgnoringSafeArea(.horizontal)
                    RotatingTimelapseIcon(isRotating: $isMotorRunning)
                }
                .frame(maxWidth: .infinity)

                //Status-Text
                Text(CurrentState)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 19)
                    .background(Color(UIColor.systemGroupedBackground))
                    .animation(.default, value: CurrentState) // Nativer Übergang für den Text
            }

            List {
                Section(header: Text("Motor")) {
                    VStack {
                        HStack {
                            Text("Geschwindigkeit")
                            Spacer()
                            Text("\(Int(motorSpeed))%")
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Slider(value: $motorSpeed, in: 50...100, step: 1)
                                .onChange(of: motorSpeed) { _, newValue in
                                    updateMotorSpeed(to: newValue)
                                }
                                .accentColor(customBlue)
                        }

                        HStack {
                            Button(action: startMotor) {
                                Text("Start")
                                    .frame(minWidth: 0, maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .disabled(!accessorySetupManager.isConnected)

                            Button(action: stopMotor) {
                                Text("Stopp")
                                    .frame(minWidth: 0, maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .tint(.red)
                            .disabled(!accessorySetupManager.isConnected)
                        }
                        .padding(.top)
                    }
                }

                if UIDevice.current.userInterfaceIdiom != .pad {
                    Section {
                        NavigationLink(destination: SettingsView()) {
                            Label("Einstellungen", systemImage: "gear")
                                .foregroundColor(Color(UIColor { $0.userInterfaceStyle == .dark ? .white : .black }))
                        }
                    }
                }
            }
            .frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 244 : 296)
            .listStyle(InsetGroupedListStyle())
            .scrollDisabled(true)
        }
        .onAppear {
            accessorySetupManager.activateSession()
        }
        .onChange(of: accessorySetupManager.isConnected) { _, newValue in
            if newValue {
                showSplashView = false
                if CurrentState == "Nicht verbunden" {
                    CurrentState = "Leerlauf"
                }
            } else {
                CurrentState = "Nicht verbunden"
                filamentDetected = false
            }
        }
        .navigationTitle("LTS Respooler")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Funktionen
    
    private func updateMotorSpeed(to value: Double) {
        print("Motorgeschwindigkeit auf \(Int(value))% gesetzt")
    }

    private func startMotor() {
        guard accessorySetupManager.isConnected else { return }
        isMotorRunning = true
        CurrentState = "Läuft..."
        print("Motor gestartet mit \(Int(motorSpeed))% Geschwindigkeit")
    }

    private func stopMotor() {
        guard accessorySetupManager.isConnected else { return }
        isMotorRunning = false
        CurrentState = "Leerlauf"
        print("Motor gestoppt")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ContentView(showSplashView: .constant(false))
        }
    }
}

func getDeviceSpecificPadding() -> CGFloat {
    let screenHeight = max(UIScreen.main.bounds.height, UIScreen.main.bounds.width)
    
    if UIDevice.current.userInterfaceIdiom == .pad {
        if screenHeight <= 1150 {
            // iPad Mini
            return 2
        } else if screenHeight <= 1300 {
            // iPad Pro 11" oder ähnliche
            return 20
        } else {
            // Größere iPads (z. B. iPad Pro 12.9")
            return 60
        }
    } else if UIDevice.current.userInterfaceIdiom == .phone {
        if screenHeight <= 700 {
            // iPhone SE (3. Gen)
            return 1 // Spezifisches Padding für iPhone SE
        } else {
            // Andere iPhones
            return 8
        }
    } else {
        // Standardwert für andere Gerätetypen
        return 8
    }
}
