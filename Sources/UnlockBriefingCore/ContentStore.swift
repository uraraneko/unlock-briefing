import Foundation

public final class ContentStore: @unchecked Sendable {
    public let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func load() -> ContentDocument {
        guard fileManager.fileExists(atPath: fileURL.path),
              let raw = try? String(contentsOf: fileURL, encoding: .utf8)
        else {
            return .empty
        }
        return BriefingEngine.parseContent(raw)
    }

    public func save(_ document: ContentDocument) throws {
        let payload = ContentDocument(
            todos: BriefingEngine.normalizeTodos(document.todos),
            archived: BriefingEngine.normalizeArchived(document.archived),
            countdowns: BriefingEngine.normalizeCountdowns(document.countdowns)
        )
        try AtomicJSON.write(payload, to: fileURL, fileManager: fileManager)
    }
}

enum AtomicJSON {
    static func write<T: Encodable>(_ value: T, to url: URL, fileManager: FileManager) throws {
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        let temp = directory.appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
        try data.write(to: temp, options: .atomic)
        if fileManager.fileExists(atPath: url.path) {
            _ = try fileManager.replaceItemAt(url, withItemAt: temp)
        } else {
            try fileManager.moveItem(at: temp, to: url)
        }
    }
}
