import Foundation

public enum ArchiveUndoTiming {
    public static let ringDuration: TimeInterval = 5
}

public enum ArchiveKind: Equatable, Sendable {
    case todo
    case countdown
}

public struct ArchiveUndoSnapshot: Equatable, Sendable {
    public var kind: ArchiveKind
    public var originalIndex: Int
    public var item: ArchivedItem

    public init(kind: ArchiveKind, originalIndex: Int, item: ArchivedItem) {
        self.kind = kind
        self.originalIndex = originalIndex
        self.item = item
    }
}

/// Index + snapshot transforms. Newest archived item is always inserted at head.
public enum ArchiveTransform {
    public static func archiveTodo(at index: Int, in document: ContentDocument) -> (ContentDocument, ArchiveUndoSnapshot)? {
        guard document.todos.indices.contains(index) else { return nil }
        var next = document
        let todo = next.todos.remove(at: index)
        let item = ArchivedItem.todo(todo)
        next.archived.insert(item, at: 0)
        return (next, ArchiveUndoSnapshot(kind: .todo, originalIndex: index, item: item))
    }

    public static func archiveCountdown(at index: Int, in document: ContentDocument) -> (ContentDocument, ArchiveUndoSnapshot)? {
        guard document.countdowns.indices.contains(index) else { return nil }
        var next = document
        let countdown = next.countdowns.remove(at: index)
        let item = ArchivedItem.countdown(countdown)
        next.archived.insert(item, at: 0)
        return (next, ArchiveUndoSnapshot(kind: .countdown, originalIndex: index, item: item))
    }

    /// Restores the snapshotted item to its original live index (append if past the end)
    /// and removes only the first matching archived occurrence.
    public static func undo(_ snapshot: ArchiveUndoSnapshot, in document: ContentDocument) -> ContentDocument? {
        guard let archivedIndex = document.archived.firstIndex(of: snapshot.item) else {
            return nil
        }
        var next = document
        next.archived.remove(at: archivedIndex)
        switch snapshot.kind {
        case .todo:
            guard case .todo(let todo) = snapshot.item else { return nil }
            next.todos.insert(todo, at: clampedInsertIndex(snapshot.originalIndex, count: next.todos.count))
        case .countdown:
            guard case .countdown(let countdown) = snapshot.item else { return nil }
            next.countdowns.insert(countdown, at: clampedInsertIndex(snapshot.originalIndex, count: next.countdowns.count))
        }
        return next
    }

    private static func clampedInsertIndex(_ original: Int, count: Int) -> Int {
        min(max(original, 0), count)
    }
}
