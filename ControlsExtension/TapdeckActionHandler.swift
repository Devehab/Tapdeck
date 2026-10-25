import AppKit

/// The extension side of `TapdeckAction`: forwards the action to the app, which
/// launches in the background if needed and never takes focus.
enum TapdeckActionHandler {
    @MainActor
    static func handle(_ action: TapdeckAction) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        try await NSWorkspace.shared.open(action.url, configuration: configuration)
    }
}
