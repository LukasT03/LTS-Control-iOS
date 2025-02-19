import SwiftUI

private let customBlue = Color(red: 1.0/255.0, green: 0.0, blue: 128.0/255.0)

struct SettingsView: View {
    @StateObject private var accessorySetupManager = AccessorySetupManager()

    // Zustände für die Toggle-Schalter
    @AppStorage("useFilamentSensor") private var useFilamentSensor = true
    @AppStorage("ledsEnabled") private var ledsEnabled = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("directionSelection") private var directionSelection = 0
    @AppStorage("motorStrength") private var motorStrength: Double = 100.0 // Standardwert 100%
    @AppStorage("torqueLimit") private var torqueLimit = 0

    // Auswahl für Verbindungsmethode (Bluetooth oder Wi-Fi)
    @State private var showImpressum = false
    @State private var showInstructions = false

    var body: some View {
        List {
            Section(header: Text("Respooler")) {
                HStack {
                    Text("Verbindung")
                    Spacer()
                    Text(accessorySetupManager.isConnected ? "Verbunden" : "Getrennt")
                        .foregroundColor(.gray)
                        .animation(.default, value: accessorySetupManager.isConnected)
                }
            }
            
            
            
            // KONFIGURATIONS-SECTION
            Section(header: Text("Konfiguration"), footer: Text("Der Auto-Stopp stoppt den Motor bei Widerstand.")
                .font(.footnote)
                .foregroundColor(.gray)) {
                Picker("Richtung", selection: $directionSelection) {
                    Text("Drehrichtung 1").tag(0)
                    Text("Drehrichtung 2").tag(1)
                }
                .pickerStyle(.segmented) // Native SegmentedControl
                .padding(.vertical, 3)

                // Picker für Torque-Limit
                Picker("Auto-Stopp Empfindlichkeit", selection: $torqueLimit) {
                    Text("aus").tag(0)
                    Text("gering").tag(1)
                    Text("mittel").tag(2)
                    Text("hoch").tag(3)
                }
                .tint(Color(UIColor.label))
                    
                Toggle("LED Feedback", isOn: $ledsEnabled)
                    .tint(customBlue)
                    
                Toggle("Filament Sensor nutzen", isOn: $useFilamentSensor)
                    .tint(customBlue)
                
                Toggle("Benachrichtigungen", isOn: $notificationsEnabled)
                    .tint(customBlue)
            }
            // Motor-Stärke Slider
            Section(header: Text("Motor-Stärke")) {
                HStack {
                    Text("80%") // Linke Begrenzung
                        .font(.footnote)
                        .foregroundColor(.gray)

                    Slider(value: $motorStrength, in: 80...120, step: 1)
                        .tint(customBlue) // Farbige Anpassung des Sliders

                    Text("120%") // Rechte Begrenzung
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
            
            Section(header: Text("Verbindung"), footer: Text("Bei Verbindungsproblemen das gespeicherte Gerät entfernen und die Verbindung neu aufbauen.")
                .font(.footnote)
                .foregroundColor(.gray)) {

                Button(action: {
                    accessorySetupManager.forgetAccessory()
                }) {
                    Text("Gespeichertes Gerät entfernen")
                }
                .foregroundColor(.red)

                Button(action: {
                    accessorySetupManager.showAccessoryPicker()
                }) {
                    Text("Verbindung herstellen")
                }
                .disabled(UserDefaults.standard.string(forKey: "storedAccessoryIdentifier") != nil)
                
            }

            // INFO
            Section(header: Text("Informationen"), footer: Text("© 2025, LTS Design, Heiligenbornstraße 23, 01219 Dresden, Deutschland, info@lts-design.com")
                .font(.footnote)
                .foregroundColor(.gray)) {
                Button(action: {
                    showInstructions = true // Öffnet das Sheet
                }) {
                    Label("Hinweise", systemImage: "info.circle")
                        .foregroundColor(Color(UIColor { $0.userInterfaceStyle == .dark ? .white : .black }))
                }
            }
        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.large)

        .sheet(isPresented: $showInstructions) {
            InstructionsView()
                .presentationDetents([.large])
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
    }
}
