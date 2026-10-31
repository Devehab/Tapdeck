import AppIntents

struct CameraLockIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Camera Lock"

    static var description: IntentDescription {
        IntentDescription("Turns off every camera on this Mac. Only Touch ID turns them back on.")
    }

    @Parameter(title: "Locked")
    var value: Bool

    func perform() async throws -> some IntentResult {
        try await (value ? TapdeckAction.cameraLockOn : .cameraLockOff).run()
        // The app switches the camera in the background; unlocking first waits
        // for Touch ID. Waiting lets the control show the real new state.
        await CameraLockState.waitUntil(locked: value, timeout: value ? .seconds(4) : .seconds(20))
        return .result()
    }
}
