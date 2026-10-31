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
        let result = Command.run("/usr/bin/pmset", ["-a", "disablesleep", disabled ? "1" : "0"])
        guard result.status == 0 else {
            reply(result.output.isEmpty ? "pmset exited with \(result.status)" : result.output)
            return
        }
        logger.notice("pmset -a disablesleep \(disabled ? 1 : 0)")
        reply(nil)
    }

    func resumeCameraLock(withReply reply: @escaping @Sendable (String?) -> Void) {
        IdleExit.arm()
        CameraLock.resume()
        reply(nil)
    }

    func setCameraLocked(_ locked: Bool, withReply reply: @escaping @Sendable (String?) -> Void) {
        IdleExit.arm()
        do {
            try CameraLock.set(locked: locked)
            logger.notice("Camera \(locked ? "locked" : "unlocked", privacy: .public)")
            reply(nil)
        } catch {
            logger.error("Camera Lock failed: \(error.localizedDescription, privacy: .public)")
            reply("Couldn't \(locked ? "lock" : "unlock") the camera: \(error.localizedDescription)")
        }
    }
}

/// Runs one of the fixed system tools the helper uses.
enum Command {
    static func run(_ path: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (-1, "Couldn't run \(path): \(error.localizedDescription)")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return (process.terminationStatus, output)
    }
}

/// Exits when a new Tapdeck replaced this helper's executable, so the new
/// helper takes over on the next connection (the app connects at launch).
/// Without this, a helper kept running by Camera Lock would outlive updates.
enum UpdateWatch {
    nonisolated(unsafe) private static var timer: DispatchSourceTimer?

    static func start() {
        guard let path = CameraLock.executablePath(of: getpid()), let original = identity(of: path) else { return }
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + 2, repeating: 2)
        source.setEventHandler {
            if identity(of: path) != original {
                logger.notice("A new helper was installed; exiting so it takes over")
                exit(0)
            }
        }
        source.resume()
        timer = source
    }

    private static func identity(of path: String) -> [Int]? {
        var info = stat()
        guard stat(path, &info) == 0 else { return nil }
        return [Int(info.st_ino), info.st_mtimespec.tv_sec, info.st_mtimespec.tv_nsec]
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
            // While the camera is locked the helper stays to keep the lock in place.
            let work = DispatchWorkItem { if !CameraLock.isLocked { exit(0) } }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
        }
    }
}
