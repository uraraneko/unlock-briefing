import XCTest
@testable import UnlockBriefingCore

/// HUD「编辑」opens the main window with `isEditing` already true. Save must write
/// the loaded document, not empty `@State` drafts.
final class EditSessionTests: XCTestCase {
    private var tempRoot: URL!
    private let fm = FileManager.default
    private let git = GitExecutable.resolve()
    private let runner = SystemProcessRunner()

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempRoot = fm.temporaryDirectory.appendingPathComponent("ub-edit-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? fm.removeItem(at: tempRoot)
        }
        try super.tearDownWithError()
    }

    func testHUDEditThenSaveDoesNotWipeLoadedContent() throws {
        let fixture = BriefingEngine.parseContent(try RepoFixtures.read("content.json.example"))
        XCTAssertFalse(fixture.todos.isEmpty, "fixture must have todos so a wipe is detectable")
        XCTAssertFalse(fixture.countdowns.isEmpty)

        let remote = try makeRemote(named: "edit-remote.git", document: fixture)
        let paths = AppPaths(supportDirectory: tempRoot.appendingPathComponent("edit-support"))
        let service = GitSyncService(paths: paths, runner: runner, gitPath: git)
        var settings = AppSettings.default
        settings.repoURL = remote.absoluteString

        let loaded = service.loadContent(settings: settings)
        XCTAssertEqual(loaded.document.todos, fixture.todos)
        XCTAssertEqual(loaded.document.countdowns, fixture.countdowns)

        // Same sequence as AppCoordinator.openMainWindow(editing: true) after reload.
        let session = BriefingSession(document: loaded.document)
        session.prepareWindow(editing: true)
        XCTAssertTrue(session.isEditing)
        XCTAssertEqual(session.documentForSave().todos, fixture.todos)
        XCTAssertEqual(session.documentForSave().countdowns, fixture.countdowns)
        XCTAssertNotEqual(session.documentForSave(), .empty)

        try service.saveContent(session.documentForSave())

        let after = service.loadContent(settings: settings)
        XCTAssertEqual(after.document.todos, fixture.todos)
        XCTAssertEqual(after.document.countdowns, fixture.countdowns)
        let disk = BriefingEngine.parseContent(try String(contentsOf: paths.contentFile, encoding: .utf8))
        XCTAssertEqual(disk.todos, fixture.todos)
        XCTAssertEqual(disk.countdowns, fixture.countdowns)
    }

    func testPrepareWindowViewingLeavesDraftsUnsaved() throws {
        let document = ContentDocument(
            todos: [TodoItem(text: "完成报告初稿")],
            countdowns: [CountdownItem(title: "考试", date: "2026-10-10")]
        )
        let session = BriefingSession(document: document)
        session.prepareWindow(editing: false)
        XCTAssertFalse(session.isEditing)
        XCTAssertEqual(session.document, document)
    }

    func testOpenMainWindowEditingWiresBriefingSession() throws {
        let coordinator = try String(
            contentsOf: RepoFixtures.root
                .appendingPathComponent("Sources/UnlockBriefingApp/AppCoordinator.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            coordinator.contains("session.prepareWindow(editing: editing)"),
            "HUD→openMainWindow(editing:) must seed drafts via BriefingSession"
        )
        XCTAssertTrue(
            coordinator.contains("func saveEdits()"),
            "Save must go through saveEdits, not raw empty view state"
        )
        XCTAssertTrue(coordinator.contains("session.documentForSave()"))
        XCTAssertTrue(
            coordinator.contains("openMainWindow(editing: true)"),
            "HUD 编辑 must open the main window in edit mode"
        )
        XCTAssertTrue(
            coordinator.contains("browseReorderSyncDelay"),
            "browse drag must debounce GitHub sync"
        )
        XCTAssertTrue(
            coordinator.contains("TimeInterval = 3"),
            "browse drag sync waits 3s after the last drop"
        )
        XCTAssertTrue(coordinator.contains("sync: .debounced"))
        XCTAssertTrue(coordinator.contains("cancelPendingSync()"))

        let view = try String(
            contentsOf: RepoFixtures.root
                .appendingPathComponent("Sources/UnlockBriefingApp/MainWindowView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(view.contains("coordinator.saveEdits()"))
        XCTAssertFalse(
            view.contains("@State private var draftTodos"),
            "local empty drafts were the wipe bug"
        )
        XCTAssertFalse(view.contains("Text(coordinator.briefingText)"), "browse UI is cards, not briefingText")
        XCTAssertTrue(view.contains("BriefingEngine.newCountdown"), "new countdown must record start via shipped helper")
        XCTAssertTrue(view.contains("设置开始日"), "legacy nil start must not bind a DatePicker that writes today")
        XCTAssertTrue(view.contains("TodoCardView"))
        XCTAssertTrue(view.contains("CountdownCardView"))
        XCTAssertTrue(view.contains("todoDragGesture"), "browse drag must start on the card, not List.onMove gaps")
        XCTAssertTrue(view.contains("highPriorityGesture"))
        XCTAssertFalse(view.contains(".onMove("), "List.onMove only hit the padding between cards")
        XCTAssertTrue(view.contains("briefingCardSurface"))

        let cards = try String(
            contentsOf: RepoFixtures.root
                .appendingPathComponent("Sources/UnlockBriefingApp/BriefingCardsView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(cards.contains("strokeBorder"), "cards need a darker border over a light fill")
        XCTAssertTrue(cards.contains("border"))

        let hud = try String(
            contentsOf: RepoFixtures.root
                .appendingPathComponent("Sources/UnlockBriefingApp/UnlockHUDController.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(hud.contains("BriefingPresentation"))
        XCTAssertTrue(hud.contains("BriefingSectionsView"))
        XCTAssertFalse(hud.contains("let text: String"))

        let settings = try String(
            contentsOf: RepoFixtures.root
                .appendingPathComponent("Sources/UnlockBriefingApp/SettingsWindowView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(settings.contains("CountdownAppearanceMode"))
        XCTAssertTrue(settings.contains("CountdownUrgencyPreset"))
        XCTAssertTrue(settings.contains("关上色不会隐藏"))
        XCTAssertFalse(settings.contains("自定义阈值"))
    }

    private func makeRemote(named: String, document: ContentDocument) throws -> URL {
        let remote = tempRoot.appendingPathComponent(named)
        let seed = tempRoot.appendingPathComponent("seed-\(named)")
        var result = try gitProc(["init", "--bare", "--initial-branch=main", remote.path])
        XCTAssertTrue(result.succeeded, result.combinedOutput)
        result = try gitProc(["clone", remote.path, seed.path])
        XCTAssertTrue(result.succeeded, result.combinedOutput)
        try ContentStore(fileURL: seed.appendingPathComponent("content.json")).save(document)
        result = try gitProc(["-C", seed.path, "add", "-A"])
        XCTAssertTrue(result.succeeded, result.combinedOutput)
        result = try gitProc([
            "-C", seed.path,
            "-c", "user.name=Seed",
            "-c", "user.email=seed@example.com",
            "commit", "-m", "init content",
        ])
        XCTAssertTrue(result.succeeded, result.combinedOutput)
        result = try gitProc(["-C", seed.path, "push", "-u", "origin", "main"])
        XCTAssertTrue(result.succeeded, result.combinedOutput)
        return remote
    }

    @discardableResult
    private func gitProc(_ arguments: [String]) throws -> ProcessResult {
        try runner.run(executable: git, arguments: arguments, currentDirectory: nil)
    }
}
