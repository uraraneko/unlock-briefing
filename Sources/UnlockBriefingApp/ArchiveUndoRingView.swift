#if canImport(UnlockBriefingCore)
import UnlockBriefingCore
#endif
import SwiftUI

/// Bottom undo control. Only the ring is the click target; the caption is inert.
struct ArchiveUndoRingView: View {
    static let duration: TimeInterval = ArchiveUndoTiming.ringDuration

    let label: String
    let onUndo: () -> Void

    @State private var progress: Double = 1

    var body: some View {
        VStack(spacing: 6) {
            Button(action: onUndo) {
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.22), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
                .frame(width: 38, height: 38)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("撤销归档")
            .accessibilityLabel("已归档\(label)，5 秒内点按圆环撤销")

            Text("撤销")
                .font(.caption2)
                .foregroundColor(.secondary)
                .allowsHitTesting(false)
        }
        .onAppear {
            progress = 1
            withAnimation(.linear(duration: Self.duration)) {
                progress = 0
            }
        }
    }
}
