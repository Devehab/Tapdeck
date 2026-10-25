import CoreGraphics

enum InputActivity {
    /// Seconds since the last real keyboard, trackpad or mouse event. Reads the
    /// HID event state, so it needs no Accessibility or Input Monitoring access
    /// and ignores events that apps synthesize.
    static var secondsSinceLastInput: Double {
        CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInputEventType)
    }

    /// `kCGAnyInputEventType`, which the Swift overlay doesn't name.
    private static let anyInputEventType = CGEventType(rawValue: ~0)!
}
