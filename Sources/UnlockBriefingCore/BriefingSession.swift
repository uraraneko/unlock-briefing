import Foundation

/// Editor drafts for the main window. HUD「编辑」and the window 编辑 button
/// both enter through `prepareWindow(editing:)` so a first-frame editor
/// cannot save empty arrays over `content.json`.
public final class BriefingSession: @unchecked Sendable {
    public var document: ContentDocument
    public var editDrafts: ContentDocument
    public var isEditing: Bool

    public init(document: ContentDocument = .empty) {
        self.document = document
        self.editDrafts = .empty
        self.isEditing = false
    }

    /// HUD「编辑」→ `openMainWindow(editing: true)` and the 编辑 button share this.
    public func prepareWindow(editing: Bool) {
        if editing {
            enterEditFromCurrentDocument()
        } else {
            isEditing = false
        }
    }

    public func enterEditFromCurrentDocument() {
        editDrafts = document
        isEditing = true
    }

    public func cancelEditing() {
        isEditing = false
    }

    /// Payload the Save button writes via `GitSyncService.saveContent`.
    public func documentForSave() -> ContentDocument {
        editDrafts
    }
}
