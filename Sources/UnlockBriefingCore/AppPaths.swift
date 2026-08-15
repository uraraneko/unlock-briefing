import Foundation

public struct AppPaths: Equatable, Sendable {
    public var supportDirectory: URL

    public init(supportDirectory: URL) {
        self.supportDirectory = supportDirectory
    }

    public static func `default`(fileManager: FileManager = .default) -> AppPaths {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return AppPaths(supportDirectory: base.appendingPathComponent("UnlockBriefing", isDirectory: true))
    }

    public var settingsFile: URL {
        supportDirectory.appendingPathComponent("settings.json")
    }

    public var dataDirectory: URL {
        supportDirectory.appendingPathComponent("data", isDirectory: true)
    }

    public var contentFile: URL {
        dataDirectory.appendingPathComponent("content.json")
    }

    public var gitHeadFile: URL {
        dataDirectory.appendingPathComponent(".git/HEAD")
    }
}
