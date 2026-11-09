import Foundation

/// Installs and removes the helper as a classic launchd daemon. Both run as
/// root from the copy at `HelperInterface.installedHelperPath`.
///
/// Releases are ad-hoc signed, and SMAppService ties a daemon to the code hash
/// of the build that first registered it, so after an update launchd would
/// refuse the new helper. A daemon in /Library/LaunchDaemons has no such tie;
/// the app reinstalls it when either half of Tapdeck changes.
enum Installer {
    static func install(trusting client: String?) -> Int32 {
        guard getuid() == 0 else { return fail("--install must run as root") }
        guard let client, !client.isEmpty else { return fail("--install needs the app's code requirement") }
        let helper = HelperInterface.installedHelperPath
        let plistPath = HelperInterface.launchdPlistPath
        let plist: [String: Any] = [
            "Label": HelperInterface.machServiceName,
            "ProgramArguments": [helper, "--client", client],
            "MachServices": [HelperInterface.machServiceName: true],
            // Keeps the helper running while the camera is locked, also after a restart.
            "KeepAlive": ["PathState": [CameraLock.stateFilePath: true]],
        ]
        do {
            let rootOnly: [FileAttributeKey: Any] = [.ownerAccountID: 0, .groupOwnerAccountID: 0]
            try FileManager.default.setAttributes(rootOnly.merging([.posixPermissions: 0o755]) { $1 }, ofItemAtPath: helper)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: URL(fileURLWithPath: plistPath), options: .atomic)
            try FileManager.default.setAttributes(rootOnly.merging([.posixPermissions: 0o644]) { $1 }, ofItemAtPath: plistPath)
        } catch {
            return fail("Couldn't write the helper's files: \(error.localizedDescription)")
        }

        // Replace a running helper; launchd may need a moment to let go of it.
        _ = Command.run("/bin/launchctl", ["bootout", "system/\(HelperInterface.machServiceName)"])
        var result = (status: Int32(-1), output: "")
        for _ in 0..<10 {
            result = Command.run("/bin/launchctl", ["bootstrap", "system", plistPath])
            if result.status == 0 { return 0 }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return fail("launchctl bootstrap failed: \(result.output)")
    }

    static func uninstall() -> Int32 {
        guard getuid() == 0 else { return fail("--uninstall must run as root") }
        _ = Command.run("/bin/launchctl", ["bootout", "system/\(HelperInterface.machServiceName)"])
        try? FileManager.default.removeItem(atPath: HelperInterface.launchdPlistPath)
        try? FileManager.default.removeItem(atPath: HelperInterface.installedHelperPath)
        return 0
    }

    private static func fail(_ message: String) -> Int32 {
        FileHandle.standardError.write(Data("TapdeckHelper: \(message)\n".utf8))
        return 1
    }
}
