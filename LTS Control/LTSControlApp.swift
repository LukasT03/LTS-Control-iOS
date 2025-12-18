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

extension LTSControlApp {
    var body: some Scene {
        WindowGroup {
            mainLayout
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
                        BoardVariantSelectionView()
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button {
                                        showBoardVariantSheet = false
                                    } label: {
                                        if #available(iOS 26, *) {
                                            Image(systemName: "xmark")
                                        } else {
                                            Text("Schließen")
                                        }
                                    }
                                }
                            }
                    }
                    .environment(bleManager)
                }
                .onAppear {
                    if bleManager.needsBoardVariantSelection && !showSplashView {
                        showBoardVariantSheet = true
                    }
                }
                .onChange(of: bleManager.isConnected) { _, isConnected in
                    if !isConnected {
                        showBoardVariantSheet = false
                        return
                    }
                    if bleManager.needsBoardVariantSelection && !showSplashView {
                        showBoardVariantSheet = true
                    }
                }
                .onChange(of: bleManager.needsBoardVariantSelection) { _, needs in
                    if needs && !showSplashView {
                        showBoardVariantSheet = true
                    } else if !needs {
                        showBoardVariantSheet = false
                    }
                }
                .onChange(of: showSplashView) { _, isShowing in
                    if isShowing {
                        showBoardVariantSheet = false
                    } else if bleManager.needsBoardVariantSelection {
                        showBoardVariantSheet = true
                    }
                }
        }
        .windowResizability(.contentSize)
    }
}

@main
struct LTSControlApp: App {
    init() {
        _ = LiveActivityManager.shared
    }
    private let bleManager = BLEManager.shared
    private let sessionManager = AccessorySessionManager.shared
    @State private var layoutModel = LayoutModel()
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup: Bool = false
    @State private var showSplashView: Bool = false
    @State private var hasCheckedSetup: Bool = false
    @State private var sharedCurrentState: LocalizedStringKey = "Nicht verbunden"
    @State private var filamentDetected: Bool = false
    @State private var scanSessionID: Int = 0
    @State private var wifiSSID: String = ""
    @State private var wifiPassword: String = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var showOverlay: Bool = false
    @State private var showTipsView = false
    @State private var showBoardVariantSheet = false
    @State private var presentedSheet: AboutView.AboutSheet? = nil

    private var boardVersion: String? {
        UserDefaults.standard.string(forKey: "boardVersion")
    }

    @ViewBuilder
    private var mainLayout: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    layoutModel.isCompactWidth = geo.size.width < 729
                }
                .onChange(of: geo.size.width) { oldValue, newValue in
                    layoutModel.isCompactWidth = newValue < 729
                }

            if UIDevice.current.userInterfaceIdiom == .pad && !layoutModel.isCompactWidth {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    VStack{
                        AboutView(
                            presentedSheet: $presentedSheet,
                            wifiSSID: $wifiSSID,
                            wifiPassword: $wifiPassword,
                            scanSessionID: $scanSessionID
                        )
                    }
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationBarTitle("LTS Control", displayMode: .inline)
                    .toolbar {
                        if #available(iOS 26, *) {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button {
                                        showTipsView = true

                                    } label: {
                                        Label("Trinkgeld senden", systemImage: "cup.and.heat.waves")
                                    }
                                }
                            } else {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button {
                                        showTipsView = true
                                    } label: {
                                        Label("Trinkgeld senden", systemImage: "cup.and.heat.waves")
                                    }
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
                        let isInitialized = geo.size.width > 1
                        let tooNarrow = isInitialized && geo.size.width < 383

                        ZStack {
                            ContentView(
                                showSplashView: $showSplashView,
                            )
                            Color(.systemGroupedBackground)
                                .ignoresSafeArea()
                                .opacity(showOverlay ? 1 : 0)
                                .zIndex(1)
                                .allowsHitTesting(showOverlay)
                        }
                        .animation(.easeInOut(duration: 0.1), value: showOverlay)
                        .onChange(of: tooNarrow) { oldValue, newValue in
                            if newValue {
                                if #unavailable(iOS 26) {
                                    showOverlay = true
                                }
                            } else {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    showOverlay = false
                                }
                            }
                        }
                        .onAppear {
                            if #available(iOS 26, *) {
                                showOverlay = false
                            } else {
                                showOverlay = geo.size.width < 383
                            }
                        }
                        .onChange(of: geo.size.width) { _, newWidth in
                            if #available(iOS 26, *) {
                                showOverlay = false
                            } else {
                                let shouldShow = newWidth < 383
                                if showOverlay != shouldShow {
                                    showOverlay = shouldShow
                                }
                            }
                        }
                    }
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .navigationSplitViewColumnWidth(min: 352, ideal: 450, max: 1000)
                }
                .navigationSplitViewStyle(.balanced)
                .sheet(item: $presentedSheet) { sheet in
                    switch sheet {
                    case .instructions:
                        InstructionsView()
                    case .changelog:
                        NavigationStack { FirmwareChangelogView() }
                    case .upgradeCode:
                        NavigationStack { UpgradeCodeView() }
                    case .connection:
                        NavigationView {
                            ConnectionView(
                                wifiSSID: $wifiSSID,
                                wifiPassword: $wifiPassword,
                                scanSessionID: $scanSessionID
                            )
                        }
                    }
                }
                .sheet(isPresented: $showTipsView) { TipsView() }
            } else {
                defaultTabView
            }
        }
    }

    private var defaultTabView: some View {
        TabView {
            NavigationStack {
                ContentView(
                    showSplashView: $showSplashView,
                )
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
                AboutView(
                    presentedSheet: $presentedSheet,
                    wifiSSID: $wifiSSID,
                    wifiPassword: $wifiPassword,
                    scanSessionID: $scanSessionID
                )
            }
            .tabItem {
                Label("Mehr", systemImage: "ellipsis.circle")
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .instructions:
                InstructionsView()
            case .changelog:
                NavigationStack { FirmwareChangelogView() }
            case .upgradeCode:
                NavigationStack { UpgradeCodeView() }
            case .connection:
                NavigationView {
                    ConnectionView(
                        wifiSSID: $wifiSSID,
                        wifiPassword: $wifiPassword,
                        scanSessionID: $scanSessionID
                    )
                }
            }
        }
    }

    private func checkInitialSetup() {
        if !hasCheckedSetup {
            let hasStoredAccessory = UserDefaults.standard.string(forKey: "storedAccessoryIdentifier") != nil
            if (!hasCompletedSetup && !hasStoredAccessory) {
                showSplashView = true
            }
        }

        if hasCompletedSetup && UserDefaults.standard.object(forKey: "setupCompletedAt") == nil {
            UserDefaults.standard.set(Date(), forKey: "setupCompletedAt")
        }

        if !hasCheckedSetup {
            hasCheckedSetup = true
        }
    }
}
