import AppKit
import OSLog
import ServiceManagement
import WidgetKit

/// Switches `pmset -a disablesleep` through the root helper, so the Mac keeps
/// running even with the lid closed.
@MainActor
final class StayAwakeController {
    static let shared = StayAwakeController()

    private let logger = Logger(subsystem: "com.ibtkrgo.Tapdeck", category: "StayAwake")
    private var approvalWatch: Task<Void, Never>?

    func set(_ enabled: Bool) async {
        defer { ControlCenter.shared.reloadControls(ofKind: ControlKind.stayAwake) }
        do {
            try await PrivilegedHelper.shared.setSleepDisabled(enabled)
            logger.notice("Stay Awake \(enabled ? "on" : "off", privacy: .public)")
        } catch PrivilegedHelper.HelperError.needsApproval {
            askForApproval(thenApply: enabled)
        } catch {
            logger.error("Stay Awake failed: \(error.localizedDescription, privacy: .public)")
            showFailure(error)
        }
    }

    private func askForApproval(thenApply enabled: Bool) {
        let alert = NSAlert()
        alert.messageText = "Allow Stay Awake to change sleep settings"
        alert.informativeText = """
            Stay Awake runs “pmset -a disablesleep” through a small Tapdeck helper, which needs your approval once.

            In System Settings › General › Login Items & Extensions, turn on Tapdeck under “Allow in the Background”. Stay Awake switches \(enabled ? "on" : "off") by itself as soon as you do.
            """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        SMAppService.openSystemSettingsLoginItems()
        watchForApproval(thenApply: enabled)
    }

    /// Applies the requested state as soon as the helper is approved.
    private func watchForApproval(thenApply enabled: Bool) {
        approvalWatch?.cancel()
        approvalWatch = Task {
            for _ in 0..<300 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                if PrivilegedHelper.shared.status == .enabled {
                    await set(enabled)
                    return
                }
            }
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
