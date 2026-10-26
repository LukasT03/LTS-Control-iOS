import SwiftUI
import UIKit

struct StatusHeaderView: View {
    @Environment(\.isSplitLayout) private var isSplitLayout
    
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
        .frame(minHeight: {
            if isSplitLayout, #available(iOS 26, *) {
                78
            } else {
                50
            }
        }())
    }
}

#Preview("Connection – Example") {
    ConnectionView(
        wifiSSID: .constant(""),
        wifiPassword: .constant(""),
        scanSessionID: .constant(0)
    )
    .environment(BLEManager())
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

struct ConnectionView: View {
    @Environment(\.isSplitLayout) private var isSplitLayout
    @Environment(BLEManager.self) private var bleManager

    @Binding var wifiSSID: String
    @Binding var wifiPassword: String
    
    @Binding var scanSessionID: Int

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
        !isConnectingToWiFi && bleManager.isConnected && bleManager.deviceState != .updating && !wifiSSID.isEmpty && !wifiPassword.isEmpty
    }
    
    private func performSendCredentials() {
        isConnectingToWiFi = true
        // The board reports the result only once, so a second failure in a row must still count as a change.
        bleManager.status.wifiConnectionResult = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        bleManager.sendWiFiPassword(wifiPassword)
        wifiPassword = ""
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            bleManager.sendWiFiSSID(wifiSSID)
            try? await Task.sleep(for: .seconds(0.3))
            bleManager.triggerWiFiConnect()
        }
    }

    private func scanButton(_ title: LocalizedStringKey) -> some View {
        Button(title) {
            bleManager.triggerWiFiScan()
            scanSessionID += 1
        }
        .disabled(!canScan)
    }

    var body: some View {
        VStack {
            List {
                Section {
                    Group {
                        StatusHeaderView(
                            isConnected: bleManager.isConnected,
                            isWiFiConnected: isWiFiConnected,
                            showWiFiError: showWiFiError,
                            shouldWiggleWiFiIcon: shouldWiggleWiFiIcon,
                            shouldBounceWiFiIcon: shouldBounceWiFiIcon
                        )
                        .pillListRow()
                    }
                }
                Section(header: Text("WLAN"),
                        footer: Text("Für die WLAN-Verbindung hier nach verfügbaren Netzwerken suchen und das Passwort eingeben. Funktioniert nur mit 2,4 GHz Netzwerken.")) {
                    if bleManager.isScanningForSSIDs {
                        HStack {
                            Text("Netzwerk")
                            Spacer()
                            ProgressView()
                        }
                        .id(scanSessionID)
                    } else {
                        SSIDPickerView(ssids: visibleSSIDs, selectedSSID: $wifiSSID, scanSessionID: scanSessionID)
                    }
                    ClearableSecureField(text: $wifiPassword, placeholder: NSLocalizedString("Passwort", comment: "Wi‑Fi password placeholder")) {
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
                
                // On iPad with iOS 26 the scan button sits in the toolbar instead.
                if !isSplitLayout {
                    Section { scanButton("Nach verfügbaren Netzwerken suchen") }
                } else if #unavailable(iOS 26) {
                    Section { scanButton("Nach verfügbaren Netzwerken suchen") }
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
            .navigationTitle("Verbindung")
            .navigationBarTitleDisplayMode(isSplitLayout ? .inline : .large)
            .toolbar {
                if isSplitLayout {
                    SheetCloseButton()
                    if #available(iOS 26, *) {
                        ToolbarItem(placement: .topBarLeading) { scanButton("Netzwerk-Scan") }
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .background(Color(UIColor.systemGroupedBackground))
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
                wifiSSID = ""
                scanSessionID += 1
            }
        }
    }
}
