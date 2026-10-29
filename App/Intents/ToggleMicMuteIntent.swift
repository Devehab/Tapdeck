import AppIntents

/// A one-step switch for Spotlight and keyboard shortcuts. The Control Center
/// toggle uses `MicMuteIntent`, which is told the new value instead.
struct ToggleMicMuteIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Mic Mute"

    static var description: IntentDescription {
        IntentDescription("Mutes or unmutes every microphone at the hardware level. Apps keep running and hear silence while it's muted.")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let mute = !AudioInputs.isDefaultInputMuted
        try await (mute ? TapdeckAction.micMuteOn : .micMuteOff).run()
        return .result(dialog: AudioInputs.isDefaultInputMuted
            ? "Microphone muted. Apps hear silence until you turn it back on."
            : "Microphone on.")
    }
}
