#if canImport(UnlockBriefingCore)
import UnlockBriefingCore
#endif
import AppKit
import SwiftUI

/// Unlock / hotkey / HUD / main window / menu bar / login item.
final class AppCoordinator: NSObject, ObservableObject {
    @Published var settings: AppSettings
    @Published var document: ContentDocument = .empty
    @Published var editDrafts: ContentDocument = .empty
    @Published var gitStatus: GitSyncStatus = .idle
    @Published var needsSettingsGuide = true
    @Published var isEditing = false
    @Published var lastError: String?

    let git: GitSyncService
    let paths: AppPaths
    let session = BriefingSession()

    private let hotkey = HotkeyMonitor()
    private let hud = UnlockHUDController()
    private let menuBar = MenuBarController()
    private let mainWindow = MainWindowController()
    private let settingsWindow = SettingsWindowController()
    private let gitQueue = DispatchQueue(label: "com.chenenci.UnlockBriefing.git")
    private var unlockWork: DispatchWorkItem?

    override init() {
        let paths = AppPaths.default()
        self.paths = paths
        self.git = GitSyncService(paths: paths)
        self.settings = git.loadSettings()
        super.init()
        mainWindow.coordinator = self
        settingsWindow.coordinator = self
    }

    func start() {
        bindChrome()
        applyMenuBar()
        applyLoginItemOnLaunch()
        hotkey.registerDefault()
        hotkey.onPressed = { [weak self] in
            self?.toggleMainWindow()
        }
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenUnlocked(_:)),
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        reloadContent(triggerSync: false)
    }

    func toggleMainWindow() {
        if mainWindow.isVisible {
            mainWindow.close()
        } else {
            openMainWindow(editing: false)
        }
    }

    func openMainWindow(editing: Bool) {
        reloadContent(triggerSync: false)
        session.document = document
        session.prepareWindow(editing: editing)
        publishSession()
        mainWindow.show()
        if settings.autoSyncOnToggle {
            startBackgroundSync()
        }
    }

    func beginEditing() {
        session.document = document
        session.enterEditFromCurrentDocument()
        publishSession()
    }

    func cancelEditing() {
        session.cancelEditing()
        publishSession()
    }

    func saveEdits() {
        session.editDrafts = editDrafts
        saveDocument(session.documentForSave())
    }

    func openSettings() {
        if !mainWindow.isVisible {
            openMainWindow(editing: false)
        }
        settingsWindow.show()
    }

    func closeSettings() {
        settingsWindow.close()
    }

    func applyMenuBar() {
        menuBar.apply(visible: settings.showMenuBar)
        menuBar.refresh()
    }

    func setShowMenuBar(_ show: Bool) {
        settings.showMenuBar = show
        persistSettings()
        applyMenuBar()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemService.setEnabled(enabled)
            settings.launchAtLogin = enabled
            persistSettings()
            lastError = nil
        } catch {
            lastError = "登录项设置失败：\(error.localizedDescription)"
        }
        menuBar.refresh()
        objectWillChange.send()
    }

    func saveRepoURL(_ raw: String) {
        settings.repoURL = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        persistSettings()
        reloadContent(triggerSync: true)
    }

    func saveDocument(_ document: ContentDocument) {
        do {
            try git.saveContent(document)
            self.document = document
            session.document = document
            session.cancelEditing()
            lastError = nil
            publishSession()
            if settings.autoSyncOnToggle, !trimmedRepoURL.isEmpty {
                startBackgroundSync()
            }
        } catch {
            lastError = "写入 content.json 失败：\(error.localizedDescription)"
        }
    }

    func startBackgroundSync() {
        let snapshot = settings
        if trimmedRepoURL.isEmpty {
            gitStatus = .idle
            return
        }
        gitStatus = .syncing
        gitQueue.async { [weak self] in
            guard let self else { return }
            let result = self.git.sync(settings: snapshot)
            DispatchQueue.main.async {
                self.gitStatus = result
                if case .failed(let reason) = result {
                    self.lastError = reason
                } else {
                    self.lastError = nil
                    let loaded = self.git.loadContent(settings: self.settings)
                    self.applyLoad(loaded)
                }
            }
        }
    }

    func reloadContent(triggerSync: Bool) {
        let loaded = git.loadContent(settings: settings)
        applyLoad(loaded)
        if triggerSync, settings.autoSyncOnToggle, !trimmedRepoURL.isEmpty {
            startBackgroundSync()
        }
    }

    func openDataDirectory() {
        NSWorkspace.shared.activateFileViewerSelecting([paths.dataDirectory])
    }

    func persistSettings() {
        do {
            try git.saveSettings(settings)
        } catch {
            lastError = "保存设置失败：\(error.localizedDescription)"
        }
    }

    var trimmedRepoURL: String {
        settings.repoURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var briefingText: String {
        let now = Date()
        let lines = BriefingEngine.getCountdowns(document.countdowns, now: now)
        return BriefingEngine.buildMessage(todos: document.todos, countdowns: lines, now: now)
    }

    @objc private func handleScreenUnlocked(_ notification: Notification) {
        scheduleUnlockBriefing()
    }

    @objc private func handleDidWake(_ notification: Notification) {
        guard settings.alsoOnWake else { return }
        scheduleUnlockBriefing()
    }

    private func scheduleUnlockBriefing() {
        unlockWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.showUnlockHUDIfNeeded()
        }
        unlockWork = work
        let delay = settings.unlockDelay > 0 ? settings.unlockDelay : 0.8
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func showUnlockHUDIfNeeded() {
        reloadContent(triggerSync: false)
        let today = BriefingEngine.todayString(for: Date())
        let onlyFirst = settings.onlyFirstUnlockOfDay
        guard BriefingEngine.shouldShow(onlyFirst: onlyFirst, lastShownDate: settings.lastShownDate, today: today) else {
            return
        }
        let duration = settings.showDuration > 0 ? settings.showDuration : 8
        hud.show(text: briefingText, duration: duration) { [weak self] in
            self?.openMainWindow(editing: true)
        }
        settings.lastShownDate = today
        persistSettings()
    }

    private func publishSession() {
        isEditing = session.isEditing
        editDrafts = session.editDrafts
    }

    private func applyLoad(_ loaded: ContentLoadResult) {
        document = loaded.document
        session.document = loaded.document
        needsSettingsGuide = loaded.needsSettingsGuide
        if let error = loaded.error {
            lastError = error
            gitStatus = .failed(error)
        }
    }

    private func bindChrome() {
        menuBar.onOpenWindow = { [weak self] in self?.openMainWindow(editing: false) }
        menuBar.onSyncNow = { [weak self] in self?.startBackgroundSync() }
        menuBar.onOpenSettings = { [weak self] in self?.openSettings() }
        menuBar.onToggleLoginItem = { [weak self] enabled in self?.setLaunchAtLogin(enabled) }
        menuBar.onQuit = { NSApp.terminate(nil) }
        menuBar.loginItemEnabled = { [weak self] in
            self?.settings.launchAtLogin == true
        }
    }

    private func applyLoginItemOnLaunch() {
        if settings.launchAtLogin {
            try? LoginItemService.setEnabled(true)
        }
    }
}
