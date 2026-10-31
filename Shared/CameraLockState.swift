import Foundation

enum CameraLockState {
    private static let file = URL(fileURLWithPath: "/Library/Managed Preferences/com.apple.coremediaio.support.plist")

    /// Whether CoreMediaIO hides every camera from apps: the managed
    /// preference `Device Access Allowed` is false. It's read from the file
    /// rather than through CFPreferences, which can keep a stale copy in a
    /// long-running process. The file is world-readable; the extension's
    /// sandbox has a read-only exception for it.
    static var isLocked: Bool {
        (NSDictionary(contentsOf: file)?["Device Access Allowed"] as? Bool) == false
    }

    static func waitUntil(locked: Bool, timeout: Duration) async {
        let deadline = ContinuousClock.now + timeout
        while isLocked != locked, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
    }
}
