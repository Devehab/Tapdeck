import AppIntents

struct MicMuteIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Mic Mute"

    static var description: IntentDescription {
        IntentDescription("Mutes every microphone at the hardware level. Apps keep running and hear silence until you turn it back on.")
    }

    @Parameter(title: "Muted")
    var value: Bool

    func perform() async throws -> some IntentResult {
        try await (value ? TapdeckAction.micMuteOn : .micMuteOff).run()
        // The app flips the switch in the background. Waiting for it lets the
        // control show the real new state instead of bouncing back.
        await AudioInputs.waitUntil(muted: value, timeout: .seconds(3))
        return .result()
    }
}
