import Foundation

public enum RepoURLPaste {
    /// Paste into the Git URL field: keep current value if clipboard is empty.
    public static func apply(_ raw: String?, onto current: String) -> String {
        guard let raw else { return current }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? current : trimmed
    }
}
