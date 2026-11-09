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
    /// The helper's launchd label and XPC service. Versions up to 1.3
    /// registered "com.ibtkrgo.Tapdeck.Helper" through SMAppService instead.
    static let machServiceName = "com.ibtkrgo.Tapdeck.PrivilegedHelper"
    static let legacyLaunchdPlistName = "com.ibtkrgo.Tapdeck.Helper.plist"
    static let appIdentifier = "com.ibtkrgo.Tapdeck"
    static let helperIdentifier = "com.ibtkrgo.Tapdeck.Helper"

    /// Where the app installs the helper, as root, after asking for an
    /// administrator's password. Root owns both files, so no app can swap them.
    static let installedHelperPath = "/Library/PrivilegedHelperTools/\(machServiceName)"
    static let launchdPlistPath = "/Library/LaunchDaemons/\(machServiceName).plist"

    /// A code requirement that only the app or helper of the build at hand
    /// meets: the designated requirement of the code at `url`. Releases are
    /// ad-hoc signed, so that's its exact code hash. A build signed with a
    /// certificate gets that certificate's requirement instead.
    static func requirement(ofCodeAt url: URL, identifier: String) -> String? {
        var staticCode: SecStaticCode?
        var requirement: SecRequirement?
        var text: CFString?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopyDesignatedRequirement(staticCode, [], &requirement) == errSecSuccess, let requirement,
              SecRequirementCopyString(requirement, [], &text) == errSecSuccess, let text
        else { return nil }
        return #"identifier "\#(identifier)" and (\#(text as String))"#
    }
}
