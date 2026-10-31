import Foundation
import Security

/// What the root helper can do. Kept deliberately small: the helper runs as
/// root, so it offers fixed operations only, never arbitrary commands.
@objc protocol TapdeckHelperProtocol {
    /// Runs `pmset -a disablesleep 1` or `0`. Replies nil on success, otherwise an error message.
    func setSleepDisabled(_ disabled: Bool, withReply reply: @escaping @Sendable (String?) -> Void)

    /// Turns every camera off for all apps, cutting cameras already in use, or
    /// back on. Replies nil on success, otherwise an error message.
    func setCameraLocked(_ locked: Bool, withReply reply: @escaping @Sendable (String?) -> Void)

    /// Makes sure a lock that's on stays in place, e.g. after an update
    /// replaced the helper. Replies nil.
    func resumeCameraLock(withReply reply: @escaping @Sendable (String?) -> Void)
}

/// Names and code-signing checks shared by the app and the helper.
enum HelperInterface {
    static let machServiceName = "com.ibtkrgo.Tapdeck.Helper"
    static let launchdPlistName = "com.ibtkrgo.Tapdeck.Helper.plist"
    static let appIdentifier = "com.ibtkrgo.Tapdeck"
    static let helperIdentifier = "com.ibtkrgo.Tapdeck.Helper"

    /// A code requirement matching `identifier` signed by the same team as the
    /// running process, so each side only talks to the other half of this app.
    static func requirement(forIdentifier identifier: String) -> String? {
        guard let team = currentTeamID() else { return nil }
        return #"anchor apple generic and identifier "\#(identifier)" and certificate leaf[subject.OU] = "\#(team)""#
    }

    private static func currentTeamID() -> String? {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess
        else { return nil }
        return (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
