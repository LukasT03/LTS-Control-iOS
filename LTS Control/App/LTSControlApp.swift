import SwiftUI
import Observation
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

@Observable
class LayoutModel {
    var isCompactWidth: Bool = false
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

    @State private var layoutModel = LayoutModel()
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup: Bool = false
    @State private var showSplashView: Bool = false
    @State private var hasCheckedSetup: Bool = false
    @State private var scanSessionID: Int = 0
    @State private var wifiSSID: String = ""
    @State private var wifiPassword: String = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var showTipsView = false
    @State private var showBoardVariantSheet = false
    @State private var presentedSheet: AboutView.AboutSheet? = nil

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
            .environment(layoutModel)
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
        case .upgradeCode:
            NavigationStack { UpgradeCodeView() }
        case .connection:
            NavigationStack {
                ConnectionView(wifiSSID: $wifiSSID, wifiPassword: $wifiPassword, scanSessionID: $scanSessionID)
            }
        }
    }

    @ViewBuilder
    private var mainLayout: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    layoutModel.isCompactWidth = geo.size.width < 729
                }
                .onChange(of: geo.size.width) { _, newValue in
                    layoutModel.isCompactWidth = newValue < 729
                }

            if UIDevice.current.userInterfaceIdiom == .pad && !layoutModel.isCompactWidth {
                splitView
            } else {
                defaultTabView
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
                        showTipsView = true
                    } label: {
                        Label("Trinkgeld senden", systemImage: "cup.and.heat.waves")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 350, ideal: 350, max: 350)
        } content: {
            SettingsView()
                .listStyle(.insetGrouped)
                .navigationTitle("Einstellungen")
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
            .navigationSplitViewColumnWidth(min: 352, ideal: 450, max: 1000)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showTipsView) { TipsView() }
    }

    private var defaultTabView: some View {
        TabView {
            NavigationStack {
                ContentView(showSplashView: $showSplashView)
                    .navigationTitle("LTS Respooler")
            }
            .tabItem {
                Label("Steuerung", systemImage: "house")
            }

            NavigationStack {
                SettingsView()
                    .navigationTitle("Einstellungen")
            }
            .tabItem {
                Label("Einstellungen", systemImage: "gearshape")
            }

            NavigationStack {
                ConnectionView(wifiSSID: $wifiSSID, wifiPassword: $wifiPassword, scanSessionID: $scanSessionID)
                    .navigationTitle("Verbindung")
            }
            .tabItem {
                Label("Verbindung", systemImage: "wifi")
            }

            NavigationStack {
                AboutView(presentedSheet: $presentedSheet)
            }
            .tabItem {
                Label("Mehr", systemImage: "ellipsis.circle")
            }
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
