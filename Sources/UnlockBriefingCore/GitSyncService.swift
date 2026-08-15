import Foundation

/// Clone / commit / `pull --rebase` / push. Content is only loaded from the configured Git repo.
public final class GitSyncService: @unchecked Sendable {
    public let paths: AppPaths
    public let settingsStore: SettingsStore
    public let contentStore: ContentStore
    public private(set) var status: GitSyncStatus = .idle

    private let runner: ProcessRunning
    private let fileManager: FileManager
    private let gitPath: String
    private var inProgress = false

    public init(
        paths: AppPaths,
        runner: ProcessRunning = SystemProcessRunner(),
        fileManager: FileManager = .default,
        gitPath: String = GitExecutable.resolve()
    ) {
        self.paths = paths
        self.runner = runner
        self.fileManager = fileManager
        self.gitPath = gitPath
        self.settingsStore = SettingsStore(fileURL: paths.settingsFile, fileManager: fileManager)
        self.contentStore = ContentStore(fileURL: paths.contentFile, fileManager: fileManager)
    }

    public func loadSettings() -> AppSettings {
        settingsStore.load()
    }

    public func saveSettings(_ settings: AppSettings) throws {
        try settingsStore.save(settings)
    }

    /// No URL → empty content + settings guide, and never invokes `git`.
    public func loadContent(settings: AppSettings) -> ContentLoadResult {
        let url = trimmedURL(settings.repoURL)
        if url.isEmpty {
            return ContentLoadResult(document: .empty, needsSettingsGuide: true, error: nil)
        }
        if let error = ensureRepository(repoURL: url) {
            return ContentLoadResult(document: .empty, needsSettingsGuide: false, error: error)
        }
        return ContentLoadResult(document: contentStore.load(), needsSettingsGuide: false, error: nil)
    }

    public func saveContent(_ document: ContentDocument) throws {
        try fileManager.createDirectory(at: paths.dataDirectory, withIntermediateDirectories: true)
        try contentStore.save(document)
    }

    @discardableResult
    public func sync(settings: AppSettings, now: Date = Date()) -> GitSyncStatus {
        let url = trimmedURL(settings.repoURL)
        if url.isEmpty {
            status = .idle
            return status
        }
        if inProgress {
            return .failed("sync already in progress")
        }
        inProgress = true
        status = .syncing
        defer { inProgress = false }

        if let error = ensureRepository(repoURL: url) {
            status = .failed(error)
            return status
        }
        if let error = commitIfDirty(now: now) {
            status = .failed(error)
            return status
        }
        if let error = pullRebase() {
            status = .failed(error)
            return status
        }
        if let error = push() {
            status = .failed(error)
            return status
        }
        status = .synced
        return status
    }

    public func isGitRepository() -> Bool {
        fileManager.fileExists(atPath: paths.gitHeadFile.path)
    }

    private func trimmedURL(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func ensureRepository(repoURL: String) -> String? {
        do {
            try fileManager.createDirectory(at: paths.supportDirectory, withIntermediateDirectories: true)
        } catch {
            return "无法创建应用数据目录：\(error.localizedDescription)"
        }
        if isGitRepository() {
            return updateRemoteIfNeeded(repoURL)
        }
        return clone(repoURL)
    }

    private func clone(_ repoURL: String) -> String? {
        if fileManager.fileExists(atPath: paths.dataDirectory.path) {
            let contents = (try? fileManager.contentsOfDirectory(atPath: paths.dataDirectory.path)) ?? []
            let visible = contents.filter { !$0.hasPrefix(".") }
            if !visible.isEmpty || isGitRepository() {
                return "数据目录已存在且不是可 clone 的空目录"
            }
        }
        let result: ProcessResult
        do {
            result = try git(["clone", "--", repoURL, paths.dataDirectory.path], directory: nil)
        } catch {
            return "clone 失败：\(error.localizedDescription)"
        }
        if !result.succeeded {
            return "clone 失败：\(readable(result))"
        }
        return nil
    }

    private func updateRemoteIfNeeded(_ repoURL: String) -> String? {
        let current: ProcessResult
        do {
            current = try git(["remote", "get-url", "origin"], directory: paths.dataDirectory)
        } catch {
            return "读取 remote 失败：\(error.localizedDescription)"
        }
        let existing = current.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if existing == repoURL {
            return nil
        }
        let updated: ProcessResult
        do {
            updated = try git(["remote", "set-url", "origin", repoURL], directory: paths.dataDirectory)
        } catch {
            return "更新 remote 失败：\(error.localizedDescription)"
        }
        if !updated.succeeded {
            return "更新 remote 失败：\(readable(updated))"
        }
        return nil
    }

    private func commitIfDirty(now: Date) -> String? {
        let statusResult: ProcessResult
        do {
            statusResult = try git(["status", "--porcelain"], directory: paths.dataDirectory)
        } catch {
            return "git status 失败：\(error.localizedDescription)"
        }
        if !statusResult.succeeded {
            return "git status 失败：\(readable(statusResult))"
        }
        if statusResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        do {
            let add = try git(["add", "-A"], directory: paths.dataDirectory)
            if !add.succeeded {
                return "git add 失败：\(readable(add))"
            }
            let stamp = commitStamp(now)
            let commit = try git(
                [
                    "-c", "user.name=UnlockBriefing",
                    "-c", "user.email=unlock-briefing@localhost",
                    "commit", "-m", "auto: sync \(stamp)",
                ],
                directory: paths.dataDirectory
            )
            if !commit.succeeded && !commit.combinedOutput.lowercased().contains("nothing to commit") {
                return "git commit 失败：\(readable(commit))"
            }
        } catch {
            return "git commit 失败：\(error.localizedDescription)"
        }
        return nil
    }

    private func pullRebase() -> String? {
        let branch = currentBranch()
        let result: ProcessResult
        do {
            result = try git(["pull", "--rebase", "origin", branch], directory: paths.dataDirectory)
        } catch {
            return "pull --rebase 失败：\(error.localizedDescription)"
        }
        if result.succeeded || isBenignPullFailure(result) {
            return nil
        }
        let text = result.combinedOutput
        if text.localizedCaseInsensitiveContains("conflict") || text.contains("CONFLICT") {
            return "冲突：请打开数据目录处理"
        }
        return "pull --rebase 失败：\(readable(result))"
    }

    private func push() -> String? {
        let branch = currentBranch()
        let result: ProcessResult
        do {
            result = try git(["push", "-u", "origin", branch], directory: paths.dataDirectory)
        } catch {
            return "push 失败：\(error.localizedDescription)"
        }
        if !result.succeeded {
            return "push 失败：\(readable(result))"
        }
        return nil
    }

    private func currentBranch() -> String {
        let result = try? git(["rev-parse", "--abbrev-ref", "HEAD"], directory: paths.dataDirectory)
        let name = result?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.isEmpty || name == "HEAD" {
            return "main"
        }
        return name
    }

    private func isBenignPullFailure(_ result: ProcessResult) -> Bool {
        let text = result.combinedOutput.lowercased()
        return text.contains("couldn't find remote ref")
            || text.contains("couldn't find remote")
            || text.contains("no tracking information")
            || text.contains("does not match any")
            || text.contains("no remote-tracking")
            || text.contains("unborn")
    }

    private func commitStamp(_ now: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: now)
    }

    private func readable(_ result: ProcessResult) -> String {
        let text = result.combinedOutput
        if text.isEmpty {
            return "exit \(result.exitCode)"
        }
        let oneLine = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if oneLine.count <= 240 {
            return oneLine
        }
        return String(oneLine.prefix(240))
    }

    @discardableResult
    private func git(_ arguments: [String], directory: URL?) throws -> ProcessResult {
        try runner.run(executable: gitPath, arguments: arguments, currentDirectory: directory)
    }
}
