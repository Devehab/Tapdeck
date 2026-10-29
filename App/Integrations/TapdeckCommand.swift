import AppKit
import CoreAudio

/// One request from outside Tapdeck: the `tapdeck` command or a browser
/// extension. Both go through here, so they behave exactly alike.
enum TapdeckCommand: Equatable {
    case status
    case micMute(Change)
    case stayAwake(Change)
    case lightsOut(Change)

    /// What to do with a tool. "On" means the tool is doing its job: the mic
    /// muted, the Mac kept awake, the lights out.
    enum Change: Equatable {
        case on, off, toggle, status
    }

    /// Reads the words people type, e.g. `mic mute`, `awake on`, `lights out`.
    /// A tool with no action asks for its status.
    init?(tool: String, action: String?) {
        let action = action?.lowercased()
        switch tool.lowercased() {
        case "status":
            self = .status
        case "mic", "microphone", "mic-mute":
            guard let change = Self.change(action, on: ["mute", "on"], off: ["unmute", "off"]) else { return nil }
            self = .micMute(change)
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

    private static func stayAwakeFailure(_ turningOn: Bool) -> String {
        if PrivilegedHelper.shared.status != .enabled {
            return "Stay Awake needs a one-time approval. Turn Tapdeck on in System Settings › General › Login Items & Extensions › Allow in the Background, then try again."
        }
        return "Tapdeck didn't respond in time. Open Tapdeck once and try again."
    }
}
