import AppIntents

struct LightsOutIntent: AppIntent {
    static let title: LocalizedStringResource = "Lights Out"

    static var description: IntentDescription {
        IntentDescription("Turns off the screen and keyboard backlight while the Mac keeps running. Touch the trackpad or press any key to bring them back.")
    }

    func perform() async throws -> some IntentResult {
        try await TapdeckAction.lightsOut.run()
        return .result()
    }
}
