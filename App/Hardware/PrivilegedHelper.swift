import Foundation
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
        try ensureEnabled()
        let connection = NSXPCConnection(machServiceName: HelperInterface.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: TapdeckHelperProtocol.self)
        if let requirement = HelperInterface.requirement(forIdentifier: HelperInterface.helperIdentifier) {
            connection.setCodeSigningRequirement(requirement)
        }
        connection.resume()
        defer { connection.invalidate() }

        let failure: String? = try await withCheckedThrowingContinuation { continuation in
            let once = ResumeOnce(continuation)
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                once.resume(throwing: error)
            } as? TapdeckHelperProtocol
            guard let proxy else {
                once.resume(throwing: HelperError.failed("Couldn't reach the Tapdeck helper."))
                return
            }
            proxy.setSleepDisabled(disabled) { message in
                once.resume(returning: message)
            }
        }
        if let failure { throw HelperError.failed(failure) }
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
