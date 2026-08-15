#if canImport(UnlockBriefingCore)
import UnlockBriefingCore
#endif
import AppKit
import SwiftUI

final class MainWindowController: NSObject, NSWindowDelegate {
    weak var coordinator: AppCoordinator?
    private var window: NSWindow?

    var isVisible: Bool {
        window?.isVisible == true
    }

    func show() {
        if window == nil {
            guard let coordinator else { return }
            let host = NSHostingController(rootView: MainWindowView(coordinator: coordinator))
            let window = NSWindow(contentViewController: host)
            window.title = "今日简报"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 520, height: 600))
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

final class SettingsWindowController: NSObject, NSWindowDelegate {
    weak var coordinator: AppCoordinator?
    private var window: NSWindow?

    func show() {
        if window == nil {
            guard let coordinator else { return }
            let host = NSHostingController(rootView: SettingsWindowView(coordinator: coordinator))
            let window = NSWindow(contentViewController: host)
            window.title = "设置"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 460, height: 280))
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.orderOut(nil)
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
