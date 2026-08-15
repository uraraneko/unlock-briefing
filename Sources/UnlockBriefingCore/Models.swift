import Foundation

public struct CountdownItem: Equatable, Codable, Sendable {
    public var title: String
    public var date: String

    public init(title: String, date: String) {
        self.title = title
        self.date = date
    }
}

public struct ContentDocument: Equatable, Codable, Sendable {
    public var todos: [String]
    public var countdowns: [CountdownItem]

    public static let empty = ContentDocument(todos: [], countdowns: [])

    public init(todos: [String], countdowns: [CountdownItem]) {
        self.todos = todos
        self.countdowns = countdowns
    }
}

public struct ContentLoadResult: Equatable, Sendable {
    public var document: ContentDocument
    public var needsSettingsGuide: Bool
    public var error: String?

    public init(document: ContentDocument, needsSettingsGuide: Bool, error: String?) {
        self.document = document
        self.needsSettingsGuide = needsSettingsGuide
        self.error = error
    }
}

public enum GitSyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case synced
    case failed(String)

    public var badgeText: String {
        switch self {
        case .idle:
            return "未同步"
        case .syncing:
            return "同步中"
        case .synced:
            return "已同步"
        case .failed:
            return "失败"
        }
    }

    public var reasonText: String? {
        if case .failed(let reason) = self {
            return reason
        }
        return nil
    }

    public var displayText: String {
        if let reasonText {
            return "\(badgeText)：\(reasonText)"
        }
        return badgeText
    }
}

public struct AppSettings: Equatable, Codable, Sendable {
    public var repoURL: String
    public var autoSyncOnToggle: Bool
    public var showDuration: Double
    public var onlyFirstUnlockOfDay: Bool
    public var alsoOnWake: Bool
    public var unlockDelay: Double
    public var launchAtLogin: Bool
    public var showMenuBar: Bool
    public var lastShownDate: String?

    public static let `default` = AppSettings(
        repoURL: "",
        autoSyncOnToggle: true,
        showDuration: 8,
        onlyFirstUnlockOfDay: true,
        alsoOnWake: false,
        unlockDelay: 0.8,
        launchAtLogin: false,
        showMenuBar: true,
        lastShownDate: nil
    )

    public init(
        repoURL: String,
        autoSyncOnToggle: Bool,
        showDuration: Double,
        onlyFirstUnlockOfDay: Bool,
        alsoOnWake: Bool,
        unlockDelay: Double,
        launchAtLogin: Bool,
        showMenuBar: Bool,
        lastShownDate: String?
    ) {
        self.repoURL = repoURL
        self.autoSyncOnToggle = autoSyncOnToggle
        self.showDuration = showDuration
        self.onlyFirstUnlockOfDay = onlyFirstUnlockOfDay
        self.alsoOnWake = alsoOnWake
        self.unlockDelay = unlockDelay
        self.launchAtLogin = launchAtLogin
        self.showMenuBar = showMenuBar
        self.lastShownDate = lastShownDate
    }

    public init(from decoder: Decoder) throws {
        let defaults = AppSettings.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        repoURL = try container.decodeIfPresent(String.self, forKey: .repoURL) ?? defaults.repoURL
        autoSyncOnToggle = try container.decodeIfPresent(Bool.self, forKey: .autoSyncOnToggle) ?? defaults.autoSyncOnToggle
        showDuration = try container.decodeIfPresent(Double.self, forKey: .showDuration) ?? defaults.showDuration
        onlyFirstUnlockOfDay = try container.decodeIfPresent(Bool.self, forKey: .onlyFirstUnlockOfDay) ?? defaults.onlyFirstUnlockOfDay
        alsoOnWake = try container.decodeIfPresent(Bool.self, forKey: .alsoOnWake) ?? defaults.alsoOnWake
        unlockDelay = try container.decodeIfPresent(Double.self, forKey: .unlockDelay) ?? defaults.unlockDelay
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        showMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showMenuBar) ?? defaults.showMenuBar
        lastShownDate = try container.decodeIfPresent(String.self, forKey: .lastShownDate)
    }
}
