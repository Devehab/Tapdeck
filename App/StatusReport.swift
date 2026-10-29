import CoreGraphics
import Foundation
import ServiceManagement

/// `Tapdeck --status`: prints what Lights Out can see and control,
/// without changing anything. Handy when a control doesn't behave.
@MainActor
enum StatusReport {
    static func print() {
        Swift.print("Display brightness API: \(DisplayBrightness.isAvailable ? "available" : "missing")")
        for display in DisplayBrightness.activeDisplays {
            let kind = CGDisplayIsBuiltin(display) != 0 ? "built-in" : "external"
            let brightness = DisplayBrightness.brightness(of: display).map { String(format: "%.2f", $0) } ?? "n/a"
            let controllable = DisplayBrightness.canChangeBrightness(of: display) ? "dimmable" : "black-out only"
            Swift.print("  display \(display) (\(kind)): brightness \(brightness), \(controllable)")
        }

        if let keyboard = KeyboardBacklight() {
            let ids = keyboard.keyboardIDs
            Swift.print("Keyboard backlight API: available, \(ids.count) keyboard(s)")
            for id in ids {
                let brightness = keyboard.brightness(of: id).map { String(format: "%.2f", $0) } ?? "n/a"
                let auto = keyboard.isAutoBrightnessEnabled(for: id) ? "on" : "off"
                Swift.print("  keyboard \(id): brightness \(brightness), auto-adjust \(auto)")
            }
        } else {
            Swift.print("Keyboard backlight API: missing")
        }

        Swift.print(String(format: "Seconds since last input: %.1f", InputActivity.secondsSinceLastInput))
        Swift.print("Lights Out pending restore: \(LightsOutSnapshot.loadPersisted() != nil ? "yes" : "no")")

        Swift.print("Stay Awake (SleepDisabled): \(SystemSleep.isDisabled ? "on" : "off")")
        Swift.print("Root helper: \(describe(PrivilegedHelper.shared.status))")

        let defaultInput = AudioInputs.defaultDevice
        Swift.print("Mic Mute: \(AudioInputs.isDefaultInputMuted ? "muted" : "on") (default input: \(defaultInput?.name ?? "none"))")
        for device in AudioInputs.all {
            let marker = device == defaultInput ? "*" : " "
            if AudioInputs.canMute(device.id) {
                Swift.print(" \(marker) \(device.name): hardware mute, \(AudioInputs.isMuted(device.id) == true ? "muted" : "on")")
            } else if AudioInputs.canSetVolume(device.id) {
                Swift.print(" \(marker) \(device.name): volume only (\(String(format: "%.2f", AudioInputs.volume(device.id) ?? 0)))")
            } else {
                Swift.print(" \(marker) \(device.name): no mute or volume control, can't be muted")
            }
        }
    }

    private static func describe(_ status: SMAppService.Status) -> String {
        switch status {
        case .enabled: "enabled"
        case .requiresApproval: "waiting for approval in System Settings"
        // A daemon reports notFound until its first registration.
        case .notRegistered, .notFound: "not registered yet (the first Stay Awake tap registers it)"
        @unknown default: "unknown (\(status.rawValue))"
        }
    }
}
