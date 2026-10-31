import AppKit
import OSLog
import WidgetKit

/// Switches `pmset -a disablesleep` through the root helper, so the Mac keeps
/// running even with the lid closed.
@MainActor
final class StayAwakeController {
    static let shared = StayAwakeController()

    private let logger = Logger(subsystem: "com.ibtkrgo.Tapdeck", category: "StayAwake")

    func set(_ enabled: Bool) async {
        defer { ControlCenter.shared.reloadControls(ofKind: ControlKind.stayAwake) }
        do {
            try await PrivilegedHelper.shared.setSleepDisabled(enabled)
            logger.notice("Stay Awake \(enabled ? "on" : "off", privacy: .public)")
        } catch PrivilegedHelper.HelperError.needsApproval {
            PrivilegedHelper.shared.askForApproval(
                title: "Allow Stay Awake to change sleep settings",
                message: """
                    Stay Awake runs “pmset -a disablesleep” through a small Tapdeck helper, which needs your approval once.

                    In System Settings › General › Login Items & Extensions, turn on Tapdeck under “Allow in the Background”. Stay Awake switches \(enabled ? "on" : "off") by itself as soon as you do.
                    """
            ) {
                await StayAwakeController.shared.set(enabled)
            }
        } catch {
            logger.error("Stay Awake failed: \(error.localizedDescription, privacy: .public)")
            showFailure(error)
        }
    }

    private func showFailure(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Stay Awake couldn't change sleep settings"
        alert.informativeText = error.localizedDescription
        NSApp.activate()
        alert.runModal()
    }
}
