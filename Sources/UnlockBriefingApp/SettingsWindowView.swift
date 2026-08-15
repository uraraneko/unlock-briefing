#if canImport(UnlockBriefingCore)
import UnlockBriefingCore
#endif
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsWindowView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var repoURL: String = ""
    @State private var showMenuBar = true
    @State private var launchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 6) {
                Text("Git 仓库地址")
                    .font(.headline)
                HStack(spacing: 8) {
                    TextField("https://github.com/you/private-data.git", text: $repoURL)
                        .textFieldStyle(.roundedBorder)
                        .onPasteCommand(of: [UTType.utf8PlainText, UTType.plainText]) { providers in
                            applyPaste(from: providers)
                        }
                    Button("粘贴") { pasteRepoURL() }
                }
                Text("未配置时主窗口为空，并引导来这里填写。本地没有仓时会 clone 后再读 content.json。支持 ⌘V 或点「粘贴」。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Toggle("开机时启动", isOn: $launchAtLogin)
            Toggle("在菜单栏显示图标", isOn: $showMenuBar)
            HStack {
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                Button("打开数据目录") { coordinator.openDataDirectory() }
                Spacer()
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 460, height: 280)
        .onAppear {
            repoURL = coordinator.settings.repoURL
            showMenuBar = coordinator.settings.showMenuBar
            launchAtLogin = coordinator.settings.launchAtLogin
        }
    }

    private func pasteRepoURL() {
        if let text = NSPasteboard.general.string(forType: .string) {
            applyClipboardText(text)
        }
    }

    private func applyPaste(from providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        _ = provider.loadObject(ofClass: String.self) { object, _ in
            guard let text = object else { return }
            DispatchQueue.main.async {
                applyClipboardText(text)
            }
        }
    }

    private func applyClipboardText(_ raw: String) {
        repoURL = RepoURLPaste.apply(raw, onto: repoURL)
    }

    private func save() {
        if launchAtLogin != coordinator.settings.launchAtLogin {
            coordinator.setLaunchAtLogin(launchAtLogin)
            launchAtLogin = coordinator.settings.launchAtLogin
        }
        if showMenuBar != coordinator.settings.showMenuBar {
            coordinator.setShowMenuBar(showMenuBar)
        }
        coordinator.saveRepoURL(repoURL)
        coordinator.closeSettings()
    }
}
