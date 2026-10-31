import CoreFoundation
import ServiceManagement

/// Everything the command line and browser extensions can see. It's read
/// straight from the system rather than asked of the app, so it's right even
/// when Tapdeck isn't running and when something else changed a setting.
struct TapdeckState: Encodable {
    struct MicMute: Encodable {
        let muted: Bool
        /// The input apps use by default.
        let input: String?
        /// False for inputs macOS gives no mute or volume control.
        let canMute: Bool
    }

    struct CameraLock: Encodable {
        let locked: Bool
        /// Camera Lock works only while Touch ID is ready, since only Touch ID unlocks it.
        let touchID: Bool
    }

    struct StayAwake: Encodable {
        let on: Bool
        /// "enabled", "needs-approval" or "not-registered".
        let helper: String
    }

    struct LightsOut: Encodable {
        let out: Bool
    }

    let micMute: MicMute
    let cameraLock: CameraLock
    let stayAwake: StayAwake
    let lightsOut: LightsOut

    @MainActor
    static func current() -> TapdeckState {
        // Lights Out keeps its state in the app's defaults; pick up the
        // running app's latest writes.
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        let input = AudioInputs.defaultDevice
        return TapdeckState(
            micMute: MicMute(
                muted: AudioInputs.isDefaultInputMuted,
                input: input?.name,
                canMute: input.map { AudioInputs.canMute($0.id) || AudioInputs.canSetVolume($0.id) } ?? false
            ),
            cameraLock: CameraLock(locked: CameraLockState.isLocked, touchID: TouchID.isReady),
            stayAwake: StayAwake(on: SystemSleep.isDisabled, helper: helperStatus),
            lightsOut: LightsOut(out: LightsOutSnapshot.loadPersisted() != nil)
        )
    }

    @MainActor
    private static var helperStatus: String {
        switch PrivilegedHelper.shared.status {
        case .enabled: "enabled"
        case .requiresApproval: "needs-approval"
        default: "not-registered"
        }
    }
}
