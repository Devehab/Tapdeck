import AppKit
import OSLog
import WidgetKit

/// Tapdeck has no windows, Dock icon or menu bar item. It lives in
/// Control Center: its controls hand actions to this app, which carries them out.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var terminationSignal: DispatchSourceSignal?

    static func main() {
        // `tapdeck …` in Terminal, or a browser extension talking to Tapdeck.
        if let exitCode = CommandLineInterface.run(Array(CommandLine.arguments.dropFirst())) {
            exit(exitCode)
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LightsOutController.shared.recoverIfNeeded()
        MicMuteController.shared.resume()
        restoreLightsOnSIGTERM()
        // Controls already placed in Control Center keep their last rendering,
        // which may come from an older build.
        ControlCenter.shared.reloadAllControls()

        // Opened by hand (not by a control, URL or Shortcut) for the first time,
        // e.g. right after installing from the DMG: nothing would appear otherwise.
        let launchEvent = NSAppleEventManager.shared().currentAppleEvent?.eventID
        if launchEvent == AEEventID(kAEOpenApplication), !UserDefaults.standard.bool(forKey: welcomeShownKey) {
            UserDefaults.standard.set(true, forKey: welcomeShownKey)
            Task { showWelcome(offerQuit: false) }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let action = TapdeckAction(url: url) else {
                Logger.tapdeck.error("Unknown action URL: \(url.absoluteString, privacy: .public)")
                continue
            }
            Task {
                do {
                    try await action.run()
                } catch {
                    Logger.tapdeck.error("\(action.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        LightsOutController.shared.restore()
    }

    /// Opening the app from Finder while it's already running explains where it lives.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWelcome(offerQuit: true)
        return false
    }

    private let welcomeShownKey = "didShowWelcome"

    /// Tapdeck has no window of its own, so this is how people learn where it lives.
    private func showWelcome(offerQuit: Bool) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = offerQuit ? "Tapdeck is running" : "Tapdeck is ready"
        alert.informativeText = """
            Tapdeck lives in Control Center. Open Control Center, click Edit Controls, choose Tapdeck, and drag in Lights Out, Stay Awake or Mic Mute.

            You can also run them from Spotlight, or give them a keyboard shortcut in the Shortcuts app.
            """
        alert.addButton(withTitle: "Got It")
        if offerQuit {
            alert.addButton(withTitle: "Quit Tapdeck")
        }
        if alert.runModal() == .alertSecondButtonReturn {
            NSApp.terminate(nil)
        }
    }

    /// `kill`, logout scripts and reinstalls send SIGTERM, which skips
    /// `applicationWillTerminate`. Put the lights back first.
    private func restoreLightsOnSIGTERM() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { LightsOutController.shared.restore() }
            exit(0)
        }
        source.resume()
        terminationSignal = source
    }
}
