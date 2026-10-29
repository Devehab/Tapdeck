import AppIntents
import SwiftUI
import WidgetKit

struct MicMuteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: ControlKind.micMute, provider: Provider()) { isMuted in
            // Red and a struck-through mic while muted; the menu bar shows only
            // the icon, so it alone must tell the two apart.
            ControlWidgetToggle("Microphone", isOn: isMuted, action: MicMuteIntent()) { isMuted in
                Label(isMuted ? "Muted" : "On", systemImage: isMuted ? "mic.slash.fill" : "mic.fill")
            }
            .tint(.red)
        }
        .displayName("Mic Mute")
        .description("Mute every microphone at the hardware level. Apps keep running and hear silence.")
    }

    /// Reads the real mute switch, so the control is right even when the mic
    /// was muted or unmuted somewhere else.
    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }

        func currentValue() async throws -> Bool {
            AudioInputs.isDefaultInputMuted
        }
    }
}
