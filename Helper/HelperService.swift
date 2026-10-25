import Foundation
import OSLog

private let logger = Logger(subsystem: "com.ibtkrgo.Tapdeck", category: "Helper")

final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // The listener's code-signing requirement has already vetted the caller.
        connection.exportedInterface = NSXPCInterface(with: TapdeckHelperProtocol.self)
        connection.exportedObject = HelperService()
        connection.resume()
        IdleExit.arm()
        return true
    }
}

final class HelperService: NSObject, TapdeckHelperProtocol {
    func setSleepDisabled(_ disabled: Bool, withReply reply: @escaping @Sendable (String?) -> Void) {
        IdleExit.arm()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-a", "disablesleep", disabled ? "1" : "0"]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            reply("Couldn't run pmset: \(error.localizedDescription)")
            return
        }
        guard process.terminationStatus == 0 else {
            let output = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            reply(output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "pmset exited with \(process.terminationStatus)")
            return
        }
        logger.notice("pmset -a disablesleep \(disabled ? 1 : 0)")
        reply(nil)
    }
}

/// Exits once nothing has used the helper for a while; launchd relaunches it
/// on the next connection. This also lets a reinstalled helper take over.
enum IdleExit {
    private static let timeout: DispatchTimeInterval = .seconds(30)
    nonisolated(unsafe) private static var pending: DispatchWorkItem?

    static func arm() {
        DispatchQueue.main.async {
            pending?.cancel()
            let work = DispatchWorkItem { exit(0) }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
        }
    }
}
