import Foundation
import OSLog

/// Every action a Tapdeck control can trigger.
///
/// The control extension is sandboxed and short-lived, so it can't touch
/// hardware or keep watching for input. It hands the action to the app over
/// the `tapdeck://` URL scheme, and the app does the real work.
/// Each target supplies its own `TapdeckActionHandler` with that behavior.
///
/// To add a control: add a case here, handle it in the app's
/// `TapdeckActionHandler`, then add an intent, a `ControlKind` and a
/// `ControlWidget` for it.
enum TapdeckAction: String, CaseIterable, Sendable {
    case lightsOut = "lights-out"
    case stayAwakeOn = "stay-awake-on"
    case stayAwakeOff = "stay-awake-off"
    case micMuteOn = "mic-mute-on"
    case micMuteOff = "mic-mute-off"
    case cameraLockOn = "camera-lock-on"
    case cameraLockOff = "camera-lock-off"

    static let urlScheme = "tapdeck"

    var url: URL {
        URL(string: "\(Self.urlScheme)://\(rawValue)")!
    }

    init?(url: URL) {
        guard url.scheme == Self.urlScheme, let host = url.host() else { return nil }
        self.init(rawValue: host)
    }

    @MainActor
    func run() async throws {
        Logger.tapdeck.notice("Running \(rawValue, privacy: .public) in \(Bundle.main.bundleIdentifier ?? "?", privacy: .public)")
        try await TapdeckActionHandler.handle(self)
    }
}

extension Logger {
    static let tapdeck = Logger(subsystem: "com.ibtkrgo.Tapdeck", category: "Tapdeck")
}
