import SwiftUI
import UIKit

struct AboutView: View {
    enum AboutSheet: Hashable, Identifiable {
        case instructions
        case changelog
        case upgradeCode
        case connection
        var id: Self { self }
    }
    @Environment(LayoutModel.self) private var layoutModel
    @Environment(\.colorScheme) private var colorScheme

    struct UpdateButtonStyle: ButtonStyle {
        @Environment(\.isEnabled) private var isEnabled
        var enabledFill: Color = Color.green
        var disabledFill: Color = Color.gray.opacity(0.17)
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(isEnabled ? enabledFill.opacity(configuration.isPressed ? 0.15 : 0.2)
                                         : disabledFill)
                )
                .foregroundStyle(isEnabled ? (configuration.isPressed ? Color.green.opacity(0.75) : Color.green.opacity(1.0)) : Color.gray.opacity(0.4))
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
    @Bindable var bleManager = BLEManager.shared
    
    @State private var updateButtonDisabledUntil: Date? = nil
    @State private var boardFirmwareVersion = "–"
    @State private var latestFirmwareVersion = "–"
    @State private var holdUpdateAvailableUntil: Date? = nil
    @State private var hasAppliedFirstUpdateAvailableDelay: Bool = false
    @State private var firmwareTimer: Timer? = nil
    @State private var showTipsView = false
    @State private var footerHeight: CGFloat = 0
    @State private var boardVersion: String? = UserDefaults.standard.string(forKey: "boardVersion")

    @Binding var presentedSheet: AboutSheet?
    @Binding var wifiSSID: String
    @Binding var wifiPassword: String
    @Binding var scanSessionID: Int

    var footerNSAttributed: NSAttributedString {
        let text = NSLocalizedString("© 2025, LTS Design, Heiligenbornstraße 23, 01219 Dresden, Deutschland, info@lts-design.com", comment: "about footer")
        let attr = NSMutableAttributedString(string: text)
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 0.86
        attr.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: attr.length))
        attr.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .footnote), range: NSRange(location: 0, length: attr.length))
        attr.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: NSRange(location: 0, length: attr.length))
        return attr
    }

    var body: some View {
        let isBLEConnected = bleManager.isConnected
        let isWiFiConnected = (isBLEConnected && (bleManager.status.wifiConnected ?? false))
        let (alertTitle, alertMessage): (String, String) = {
            if bleManager.status.otaSuccess == true {
                return (
                    NSLocalizedString("Update erfolgreich!", comment: "OTA result alert title"),
                    NSLocalizedString("Das OTA-Update war erfolgreich.", comment: "OTA result alert message")
                )
            } else {
                return (
                    NSLocalizedString("Update fehlgeschlagen!", comment: "OTA result alert title"),
                    NSLocalizedString("Das OTA-Update ist fehlgeschlagen. Stelle sicher, dass das verbundene WLAN über eine funktionierende Internetverbindung verfügt.", comment: "OTA result alert message")
                )
            }
        }()
        let isV3Board = (boardVersion?.contains("CtrBoard V3") ?? false)

        GeometryReader{ geo in
            ZStack {
                ( !layoutModel.isCompactWidth && colorScheme == .dark ? Color.clear : Color(UIColor.systemGroupedBackground) )
                    .ignoresSafeArea()
                VStack {
                    
                    Spacer()
                    VStack{
                        Image("AppIconSquare")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 170)
                            .shadow(color: Color.black.opacity(0.1), radius: 12)
                        
                        Text("LTS Control")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.top, 20)
                        
                        if let boardType = boardTypeLabel(for: boardVersion) {
                            Text(boardType)
                                .font(.subheadline)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(.bottom, 4)
                        }
                        
                        Text("App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")")
                            .font(.subheadline)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                        
                        if (bleManager.status.firmwareVersion ?? boardFirmwareVersion) != "–" {
                            Text("Board Version: \(bleManager.status.firmwareVersion ?? boardFirmwareVersion)")
                                .font(.subheadline)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        }
                    }

                    Spacer()

                    VStack(spacing: 0) {
                        if layoutModel.isCompactWidth {
                            HStack(spacing: 12) {
                                ZStack {
                                    Capsule()
                                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                                        .frame(height: 50)
                                        .shadow(color: Color.black.opacity(0.07), radius: 6)
                                    Button {
                                        presentedSheet = .instructions
                                    } label: {
                                        HStack {
                                            Image(systemName: "info.circle")
                                                .font(.system(size: 23.5))
                                                .frame(width: 28, height: 28)
                                                .foregroundStyle(.indigo)
                                            Text("Hinweise")
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.tertiary)
                                                .font(.system(size: 14))
                                                .fontWeight(.semibold)
                                        }
                                        .padding(.horizontal, 12)
                                        .frame(height: 30)
                                    }
                                    .buttonStyle(.borderless)
                                    .tint(.primary)
                                }
                                
                                ZStack {
                                    Capsule()
                                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                                        .frame(height: 50)
                                        .shadow(color: Color.black.opacity(0.07), radius: 6)
                                    Button {
                                        showTipsView = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "cup.and.heat.waves")
                                                .font(.system(size: 22))
                                                .frame(width: 28, height: 28)
                                                .foregroundStyle(.orange)
                                            Text("Trinkgeld")
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.tertiary)
                                                .font(.system(size: 14))
                                                .fontWeight(.semibold)
                                        }
                                        .padding(.horizontal, 12)
                                        .frame(height: 30)
                                    }
                                    .buttonStyle(.borderless)
                                    .tint(.primary)
                                }
                            }
                            .frame(height: 50)
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        } else {
                            HStack {
                                ZStack {
                                    Capsule()
                                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                                        .frame(height: 50)
                                        .shadow(color: Color.black.opacity(0.07), radius: 6)
                                    Button {
                                        presentedSheet = .instructions
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "info.circle")
                                                .font(.system(size: 23.5))
                                                .frame(width: 28, height: 28)
                                                .foregroundStyle(.indigo)
                                            Text("Hinweise")
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.tertiary)
                                                .font(.system(size: 14))
                                                .fontWeight(.semibold)
                                        }
                                        .padding(.horizontal, 12)
                                        .frame(height: 50)
                                    }
                                    .buttonStyle(.borderless)
                                    .tint(.primary)
                                }
                            }
                            .frame(height: 50)
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                            
                            HStack {
                                ZStack {
                                    Capsule()
                                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                                        .frame(height: 50)
                                        .shadow(color: Color.black.opacity(0.07), radius: 6)
                                    Button {
                                        presentedSheet = .connection
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "wifi")
                                                .font(.system(size: 22))
                                                .frame(width: 28, height: 28)
                                                .foregroundStyle(.blue)
                                            Text("Verbindungseinstellungen")
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.tertiary)
                                                .font(.system(size: 14))
                                                .fontWeight(.semibold)
                                        }
                                        .padding(.horizontal, 12)
                                        .frame(height: 50)
                                    }
                                    .buttonStyle(.borderless)
                                    .tint(.primary)
                                }
                            }
                            .frame(height: 50)
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                        
                        VStack(alignment: .leading) {
                            let effectiveBoardVersion = bleManager.status.firmwareVersion ?? boardFirmwareVersion
                            let v3Blocked = isV3Board && effectiveBoardVersion == "1.0.0"
                            let isUpdateAvailable = latestFirmwareVersion != "–"
                            && effectiveBoardVersion != "–"
                            && isNewerVersion(latestFirmwareVersion, than: effectiveBoardVersion)
                            let now = Date()
                            let isUpdateAvailableDisplayed = isUpdateAvailable && (holdUpdateAvailableUntil.map { now >= $0 } ?? true)
                            let delayActive = updateButtonDisabledUntil.map { Date() < $0 } ?? false
                            let isUpdateButtonEnabled = isUpdateAvailableDisplayed && isWiFiConnected && !delayActive
                            
                            VStack(alignment: .leading) {
                                Text("Board Update")
                                    .font(.headline)

                                Group {
                                    if v3Blocked {
                                        Text("Updates nicht unterstützt")
                                    } else if !bleManager.isConnected {
                                        Text("Board nicht verbunden")
                                    } else if bleManager.deviceState == .updating {
                                        Text("Firmware wird aktualisiert...")
                                    } else if bleManager.status.otaSuccess == true {
                                        Text("Firmware ist aktuell")
                                    } else if bleManager.status.otaSuccess == false {
                                        Text("Update fehlgeschlagen!")
                                    } else if isUpdateAvailableDisplayed {
                                        let from = bleManager.status.firmwareVersion ?? boardFirmwareVersion
                                        let to = latestFirmwareVersion
                                        Text("Update verfügbar (\(from) → \(to))")
                                    } else {
                                        Text("Firmware ist aktuell")
                                    }
                                }
                                .foregroundColor(.secondary)

                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 13)
                            
                            Button(action: {
                                if v3Blocked { return }
                                bleManager.triggerOTAUpdate()
                            }) {
                                if v3Blocked {
                                    Text("Nicht unterstützt")
                                        .frame(maxWidth: .infinity, maxHeight: 21)
                                } else if bleManager.deviceState == .updating {
                                    ProgressView()
                                        .controlSize(.regular)
                                        .tint(.secondary)
                                        .frame(maxWidth: .infinity, maxHeight: 21)
                                } else if isUpdateAvailableDisplayed && !isWiFiConnected && bleManager.isConnected {
                                    Text("Keine WLAN-Verbindung")
                                        .frame(maxWidth: .infinity, maxHeight: 21)
                                } else {
                                    Text("Firmware aktualisieren")
                                        .frame(maxWidth: .infinity, maxHeight: 21)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                            .buttonStyle(UpdateButtonStyle(enabledFill: .green))
                            .animation(.default, value: bleManager.deviceState == .updating)
                            .animation(isUpdateButtonEnabled ? .default : nil, value: isUpdateButtonEnabled)
                            .disabled(v3Blocked || !isUpdateButtonEnabled || bleManager.deviceState == .updating)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                .fill(Color(UIColor.secondarySystemGroupedBackground))
                        )
                        .frame(maxHeight: 135)
                        .overlay(alignment: .topTrailing) {
                            Button(action: {
                                let effectiveBoardVersion = bleManager.status.firmwareVersion ?? boardFirmwareVersion
                                let v3Blocked = isV3Board && effectiveBoardVersion == "1.0.0"
                                if v3Blocked {
                                    presentedSheet = .upgradeCode
                                } else {
                                    presentedSheet = .changelog
                                }
                            }) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 21))
                                    .tint(.primary)
                            }
                            .padding(.top, 13)
                            .padding(.trailing, 13)
                        }
                        .padding(.horizontal)
                        
                        GeometryReader { proxy in
                            AttributedTextView(
                                attributedString: footerNSAttributed,
                                availableWidth: proxy.size.width,
                                dynamicHeight: $footerHeight
                            )
                            .frame(width: proxy.size.width, height: footerHeight, alignment: .leading)
                        }
                        .frame(height: footerHeight)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                        .padding(.horizontal, layoutModel.isCompactWidth ? 32 : 20)
                    }
                    .ignoresSafeArea(.keyboard)
                    .sheet(isPresented: $showTipsView) { TipsView() }
                    .alert(alertTitle, isPresented: $bleManager.showOTAAlert) {
                        if bleManager.status.otaSuccess == true {
                            Button(NSLocalizedString("Änderungen anzeigen", comment: "Show changelog")) {
                                presentedSheet = .changelog
                                bleManager.clearOtaStatus()
                            }
                        }
                        Button(NSLocalizedString("OK", comment: "OK")) { bleManager.clearOtaStatus() }
                    } message: {
                        Text(alertMessage)
                    }
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .onAppear {
                    if let storedFW = UserDefaults.standard.string(forKey: "boardFirmwareVersion") {
                        boardFirmwareVersion = storedFW
                    }
                    if let storedBoard = UserDefaults.standard.string(forKey: "boardVersion") { boardVersion = storedBoard }
                    if let cachedLatest = UserDefaults.standard.string(forKey: "latestBoardFirmwareVersion"), !cachedLatest.isEmpty {
                        latestFirmwareVersion = cachedLatest
                    }
                    self.fetchLatestFirmwareVersion()
                    self.startFirmwareTimer()
                }
                .onDisappear {
                    self.invalidateFirmwareTimer()
                }
                .onChange(of: bleManager.status.firmwareVersion) { _, newValue in
                    guard let fw = newValue, !fw.isEmpty else { return }
                    boardFirmwareVersion = fw
                    UserDefaults.standard.set(fw, forKey: "boardFirmwareVersion")
                }
                .onChange(of: latestFirmwareVersion) { _, _ in
                    scheduleFirstUpdateAvailableDelayIfNeeded()
                }
                .onChange(of: boardFirmwareVersion) { _, _ in
                    scheduleFirstUpdateAvailableDelayIfNeeded()
                }
                .onChange(of: bleManager.isConnected) { _, newValue in
                    if newValue == true {
                        updateButtonDisabledUntil = Date().addingTimeInterval(1.5)
                    } else {
                        updateButtonDisabledUntil = nil
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                    boardVersion = UserDefaults.standard.string(forKey: "boardVersion")
                }
            }
        }
    }

    private func boardTypeLabel(for raw: String?) -> String? {
        guard let raw = raw else { return nil }
        if raw.contains("CtrBoard V3") { return "Control Board V3" }
        if raw.contains("CtrBoard V4") { return "Control Board V4" }
        if raw.localizedCaseInsensitiveContains("esp32 PCB") { return "ESP32 PCB" }
        return nil
    }

    private func isNewerVersion(_ latest: String, than current: String) -> Bool {
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(latestParts.count, currentParts.count)
        let paddedLatest = latestParts + Array(repeating: 0, count: maxCount - latestParts.count)
        let paddedCurrent = currentParts + Array(repeating: 0, count: maxCount - currentParts.count)

        return paddedLatest.lexicographicallyPrecedes(paddedCurrent) == false &&
               paddedLatest != paddedCurrent
    }

    private func fetchLatestFirmwareVersion() {

        var components = URLComponents(string: "https://download.lts-design.com/Firmware/latest_board_firmware.txt")
        let bucket = Int(Date().timeIntervalSince1970 / 15)
        let existingItems = components?.queryItems ?? []
        components?.queryItems = existingItems + [URLQueryItem(name: "t", value: String(bucket))]
        guard let url = components?.url else { return }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let data = data,
                  let versionString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !versionString.isEmpty else { return }
            DispatchQueue.main.async {
                self.latestFirmwareVersion = versionString
                UserDefaults.standard.set(versionString, forKey: "latestBoardFirmwareVersion")
            }
        }.resume()
    }

    private func scheduleFirstUpdateAvailableDelayIfNeeded() {
        if hasAppliedFirstUpdateAvailableDelay { return }
        let effectiveBoardVersion = bleManager.status.firmwareVersion ?? boardFirmwareVersion
        let isAvail = latestFirmwareVersion != "–"
            && effectiveBoardVersion != "–"
            && isNewerVersion(latestFirmwareVersion, than: effectiveBoardVersion)
        guard isAvail else { return }
        hasAppliedFirstUpdateAvailableDelay = true
        holdUpdateAvailableUntil = Date().addingTimeInterval(0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            if let until = self.holdUpdateAvailableUntil, Date() >= until {
                self.holdUpdateAvailableUntil = nil
            }
        }
    }

    private func startFirmwareTimer() {
        firmwareTimer?.invalidate()
        firmwareTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            self.fetchLatestFirmwareVersion()
        }
    }

    private func invalidateFirmwareTimer() {
        firmwareTimer?.invalidate()
        firmwareTimer = nil
    }
}

#if DEBUG
#Preview {
    struct PreviewHost: View {
        @State private var presentedSheet: AboutView.AboutSheet? = nil
        @State private var wifiSSID: String = ""
        @State private var wifiPassword: String = ""
        @State private var scanSessionID: Int = 0
        var body: some View {
            AboutView(
                presentedSheet: $presentedSheet,
                wifiSSID: $wifiSSID,
                wifiPassword: $wifiPassword,
                scanSessionID: $scanSessionID
            )
            .environment(\.locale, .init(identifier: "en"))
            .environment(LayoutModel())
        }
    }
    return PreviewHost()
}
#endif

struct AttributedTextView: UIViewRepresentable {
    let attributedString: NSAttributedString
    let availableWidth: CGFloat
    @Binding var dynamicHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.isUserInteractionEnabled = false
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedString
        let targetSize = CGSize(width: availableWidth, height: .greatestFiniteMagnitude)
        let height = uiView.sizeThatFits(targetSize).height
        DispatchQueue.main.async {
            self.dynamicHeight = height
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AttributedTextView
        init(_ parent: AttributedTextView) { self.parent = parent }
    }
}

