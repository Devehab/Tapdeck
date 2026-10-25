import Foundation

// TapdeckHelper: a root launchd daemon that the app registers with
// SMAppService and the user approves once. launchd starts it on demand when the
// app connects, and it quits after a short idle period.

let listener = NSXPCListener(machServiceName: HelperInterface.machServiceName)
let listenerDelegate = HelperListenerDelegate()

guard let clientRequirement = HelperInterface.requirement(forIdentifier: HelperInterface.appIdentifier) else {
    fatalError("Helper is not code-signed by a team; refusing to accept connections")
}
listener.setConnectionCodeSigningRequirement(clientRequirement)
listener.delegate = listenerDelegate
listener.resume()
IdleExit.arm()
dispatchMain()
