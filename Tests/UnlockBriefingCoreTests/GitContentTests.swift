import XCTest
@testable import UnlockBriefingCore

/// Drives shipped `GitSyncService` + `ContentStore` against temporary `file://` remotes.
final class GitContentTests: XCTestCase {
    private var tempRoot: URL!
    private let fm = FileManager.default
    private let git = GitExecutable.resolve()
    private let runner = SystemProcessRunner()

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempRoot = fm.temporaryDirectory.appendingPathComponent("ub-git-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? fm.removeItem(at: tempRoot)
        }
        try super.tearDownWithError()
    }

    func testNoURLDoesNotInvokeGitAndReturnsEmptyGuide() {
        let recorder = RecordingProcessRunner(inner: runner)
        let paths = AppPaths(supportDirectory: tempRoot.appendingPathComponent("support"))
        let service = GitSyncService(paths: paths, runner: recorder, gitPath: git)
        let loaded = service.loadContent(settings: .default)
        XCTAssertTrue(loaded.needsSettingsGuide)
        XCTAssertEqual(loaded.document, .empty)
        XCTAssertNil(loaded.error)
        XCTAssertTrue(recorder.calls.isEmpty, "no-URL load must not invoke git")

        let status = service.sync(settings: .default)
        XCTAssertEqual(status, .idle)
        XCTAssertTrue(recorder.calls.isEmpty, "no-URL sync must not invoke git")
        XCTAssertFalse(service.isGitRepository())
    }

    func testCloneThenReadContentJSON() throws {
        let fixture = try sampleDocument()
        let remote = try makeRemote(named: "remote.git", document: fixture)
        let paths = AppPaths(supportDirectory: tempRoot.appendingPathComponent("clone-support"))
        let recorder = RecordingProcessRunner(inner: runner)
        let service = GitSyncService(paths: paths, runner: recorder, gitPath: git)
        var settings = AppSettings.default
        settings.repoURL = remote.absoluteString

        let loaded = service.loadContent(settings: settings)
        XCTAssertFalse(loaded.needsSettingsGuide)
        XCTAssertNil(loaded.error, loaded.error ?? "")
        XCTAssertEqual(loaded.document.todos, fixture.todos)
        XCTAssertEqual(loaded.document.countdowns, fixture.countdowns)
        XCTAssertTrue(service.isGitRepository())
        XCTAssertTrue(recorder.invokedGit)
        XCTAssertTrue(recorder.calls.contains { $0.arguments.first == "clone" })
        XCTAssertTrue(fm.fileExists(atPath: paths.contentFile.path))
    }

    func testEditWriteThenSyncCommitPullPush() throws {
        let fixture = try sampleDocument()
        let remote = try makeRemote(named: "sync-remote.git", document: fixture)
        let paths = AppPaths(supportDirectory: tempRoot.appendingPathComponent("sync-support"))
        let probe = StatusProbeRunner(inner: runner)
        let service = GitSyncService(paths: paths, runner: probe, gitPath: git)
        probe.service = service
        var settings = AppSettings.default
        settings.repoURL = remote.absoluteString

        var loaded = service.loadContent(settings: settings)
        XCTAssertEqual(loaded.document.todos.first, "完成报告初稿")

        var edited = loaded.document
        edited.todos.append("新待办")
        edited.countdowns.append(CountdownItem(title: "发布会", date: "2027-01-01"))
        try service.saveContent(edited)

        let disk = try String(contentsOf: paths.contentFile, encoding: .utf8)
        let parsed = BriefingEngine.parseContent(disk)
        XCTAssertTrue(parsed.todos.contains("新待办"), "edit writes content.json")
        XCTAssertEqual(parsed.countdowns.last?.title, "发布会")

        let stamp = RepoFixtures.localDate(year: 2026, month: 8, day: 15, hour: 16, minute: 19, second: 0)
        let status = service.sync(settings: settings, now: stamp)
        XCTAssertEqual(status, .synced, String(describing: status))
        XCTAssertTrue(probe.sawSyncing, "status must be 同步中 while git runs")
        XCTAssertEqual(service.status, .synced)
        XCTAssertEqual(service.status.badgeText, "已同步")
        XCTAssertEqual(GitSyncStatus.syncing.badgeText, "同步中")
        XCTAssertEqual(GitSyncStatus.failed("network").displayText, "失败：network")

        let log = try git(["-C", paths.dataDirectory.path, "log", "-1", "--pretty=%s"])
        XCTAssertEqual(log.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "auto: sync 2026-08-15 16:19:00")

        let verifyDir = tempRoot.appendingPathComponent("verify-clone")
        let clone = try git(["clone", remote.path, verifyDir.path])
        XCTAssertTrue(clone.succeeded, clone.combinedOutput)
        let remoteContent = try String(
            contentsOf: verifyDir.appendingPathComponent("content.json"),
            encoding: .utf8
        )
        let remoteDoc = BriefingEngine.parseContent(remoteContent)
        XCTAssertTrue(remoteDoc.todos.contains("新待办"))
        XCTAssertEqual(remoteDoc.countdowns.last?.date, "2027-01-01")

        loaded = service.loadContent(settings: settings)
        XCTAssertEqual(loaded.document.todos.last, "新待办")
    }

    func testPullRebasePicksUpRemoteEdit() throws {
        let fixture = try sampleDocument()
        let remote = try makeRemote(named: "pull-remote.git", document: fixture)

        let firstPaths = AppPaths(supportDirectory: tempRoot.appendingPathComponent("first"))
        let first = GitSyncService(paths: firstPaths, runner: runner, gitPath: git)
        var settings = AppSettings.default
        settings.repoURL = remote.absoluteString
        XCTAssertNil(first.loadContent(settings: settings).error)

        let otherDir = tempRoot.appendingPathComponent("other-clone")
        _ = try git(["clone", remote.path, otherDir.path])
        var otherDoc = fixture
        otherDoc.todos = ["远端待办"]
        try ContentStore(fileURL: otherDir.appendingPathComponent("content.json")).save(otherDoc)
        _ = try git(["-C", otherDir.path, "add", "-A"])
        _ = try git([
            "-C", otherDir.path,
            "-c", "user.name=Other",
            "-c", "user.email=other@example.com",
            "commit", "-m", "remote edit",
        ])
        _ = try git(["-C", otherDir.path, "push", "origin", "HEAD"])

        let pulled = first.sync(settings: settings)
        XCTAssertEqual(pulled, .synced, String(describing: pulled))
        let after = first.loadContent(settings: settings)
        XCTAssertEqual(after.document.todos, ["远端待办"])
    }

    func testSettingsPersistRepoURLAndMenuBarDefault() throws {
        let paths = AppPaths(supportDirectory: tempRoot.appendingPathComponent("settings-support"))
        let service = GitSyncService(paths: paths, runner: RecordingProcessRunner(), gitPath: git)
        var settings = AppSettings.default
        XCTAssertTrue(settings.showMenuBar)
        XCTAssertEqual(settings.unlockDelay, 0.8)
        XCTAssertEqual(settings.showDuration, 8)
        settings.repoURL = "git@example.com:user/data.git"
        settings.showMenuBar = false
        settings.launchAtLogin = true
        try service.saveSettings(settings)
        let loaded = service.loadSettings()
        XCTAssertEqual(loaded.repoURL, "git@example.com:user/data.git")
        XCTAssertFalse(loaded.showMenuBar)
        XCTAssertTrue(loaded.launchAtLogin)
    }

    func testDoesNotReadHammerspoonOrSeedFiles() throws {
        let hammerspoon = tempRoot.appendingPathComponent(".hammerspoon")
        try fm.createDirectory(at: hammerspoon, withIntermediateDirectories: true)
        try """
        {"todos":["来自Hammerspoon"],"countdowns":[]}
        """.write(to: hammerspoon.appendingPathComponent("content.json"), atomically: true, encoding: .utf8)
        try RepoFixtures.read("content.json.example").write(
            to: tempRoot.appendingPathComponent("content.json.example"),
            atomically: true,
            encoding: .utf8
        )

        let paths = AppPaths(supportDirectory: tempRoot.appendingPathComponent("app-support"))
        let recorder = RecordingProcessRunner(inner: runner)
        let service = GitSyncService(paths: paths, runner: recorder, gitPath: git)
        let loaded = service.loadContent(settings: .default)

        XCTAssertTrue(loaded.needsSettingsGuide)
        XCTAssertEqual(loaded.document, .empty)
        XCTAssertFalse(loaded.document.todos.contains("来自Hammerspoon"))
        XCTAssertFalse(paths.supportDirectory.path.contains(".hammerspoon"))
        XCTAssertFalse(paths.contentFile.path.contains(".hammerspoon"))
        XCTAssertTrue(recorder.calls.isEmpty)
    }

    func testDefaultPathsLiveUnderApplicationSupport() {
        let paths = AppPaths.default()
        XCTAssertTrue(paths.supportDirectory.path.contains("Application Support/UnlockBriefing"))
        XCTAssertFalse(paths.supportDirectory.path.contains(".hammerspoon"))
        XCTAssertEqual(paths.contentFile.lastPathComponent, "content.json")
        XCTAssertEqual(paths.settingsFile.lastPathComponent, "settings.json")
    }

    func testFailedStatusHasReadableReason() {
        XCTAssertEqual(GitSyncStatus.failed("clone 失败：repository not found").displayText, "失败：clone 失败：repository not found")
        XCTAssertEqual(GitSyncStatus.syncing.badgeText, "同步中")
        XCTAssertEqual(GitSyncStatus.synced.badgeText, "已同步")
    }

    private func sampleDocument() throws -> ContentDocument {
        BriefingEngine.parseContent(try RepoFixtures.read("content.json.example"))
    }

    private func makeRemote(named: String, document: ContentDocument) throws -> URL {
        let remote = tempRoot.appendingPathComponent(named)
        let seed = tempRoot.appendingPathComponent("seed-\(named)")
        var result = try git(["init", "--bare", "--initial-branch=main", remote.path])
        XCTAssertTrue(result.succeeded, result.combinedOutput)
        result = try git(["clone", remote.path, seed.path])
        XCTAssertTrue(result.succeeded, result.combinedOutput)
        try ContentStore(fileURL: seed.appendingPathComponent("content.json")).save(document)
        result = try git(["-C", seed.path, "add", "-A"])
        XCTAssertTrue(result.succeeded, result.combinedOutput)
        result = try git([
            "-C", seed.path,
            "-c", "user.name=Seed",
            "-c", "user.email=seed@example.com",
            "commit", "-m", "init content",
        ])
        XCTAssertTrue(result.succeeded, result.combinedOutput)
        result = try git(["-C", seed.path, "push", "-u", "origin", "main"])
        XCTAssertTrue(result.succeeded, result.combinedOutput)
        return remote
    }

    @discardableResult
    private func git(_ arguments: [String]) throws -> ProcessResult {
        try runner.run(executable: git, arguments: arguments, currentDirectory: nil)
    }
}

private final class StatusProbeRunner: ProcessRunning {
    let inner: ProcessRunning
    weak var service: GitSyncService?
    var sawSyncing = false

    init(inner: ProcessRunning) {
        self.inner = inner
    }

    func run(executable: String, arguments: [String], currentDirectory: URL?) throws -> ProcessResult {
        if service?.status == .syncing {
            sawSyncing = true
        }
        return try inner.run(executable: executable, arguments: arguments, currentDirectory: currentDirectory)
    }
}
