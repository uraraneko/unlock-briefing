#if canImport(UnlockBriefingCore)
import UnlockBriefingCore
#endif
import SwiftUI

struct ArchiveCardButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "archivebox")
                Text("归档")
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("归档")
        .accessibilityLabel("归档")
        .padding(8)
    }
}
