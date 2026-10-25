import Foundation
import IOKit

enum SystemSleep {
    /// Whether `pmset -a disablesleep 1` is in effect (pmset shows it as
    /// `SleepDisabled`). Read from the power-management root domain, which needs
    /// no privileges and works inside the extension's sandbox.
    static var isDisabled: Bool {
        let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard rootDomain != 0 else { return false }
        defer { IOObjectRelease(rootDomain) }
        let value = IORegistryEntryCreateCFProperty(rootDomain, "SleepDisabled" as CFString, kCFAllocatorDefault, 0)
        return (value?.takeRetainedValue() as? Bool) ?? false
    }

    static func waitUntil(disabled: Bool, timeout: Duration) async {
        let deadline = ContinuousClock.now + timeout
        while isDisabled != disabled, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
