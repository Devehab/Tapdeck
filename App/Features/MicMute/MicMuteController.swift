import AppKit
import CoreAudio
import OSLog
import WidgetKit

/// Mutes every microphone the way a hardware mute button does: through each
/// device's own mute switch. Apps keep their stream and their permission and
/// simply receive silence; nothing is revoked, paused or reconfigured.
///
/// The mute lives in the audio devices, so it holds even if Tapdeck quits.
/// While it's on, Tapdeck also mutes any microphone that connects later.
@MainActor
final class MicMuteController {
    static let shared = MicMuteController()

    private let logger = Logger(subsystem: "com.ibtkrgo.Tapdeck", category: "MicMute")
    private let activeKey = "MicMute.active"
    /// Inputs without a mute switch get their volume set to 0; the old
    /// volume is kept here (by device UID) to put back.
    private let loweredKey = "MicMute.loweredVolumes"
    private var watchingSystem = false
    private var watchedDevices: Set<AudioDeviceID> = []
    /// Unmutable inputs already reported during this mute, so a flaky
    /// device doesn't raise the same alert again and again.
    private var reportedUnmutable: Set<String> = []

    var isActive: Bool { UserDefaults.standard.bool(forKey: activeKey) }

    /// Called at launch: keeps the control in sync with outside changes and
    /// re-applies a mute that was on when Tapdeck last quit.
    func resume() {
        startWatching()
        if isActive { applyMute(reportUnmutableDefault: false) }
    }

    func set(muted: Bool) {
        startWatching()
        if muted {
            reportedUnmutable = []
            applyMute(reportUnmutableDefault: true)
        } else {
            applyUnmute()
        }
        ControlCenter.shared.reloadControls(ofKind: ControlKind.micMute)
    }

    private func applyMute(reportUnmutableDefault: Bool) {
        UserDefaults.standard.set(true, forKey: activeKey)
        var lowered = loweredVolumes
        var unmutable: [AudioInputs.Device] = []
        for device in AudioInputs.all {
            if AudioInputs.canMute(device.id) {
                AudioInputs.setMuted(true, device.id)
            } else if AudioInputs.canSetVolume(device.id) {
                if lowered[device.uid] == nil, let volume = AudioInputs.volume(device.id) {
                    lowered[device.uid] = volume
                }
                AudioInputs.setVolume(0, device.id)
            } else {
                unmutable.append(device)
            }
        }
        loweredVolumes = lowered
        logger.notice("Mic muted; no mute control on: \(unmutable.map(\.name).joined(separator: ", "), privacy: .public)")

        if reportUnmutableDefault, let input = AudioInputs.defaultDevice,
           unmutable.contains(input), !reportedUnmutable.contains(input.uid) {
            reportedUnmutable.insert(input.uid)
            warnUnmutable(input)
        }
    }

    private func applyUnmute() {
        UserDefaults.standard.set(false, forKey: activeKey)
        let lowered = loweredVolumes
        for device in AudioInputs.all {
            if AudioInputs.canMute(device.id) {
                AudioInputs.setMuted(false, device.id)
            }
            if let volume = lowered[device.uid] {
                AudioInputs.setVolume(volume, device.id)
            }
        }
        loweredVolumes = [:]
        logger.notice("Mic on")
    }

    /// Apps can still hear a microphone that has neither a mute switch nor a
    /// volume control, so say so instead of showing a mute that isn't real.
    private func warnUnmutable(_ device: AudioInputs.Device) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "“\(device.name)” can't be muted"
        alert.informativeText = "macOS gives this microphone no mute or volume control, so apps using it can still hear you. Tapdeck muted every other microphone. To be fully muted, pick another input in System Settings › Sound, or mute this one at its source."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private var loweredVolumes: [String: Float] {
        get { UserDefaults.standard.dictionary(forKey: loweredKey) as? [String: Float] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: loweredKey) }
    }

    // MARK: Watching for changes

    private func startWatching() {
        if !watchingSystem {
            watchingSystem = true
            let system = AudioObjectID(kAudioObjectSystemObject)
            for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice] {
                var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
                AudioObjectAddPropertyListenerBlock(system, &address, .main) { _, _ in
                    MainActor.assumeIsolated { MicMuteController.shared.inputsChanged() }
                }
            }
        }
        for device in AudioInputs.all where AudioInputs.canMute(device.id) && !watchedDevices.contains(device.id) {
            watchedDevices.insert(device.id)
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioObjectPropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
            AudioObjectAddPropertyListenerBlock(device.id, &address, .main) { _, _ in
                MainActor.assumeIsolated { MicMuteController.shared.muteSwitchChanged() }
            }
        }
    }

    /// A microphone connected, disconnected or became the default input.
    private func inputsChanged() {
        startWatching()
        if isActive { applyMute(reportUnmutableDefault: true) }
        ControlCenter.shared.reloadControls(ofKind: ControlKind.micMute)
    }

    /// Someone flipped a mute switch, possibly another app or Audio MIDI Setup.
    private func muteSwitchChanged() {
        if isActive, let input = AudioInputs.defaultDevice, AudioInputs.isMuted(input.id) == false {
            // The default mic was turned back on elsewhere: treat that as "mic on".
            applyUnmute()
        }
        ControlCenter.shared.reloadControls(ofKind: ControlKind.micMute)
    }
}
