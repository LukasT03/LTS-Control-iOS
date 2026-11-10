import StoreKit
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
        finishTransactionUpdates()
    }

    /// Tips can complete outside the tips sheet (e.g. Ask to Buy) or stay unfinished after a crash.
    /// StoreKit delivers those here from launch on; they are consumables, so they're just finished.
    private func finishTransactionUpdates() {
        Task {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
            }
        }
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
    @State private var wifiForm = WiFiForm()
    /// Starts with the sidebar open: pushing in the settings column would otherwise show it on its own after launch.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedTab: AppTab = .control
    @State private var settingsPath: [SettingsView.Page] = []
    @State private var showBoardVariantSheet = false
    /// Presented from the root, so it stays open when the layout switches.
    @State private var presentedSheet: AboutView.AboutSheet? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private enum AppTab { case control, settings, connection, more }

    var body: some View {
        mainLayout
            .sheet(item: $presentedSheet) { sheet in
                sheetContent(sheet)
            }
            .environment(bleManager)
            .environment(sessionManager)
            .environment(wifiForm)
            .environment(\.isSplitLayout, horizontalSizeClass == .regular)
            .onAppear(perform: checkInitialSetup)
            .sheet(isPresented: $showSplashView) {
                SplashView()
                    .environment(bleManager)
                    .environment(sessionManager)
                    .environment(\.isSplitLayout, horizontalSizeClass == .regular)
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
                .presentationBackground(.background)
        case .tips:
            TipsView()
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
        // While the window turns compact (e.g. folding iPhone Duo), the split view collapses to the detail column
        // before the tab view replaces it. Keeping that would bring it back with only the control view.
        .onChange(of: columnVisibility) { oldValue, newValue in
            if horizontalSizeClass != .regular && newValue == .detailOnly {
                columnVisibility = oldValue
            }
        }
    }

    /// Carries the current page over when the layout switches: Verbindung is a tab in compact width
    /// and a settings page in regular width, Mehr is a tab in compact width and the sidebar in regular width.
    /// The sheets are opened from Mehr, so it stays behind them; an open settings page keeps Einstellungen in front.
    /// A settings page left behind in its tab doesn't come along into the settings column.
    private func adaptToLayout() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if horizontalSizeClass == .regular {
                if selectedTab == .connection {
                    settingsPath = [.connection]
                } else if selectedTab != .settings {
                    settingsPath = []
                }
                columnVisibility = selectedTab == .more ? .all : .doubleColumn
            } else {
                // Compact width has no link to the connection page, so it moves to its tab.
                let showsConnection = settingsPath.first == .connection
                if showsConnection { settingsPath = [] }

                if presentedSheet != nil {
                    selectedTab = .more
                } else if showsConnection {
                    selectedTab = .connection
                } else if !settingsPath.isEmpty {
                    selectedTab = .settings
                } else if selectedTab == .connection || (selectedTab == .more && columnVisibility != .all) {
                    selectedTab = .control
                }
            }
        }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack {
                AboutView(presentedSheet: $presentedSheet)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The card sits as far from the bottom edge as from the sides, past the home indicator inset.
            // Ignored here at the column's root together with the keyboard: while the keyboard is up the inset
            // counts as both, and anything less lets the sidebar's content move up.
            .ignoresSafeArea(edges: .bottom)
            .navigationBarTitle("LTS Respooler", displayMode: .inline)
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
                Label("Einstellungen", systemImage: "slider.horizontal.3")
            }
            .tag(AppTab.settings)

            NavigationStack {
                ConnectionView()
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
