import SwiftUI
import UIKit

struct StatusHeaderView: View {
    @Environment(LayoutModel.self) private var layoutModel
    
    let isConnected: Bool
    let isWiFiConnected: Bool
    let isWiFiErrorHighlight: Bool
    let shouldWiggleWiFiIcon: Bool
    let shouldBounceWiFiIcon: Bool
    let showWiFiErrorText: Bool

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
            .frame(height: 40, alignment: .center)
            .padding(.leading, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .frame(height: 50)
            .contentShape(Capsule())
            
            HStack(spacing: 8) {
                Image(systemName: isWiFiConnected ? "wifi" : "wifi.slash")
                    .padding(.bottom, isWiFiConnected ? 3 : 2)
                    .font(.system(size: 22))
                    .frame(width: 28, height: 28, alignment: .bottom)
                    .foregroundColor(isWiFiConnected ? .green : (isWiFiErrorHighlight ? .red : Color.primary))
                    .animation(.default, value: isWiFiErrorHighlight)
                    .animation(.default, value: isWiFiConnected)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.wiggle, value: shouldWiggleWiFiIcon)
                    .symbolEffect(.bounce, value: shouldBounceWiFiIcon)

                VStack(alignment: .leading, spacing: 0) {
                    Text("WLAN")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(
                        showWiFiErrorText
                        ? "Fehler!"
                        : (isConnected
                            ? (isWiFiConnected ? "Verbunden" : "Getrennt")
                            : "Getrennt")
                    )
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
        .frame(minHeight: {
            if !layoutModel.isCompactWidth, #available(iOS 26, *) {
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
    .environment(LayoutModel())
    .environment(BLEManager())
}

struct SSIDPickerView: View, Equatable {
    let ssids: [String]
    @Binding var selectedSSID: String
    let scanSessionID: Int

    static func == (lhs: SSIDPickerView, rhs: SSIDPickerView) -> Bool {
        lhs.ssids == rhs.ssids && lhs.selectedSSID == rhs.selectedSSID && lhs.scanSessionID == rhs.scanSessionID
    }

    var body: some View {
        let unique = Array(NSOrderedSet(array: ssids)) as! [String]
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
        tf.placeholder = NSLocalizedString(placeholder, comment: "")
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
        uiView.placeholder = NSLocalizedString(placeholder, comment: "")
    }
}

struct ConnectionView: View {
    @Environment(LayoutModel.self) private var layoutModel
    @Environment(BLEManager.self) private var bleManager
    @Environment(\.dismiss) private var dismiss
    
    @Binding var wifiSSID: String
    @Binding var wifiPassword: String
    
    @State private var isConnectingToWiFi: Bool = false
    @State private var shouldWiggleWiFiIcon: Bool = false
    @State private var shouldBounceWiFiIcon: Bool = false
    @State private var isWiFiErrorHighlight: Bool = false
    @State private var showWiFiErrorText: Bool = false
    @Binding var scanSessionID: Int
    
    private var visibleSSIDs: [String] { bleManager.ssidList.availableSSIDs ?? [] }
    
    @FocusState private var focusedField: Field?
    enum Field {
        case ssid, password
    }
    
    private var isWiFiConnected: Bool {
        bleManager.isConnected && (bleManager.status.wifiConnected ?? false)
    }
    
    private var canSendCredentials: Bool {
        !isConnectingToWiFi && bleManager.isConnected && bleManager.deviceState != .updating && !wifiSSID.isEmpty && !wifiPassword.isEmpty
    }
    
    private func performSendCredentials() {
        isConnectingToWiFi = true
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        bleManager.sendWiFiPassword(wifiPassword)
        wifiPassword = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            bleManager.sendWiFiSSID(wifiSSID)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                bleManager.triggerWiFiConnect()
            }
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            VStack{
                List {
                    Section {
                        Group {
                            StatusHeaderView(
                                isConnected: bleManager.isConnected,
                                isWiFiConnected: isWiFiConnected,
                                isWiFiErrorHighlight: isWiFiErrorHighlight,
                                shouldWiggleWiFiIcon: shouldWiggleWiFiIcon,
                                shouldBounceWiFiIcon: shouldBounceWiFiIcon,
                                showWiFiErrorText: showWiFiErrorText
                            )
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
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
                            focusedField = nil
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
                    
                    if layoutModel.isCompactWidth {
                        Section {
                            Button(action: {
                                bleManager.triggerWiFiScan()
                                scanSessionID += 1
                            }) {
                                Text("Nach verfügbaren Netzwerken suchen")
                            }
                            .disabled(!bleManager.isConnected || bleManager.deviceState == .updating)
                        }
                    } else {
                        if #unavailable(iOS 26) {
                            Section {
                                Button(action: {
                                    bleManager.triggerWiFiScan()
                                    scanSessionID += 1
                                }) {
                                    Text("Nach verfügbaren Netzwerken suchen")
                                }
                                .disabled(!bleManager.isConnected || bleManager.deviceState == .updating)
                            }
                        }
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
                            AccessorySessionManager.shared.forgetAccessoryWithPolling()
                        }) {
                            Text("Gespeichertes Gerät entfernen")
                        }
                        .foregroundColor(.red)
                    }
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .navigationTitle("Verbindung")
                .navigationBarTitleDisplayMode(!layoutModel.isCompactWidth ? .inline : .large)
                .toolbar {
                    if !layoutModel.isCompactWidth {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                dismiss()
                            } label: {
                                if #available(iOS 26, *) {
                                    Image(systemName: "xmark")
                                } else {
                                    Text("Schließen")
                                }
                            }
                        }
                        if #available(iOS 26, *) {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    bleManager.triggerWiFiScan()
                                    scanSessionID += 1
                                } label: {
                                    Text("Netzwerk-Scan")
                                }
                                .disabled(!bleManager.isConnected || bleManager.deviceState == .updating)
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .background(Color(UIColor.systemGroupedBackground))
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: bleManager.status.wifiLastResult) { _, newValue in
            if newValue != nil {
                isConnectingToWiFi = false
            }
            if newValue == false {
                shouldWiggleWiFiIcon.toggle()
                isWiFiErrorHighlight = true
                showWiFiErrorText = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    isWiFiErrorHighlight = false
                    showWiFiErrorText = false
                }
            }
            if newValue == true {
                shouldBounceWiFiIcon.toggle()
            }
        }
        .onChange(of: bleManager.status.wifiConnectionResult) { _, newValue in
            if let newValue {
                isConnectingToWiFi = false
                if newValue == true {
                    shouldBounceWiFiIcon.toggle()
                } else {
                    shouldWiggleWiFiIcon.toggle()
                    isWiFiErrorHighlight = true
                    showWiFiErrorText = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                        isWiFiErrorHighlight = false
                        showWiFiErrorText = false
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
