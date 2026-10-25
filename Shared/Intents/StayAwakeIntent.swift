import AppIntents

struct StayAwakeIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Stay Awake"

    static var description: IntentDescription {
        IntentDescription("Keeps the Mac running even with the lid closed (pmset -a disablesleep).")
    }

    @Parameter(title: "Stay awake")
    var value: Bool

    func perform() async throws -> some IntentResult {
        try await (value ? TapdeckAction.stayAwakeOn : .stayAwakeOff).run()
        // The app applies the change in the background. Waiting for it lets the
        // control show the real new state instead of bouncing back.
        await SystemSleep.waitUntil(disabled: value, timeout: .seconds(4))
        return .result()
    }
}
