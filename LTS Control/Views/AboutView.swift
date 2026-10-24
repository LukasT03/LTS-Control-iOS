import SwiftUI

struct AboutView: View {
    enum AboutSheet: Hashable, Identifiable {
        case instructions
        case changelog
        case upgradeCode
        case connection
        var id: Self { self }
    }

    struct UpdateButtonStyle: ButtonStyle {
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.colorScheme) private var colorScheme

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(isEnabled ? Color.green.opacity(configuration.isPressed ? 0.15 : 0.2)
                                        : Color.gray.opacity(colorScheme == .dark ? 0.24 : 0.16))
                )
                .foregroundStyle(isEnabled ? Color.green.opacity(configuration.isPressed ? 0.75 : 1.0) : Color.gray.opacity(colorScheme == .dark ? 0.45 : 0.4))
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }

    @Environment(BLEManager.self) private var bleManager
    @Environment(LayoutModel.self) private var layoutModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @Binding var presentedSheet: AboutSheet?

    @State private var firmware = FirmwareUpdateModel()
    @State private var showTipsView = false
    @State private var didAppear = false
    /// Right after connecting the board hasn't reported Wi‑Fi and firmware yet, so the update button waits a moment.
    @State private var isSettlingAfterConnect = false

    private var status: DeviceStatus { bleManager.status }

    private var boardFirmware: String? {
        guard let fw = status.firmwareVersion, !fw.isEmpty else { return nil }
        return fw
    }

    private var isWiFiConnected: Bool { bleManager.isConnected && status.wifiConnected == true }
    private var isUpdateAvailable: Bool { firmware.isUpdateAvailable(for: boardFirmware) }
    private var isUpdating: Bool { bleManager.deviceState == .updating }
    private var isUpdateButtonEnabled: Bool { isUpdateAvailable && isWiFiConnected && !isSettlingAfterConnect }

    /// The V3 Control Board is stuck on firmware 1.0.0 and gets no more updates.
    private var isV3Blocked: Bool {
        (status.boardVersion?.contains("CtrBoard V3") ?? false) && boardFirmware == "1.0.0"
    }

    private var updateStatusText: LocalizedStringKey {
        if isV3Blocked { return "Updates nicht unterstützt" }
        if !bleManager.isConnected { return "Board nicht verbunden" }
        if isUpdating { return "Firmware wird aktualisiert..." }
        if status.otaSuccess == true { return "Firmware ist aktuell" }
        if status.otaSuccess == false { return "Update fehlgeschlagen!" }
        if isUpdateAvailable, let from = boardFirmware, let to = firmware.latestVersion {
            return "Update verfügbar (\(from) → \(to))"
        }
        return "Firmware ist aktuell"
    }

    private var boardTypeLabel: String? {
        guard let raw = status.boardVersion else { return nil }
        let isPro = status.boardVariant == .pro
        if raw.contains("CtrBoard V3") { return "Control Board V3" }
        if raw.contains("CtrBoard V4") || raw.contains("LTS CB") { return isPro ? "Control Board (Pro)" : "Control Board" }
        if raw.contains("LTS DB") { return isPro ? "Driver Board (Pro)" : "Driver Board" }
        if raw.localizedCaseInsensitiveContains("esp32 PCB") { return "Driver Board" }
        return nil
    }

    var body: some View {
        @Bindable var bleManager = bleManager

        ZStack {
            (!layoutModel.isCompactWidth && colorScheme == .dark ? Color.clear : Color(UIColor.systemGroupedBackground))
                .ignoresSafeArea()
            VStack {
                Spacer()
                header
                Spacer()

                VStack(spacing: 0) {
                    if layoutModel.isCompactWidth {
                        HStack(spacing: 12) {
                            capsuleButton("Hinweise", icon: "info.circle", iconSize: 23.5, color: .indigo) { presentedSheet = .instructions }
                            capsuleButton("Trinkgeld", icon: "cup.and.heat.waves", iconSize: 22, color: .orange) { showTipsView = true }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    } else {
                        capsuleButton("Hinweise", icon: "info.circle", iconSize: 23.5, color: .indigo) { presentedSheet = .instructions }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        capsuleButton("Verbindungseinstellungen", icon: "wifi", iconSize: 22, color: .blue) { presentedSheet = .connection }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                    }

                    updateCard
                        .padding(.horizontal)
                        .padding(.bottom)
                }
                .ignoresSafeArea(.keyboard)
                .sheet(isPresented: $showTipsView) { TipsView() }
                .alert(status.otaSuccess == true ? LocalizedStringKey("Update erfolgreich!") : "Update fehlgeschlagen!", isPresented: $bleManager.showOTAAlert) {
                    if status.otaSuccess == true {
                        Button("Änderungen anzeigen") {
                            presentedSheet = .changelog
                            bleManager.clearOtaStatus()
                        }
                    }
                    Button("OK") { bleManager.clearOtaStatus() }
                } message: {
                    if status.otaSuccess == true {
                        Text("Das OTA-Update war erfolgreich.")
                    } else {
                        Text("Das OTA-Update ist fehlgeschlagen. Stelle sicher, dass das verbundene WLAN über eine funktionierende Internetverbindung verfügt.")
                    }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onAppear { didAppear = true }
        // Checks for new firmware on appear, on every (dis)connect and when the app returns to the foreground.
        .task(id: bleManager.isConnected) { await firmware.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await firmware.refresh() } }
        }
        .onChange(of: bleManager.isConnected) { _, isConnected in
            isSettlingAfterConnect = isConnected
        }
        .task(id: isSettlingAfterConnect) {
            guard isSettlingAfterConnect else { return }
            try? await Task.sleep(for: .seconds(1.5))
            isSettlingAfterConnect = false
        }
    }

    private var header: some View {
        VStack {
            Image("AppIconSquare")
                .resizable()
                .scaledToFit()
                .frame(width: 170)
                .shadow(color: Color.black.opacity(0.1), radius: 12)

            Text("LTS Control")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 20)

            if let boardTypeLabel {
                Text(boardTypeLabel)
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .padding(.bottom, 4)
            }

            Text("App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")")
                .font(.subheadline)
                .foregroundColor(Color(UIColor.secondaryLabel))

            if let boardFirmware {
                Text("Board Version: \(boardFirmware)")
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
        }
    }

    private var updateCard: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                Text("Board Update")
                    .font(.headline)
                Text(updateStatusText)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 13)

            Button {
                if !isV3Blocked { bleManager.triggerOTAUpdate() }
            } label: {
                Group {
                    if isV3Blocked {
                        Text("Nicht unterstützt")
                    } else if isUpdating {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(.secondary)
                    } else if isUpdateAvailable && !isWiFiConnected && bleManager.isConnected {
                        Text("Keine WLAN-Verbindung")
                    } else {
                        Text("Firmware aktualisieren")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 21)
            }
            .padding(.horizontal)
            .padding(.bottom)
            .buttonStyle(UpdateButtonStyle())
            .animation(.default, value: isUpdating)
            .animation(didAppear && isUpdateButtonEnabled ? .default : nil, value: isUpdateButtonEnabled)
            .disabled(isV3Blocked || !isUpdateButtonEnabled || isUpdating)
        }
        .background(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .frame(maxHeight: 135)
        .overlay(alignment: .topTrailing) {
            Button {
                presentedSheet = isV3Blocked ? .upgradeCode : .changelog
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 21))
                    .tint(.primary)
            }
            .padding(.top, 13)
            .padding(.trailing, 13)
        }
    }

    private func capsuleButton(_ title: LocalizedStringKey, icon: String, iconSize: CGFloat, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(color)
                Text(title)
                Spacer()
                DisclosureChevron()
            }
            .padding(.horizontal, 12)
            .frame(height: 50)
        }
        .buttonStyle(.borderless)
        .tint(.primary)
        .background(
            Capsule()
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.07), radius: 6)
        )
    }
}

#if DEBUG
#Preview {
    AboutView(presentedSheet: .constant(nil))
        .environment(\.locale, .init(identifier: "en"))
        .environment(BLEManager.shared)
        .environment(LayoutModel())
}
#endif
