import AppIntents

/// A one-step switch for Spotlight and keyboard shortcuts. The Control Center
/// toggle uses `CameraLockIntent`, which is told the new value instead.
struct ToggleCameraLockIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Camera Lock"

    static var description: IntentDescription {
        IntentDescription("Turns off every camera on this Mac, or turns them back on after Touch ID.")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let lock = !CameraLockState.isLocked
        try await (lock ? TapdeckAction.cameraLockOn : .cameraLockOff).run()
        if lock {
            return .result(dialog: CameraLockState.isLocked
                ? "Camera locked. Only Touch ID turns it back on."
                : "The camera isn't locked.")
        }
        return .result(dialog: CameraLockState.isLocked
            ? "The camera is still locked."
            : "Camera on. Quit and reopen any app that was using it.")
    }
}
