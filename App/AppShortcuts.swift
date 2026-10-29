import AppIntents

/// Puts Tapdeck's tools in Spotlight and the Shortcuts app with no setup. From
/// Shortcuts, any of them can get its own keyboard shortcut.
struct TapdeckShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LightsOutIntent(),
            phrases: [
                "Lights out with \(.applicationName)",
                "Turn off the screen with \(.applicationName)",
            ],
            shortTitle: "Lights Out",
            systemImageName: "lightbulb.slash"
        )
        AppShortcut(
            intent: ToggleStayAwakeIntent(),
            phrases: [
                "Toggle Stay Awake with \(.applicationName)",
                "Keep my Mac awake with \(.applicationName)",
            ],
            shortTitle: "Toggle Stay Awake",
            systemImageName: "sun.max"
        )
        AppShortcut(
            intent: ToggleMicMuteIntent(),
            phrases: [
                "Toggle Mic Mute with \(.applicationName)",
                "Mute my microphone with \(.applicationName)",
            ],
            shortTitle: "Toggle Mic Mute",
            systemImageName: "mic.slash"
        )
    }
}
