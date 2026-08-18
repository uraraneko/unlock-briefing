import Foundation

public enum TodoPriority: String, Codable, Equatable, Sendable, CaseIterable {
    case high
    case medium
    case low

    public var label: String {
        switch self {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }
}

public struct TodoItem: Equatable, Codable, Sendable, ExpressibleByStringLiteral {
    public var text: String
    public var priority: TodoPriority

    public init(text: String, priority: TodoPriority = .medium) {
        self.text = text
        self.priority = priority
    }

    public init(stringLiteral value: String) {
        self.init(text: value, priority: .medium)
    }
}

public struct CountdownItem: Equatable, Codable, Sendable {
    public var title: String
    public var date: String
    public var start: String?

    public init(title: String, date: String, start: String? = nil) {
        self.title = title
        self.date = date
        self.start = start
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(String.self, forKey: .date)
        let rawStart = try container.decodeIfPresent(String.self, forKey: .start)
        start = rawStart.flatMap { $0.isEmpty ? nil : $0 }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        if let start, !start.isEmpty {
            try container.encode(start, forKey: .start)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case title, date, start
    }
}

public enum CountdownAppearanceMode: String, Codable, Equatable, Sendable, CaseIterable {
    case off
    case remainingDays
    case progressFill

    public var displayName: String {
        switch self {
        case .off: return "不上色"
        case .remainingDays: return "按剩余天数"
        case .progressFill: return "进度填充"
        }
    }
}

public enum CountdownUrgencyPreset: String, Codable, Equatable, Sendable, CaseIterable {
    case relaxed
    case standard
    case tight

    public var displayName: String {
        switch self {
        case .relaxed: return "宽松"
        case .standard: return "标准"
        case .tight: return "紧张"
        }
    }

    /// Green if remaining days `> greenAbove`, yellow if `> yellowAbove`,
    /// orange if `> orangeAbove`, otherwise red.
    public var greenAbove: Int {
        switch self {
        case .relaxed: return 60
        case .standard: return 30
        case .tight: return 14
        }
    }

    public var yellowAbove: Int {
        switch self {
        case .relaxed: return 14
        case .standard: return 7
        case .tight: return 3
        }
    }

    public var orangeAbove: Int {
        switch self {
        case .relaxed: return 3
        case .standard: return 0
        case .tight: return 0
        }
    }

    public var cutsCaption: String {
        ">\(greenAbove) 绿 / >\(yellowAbove) 黄 / >\(orangeAbove) 橙 / ≤\(orangeAbove) 红"
    }
}

public enum CountdownColorBand: String, Equatable, Sendable {
    case green
    case yellow
    case orange
    case red
}

public struct ContentDocument: Equatable, Codable, Sendable {
    public var todos: [TodoItem]
    public var countdowns: [CountdownItem]

    public static let empty = ContentDocument(todos: [], countdowns: [])

    public init(todos: [TodoItem], countdowns: [CountdownItem]) {
        self.todos = todos
        self.countdowns = countdowns
    }
}

public struct CountdownPresentation: Equatable, Sendable {
    public var item: CountdownItem
    public var line: String
    public var remainingLabel: String
    public var isExpired: Bool
    public var remainingDays: Int
    public var progress: Double
    public var progressBand: CountdownColorBand
    public var remainingDaysBand: CountdownColorBand
}

public struct BriefingPresentation: Equatable, Sendable {
    public var greetingLine: String
    public var isEmpty: Bool
    public var emptyMessage: String
    public var todos: [TodoItem]
    public var countdowns: [CountdownPresentation]
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
    public var countdownAppearance: CountdownAppearanceMode
    public var countdownUrgencyPreset: CountdownUrgencyPreset

    public static let `default` = AppSettings(
        repoURL: "",
        autoSyncOnToggle: true,
        showDuration: 8,
        onlyFirstUnlockOfDay: true,
        alsoOnWake: false,
        unlockDelay: 0.8,
        launchAtLogin: false,
        showMenuBar: true,
        lastShownDate: nil,
        countdownAppearance: .remainingDays,
        countdownUrgencyPreset: .standard
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
        lastShownDate: String?,
        countdownAppearance: CountdownAppearanceMode,
        countdownUrgencyPreset: CountdownUrgencyPreset
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
        self.countdownAppearance = countdownAppearance
        self.countdownUrgencyPreset = countdownUrgencyPreset
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
        countdownAppearance = try container.decodeIfPresent(CountdownAppearanceMode.self, forKey: .countdownAppearance)
            ?? defaults.countdownAppearance
        countdownUrgencyPreset = try container.decodeIfPresent(CountdownUrgencyPreset.self, forKey: .countdownUrgencyPreset)
            ?? defaults.countdownUrgencyPreset
    }
}
