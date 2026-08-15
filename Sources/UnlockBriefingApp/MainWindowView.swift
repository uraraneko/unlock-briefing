#if canImport(UnlockBriefingCore)
import UnlockBriefingCore
#endif
import SwiftUI

struct MainWindowView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if coordinator.needsSettingsGuide {
                guide
            } else if coordinator.isEditing {
                editor
            } else {
                viewer
            }
            if let error = coordinator.lastError, !error.isEmpty {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.red)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 520)
        .onAppear {
            if coordinator.isEditing && coordinator.editDrafts == .empty && coordinator.document != .empty {
                coordinator.beginEditing()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("今日简报")
                .font(.title2.weight(.semibold))
            statusBadge
            Spacer()
            if !coordinator.needsSettingsGuide {
                Button(coordinator.isEditing ? "取消" : "编辑") {
                    if coordinator.isEditing {
                        coordinator.cancelEditing()
                    } else {
                        coordinator.beginEditing()
                    }
                }
            }
            Button("设置") { coordinator.openSettings() }
        }
    }

    private var statusBadge: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(coordinator.gitStatus.badgeText)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(badgeColor.opacity(0.15))
                .foregroundColor(badgeColor)
                .clipShape(Capsule())
            if let reason = coordinator.gitStatus.reasonText {
                Text(reason)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var badgeColor: Color {
        switch coordinator.gitStatus {
        case .synced:
            return .green
        case .syncing:
            return .orange
        case .failed:
            return .red
        case .idle:
            return .secondary
        }
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还没有配置 Git 仓库")
                .font(.headline)
            Text("内容只从设置里的仓库拉取。填写仓库地址后会自动 clone，并读取其中的 content.json。")
                .foregroundColor(.secondary)
            Button("去设置填写仓库地址") {
                coordinator.openSettings()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var viewer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(coordinator.briefingText)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("待办")
                .font(.headline)
            ForEach(coordinator.editDrafts.todos.indices, id: \.self) { index in
                HStack {
                    TextField("待办", text: todoBinding(index))
                    Button("删除") { removeTodo(at: index) }
                }
            }
            Button("+ 添加待办") {
                coordinator.editDrafts.todos.append("")
            }

            Text("倒计时")
                .font(.headline)
            ForEach(coordinator.editDrafts.countdowns.indices, id: \.self) { index in
                HStack {
                    TextField("标题", text: titleBinding(index))
                    TextField("YYYY-MM-DD", text: dateBinding(index))
                        .frame(width: 130)
                    Button("删除") { removeCountdown(at: index) }
                }
            }
            Button("+ 添加倒计时") {
                coordinator.editDrafts.countdowns.append(CountdownItem(title: "", date: ""))
            }

            HStack {
                Button("保存") {
                    coordinator.saveEdits()
                }
                .keyboardShortcut(.defaultAction)
                Button("打开数据目录") { coordinator.openDataDirectory() }
            }
        }
        .onAppear {
            if coordinator.editDrafts == .empty && coordinator.document != .empty {
                coordinator.beginEditing()
            }
        }
    }

    private func todoBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                coordinator.editDrafts.todos.indices.contains(index) ? coordinator.editDrafts.todos[index] : ""
            },
            set: { value in
                guard coordinator.editDrafts.todos.indices.contains(index) else { return }
                coordinator.editDrafts.todos[index] = value
            }
        )
    }

    private func titleBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                coordinator.editDrafts.countdowns.indices.contains(index)
                    ? coordinator.editDrafts.countdowns[index].title : ""
            },
            set: { value in
                guard coordinator.editDrafts.countdowns.indices.contains(index) else { return }
                coordinator.editDrafts.countdowns[index].title = value
            }
        )
    }

    private func dateBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                coordinator.editDrafts.countdowns.indices.contains(index)
                    ? coordinator.editDrafts.countdowns[index].date : ""
            },
            set: { value in
                guard coordinator.editDrafts.countdowns.indices.contains(index) else { return }
                coordinator.editDrafts.countdowns[index].date = value
            }
        )
    }

    private func removeTodo(at index: Int) {
        guard coordinator.editDrafts.todos.indices.contains(index) else { return }
        coordinator.editDrafts.todos.remove(at: index)
    }

    private func removeCountdown(at index: Int) {
        guard coordinator.editDrafts.countdowns.indices.contains(index) else { return }
        coordinator.editDrafts.countdowns.remove(at: index)
    }
}
