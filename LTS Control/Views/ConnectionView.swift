import SwiftUI
import UIKit

struct StatusHeaderView: View {
    let isConnected: Bool
    let isWiFiConnected: Bool
    let showWiFiError: Bool
    let shouldWiggleWiFiIcon: Bool
    let shouldBounceWiFiIcon: Bool

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: isConnected
                    ? "antenna.radiowaves.left.and.right"
                    : "antenna.radiowaves.left.and.right.slash")
                    .foregroundColor(isConnected ? .cyan : Color.primary)
                    .animation(.default, value: isConnected)
                    .font(.system(size: 22))
                    .frame(width: 28, height: 27, alignment: .bottom)
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 0) {
                    Text("Bluetooth")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(isConnected ? "Verbunden" : "Getrennt")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .pillStyle()

            HStack(spacing: 8) {
                Image(systemName: isWiFiConnected ? "wifi" : "wifi.slash")
                    .padding(.bottom, isWiFiConnected ? 3 : 2)
                    .font(.system(size: 22))
                    .frame(width: 28, height: 28, alignment: .bottom)
                    .foregroundColor(isWiFiConnected ? .green : (showWiFiError ? .red : Color.primary))
                    .animation(.default, value: showWiFiError)
                    .animation(.default, value: isWiFiConnected)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.wiggle, value: shouldWiggleWiFiIcon)
                    .symbolEffect(.bounce, value: shouldBounceWiFiIcon)

                VStack(alignment: .leading, spacing: 0) {
                    Text("WLAN")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(showWiFiError ? "Fehler!" : (isWiFiConnected ? "Verbunden" : "Getrennt"))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                }
                Spacer()
            }
            .pillStyle()
        }
        .frame(minHeight: 50)
    }
}

#Preview("Connection – Example") {
    ConnectionView()
        .environment(BLEManager())
        .environment(WiFiForm())
}

struct SSIDPickerView: View {
    let ssids: [String]
    @Binding var selectedSSID: String
    let scanSessionID: Int

    var body: some View {
        var seen = Set<String>()
        let unique = ssids.filter { seen.insert($0).inserted }
        Picker("Netzwerk", selection: $selectedSSID) {
            Text("Auswählen (\(unique.count))").tag("")
            ForEach(unique, id: \.self) {
                Text($0.trimmingCharacters(in: .whitespaces))
            }
        }
        .id(scanSessionID)
    }
}

struct ClearableSecureField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var onSubmit: (() -> Void)? = nil

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ClearableSecureField
        init(_ parent: ClearableSecureField) { self.parent = parent }
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            parent.onSubmit?()
            return true
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField(frame: .zero)
        tf.delegate = context.coordinator
        tf.isSecureTextEntry = true
        tf.placeholder = placeholder
        tf.clearButtonMode = .whileEditing
        tf.textContentType = .password
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.keyboardType = .asciiCapable
        tf.returnKeyType = .done
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
        uiView.placeholder = placeholder
    }
}

/// What's entered on the connection page. Lives at the root, so it survives switching between
/// the Verbindung tab (compact width) and the page in the settings column (regular width).
@MainActor
@Observable
final class WiFiForm {
    var ssid = ""
    var password = ""
    /// Rebuilds the network picker for every scan.
    var scanSessionID = 0
}

/// Wi‑Fi and Bluetooth settings. The Verbindung tab in compact width, a settings page in regular width.
struct ConnectionView: View {
    @Environment(BLEManager.self) private var bleManager
    @Environment(WiFiForm.self) private var form

    @State private var isConnectingToWiFi: Bool = false
    @State private var shouldWiggleWiFiIcon: Bool = false
    @State private var shouldBounceWiFiIcon: Bool = false
    @State private var showWiFiError: Bool = false

    private var visibleSSIDs: [String] { bleManager.availableSSIDs ?? [] }

    private var canScan: Bool { bleManager.isConnected && bleManager.deviceState != .updating }

    private var isWiFiConnected: Bool {
        bleManager.isConnected && (bleManager.status.wifiConnected ?? false)
    }

    private var canSendCredentials: Bool {
        !isConnectingToWiFi && bleManager.isConnected && bleManager.deviceState != .updating && !form.ssid.isEmpty && !form.password.isEmpty
    }

    private func performSendCredentials() {
        isConnectingToWiFi = true
        // The board reports the result only once, so a second failure in a row must still count as a change.
        bleManager.status.wifiConnectionResult = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        bleManager.sendWiFiPassword(form.password)
        form.password = ""
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            bleManager.sendWiFiSSID(form.ssid)
            try? await Task.sleep(for: .seconds(0.3))
            bleManager.triggerWiFiConnect()
        }
    }

    var body: some View {
        @Bindable var form = form

        List {
            Section {
                StatusHeaderView(
                    isConnected: bleManager.isConnected,
                    isWiFiConnected: isWiFiConnected,
                    showWiFiError: showWiFiError,
                    shouldWiggleWiFiIcon: shouldWiggleWiFiIcon,
                    shouldBounceWiFiIcon: shouldBounceWiFiIcon
                )
                .pillListRow()
            }

            Section(header: Text("WLAN"),
                    footer: Text("Für die WLAN-Verbindung hier nach verfügbaren Netzwerken suchen und das Passwort eingeben. Funktioniert nur mit 2,4 GHz Netzwerken.")) {
                if bleManager.isScanningForSSIDs {
                    HStack {
                        Text("Netzwerk")
                        Spacer()
                        ProgressView()
                    }
                    .id(form.scanSessionID)
                } else {
                    SSIDPickerView(ssids: visibleSSIDs, selectedSSID: $form.ssid, scanSessionID: form.scanSessionID)
                }
                ClearableSecureField(text: $form.password, placeholder: NSLocalizedString("Passwort", comment: "Wi‑Fi password placeholder")) {
                    if canSendCredentials {
                        performSendCredentials()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Spacer()
                    Button(action: {
                        performSendCredentials()
                    }) {
                        if isConnectingToWiFi {
                            ProgressView()
                        }
                        else {
                            Text("Zugangsdaten senden")
                        }
                    }
                    .disabled(!canSendCredentials)
                    Spacer()
                }
            }

            Section {
                Button("Nach verfügbaren Netzwerken suchen") {
                    bleManager.triggerWiFiScan()
                    form.scanSessionID += 1
                }
                .disabled(!canScan)
            }

            Section(header: Text("Bluetooth"),
                    footer: Text("Bei Verbindungsproblemen das gespeicherte Gerät entfernen und die Verbindung neu aufbauen.")) {
                Button(action: {
                    AccessorySessionManager.shared.showAccessoryPicker()
                }) {
                    Text("Verbindung herstellen")
                }
                .disabled(!AccessorySessionManager.shared.canConnect)

                Button(action: {
                    AccessorySessionManager.shared.forgetAccessory()
                }) {
                    Text("Gespeichertes Gerät entfernen")
                }
                .foregroundColor(.red)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: bleManager.status.wifiConnectionResult) { _, newValue in
            if let newValue {
                isConnectingToWiFi = false
                if newValue == true {
                    shouldBounceWiFiIcon.toggle()
                } else {
                    shouldWiggleWiFiIcon.toggle()
                    showWiFiError = true
                    Task {
                        try? await Task.sleep(for: .seconds(3.5))
                        showWiFiError = false
                    }
                }
            }
        }
        .onChange(of: isWiFiConnected) { _, newValue in
            if newValue {
                isConnectingToWiFi = false
            }
        }
        .onChange(of: bleManager.isConnected) { _, newValue in
            if newValue == false {
                // The board's result can't arrive anymore.
                isConnectingToWiFi = false
                form.ssid = ""
                form.scanSessionID += 1
            }
        }
    }
}
