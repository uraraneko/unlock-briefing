#if canImport(UnlockBriefingCore)
import UnlockBriefingCore
#endif
import AppKit
import SwiftUI

/// Non-activating center HUD. Auto-hides after `showDuration` (default 8s).
final class UnlockHUDController {
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    private var onEdit: (() -> Void)?

    func show(text: String, duration: TimeInterval, onEdit: @escaping () -> Void) {
        hide()
        self.onEdit = onEdit

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 240),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        let host = NSHostingView(rootView: HUDCard(text: text, onEdit: { [weak self] in
            self?.hide()
            onEdit()
        }))
        host.frame = NSRect(x: 0, y: 0, width: 460, height: 320)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        let fitting = host.fittingSize
        var frame = panel.frame
        frame.size = NSSize(width: max(420, fitting.width), height: max(120, fitting.height))
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            frame.origin.x = visible.midX - frame.width / 2
            frame.origin.y = visible.midY - frame.height / 2
        }
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel

        let work = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    func hide() {
        hideWork?.cancel()
        hideWork = nil
        panel?.orderOut(nil)
        panel = nil
        onEdit = nil
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }
}

private struct HUDCard: View {
    let text: String
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text)
                .font(.custom("PingFang SC", size: 18))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("编辑", action: onEdit)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.85))
            }
        }
        .padding(20)
        .frame(width: 420, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(12)
    }
}
