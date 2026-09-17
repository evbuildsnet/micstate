import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?

    func applicationDidFinishLaunching(_: Notification) {
        Prefs.register()
        controller = AppController()
    }

    func applicationWillTerminate(_: Notification) {
        controller?.shutdown()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(Variant.regularApp ? .regular : .accessory)
app.run()
