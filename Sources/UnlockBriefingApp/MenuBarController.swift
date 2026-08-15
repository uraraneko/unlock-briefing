import AppKit

final class MenuBarController {
    private var item: NSStatusItem?
    var onOpenWindow: (() -> Void)?
    var onSyncNow: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onToggleLoginItem: ((Bool) -> Void)?
    var onQuit: (() -> Void)?
    var loginItemEnabled: () -> Bool = { false }

    func apply(visible: Bool) {
        if visible {
            if item == nil {
                let created = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                created.button?.image = NSImage(systemSymbolName: "list.bullet.clipboard", accessibilityDescription: "Unlock Briefing")
                created.button?.image?.isTemplate = true
                created.menu = buildMenu()
                item = created
            } else {
                item?.menu = buildMenu()
            }
        } else if let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    func refresh() {
        item?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(menuItem("打开窗口", #selector(openWindow)))
        menu.addItem(menuItem("立即同步", #selector(syncNow)))
        menu.addItem(.separator())
        let login = menuItem("开机启动", #selector(toggleLogin))
        login.state = loginItemEnabled() ? .on : .off
        menu.addItem(login)
        menu.addItem(menuItem("设置…", #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(menuItem("退出", #selector(quit)))
        return menu
    }

    private func menuItem(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openWindow() { onOpenWindow?() }
    @objc private func syncNow() { onSyncNow?() }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func quit() { onQuit?() }

    @objc private func toggleLogin() {
        onToggleLoginItem?(!loginItemEnabled())
        refresh()
    }
}
