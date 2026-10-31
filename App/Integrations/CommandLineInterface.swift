import Foundation

/// `tapdeck` in Terminal. The same binary is the app, the command and the
/// browser host; `main()` comes here first and only starts the app when the
/// arguments aren't a command.
@MainActor
enum CommandLineInterface {
    /// Returns an exit code for a command, or nil to launch the app normally.
    static func run(_ arguments: [String]) -> Int32? {
        guard let first = arguments.first else { return nil }
        if first.hasPrefix("chrome-extension://") {
            return NativeMessagingHost.run(origin: first)
        }
        // macOS and Xcode can pass flags such as -NSDocumentRevisionsDebugMode
        // when launching the app; those aren't commands.
        let ownFlags: Set = ["--status", "--unregister-helper", "--help", "-h", "--version"]
        if first.hasPrefix("-"), !ownFlags.contains(first) {
            return nil
        }

        let json = arguments.contains("--json")
        let words = arguments.filter { !$0.hasPrefix("-") }
        switch first {
        case "--status":
            StatusReport.print()
            return 0
        case "--unregister-helper":
            return unregisterHelper()
        case "help", "--help", "-h":
            print(usage)
            return 0
        case "version", "--version":
            print("Tapdeck \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
            return 0
        case "install-cli":
            return installCLI(into: words.dropFirst().first)
        case "chrome", "browser":
            return chrome(Array(words.dropFirst()))
        default:
            break
        }

        guard let command = TapdeckCommand(tool: first, action: words.dropFirst().first) else {
            FileHandle.standardError.write(Data("tapdeck: unknown command “\(arguments.joined(separator: " "))”\n\n\(usage)\n".utf8))
            return 2
        }
        if command == .status, arguments.contains("--verbose") {
            StatusReport.print()
            return 0
        }
        let response = CommandRunner.run(command)
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: (try? encoder.encode(response)) ?? Data(), as: UTF8.self))
        } else {
            printState(response.state)
            if let error = response.error {
                FileHandle.standardError.write(Data("\n\(error)\n".utf8))
            }
        }
        return response.ok ? 0 : 1
    }

    private static func printState(_ state: TapdeckState) {
        var mic = state.micMute.muted ? "Muted" : "On"
        if let input = state.micMute.input {
            mic += "  (\(input)\(state.micMute.canMute ? "" : ", can't be muted"))"
        }
        var camera = state.cameraLock.locked ? "Locked" : "On"
        if !state.cameraLock.touchID {
            camera += "  (Camera Lock needs Touch ID)"
        }
        var awake = state.stayAwake.on ? "Won't Sleep" : "Sleeps Normally"
        if state.stayAwake.helper != "enabled" {
            awake += "  (needs one-time approval)"
        }
        print("Microphone   \(mic)")
        print("Camera       \(camera)")
        print("Stay Awake   \(awake)")
        print("Lights Out   \(state.lightsOut.out ? "Out" : "Off")")
    }

    private static let usage = """
        Usage: tapdeck <command> [--json]

          status                       Show every tool's state (--verbose for diagnostics)
          mic [mute|unmute|toggle]     Mic Mute: mute every microphone at the hardware level
          camera [lock|unlock|toggle]  Camera Lock: turn every camera off; only Touch ID unlocks
          awake [on|off|toggle]        Stay Awake: keep the Mac running, even with the lid closed
          lights [out|on]              Lights Out: screen and keyboard light off; any touch restores

          chrome install [ID…]         Let browser extensions talk to Tapdeck (the sample
                                       extension is always allowed; add your own IDs)
          chrome status                Show which browsers and extensions are allowed
          chrome uninstall             Remove the browser connection
          install-cli [folder]         Put the `tapdeck` command on your PATH (~/.local/bin by default)

        A tool without an action prints its state. --json prints {"ok", "state", "error"}.
        Exit codes: 0 done, 1 the change didn't happen (see the message), 2 usage error.
        """

    // MARK: Browser connection

    private static func chrome(_ words: [String]) -> Int32 {
        switch words.first {
        case "install":
            let ids = Array(words.dropFirst())
            if let bad = ids.first(where: { !NativeMessagingHost.isValidExtensionID($0) }) {
                FileHandle.standardError.write(Data("tapdeck: “\(bad)” isn't an extension ID. Copy the 32-letter ID from chrome://extensions.\n".utf8))
                return 2
            }
            if !(Bundle.main.bundlePath.hasPrefix("/Applications/")) {
                FileHandle.standardError.write(Data("Note: Tapdeck is running from \(Bundle.main.bundlePath). Browsers will start this copy; install it in /Applications first if that's not what you want.\n".utf8))
            }
            let results = NativeMessagingHost.install(extensionIDs: ids)
            guard !results.isEmpty else {
                FileHandle.standardError.write(Data("tapdeck: no Chromium-based browser found (Chrome, Brave, Edge, Arc, Vivaldi or Chromium). Open the browser once, then try again.\n".utf8))
                return 1
            }
            for result in results {
                print("✓ \(result.browser): \(result.file.path)")
                result.origins.forEach { print("    allows \($0)") }
            }
            print("\nReload the extension in chrome://extensions, then open its popup.")
            return 0
        case "uninstall":
            let removed = NativeMessagingHost.uninstall()
            removed.forEach { print("Removed \($0.path)") }
            if removed.isEmpty { print("Nothing to remove.") }
            return 0
        case "status", nil:
            let installed = NativeMessagingHost.installed()
            if installed.isEmpty {
                print("No browser is connected. Run: tapdeck chrome install")
            }
            for item in installed {
                print("\(item.browser): \(item.file.path)")
                item.origins.forEach { print("    allows \($0)") }
            }
            return 0
        default:
            print(usage)
            return 2
        }
    }

    // MARK: Install the command

    private static func installCLI(into folder: String?) -> Int32 {
        guard let executable = Bundle.main.executablePath else { return 1 }
        let directory = URL(fileURLWithPath: NSString(string: folder ?? "~/.local/bin").expandingTildeInPath)
        let target = directory.appending(path: "tapdeck")
        // A small script rather than a symlink, so Tapdeck always runs from
        // inside its app bundle and finds its settings and helper.
        let script = """
            #!/bin/sh
            # Installed by Tapdeck. Runs Tapdeck's command-line interface.
            exec "\(executable)" "$@"

            """
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try script.write(to: target, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)
        } catch {
            FileHandle.standardError.write(Data("tapdeck: couldn't write \(target.path): \(error.localizedDescription)\n".utf8))
            return 1
        }
        print("Installed \(target.path)")
        let path = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        if !path.contains(directory.path) {
            print("\(directory.path) isn't on your PATH yet. Add this line to ~/.zshrc:\n    export PATH=\"\(directory.path):$PATH\"")
        }
        return 0
    }

    private static func unregisterHelper() -> Int32 {
        do {
            try PrivilegedHelper.shared.unregister()
            print("Root helper unregistered.")
            return 0
        } catch {
            print("Couldn't unregister the root helper: \(error.localizedDescription)")
            return 1
        }
    }
}
