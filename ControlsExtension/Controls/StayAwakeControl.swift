import AppIntents
import SwiftUI
import WidgetKit

struct StayAwakeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: ControlKind.stayAwake, provider: Provider()) { isOn in
            // Sun = the Mac stays awake, moon = it sleeps as usual. The menu bar
            // shows only the icon, so it alone must tell the two apart.
            ControlWidgetToggle("Stay Awake", isOn: isOn, action: StayAwakeIntent()) { isOn in
                Label(isOn ? "Won't Sleep" : "Sleeps Normally", systemImage: isOn ? "sun.max.fill" : "moon.zzz.fill")
            }
            .tint(.orange)
        }
        .displayName("Stay Awake")
        .description("Keep the Mac running even with the lid closed.")
    }

    /// Reads the live system setting, so the control is right even after
    /// `pmset` was changed from Terminal.
    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }

        func currentValue() async throws -> Bool {
            SystemSleep.isDisabled
        }
    }
}
