import AppKit
import LocalAuthentication
import OSLog
import WidgetKit

/// Turns every camera off for all apps, including cameras already in use, and
/// back on only after Touch ID. The root helper does the switching; see
/// `CameraLock` in the helper for how.
@MainActor
final class CameraLockController {
    static let shared = CameraLockController()

    private let logger = Logger(subsystem: "com.ibtkrgo.Tapdeck", category: "CameraLock")

    /// Called at launch: a lock that's on gets its helper back, e.g. after an
    /// update replaced the helper.
    func resume() {
        guard CameraLockState.isLocked else { return }
        Task {
            // Give a helper replaced by the update a moment to exit.
            try? await Task.sleep(for: .seconds(3))
            do {
                try await PrivilegedHelper.shared.resumeCameraLock()
            } catch {
                logger.error("Couldn't resume Camera Lock: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func set(locked: Bool) async {
        defer { ControlCenter.shared.reloadControls(ofKind: ControlKind.cameraLock) }
        if locked {
            await lock()
        } else {
            await unlock()
        }
    }

    private func lock() async {
        guard !CameraLockState.isLocked else { return }
        // Only Touch ID can unlock the camera, so never lock it without Touch ID.
        if let reason = TouchID.unavailableReason {
            explainTouchIDNeeded(reason)
            return
        }
        await apply(locked: true)
    }

    private func unlock() async {
        guard CameraLockState.isLocked else { return }
        if let reason = TouchID.unavailableReason {
            showMessage("The camera stays locked", "Camera Lock opens only with Touch ID. \(TouchID.advice(for: reason))")
            return
        }
        do {
            try await TouchID.authenticate(reason: "turn the camera back on")
        } catch let error as LAError where [.userCancel, .systemCancel, .appCancel, .userFallback].contains(error.code) {
            logger.notice("Touch ID cancelled; camera stays locked")
            return
        } catch let error as LAError where error.code == .biometryLockout {
            showMessage("The camera stays locked", TouchID.advice(for: .biometryLockout))
            return
        } catch {
            showMessage("The camera stays locked", "Touch ID didn't match.")
            return
        }
        await apply(locked: false)
    }

    private func apply(locked: Bool) async {
        do {
            try await PrivilegedHelper.shared.setCameraLocked(locked)
            await CameraLockState.waitUntil(locked: locked, timeout: .seconds(3))
            logger.notice("Camera \(CameraLockState.isLocked ? "locked" : "on", privacy: .public)")
            if !locked, !CameraLockState.isLocked {
                remindToReopenApps()
            }
        } catch PrivilegedHelper.HelperError.needsApproval {
            PrivilegedHelper.shared.askForApproval(
                title: "Allow Camera Lock",
                message: """
                    Camera Lock turns cameras off through a small Tapdeck helper, which needs your approval once.

                    In System Settings › General › Login Items & Extensions, turn on Tapdeck under “Allow in the Background”. Camera Lock continues by itself as soon as you do.
                    """
            ) {
                // Unlocking asks for Touch ID again before going ahead.
                await CameraLockController.shared.set(locked: locked)
            }
        } catch {
            logger.error("Camera Lock failed: \(error.localizedDescription, privacy: .public)")
            showMessage(locked ? "Camera Lock couldn't lock the camera" : "Camera Lock couldn't turn the camera back on", error.localizedDescription)
        }
    }

    private func explainTouchIDNeeded(_ reason: LAError.Code) {
        let alert = NSAlert()
        alert.messageText = "Camera Lock needs Touch ID"
        alert.informativeText = "Only Touch ID can turn the camera back on, so Camera Lock works only while Touch ID is ready. \(TouchID.advice(for: reason))"
        alert.addButton(withTitle: reason == .biometryNotEnrolled ? "Open Touch ID Settings" : "OK")
        if reason == .biometryNotEnrolled {
            alert.addButton(withTitle: "Cancel")
        }
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn, reason == .biometryNotEnrolled {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Touch-ID-Settings.extension")!)
        }
    }

    /// Apps that had a camera open when it was locked lost it for good; they
    /// find it again only after a fresh start.
    private func remindToReopenApps() {
        let key = "CameraLockSkipReopenReminder"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let alert = NSAlert()
        alert.messageText = "Camera on"
        alert.informativeText = Self.reopenAppsAdvice
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't remind me again"
        NSApp.activate()
        alert.runModal()
        if alert.suppressionButton?.state == .on {
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    nonisolated static let reopenAppsAdvice = "If an app was using the camera when you locked it, quit that app completely (⌘Q, not just its window) and open it again to see the camera. In a browser, quit the whole browser."

    private func showMessage(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        NSApp.activate()
        alert.runModal()
    }
}
