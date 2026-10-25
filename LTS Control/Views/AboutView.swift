import SwiftUI

struct AboutView: View {
    enum AboutSheet: Hashable, Identifiable {
        case instructions
        case changelog
        case connection
        case tips
        var id: Self { self }
    }

    @Environment(BLEManager.self) private var bleManager
    @Environment(\.isSplitLayout) private var isSplitLayout
    @Environment(\.scenePhase) private var scenePhase

    @Binding var presentedSheet: AboutSheet?

    @State private var firmware = FirmwareUpdateModel()
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
            // The sidebar keeps the system's own background.
            if !isSplitLayout {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
            }
            VStack {
                Spacer()
                header
                Spacer()

                VStack(spacing: 0) {
                    if !isSplitLayout {
                        HStack(spacing: 12) {
                            capsuleButton("Hinweise", icon: "info.circle", iconSize: 23.5, color: .indigo) { presentedSheet = .instructions }
                            capsuleButton("Trinkgeld", icon: "cup.and.heat.waves", iconSize: 22, color: .orange) { presentedSheet = .tips }
                        }
                        .horizontalPadding()
                        .padding(.bottom, 20)
                    } else {
                        capsuleButton("Hinweise", icon: "info.circle", iconSize: 23.5, color: .indigo) { presentedSheet = .instructions }
                            .horizontalPadding()
                            .padding(.bottom, 20)
                        capsuleButton("Verbindungseinstellungen", icon: "wifi", iconSize: 22, color: .blue) { presentedSheet = .connection }
                            .horizontalPadding()
                            .padding(.bottom, 20)
                    }

                    updateCard
                        .horizontalPadding(includesBottom: isSplitLayout)
                        .padding(.bottom, isSplitLayout ? 0 : nil)
                }
                .ignoresSafeArea(.keyboard)
                // In the sidebar the card sits as far from the bottom edge as from the sides, past the home indicator inset.
                .ignoresSafeArea(.container, edges: isSplitLayout ? .bottom : [])
                // With the card's own 16 pt that's 20 pt, the side margin on iPhone Duo.
                // Not in the sidebar, which has no bar edge of its own; it only flickers there while a sheet opens.
                .replacingHomeIndicatorInset(with: 4, isEnabled: !isSplitLayout)
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
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.bottom)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.green)
            .animation(.default, value: isUpdating)
            .animation(didAppear && isUpdateButtonEnabled ? .default : nil, value: isUpdateButtonEnabled)
            .disabled(isV3Blocked || !isUpdateButtonEnabled || isUpdating)
        }
        .modifier(CardBackground())
        .frame(maxHeight: 135)
        .overlay(alignment: .topTrailing) {
            Button {
                presentedSheet = .changelog
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 23))
                    // Same box as the former 21 pt circle icon, so the larger icon keeps its center.
                    .frame(width: 21, height: 21)
            }
            .padding(.top, 14)
            .padding(.trailing, 14)
        }
    }

    @ViewBuilder
    private func capsuleButton(_ title: LocalizedStringKey, icon: String, iconSize: CGFloat, color: Color, action: @escaping () -> Void) -> some View {
        let button = Button(action: action) {
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

        if #available(iOS 26, *) {
            button.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            button.background(
                Capsule()
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.07), radius: 6)
            )
        }
    }
}

/// In the sidebar on iOS 26 the card is Liquid Glass, so it works on the sidebar's background.
private struct CardBackground: ViewModifier {
    @Environment(\.isSplitLayout) private var isSplitLayout

    func body(content: Content) -> some View {
        if #available(iOS 26, *), isSplitLayout {
            // The bottom leading corner follows the display corner it sits in.
            content.glassEffect(.regular, in: .rect(
                topLeadingCorner: .fixed(25),
                topTrailingCorner: .fixed(25),
                bottomLeadingCorner: .concentric(minimum: .fixed(20)),
                bottomTrailingCorner: .fixed(25)
            ))
        } else {
            content.background(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
    }
}

#if DEBUG
#Preview {
    AboutView(presentedSheet: .constant(nil))
        .environment(\.locale, .init(identifier: "en"))
        .environment(BLEManager.shared)
}
#endif
