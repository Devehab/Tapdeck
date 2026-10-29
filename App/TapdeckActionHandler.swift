/// The app side of `TapdeckAction`: does the actual work for each control.
enum TapdeckActionHandler {
    @MainActor
    static func handle(_ action: TapdeckAction) async throws {
        switch action {
        case .lightsOut:
            LightsOutController.shared.toggle()
        case .stayAwakeOn:
            await StayAwakeController.shared.set(true)
        case .stayAwakeOff:
            await StayAwakeController.shared.set(false)
        case .micMuteOn:
            MicMuteController.shared.set(muted: true)
        case .micMuteOff:
            MicMuteController.shared.set(muted: false)
        }
    }
}
