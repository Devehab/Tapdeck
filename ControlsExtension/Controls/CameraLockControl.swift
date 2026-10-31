import AppIntents
import SwiftUI
import WidgetKit

struct CameraLockControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: ControlKind.cameraLock, provider: Provider()) { isLocked in
            // Red and a struck-through camera while locked; the menu bar shows
            // only the icon, so it alone must tell the two apart.
            ControlWidgetToggle("Camera", isOn: isLocked, action: CameraLockIntent()) { isLocked in
                Label(isLocked ? "Locked" : "On", systemImage: isLocked ? "video.slash.fill" : "video.fill")
            }
            .tint(.red)
        }
        .displayName("Camera Lock")
        .description("Turn off every camera on this Mac. Only Touch ID turns them back on.")
    }

    /// Reads the camera setting macOS enforces, so the control is right even
    /// when the camera was locked from Terminal or a browser extension.
    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }

        func currentValue() async throws -> Bool {
            CameraLockState.isLocked
        }
    }
}
