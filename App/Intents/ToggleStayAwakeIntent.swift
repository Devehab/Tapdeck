import AppIntents

/// A one-step switch for Spotlight and keyboard shortcuts. The Control Center
/// toggle uses `StayAwakeIntent`, which is told the new value instead.
struct ToggleStayAwakeIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Stay Awake"

    static var description: IntentDescription {
        IntentDescription("Switches Stay Awake on or off. While it's on, the Mac keeps running even with the lid closed.")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let enable = !SystemSleep.isDisabled
        try await (enable ? TapdeckAction.stayAwakeOn : .stayAwakeOff).run()
        let isOn = SystemSleep.isDisabled
        return .result(dialog: isOn
            ? "Stay Awake is on. Your Mac won't sleep, even with the lid closed."
            : "Stay Awake is off. Your Mac sleeps normally.")
    }
}
