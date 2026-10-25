import CoreGraphics
import Foundation

/// The lighting to put back when Lights Out ends. It's also written to
/// UserDefaults while lights are out, so a crash or forced quit can still be
/// undone the next time the app starts.
struct LightsOutSnapshot: Codable {
    struct Display: Codable {
        let id: CGDirectDisplayID
        let brightness: Float
    }

    struct Keyboard: Codable {
        let id: UInt64
        let brightness: Float
        let autoBrightness: Bool
    }

    var displays: [Display]
    var keyboards: [Keyboard]

    @MainActor
    static func capture(keyboard backlight: KeyboardBacklight?) -> LightsOutSnapshot {
        let displays = DisplayBrightness.activeDisplays.compactMap { id -> Display? in
            guard DisplayBrightness.canChangeBrightness(of: id),
                  let brightness = DisplayBrightness.brightness(of: id)
            else { return nil }
            return Display(id: id, brightness: brightness)
        }
        let keyboards = (backlight?.keyboardIDs ?? []).compactMap { id -> Keyboard? in
            guard let backlight, let brightness = backlight.brightness(of: id) else { return nil }
            return Keyboard(id: id, brightness: brightness, autoBrightness: backlight.isAutoBrightnessEnabled(for: id))
        }
        return LightsOutSnapshot(displays: displays, keyboards: keyboards)
    }

    private static let defaultsKey = "LightsOut.pendingRestore"

    func persist() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }

    static func loadPersisted() -> LightsOutSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(LightsOutSnapshot.self, from: data)
    }

    static func clearPersisted() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
