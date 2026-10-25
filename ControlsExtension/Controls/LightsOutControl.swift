import AppIntents
import SwiftUI
import WidgetKit

struct LightsOutControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: ControlKind.lightsOut) {
            ControlWidgetButton(action: LightsOutIntent()) {
                Label("Lights Out", systemImage: "lightbulb.slash")
            }
        }
        .displayName("Lights Out")
        .description("Turn off the screen and keyboard light while the Mac keeps running. Touch the trackpad or press a key to bring them back.")
    }
}
