import AppKit
import CoreAudio

/// One request from outside Tapdeck: the `tapdeck` command or a browser
/// extension. Both go through here, so they behave exactly alike.
enum TapdeckCommand: Equatable {
    case status
    case micMute(Change)
    case cameraLock(Change)
    case stayAwake(Change)
    case lightsOut(Change)

    /// What to do with a tool. "On" means the tool is doing its job: the mic
    /// muted, the camera locked, the Mac kept awake, the lights out.
    enum Change: Equatable {
        case on, off, toggle, status
    }

    /// Reads the words people type, e.g. `mic mute`, `camera lock`, `awake on`, `lights out`.
    /// A tool with no action asks for its status.
    init?(tool: String, action: String?) {
        let action = action?.lowercased()
        switch tool.lowercased() {
        case "status":
            self = .status
        case "mic", "microphone", "mic-mute":
            guard let change = Self.change(action, on: ["mute", "on"], off: ["unmute", "off"]) else { return nil }
            self = .micMute(change)
        case "camera", "cam", "camera-lock":
            guard let change = Self.change(action, on: ["lock", "off"], off: ["unlock", "on"]) else { return nil }
            self = .cameraLock(change)
        case "awake", "stay-awake":
            guard let change = Self.change(action, on: ["on"], off: ["off"]) else { return nil }
            self = .stayAwake(change)
        case "lights", "lights-out":
            guard let change = Self.change(action, on: ["out", "off"], off: ["on", "restore"]) else { return nil }
            self = .lightsOut(change)
        default:
            return nil
        }
    }

    private static func change(_ action: String?, on: [String], off: [String]) -> Change? {
        switch action {
        case nil, "status": .status
        case "toggle": .toggle
        case let word? where on.contains(word): .on
        case let word? where off.contains(word): .off
        default: nil
        }
    }
}

/// Runs a `TapdeckCommand`. State is read directly; changes are handed to the
/// app over `tapdeck://`, the same path the Control Center buttons use, so the
/// buttons update and the app keeps doing its follow-up work (watching for new
/// microphones, waking the screen on touch).
@MainActor
enum CommandRunner {
    struct Response: Encodable {
        let ok: Bool
        let state: TapdeckState
        let error: String?
    }

    static func run(_ command: TapdeckCommand) -> Response {
        switch command {
        case .status:
            return Response(ok: true, state: .current(), error: nil)
        case .micMute(let change):
            return apply(change, timeout: 4,
                         isOn: { AudioInputs.isDefaultInputMuted },
                         send: { $0 ? .micMuteOn : .micMuteOff },
                         failure: micMuteFailure)
        case .cameraLock(let change):
            if change != .status, let reason = TouchID.unavailableReason {
                return Response(ok: false, state: .current(),
                                error: "Camera Lock works only with Touch ID. \(TouchID.advice(for: reason))")
            }
            let wasLocked = CameraLockState.isLocked
            let locking = change == .on || (change == .toggle && !wasLocked)
            // Unlocking waits for Touch ID, so give people time.
            let response = apply(change, timeout: locking ? 6 : 60,
                                 hint: locking ? nil : "Touch the Touch ID sensor to turn the camera back on.",
                                 isOn: { CameraLockState.isLocked },
                                 send: { $0 ? .cameraLockOn : .cameraLockOff },
                                 failure: cameraLockFailure)
            if wasLocked, !CameraLockState.isLocked {
                FileHandle.standardError.write(Data("\(CameraLockController.reopenAppsAdvice)\n".utf8))
            }
            return response
        case .stayAwake(let change):
            return apply(change, timeout: 5,
                         isOn: { SystemSleep.isDisabled },
                         send: { $0 ? .stayAwakeOn : .stayAwakeOff },
                         failure: stayAwakeFailure)
        case .lightsOut(let change):
            // Lights Out has a single toggle action; only send it when the state must change.
            return apply(change, timeout: 4,
                         isOn: { TapdeckState.current().lightsOut.out },
                         send: { _ in .lightsOut },
                         failure: { _ in "Tapdeck didn't respond in time. Open Tapdeck once and try again." })
        }
    }

    private static func apply(
        _ change: TapdeckCommand.Change,
        timeout: TimeInterval,
        hint: String? = nil,
        isOn: () -> Bool,
        send: (Bool) -> TapdeckAction,
        failure: (Bool) -> String
    ) -> Response {
        let target: Bool
        switch change {
        case .status: return Response(ok: true, state: .current(), error: nil)
        case .toggle: target = !isOn()
        case .on: target = true
        case .off: target = false
        }
        if isOn() != target {
            handOff(send(target))
            // stderr: stdout carries the reply, and for browsers the framed JSON.
            if let hint { FileHandle.standardError.write(Data("\(hint)\n".utf8)) }
            let deadline = Date().addingTimeInterval(timeout)
            while isOn() != target, Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
        }
        let ok = isOn() == target
        return Response(ok: ok, state: .current(), error: ok ? nil : failure(target))
    }

    /// Opens `tapdeck://…` in the background; launches Tapdeck if needed and never takes focus.
    private static func handOff(_ action: TapdeckAction) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        NSWorkspace.shared.open(action.url, configuration: configuration) { _, _ in }
    }

    private static func micMuteFailure(_ muting: Bool) -> String {
        if muting, let input = AudioInputs.defaultDevice, !AudioInputs.canMute(input.id) {
            return "“\(input.name)” has no mute control, so macOS can't mute it. Tapdeck muted every other microphone. Pick another input in System Settings › Sound to be fully muted."
        }
        return "Tapdeck didn't respond in time. Open Tapdeck once and try again."
    }

    private static func cameraLockFailure(_ locking: Bool) -> String {
        if locking, PrivilegedHelper.shared.status != .enabled {
            return "Camera Lock needs a one-time approval. Turn Tapdeck on in System Settings › General › Login Items & Extensions › Allow in the Background, then try again."
        }
        return locking
            ? "Tapdeck didn't lock the camera in time. Open Tapdeck once and try again."
            : "The camera is still locked: Touch ID didn't confirm it."
    }

    private static func stayAwakeFailure(_ turningOn: Bool) -> String {
        if PrivilegedHelper.shared.status != .enabled {
            return "Stay Awake needs a one-time approval. Turn Tapdeck on in System Settings › General › Login Items & Extensions › Allow in the Background, then try again."
        }
        return "Tapdeck didn't respond in time. Open Tapdeck once and try again."
    }
}
