import AppKit
import IOKit.pwr_mgt
import OSLog

/// Turns the screen and keyboard backlight off while the Mac keeps running, and
/// puts them back the moment the trackpad, mouse or keyboard is used.
@MainActor
final class LightsOutController {
    static let shared = LightsOutController()

    /// Input in this window after activation is ignored, so the click on the
    /// control and the finger lifting off the trackpad don't undo it at once.
    private let gracePeriod: TimeInterval = 1.2
    private let pollInterval: TimeInterval = 0.1
    /// Auto-brightness can creep the backlight back up; push it down again this often.
    private let reassertInterval: TimeInterval = 2

    private let keyboard = KeyboardBacklight()
    private var snapshot: LightsOutSnapshot?
    private var pollTimer: Timer?
    private var armedAt = Date.distantFuture
    private var lastReassert = Date.distantPast
    private var awakeAssertion = IOPMAssertionID(0)
    private let logger = Logger(subsystem: "com.ibtkrgo.Tapdeck", category: "LightsOut")

    var isActive: Bool { snapshot != nil }

    private init() {
        // Wake from sleep should never land on a dark screen.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { LightsOutController.shared.restore() }
        }
    }

    func toggle() {
        isActive ? restore() : activate()
    }

    func activate() {
        guard !isActive else { return }
        let snapshot = LightsOutSnapshot.capture(keyboard: keyboard)
        snapshot.persist()
        self.snapshot = snapshot

        for kb in snapshot.keyboards {
            if kb.autoBrightness { keyboard?.setAutoBrightnessEnabled(false, for: kb.id) }
            keyboard?.setBrightness(0, of: kb.id)
        }
        for display in snapshot.displays {
            DisplayBrightness.setBrightness(0, of: display.id)
        }
        for display in DisplayBrightness.activeDisplays {
            DisplayBrightness.blackOut(display)
        }
        keepAwake()

        armedAt = Date().addingTimeInterval(gracePeriod)
        lastReassert = Date()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
            MainActor.assumeIsolated { LightsOutController.shared.tick() }
        }
        pollTimer?.tolerance = 0.02
        logger.notice("Lights out: \(snapshot.displays.count) display(s), \(snapshot.keyboards.count) keyboard(s)")
    }

    func restore() {
        guard let snapshot else { return }
        pollTimer?.invalidate()
        pollTimer = nil

        DisplayBrightness.restoreColors()
        for display in snapshot.displays {
            DisplayBrightness.setBrightness(display.brightness, of: display.id)
        }
        for kb in snapshot.keyboards {
            keyboard?.setBrightness(kb.brightness, of: kb.id)
            if kb.autoBrightness { keyboard?.setAutoBrightnessEnabled(true, for: kb.id) }
        }
        releaseAwake()

        LightsOutSnapshot.clearPersisted()
        self.snapshot = nil
        logger.notice("Lights restored")
    }

    /// Undoes a Lights Out that was still on when the app last quit or crashed.
    func recoverIfNeeded() {
        guard !isActive, let pending = LightsOutSnapshot.loadPersisted() else { return }
        logger.notice("Restoring lights left off by a previous run")
        snapshot = pending
        restore()
    }

    private func tick() {
        let now = Date()
        guard now >= armedAt else { return }

        // Any input newer than the end of the grace period brings the lights back.
        if InputActivity.secondsSinceLastInput < now.timeIntervalSince(armedAt) {
            restore()
            return
        }

        if now.timeIntervalSince(lastReassert) >= reassertInterval, let snapshot {
            lastReassert = now
            for display in snapshot.displays where (DisplayBrightness.brightness(of: display.id) ?? 0) > 0.001 {
                DisplayBrightness.setBrightness(0, of: display.id)
            }
            for kb in snapshot.keyboards where (keyboard?.brightness(of: kb.id) ?? 0) > 0.001 {
                keyboard?.setBrightness(0, of: kb.id)
            }
        }
    }

    /// Keeps the Mac and its (dark) display from idling to sleep, so running
    /// work continues and coming back skips the lock screen.
    private func keepAwake() {
        guard awakeAssertion == 0 else { return }
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Tapdeck Lights Out is keeping the Mac awake with the screen dark" as CFString,
            &awakeAssertion
        )
    }

    private func releaseAwake() {
        guard awakeAssertion != 0 else { return }
        IOPMAssertionRelease(awakeAssertion)
        awakeAssertion = 0
    }
}
