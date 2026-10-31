import AppKit
import ServiceManagement

/// The app's side of the root helper: registers it with launchd through
/// SMAppService and calls it over XPC.
@MainActor
final class PrivilegedHelper {
    static let shared = PrivilegedHelper()

    enum HelperError: LocalizedError {
        case needsApproval
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .needsApproval: "The Tapdeck helper is waiting for approval in System Settings."
            case .failed(let message): message
            }
        }
    }

    private let service = SMAppService.daemon(plistName: HelperInterface.launchdPlistName)

    var status: SMAppService.Status { service.status }

    /// Registers the helper if needed. Throws `needsApproval` until it's turned
    /// on in System Settings → General → Login Items & Extensions.
    func ensureEnabled() throws {
        if service.status == .enabled { return }
        if service.status != .requiresApproval {
            do {
                try service.register()
            } catch {
                guard service.status == .requiresApproval else { throw error }
            }
        }
        guard service.status == .enabled else { throw HelperError.needsApproval }
    }

    func unregister() throws {
        try service.unregister()
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

    func resumeCameraLock() async throws {
        let _: String? = try await call { helper, reply in
            helper.resumeCameraLock(withReply: reply)
        }
    }

    private func call<Value: Sendable>(
        _ send: (TapdeckHelperProtocol, @escaping @Sendable (Value) -> Void) -> Void
    ) async throws -> Value {
        try ensureEnabled()
        let connection = NSXPCConnection(machServiceName: HelperInterface.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: TapdeckHelperProtocol.self)
        if let requirement = HelperInterface.requirement(forIdentifier: HelperInterface.helperIdentifier) {
            connection.setCodeSigningRequirement(requirement)
        }
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

    // MARK: Approval

    private var approvalWatch: Task<Void, Never>?

    /// Explains why the helper is needed, opens Login Items, and runs `then`
    /// as soon as the helper is approved.
    func askForApproval(title: String, message: String, then: @escaping @MainActor () async -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        SMAppService.openSystemSettingsLoginItems()

        approvalWatch?.cancel()
        approvalWatch = Task {
            for _ in 0..<300 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                if status == .enabled {
                    await then()
                    return
                }
            }
        }
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
