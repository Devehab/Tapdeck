import CoreGraphics
import Foundation

/// Display brightness through the private DisplayServices framework, the same
/// path the brightness keys and Control Center's Display slider use.
@MainActor
enum DisplayBrightness {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias CanChangeFn = @convention(c) (CGDirectDisplayID) -> Bool

    private static let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    private static let getFn: GetFn? = symbol("DisplayServicesGetBrightness")
    private static let setFn: SetFn? = symbol("DisplayServicesSetBrightness")
    private static let canChangeFn: CanChangeFn? = symbol("DisplayServicesCanChangeBrightness")

    private static func symbol<T>(_ name: String) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    static var isAvailable: Bool { getFn != nil && setFn != nil }

    static var activeDisplays: [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    static func canChangeBrightness(of display: CGDirectDisplayID) -> Bool {
        canChangeFn?(display) ?? false
    }

    static func brightness(of display: CGDirectDisplayID) -> Float? {
        var value: Float = 0
        guard let getFn, getFn(display, &value) == 0 else { return nil }
        return value
    }

    @discardableResult
    static func setBrightness(_ value: Float, of display: CGDirectDisplayID) -> Bool {
        setFn?(display, value) == 0
    }

    /// Paints the display fully black through its gamma table. At brightness 0
    /// some panels still glow faintly; on mini-LED panels black pixels also turn
    /// their backlight zones off. The system drops the table if this process exits.
    static func blackOut(_ display: CGDirectDisplayID) {
        CGSetDisplayTransferByFormula(display, 0, 0, 1, 0, 0, 1, 0, 0, 1)
    }

    static func restoreColors() {
        CGDisplayRestoreColorSyncSettings()
    }
}
