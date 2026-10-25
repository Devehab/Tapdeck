import Foundation

/// Keyboard backlight through CoreBrightness's private `KeyboardBrightnessClient`,
/// the object behind Control Center's Keyboard Brightness slider.
@MainActor
final class KeyboardBacklight {
    private let client: NSObject

    init?() {
        guard dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW) != nil,
              let clientClass = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type
        else { return nil }
        client = clientClass.init()
    }

    var keyboardIDs: [UInt64] {
        typealias Fn = @convention(c) (NSObject, Selector) -> Unmanaged<NSArray>?
        guard let (selector, fn) = method("copyKeyboardBacklightIDs", as: Fn.self),
              let ids = fn(client, selector)?.takeRetainedValue() as? [NSNumber]
        else { return [] }
        return ids.map(\.uint64Value)
    }

    func brightness(of keyboard: UInt64) -> Float? {
        typealias Fn = @convention(c) (NSObject, Selector, UInt64) -> Float
        guard let (selector, fn) = method("brightnessForKeyboard:", as: Fn.self) else { return nil }
        return fn(client, selector, keyboard)
    }

    @discardableResult
    func setBrightness(_ value: Float, of keyboard: UInt64) -> Bool {
        typealias Fn = @convention(c) (NSObject, Selector, Float, UInt64) -> Bool
        guard let (selector, fn) = method("setBrightness:forKeyboard:", as: Fn.self) else { return false }
        return fn(client, selector, value, keyboard)
    }

    /// "Adjust keyboard brightness in low light". Left on, it can relight the
    /// keyboard on its own, so Lights Out pauses it.
    func isAutoBrightnessEnabled(for keyboard: UInt64) -> Bool {
        typealias Fn = @convention(c) (NSObject, Selector, UInt64) -> Bool
        guard let (selector, fn) = method("isAutoBrightnessEnabledForKeyboard:", as: Fn.self) else { return false }
        return fn(client, selector, keyboard)
    }

    @discardableResult
    func setAutoBrightnessEnabled(_ enabled: Bool, for keyboard: UInt64) -> Bool {
        typealias Fn = @convention(c) (NSObject, Selector, Bool, UInt64) -> Bool
        guard let (selector, fn) = method("enableAutoBrightness:forKeyboard:", as: Fn.self) else { return false }
        return fn(client, selector, enabled, keyboard)
    }

    private func method<T>(_ name: String, as type: T.Type) -> (Selector, T)? {
        let selector = NSSelectorFromString(name)
        guard client.responds(to: selector) else { return nil }
        return (selector, unsafeBitCast(client.method(for: selector), to: type))
    }
}
