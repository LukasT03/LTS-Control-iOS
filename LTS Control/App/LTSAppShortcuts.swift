import AppIntents

struct LTSAppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartMotorIntent(),
            phrases: [
                "Starte den Respooler in ${applicationName}",
                "Respooler starten in ${applicationName}",
                "Spulvorgang starten in ${applicationName}",
            ],
            shortTitle: "Respooler starten",
            systemImageName: "play.circle.fill"
        )
        
        AppShortcut(
            intent: StopMotorIntent(),
            phrases: [
                "Stoppe den Respooler in ${applicationName}",
                "Respooler stoppen in ${applicationName}",
                "Spulvorgang stoppen in ${applicationName}",
                "Respooler anhalten in ${applicationName}"
            ],
            shortTitle: "Respooler stoppen",
            systemImageName: "xmark.circle.fill"
        )
        
        AppShortcut(
            intent: PauseMotorIntent(),
            phrases: [
                "Pausiere den Respooler in ${applicationName}",
                "Respooler pausieren in ${applicationName}",
                "Spulvorgang pausieren in ${applicationName}"
            ],
            shortTitle: "Respooler pausieren",
            systemImageName: "pause.circle.fill"
        )
    }
}
