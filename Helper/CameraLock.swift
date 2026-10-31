import Darwin
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.ibtkrgo.Tapdeck", category: "Helper")

/// Camera Lock, the root half.
///
/// CoreMediaIO, which every app uses to reach a camera, lists no cameras when
/// the managed preference `Device Access Allowed` in
/// com.apple.coremediaio.support is false. Apple's camera restriction profile
/// works by writing exactly that; the helper writes it directly, so locking
/// needs no profile. Like macOS does after a profile change, the helper then
/// tells every process to drop its cached copy, and restarts the camera
/// services: apps already using a camera lose it, and when they ask again the
/// camera hub (registerassistantservice) re-reads the setting and refuses.
/// Unlocking restarts them too, so open apps find their cameras again.
///
/// macOS rewrites /Library/Managed Preferences when profiles change, so while
/// the camera is locked the helper stays running and puts the setting back.
enum CameraLock {
    private static let folder = URL(fileURLWithPath: "/Library/Managed Preferences")
    private static let domain = "com.apple.coremediaio.support"
    private static let file = folder.appending(path: "\(domain).plist")
    private static let key = "Device Access Allowed"

    /// Root-only record of the lock. launchd keeps the helper running while it
    /// exists (KeepAlive PathState); the app also asks the helper to resume
    /// the lock when it launches.
    private static let stateFile = URL(fileURLWithPath: "/Library/Application Support/com.ibtkrgo.Tapdeck/camera-locked")

    /// The camera hub and the services that stream camera video to apps:
    /// built-in cameras, USB cameras, DriverKit cameras and iPhone (Continuity)
    /// cameras. launchd starts them again on demand.
    private static let cameraServices: Set<String> = [
        "/System/Library/Frameworks/CoreMediaIO.framework/Versions/A/Resources/com.apple.cmio.registerassistantservice",
        "/usr/libexec/cameracaptured",
        "/usr/sbin/appleh13camerad",
        "/usr/sbin/appleh16camerad",
        "/System/Library/Frameworks/CoreMediaIO.framework/Versions/A/Resources/UVCAssistant.systemextension/Contents/MacOS/UVCAssistant",
        "/usr/libexec/com.apple.cmio.videodriverkithostextension.systemextension/Contents/MacOS/com.apple.cmio.videodriverkithostextension",
        "/usr/libexec/ContinuityCaptureAgent",
    ]

    nonisolated(unsafe) private static var guardTimer: DispatchSourceTimer?

    static var isLocked: Bool {
        FileManager.default.fileExists(atPath: stateFile.path)
    }

    static func set(locked: Bool) throws {
        if locked {
            try FileManager.default.createDirectory(at: stateFile.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try Data().write(to: stateFile)
            try apply()
            // Let running apps pick up the change before their cameras restart.
            Thread.sleep(forTimeInterval: 0.3)
            restartCameraServices()
            startGuarding()
        } else {
            try? FileManager.default.removeItem(at: stateFile)
            stopGuarding()
            try remove()
            Thread.sleep(forTimeInterval: 0.3)
            restartCameraServices()
        }
    }

    /// Called when the helper starts: puts a lock back that macOS removed
    /// while the helper wasn't running.
    static func resume() {
        guard isLocked else { return }
        try? apply()
        startGuarding()
    }

    private static func apply() throws {
        var preferences = NSDictionary(contentsOf: file) as? [String: Any] ?? [:]
        guard preferences[key] as? Bool != false else { return }
        preferences[key] = false
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try write(preferences)
        logger.notice("Camera access turned off")
    }

    private static func remove() throws {
        guard var preferences = NSDictionary(contentsOf: file) as? [String: Any], preferences[key] != nil else { return }
        preferences[key] = nil
        if preferences.isEmpty {
            try FileManager.default.removeItem(at: file)
            announceChange()
        } else {
            try write(preferences)
        }
        logger.notice("Camera access turned back on")
    }

    private static func write(_ preferences: [String: Any]) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: preferences, format: .binary, options: 0)
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
        announceChange()
    }

    /// What macOS's ManagedClient calls after rewriting managed preferences:
    /// cfprefsd and every process holding the domain drop their cached values.
    private static func announceChange() {
        typealias StatusChanged = @convention(c) (CFArray?) -> Void
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_CFPreferencesManagementStatusChangedForDomains") else {
            logger.error("Can't announce the camera setting change on this macOS")
            return
        }
        unsafeBitCast(symbol, to: StatusChanged.self)([domain] as CFArray)
    }

    private static func restartCameraServices() {
        var pids = [pid_t](repeating: 0, count: Int(proc_listallpids(nil, 0)) + 64)
        let count = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size)))
        var restarted: [String] = []
        for pid in pids.prefix(count) where pid > 0 {
            guard let path = executablePath(of: pid), cameraServices.contains(path) else { continue }
            if kill(pid, SIGTERM) == 0 {
                restarted.append((path as NSString).lastPathComponent)
            }
        }
        logger.notice("Restarted camera services: \(restarted.joined(separator: ", "), privacy: .public)")
    }

    static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }

    /// Checks every second that the setting is still in place.
    private static func startGuarding() {
        guard guardTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler {
            guard isLocked else { return }
            if (NSDictionary(contentsOf: file) as? [String: Any])?[key] as? Bool != false {
                logger.notice("Camera access setting was removed; putting it back")
                try? apply()
            }
        }
        timer.resume()
        guardTimer = timer
    }

    private static func stopGuarding() {
        guardTimer?.cancel()
        guardTimer = nil
    }
}
