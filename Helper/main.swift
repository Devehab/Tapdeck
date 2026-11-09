import Foundation

// TapdeckHelper: a root launchd daemon. The app copies it to
// /Library/PrivilegedHelperTools and runs `--install` there as root, after
// the user enters an administrator's password. launchd then starts it on
// demand when the app connects, and it quits after a short idle period.

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "--install":
    exit(Installer.install(trusting: arguments.dropFirst().first))
case "--uninstall":
    exit(Installer.uninstall())
default:
    break
}

// The launchd plist passes the requirement of the app build it was installed
// for; only that build can connect.
guard let index = arguments.firstIndex(of: "--client"), arguments.indices.contains(index + 1) else {
    fatalError("Started without --client; refusing to accept connections")
}
let listener = NSXPCListener(machServiceName: HelperInterface.machServiceName)
let listenerDelegate = HelperListenerDelegate()
listener.setConnectionCodeSigningRequirement(arguments[index + 1])
listener.delegate = listenerDelegate
listener.resume()
CameraLock.resume()
UpdateWatch.start()
IdleExit.arm()
dispatchMain()
