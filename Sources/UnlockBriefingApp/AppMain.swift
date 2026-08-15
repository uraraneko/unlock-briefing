#if canImport(UnlockBriefingCore)
import UnlockBriefingCore
#endif
import AppKit
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppMenu.install()
        coordinator.start()
        LaunchProbe.log()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

enum LaunchProbe {
    static func log() {
        let policy = NSApp.activationPolicy().rawValue
        let lsui = Bundle.main.object(forInfoDictionaryKey: "LSUIElement") ?? "missing"
        let lines = [
            "UnlockBriefing started",
            "activationPolicy=\(policy)",
            "LSUIElement=\(lsui)",
        ]
        let blob = lines.joined(separator: "\n") + "\n"
        if let data = blob.data(using: .utf8) {
            FileHandle.standardError.write(data)
            FileHandle.standardOutput.write(data)
        }
        fflush(stdout)
        fflush(stderr)
        NSLog("%@", blob)
    }
}
