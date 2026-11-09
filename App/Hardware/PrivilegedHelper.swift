import AppKit
import ServiceManagement

/// The app's side of the root helper: installs it as a launchd daemon and
/// calls it over XPC.
///
/// Installing copies the helper to /Library/PrivilegedHelperTools and runs it
/// there as root, which takes an administrator's password once, and again
/// after an update: the installed helper only accepts the app build it was
/// installed for, and the app only talks to the helper it ships with.
@MainActor
final class PrivilegedHelper {
    static let shared = PrivilegedHelper()

    enum HelperError: LocalizedError {
        /// The password prompt was cancelled.
        case cancelled
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cancelled: "The Tapdeck helper wasn't installed."
            case .failed(let message): message
            }
        }
    }

    enum Status {
        case installed
        /// Installed for another build of Tapdeck, e.g. before an update.
        case outdated
        case notInstalled
    }

    private let bundledHelper = Bundle.main.bundleURL.appending(path: "Contents/MacOS/TapdeckHelper")

    var status: Status {
        guard let plist = NSDictionary(contentsOfFile: HelperInterface.launchdPlistPath),
              let arguments = plist["ProgramArguments"] as? [String]
        else { return .notInstalled }
        let trusted = arguments.firstIndex(of: "--client").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        let installed = HelperInterface.requirement(ofCodeAt: URL(fileURLWithPath: HelperInterface.installedHelperPath), identifier: HelperInterface.helperIdentifier)
        guard trusted == appRequirement, installed != nil, installed == helperRequirement else { return .outdated }
        return .installed
    }

    private var appRequirement: String? {
        HelperInterface.requirement(ofCodeAt: Bundle.main.bundleURL, identifier: HelperInterface.appIdentifier)
    }

    private var helperRequirement: String? {
        HelperInterface.requirement(ofCodeAt: bundledHelper, identifier: HelperInterface.helperIdentifier)
    }

    /// Installs the helper unless this build's helper is in place. macOS asks
    /// for an administrator's password; throws `cancelled` if it's dismissed.
    func ensureInstalled() async throws {
        if status == .installed { return }
        guard let appRequirement else { throw HelperError.failed("Can't read Tapdeck's signature. Reinstall Tapdeck.") }
        let target = HelperInterface.installedHelperPath
        try await runAsAdministrator(
            "/bin/mkdir -p /Library/PrivilegedHelperTools"
                + " && /usr/bin/ditto --noextattr --noqtn \(shellQuoted(bundledHelper.path)) \(shellQuoted(target))"
                + " && \(shellQuoted(target)) --install \(shellQuoted(appRequirement))",
            prompt: "Tapdeck wants to install its helper, so Stay Awake and Camera Lock can change system settings."
        )
        guard status == .installed else { throw HelperError.failed("The Tapdeck helper didn't install. Try again.") }
    }

    func uninstall() async throws {
        guard FileManager.default.fileExists(atPath: HelperInterface.installedHelperPath) else { return }
        try await runAsAdministrator(
            "\(shellQuoted(HelperInterface.installedHelperPath)) --uninstall",
            prompt: "Tapdeck wants to remove its helper."
        )
    }

    /// Versions up to 1.3 registered the helper through SMAppService. That
    /// registration is tied to their signing certificate, so drop it.
    func removeLegacyRegistration() {
        let legacy = SMAppService.daemon(plistName: HelperInterface.legacyLaunchdPlistName)
        guard legacy.status == .enabled || legacy.status == .requiresApproval else { return }
        try? legacy.unregister()
    }

    func setSleepDisabled(_ disabled: Bool) async throws {
        let failure: String? = try await call { helper, reply in
            helper.setSleepDisabled(disabled, withReply: reply)
        }
        if let failure { throw HelperError.failed(failure) }
    }

    func setCameraLocked(_ locked: Bool) async throws {
        let failure: String? = try await call { helper, reply in
            helper.setCameraLocked(locked, withReply: reply)
        }
        if let failure { throw HelperError.failed(failure) }
    }

    /// Never asks for a password: it runs at launch, and an older helper keeps
    /// a lock in place by itself until the next tap installs the new one.
    func resumeCameraLock() async throws {
        guard status == .installed else { return }
        let _: String? = try await call { helper, reply in
            helper.resumeCameraLock(withReply: reply)
        }
    }

    private func call<Value: Sendable>(
        _ send: (TapdeckHelperProtocol, @escaping @Sendable (Value) -> Void) -> Void
    ) async throws -> Value {
        try await ensureInstalled()
        guard let requirement = helperRequirement else {
            throw HelperError.failed("Can't read the Tapdeck helper's signature. Reinstall Tapdeck.")
        }
        let connection = NSXPCConnection(machServiceName: HelperInterface.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: TapdeckHelperProtocol.self)
        connection.setCodeSigningRequirement(requirement)
        connection.resume()
        defer { connection.invalidate() }

        return try await withCheckedThrowingContinuation { continuation in
            let once = ResumeOnce(continuation)
            // @Sendable: XPC calls this on its own queue, never the main actor.
            let proxy = connection.remoteObjectProxyWithErrorHandler { @Sendable error in
                once.resume(throwing: error)
            } as? TapdeckHelperProtocol
            guard let proxy else {
                once.resume(throwing: HelperError.failed("Couldn't reach the Tapdeck helper."))
                return
            }
            send(proxy) { @Sendable value in once.resume(returning: value) }
        }
    }

    // MARK: Administrator prompt

    /// Runs `command` as root through the standard macOS administrator prompt.
    private func runAsAdministrator(_ command: String, prompt: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "do shell script \(appleScriptQuoted(command)) with prompt \(appleScriptQuoted(prompt)) with administrator privileges"]
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = FileHandle.nullDevice
        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
        guard status != 0 else { return }
        let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        // -128: the user cancelled the prompt.
        if message.contains("-128") { throw HelperError.cancelled }
        throw HelperError.failed(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    private func appleScriptQuoted(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

/// XPC can report both a reply and a connection error for one call; a
/// continuation must be resumed exactly once.
private final class ResumeOnce<Value: Sendable>: @unchecked Sendable {
    private var continuation: CheckedContinuation<Value, Error>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: Value) {
        take()?.resume(returning: value)
    }

    func resume(throwing error: Error) {
        take()?.resume(throwing: error)
    }

    private func take() -> CheckedContinuation<Value, Error>? {
        lock.withLock {
            defer { continuation = nil }
            return continuation
        }
    }
}
