import LocalAuthentication

/// Touch ID with no password fallback, so Camera Lock opens with a finger only.
enum TouchID {
    /// Why Touch ID can't be used right now, or nil when it can.
    static var unavailableReason: LAError.Code? {
        var error: NSError?
        if LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return nil
        }
        return error.map { LAError.Code(rawValue: $0.code) ?? .biometryNotAvailable } ?? .biometryNotAvailable
    }

    static var isReady: Bool { unavailableReason == nil }

    /// Shows the Touch ID prompt: “Tapdeck is trying to <reason>.”
    static func authenticate(reason: String) async throws {
        let context = LAContext()
        // An empty title hides the “Use Password…” button.
        context.localizedFallbackTitle = ""
        try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
    }

    /// One sentence on what to do when Touch ID can't be used.
    static func advice(for code: LAError.Code) -> String {
        switch code {
        case .biometryNotEnrolled:
            "Add a fingerprint in System Settings › Touch ID & Password."
        case .biometryLockout:
            "Touch ID is paused after too many tries. Lock the screen and sign in with your password once to turn it back on."
        default:
            "This Mac can't use Touch ID right now. If the MacBook lid is closed, open it, or connect your Magic Keyboard with Touch ID."
        }
    }
}
