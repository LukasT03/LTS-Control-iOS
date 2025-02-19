import SwiftUI

@main
struct LTSControlApp: App {
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup: Bool = false
    @State private var showSplashView: Bool = false
    @State private var hasCheckedSetup: Bool = false // Stellt sicher, dass nur beim Start geprüft wird

    var body: some Scene {
        WindowGroup {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad-Layout mit permanenter Sidebar
                HStack(spacing: 0) {

                    NavigationStack {
                        ContentView(showSplashView: $showSplashView)
                            .onAppear {
                                if !hasCheckedSetup { // Prüft nur beim ersten Mal nach dem App-Start
                                    let hasStoredAccessory = UserDefaults.standard.string(forKey: "storedAccessoryIdentifier") != nil
                                    if !hasCompletedSetup && !hasStoredAccessory {
                                        showSplashView = true
                                    }
                                    hasCheckedSetup = true // Verhindert erneute Prüfung
                                }
                            }
                            .sheet(isPresented: $showSplashView) {
                                SplashView()
                            }
                    }
                    .padding(.horizontal, 60)
                    .background(Color(UIColor.systemGroupedBackground))
                    
                    Divider() // Trennlinie
                    
                    // SettingsView mit NavigationStack und Titel
                    NavigationStack {
                        SettingsView()
                            .navigationTitle("Einstellungen")
                    }
                    .frame(width: 394) // Feste Breite der Sidebar
                    .background(Color(UIColor.systemGroupedBackground))

                }
                .ignoresSafeArea()
            } else {
                // iPhone-Layout mit NavigationStack
                NavigationStack {
                    ContentView(showSplashView: $showSplashView)
                        .onAppear {
                            if !hasCheckedSetup { // Prüft nur beim ersten Mal nach dem App-Start
                                let hasStoredAccessory = UserDefaults.standard.string(forKey: "storedAccessoryIdentifier") != nil
                                if !hasCompletedSetup && !hasStoredAccessory {
                                    showSplashView = true
                                }
                                hasCheckedSetup = true // Verhindert erneute Prüfung
                            }
                        }
                        .sheet(isPresented: $showSplashView) {
                            SplashView()
                        }
                }
            }
        }
    }
}
