import SwiftUI
import WidgetKit

/// Every control Tapdeck offers in Control Center and the menu bar.
@main
struct TapdeckBundle: WidgetBundle {
    var body: some Widget {
        LightsOutControl()
        StayAwakeControl()
        MicMuteControl()
    }
}
