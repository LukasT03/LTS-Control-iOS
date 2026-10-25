import SwiftUI
import UIKit

extension Color {
    static var ltsBlue: Color {
        Color(UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 20/255, green: 90/255, blue: 170/255, alpha: 1)
            } else {
                return UIColor(red: 12/255, green: 76/255, blue: 152/255, alpha: 1)
            }
        })
    }
}

extension EnvironmentValues {
    /// Whether the window shows the iPad split view (regular width) instead of the tab bar.
    /// Read once at the root, since split view columns and sheets report their own size class.
    @Entry var isSplitLayout = false
}

@main
struct LTSControlApp: App {
    private let bleManager = BLEManager.shared
    private let sessionManager = AccessorySessionManager.shared

    init() {
        _ = LiveActivityManager.shared
        _ = LocalNotificationManager.shared // sets itself as notification delegate, must exist before launch finishes
    }

    var body: some Scene {
        WindowGroup {
            MainRootView(bleManager: bleManager, sessionManager: sessionManager)
        }
        .windowResizability(.contentSize)
    }
}

private struct MainRootView: View {
    let bleManager: BLEManager
    let sessionManager: AccessorySessionManager

    @AppStorage("hasCompletedSetup") private var hasCompletedSetup: Bool = false
    @State private var showSplashView: Bool = false
    @State private var hasCheckedSetup: Bool = false
    @State private var scanSessionID: Int = 0
    @State private var wifiSSID: String = ""
    @State private var wifiPassword: String = ""
    /// Starts with the sidebar open: pushing in the settings column would otherwise show it on its own after launch.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedTab: AppTab = .control
    @State private var settingsPath: [SettingsView.Page] = []
    @State private var showBoardVariantSheet = false
    /// Presented from the root, so it stays open when the layout switches.
    @State private var presentedSheet: AboutView.AboutSheet? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private enum AppTab { case control, settings, connection, more }

    private var tipsButtonPlacement: ToolbarItemPlacement {
        if #available(iOS 26, *) { .topBarLeading } else { .topBarTrailing }
    }

    var body: some View {
        mainLayout
            .sheet(item: $presentedSheet) { sheet in
                sheetContent(sheet)
            }
            .environment(bleManager)
            .environment(sessionManager)
            .environment(\.isSplitLayout, horizontalSizeClass == .regular)
            .onAppear(perform: checkInitialSetup)
            .sheet(isPresented: $showSplashView) {
                SplashView()
                    .environment(bleManager)
                    .environment(sessionManager)
            }
            .sheet(isPresented: $showBoardVariantSheet) {
                NavigationStack {
                    BoardVariantView(isInitialSelection: true)
                        .toolbar { SheetCloseButton() }
                }
                .environment(bleManager)
            }
            .onAppear(perform: updateBoardVariantSheet)
            .onChange(of: bleManager.isConnected) { updateBoardVariantSheet() }
            .onChange(of: bleManager.needsBoardVariantSelection) { updateBoardVariantSheet() }
            .onChange(of: showSplashView) { updateBoardVariantSheet() }
    }

    /// Asks for the board variant once a connected board reports none, but never on top of the splash screen.
    private func updateBoardVariantSheet() {
        showBoardVariantSheet = bleManager.isConnected && bleManager.needsBoardVariantSelection && !showSplashView
    }

    @ViewBuilder
    private func sheetContent(_ sheet: AboutView.AboutSheet) -> some View {
        switch sheet {
        case .instructions:
            InstructionsView()
        case .changelog:
            NavigationStack { FirmwareChangelogView() }
        case .tips:
            TipsView()
        case .connection:
            NavigationStack {
                ConnectionView(wifiSSID: $wifiSSID, wifiPassword: $wifiPassword, scanSessionID: $scanSessionID)
            }
        }
    }

    @ViewBuilder
    private var mainLayout: some View {
        Group {
            if horizontalSizeClass == .regular {
                splitView
            } else {
                defaultTabView
            }
        }
        .onChange(of: horizontalSizeClass) { adaptToLayout() }
    }

    /// Carries the current page over when the layout switches: Verbindung is a tab in compact width
    /// and a sheet in regular width, Mehr is a tab in compact width and the sidebar in regular width.
    /// The other sheets are opened from Mehr, so it stays behind them; an open settings page keeps Einstellungen in front.
    private func adaptToLayout() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if horizontalSizeClass == .regular {
                if selectedTab == .connection { presentedSheet = .connection }
                columnVisibility = selectedTab == .more ? .all : .doubleColumn
            } else if presentedSheet == .connection {
                presentedSheet = nil
                selectedTab = .connection
            } else if presentedSheet != nil {
                selectedTab = .more
            } else if !settingsPath.isEmpty {
                selectedTab = .settings
            } else if selectedTab == .connection || (selectedTab == .more && columnVisibility != .all) {
                selectedTab = .control
            }
        }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack {
                AboutView(presentedSheet: $presentedSheet)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarTitle("LTS Control", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: tipsButtonPlacement) {
                    Button {
                        presentedSheet = .tips
                    } label: {
                        Label("Trinkgeld senden", systemImage: "cup.and.heat.waves")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 350, ideal: 350, max: 350)
        } content: {
            // Its own stack, so detail rows push inside this column instead of replacing the controls.
            NavigationStack(path: $settingsPath) {
                SettingsView()
                    .listStyle(.insetGrouped)
                    .navigationTitle("Einstellungen")
            }
            .navigationSplitViewColumnWidth(min: 360, ideal: 360, max: 1000)
        } detail: {
            GeometryReader { geo in
                // Before iOS 26 the control view breaks below 383 pt while the split view resizes, so it's covered.
                let showOverlay: Bool = {
                    if #available(iOS 26, *) { false } else { geo.size.width < 383 }
                }()
                ZStack {
                    ContentView(showSplashView: $showSplashView)
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                        .opacity(showOverlay ? 1 : 0)
                        .zIndex(1)
                        .allowsHitTesting(showOverlay)
                }
                .animation(.easeInOut(duration: 0.1), value: showOverlay)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationSplitViewColumnWidth(min: 364, ideal: 450, max: 1000)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var defaultTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ContentView(showSplashView: $showSplashView)
                    .navigationTitle("LTS Respooler")
            }
            .tabItem {
                Label("Steuerung", systemImage: "house")
            }
            .tag(AppTab.control)

            NavigationStack(path: $settingsPath) {
                SettingsView()
                    .navigationTitle("Einstellungen")
            }
            .tabItem {
                Label("Einstellungen", systemImage: "gearshape")
            }
            .tag(AppTab.settings)

            NavigationStack {
                ConnectionView(wifiSSID: $wifiSSID, wifiPassword: $wifiPassword, scanSessionID: $scanSessionID)
                    .navigationTitle("Verbindung")
            }
            .tabItem {
                Label("Verbindung", systemImage: "wifi")
            }
            .tag(AppTab.connection)

            NavigationStack {
                AboutView(presentedSheet: $presentedSheet)
            }
            .tabItem {
                Label("Mehr", systemImage: "ellipsis.circle")
            }
            .tag(AppTab.more)
        }
    }

    private func checkInitialSetup() {
        guard !hasCheckedSetup else { return }
        hasCheckedSetup = true
        let hasStoredAccessory = UserDefaults.standard.string(forKey: "storedAccessoryIdentifier") != nil
        if !hasCompletedSetup && !hasStoredAccessory {
            showSplashView = true
        }
        if hasCompletedSetup && UserDefaults.standard.object(forKey: "setupCompletedAt") == nil {
            UserDefaults.standard.set(Date(), forKey: "setupCompletedAt")
        }
    }
}

#if DEBUG
#Preview("Main Root") {
    MainRootView(bleManager: .shared, sessionManager: .shared)
        .environment(\.locale, .init(identifier: "en"))
}
#endif
