import CoreAudio
import Foundation

/// Microphones and other audio inputs, through CoreAudio.
///
/// Muting flips each device's own mute control, the same switch a hardware
/// mute button on a mic flips: apps keep their stream and their permission,
/// and receive exact digital silence until it's switched back.
enum AudioInputs {
    struct Device: Equatable {
        let id: AudioDeviceID
        let uid: String
        let name: String
    }

    static var all: [Device] {
        var address = globalAddress(kAudioHardwarePropertyDevices)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.filter { inputChannelCount($0) > 0 }.compactMap(device)
    }

    static var defaultDevice: Device? {
        var address = globalAddress(kAudioHardwarePropertyDefaultInputDevice)
        var id: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown
        else { return nil }
        return device(id)
    }

    /// What the Mic Mute control shows: whether the input apps use by default is muted.
    static var isDefaultInputMuted: Bool {
        guard let device = defaultDevice else { return false }
        return isMuted(device.id) == true
    }

    static func waitUntil(muted: Bool, timeout: Duration) async {
        let deadline = ContinuousClock.now + timeout
        while isDefaultInputMuted != muted, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    // MARK: Mute

    static func canMute(_ id: AudioDeviceID) -> Bool {
        !settableElements(id, kAudioDevicePropertyMute).isEmpty
    }

    static func isMuted(_ id: AudioDeviceID) -> Bool? {
        guard let element = settableElements(id, kAudioDevicePropertyMute).first else { return nil }
        var address = inputAddress(kAudioDevicePropertyMute, element)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value != 0
    }

    @discardableResult
    static func setMuted(_ muted: Bool, _ id: AudioDeviceID) -> Bool {
        let elements = settableElements(id, kAudioDevicePropertyMute)
        var value: UInt32 = muted ? 1 : 0
        return !elements.isEmpty && elements.allSatisfy { element in
            var address = inputAddress(kAudioDevicePropertyMute, element)
            return AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
        }
    }

    // MARK: Volume, for inputs that have no mute control

    static func canSetVolume(_ id: AudioDeviceID) -> Bool {
        !settableElements(id, kAudioDevicePropertyVolumeScalar).isEmpty
    }

    static func volume(_ id: AudioDeviceID) -> Float? {
        guard let element = settableElements(id, kAudioDevicePropertyVolumeScalar).first else { return nil }
        var address = inputAddress(kAudioDevicePropertyVolumeScalar, element)
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    @discardableResult
    static func setVolume(_ volume: Float, _ id: AudioDeviceID) -> Bool {
        let elements = settableElements(id, kAudioDevicePropertyVolumeScalar)
        var value = Float32(volume)
        return !elements.isEmpty && elements.allSatisfy { element in
            var address = inputAddress(kAudioDevicePropertyVolumeScalar, element)
            return AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value) == noErr
        }
    }

    // MARK: Helpers

    /// The main element when the device controls the whole input at once,
    /// otherwise every channel, as long as each one can be set.
    private static func settableElements(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> [AudioObjectPropertyElement] {
        func isSettable(_ element: AudioObjectPropertyElement) -> Bool {
            var address = inputAddress(selector, element)
            var settable: DarwinBoolean = false
            return AudioObjectHasProperty(id, &address)
                && AudioObjectIsPropertySettable(id, &address, &settable) == noErr
                && settable.boolValue
        }
        if isSettable(kAudioObjectPropertyElementMain) { return [kAudioObjectPropertyElementMain] }
        let channels = (0..<inputChannelCount(id)).map { AudioObjectPropertyElement($0 + 1) }
        return !channels.isEmpty && channels.allSatisfy(isSettable) ? channels : []
    }

    private static func device(_ id: AudioDeviceID) -> Device? {
        guard let uid = string(id, kAudioDevicePropertyDeviceUID) else { return nil }
        return Device(id: id, uid: uid, name: string(id, kAudioObjectPropertyName) ?? uid)
    }

    private static func inputChannelCount(_ id: AudioDeviceID) -> Int {
        var address = inputAddress(kAudioDevicePropertyStreamConfiguration, kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { buffer.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, buffer) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(buffer.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = globalAddress(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func globalAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    private static func inputAddress(_ selector: AudioObjectPropertySelector, _ element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeInput, mElement: element)
    }
}
