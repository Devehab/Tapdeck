import Foundation
import OSLog

/// Lets browser extensions talk to Tapdeck through Chrome's native messaging:
/// the browser starts this binary when an extension sends a message, passes
/// JSON over stdin and stdout, and the process exits when the extension is
/// done. Nothing listens on a port and nothing stays running.
///
/// Each message is a 32-bit length in native byte order followed by that many
/// bytes of UTF-8 JSON, both ways. Requests look like
/// `{"command": "mic", "action": "toggle"}`; every reply carries the full state.
@MainActor
enum NativeMessagingHost {
    static let name = "com.ibtkrgo.tapdeck"

    /// The sample extension in `extensions/chrome`. Its manifest carries a fixed
    /// public key, so it gets this ID wherever it's loaded from.
    static let sampleExtensionID = "jcpfohebbppapakgjnigbikckpfjinci"

    private static let logger = Logger(subsystem: "com.ibtkrgo.Tapdeck", category: "NativeMessaging")
    private static let maxMessageSize = 1024 * 1024

    /// Chrome starts the host with the calling extension's origin as the first argument.
    static func run(origin: String) -> Int32 {
        logger.notice("Connected: \(origin, privacy: .public)")
        while let request = readMessage() {
            writeMessage(reply(to: request))
        }
        return 0
    }

    private static func reply(to request: Data) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let object = try? JSONSerialization.jsonObject(with: request) as? [String: Any],
              let tool = object["command"] as? String
        else {
            return errorReply("Send a JSON object such as {\"command\": \"status\"} or {\"command\": \"mic\", \"action\": \"toggle\"}.", encoder)
        }
        guard let command = TapdeckCommand(tool: tool, action: object["action"] as? String) else {
            return errorReply("Unknown command “\(tool)” with action “\(object["action"] as? String ?? "")”. Commands: status, mic, camera, awake, lights.", encoder)
        }
        logger.notice("Request: \(tool, privacy: .public) \(object["action"] as? String ?? "status", privacy: .public)")
        return (try? encoder.encode(CommandRunner.run(command))) ?? Data("{}".utf8)
    }

    private static func errorReply(_ message: String, _ encoder: JSONEncoder) -> Data {
        let response = CommandRunner.Response(ok: false, state: .current(), error: message)
        return (try? encoder.encode(response)) ?? Data("{}".utf8)
    }

    // MARK: Framing

    private static func readMessage() -> Data? {
        guard let header = readExactly(4) else { return nil }
        let length = Int(header.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        guard length > 0, length <= maxMessageSize else { return nil }
        return readExactly(length)
    }

    private static func readExactly(_ count: Int) -> Data? {
        var data = Data()
        while data.count < count {
            guard let chunk = try? FileHandle.standardInput.read(upToCount: count - data.count), !chunk.isEmpty else {
                return nil
            }
            data.append(chunk)
        }
        return data
    }

    private static func writeMessage(_ message: Data) {
        var length = UInt32(message.count)
        let header = withUnsafeBytes(of: &length) { Data($0) }
        try? FileHandle.standardOutput.write(contentsOf: header + message)
    }

    // MARK: Installing the host for browsers

    /// Chromium-based browsers each look in their own NativeMessagingHosts folder.
    static let browsers: [(name: String, folder: String)] = [
        ("Google Chrome", "Google/Chrome"),
        ("Chrome Beta", "Google/Chrome Beta"),
        ("Chrome Canary", "Google/Chrome Canary"),
        ("Chromium", "Chromium"),
        ("Brave", "BraveSoftware/Brave-Browser"),
        ("Microsoft Edge", "Microsoft Edge"),
        ("Arc", "Arc/User Data"),
        ("Vivaldi", "Vivaldi"),
    ]

    private static var applicationSupport: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
    }

    private static func manifestURL(in folder: String) -> URL {
        applicationSupport.appending(path: folder).appending(path: "NativeMessagingHosts/\(name).json")
    }

    /// Writes the host manifest for every installed browser, allowing the sample
    /// extension plus `extensionIDs`. IDs already allowed are kept.
    static func install(extensionIDs: [String]) -> [(browser: String, file: URL, origins: [String])] {
        guard let executable = Bundle.main.executablePath else { return [] }
        var results: [(String, URL, [String])] = []
        for browser in browsers where FileManager.default.fileExists(atPath: applicationSupport.appending(path: browser.folder).path) {
            let url = manifestURL(in: browser.folder)
            var origins = existingOrigins(at: url)
            for id in [sampleExtensionID] + extensionIDs {
                let origin = "chrome-extension://\(id)/"
                if !origins.contains(origin) { origins.append(origin) }
            }
            let manifest: [String: Any] = [
                "name": name,
                "description": "Tapdeck: Mic Mute, Camera Lock, Stay Awake and Lights Out",
                "path": executable,
                "type": "stdio",
                "allowed_origins": origins,
            ]
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
                try data.write(to: url)
                results.append((browser.name, url, origins))
            } catch {
                logger.error("Couldn't write \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return results
    }

    static func uninstall() -> [URL] {
        browsers.map { manifestURL(in: $0.folder) }.filter { (try? FileManager.default.removeItem(at: $0)) != nil }
    }

    static func installed() -> [(browser: String, file: URL, origins: [String])] {
        browsers.compactMap { browser in
            let url = manifestURL(in: browser.folder)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return (browser.name, url, existingOrigins(at: url))
        }
    }

    private static func existingOrigins(at url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        return manifest["allowed_origins"] as? [String] ?? []
    }

    static func isValidExtensionID(_ id: String) -> Bool {
        id.count == 32 && id.allSatisfy { ("a"..."p").contains($0) }
    }
}
