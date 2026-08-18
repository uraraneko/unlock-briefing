#if canImport(UnlockBriefingCore)
import UnlockBriefingCore
#endif
import AppKit
import SwiftUI

struct MainWindowView: View {
    @ObservedObject var coordinator: AppCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @State private var todoIDs: [UUID] = []
    @State private var selectedTodoIndex: Int?
    @State private var draggingTodoIndex: Int?
    @State private var dragTranslation: CGFloat = 0
    @State private var insertionIndex: Int?
    @State private var todoFrames: [Int: CGRect] = [:]
    @State private var dragStartFrames: [CGRect] = []
    @FocusState private var focusedTodoID: UUID?

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
            syncTodoIDs()
        }
        .onChange(of: coordinator.document.todos) { _ in
            if !coordinator.isEditing { syncTodoIDs() }
        }
        .onChange(of: coordinator.editDrafts.todos.count) { _ in
            if coordinator.isEditing { syncTodoIDs() }
        }
        .onChange(of: coordinator.isEditing) { _ in
            syncTodoIDs()
            resetTodoDrag()
        }
        .background(keyboardMoveButtons)
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
        let presentation = coordinator.briefingPresentation()
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(presentation.greetingLine)
                    .font(.title3.weight(.semibold))
                    .padding(.top, 4)
                if !presentation.isEmpty {
                    if !presentation.todos.isEmpty {
                        Text("今日待办")
                            .font(.headline)
                        browseTodoStack(presentation.todos)
                    }
                    if !presentation.countdowns.isEmpty {
                        Text("关键倒计时")
                            .font(.headline)
                        ForEach(Array(presentation.countdowns.enumerated()), id: \.offset) { _, card in
                            CountdownCardView(
                                card: card,
                                appearance: coordinator.settings.countdownAppearance,
                                surface: .window,
                                darkWindow: colorScheme == .dark
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 6)
        }
        .scrollDisabled(draggingTodoIndex != nil)
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("待办")
                    .font(.headline)
                editorTodoStack
                Button("+ 添加待办") { addTodo() }

                Text("倒计时")
                    .font(.headline)
                    .padding(.top, 4)
                ForEach(editorCountdownIndices, id: \.self) { index in
                    editorCountdownRow(index)
                }
                Button("+ 添加倒计时") {
                    coordinator.editDrafts.countdowns.append(BriefingEngine.newCountdown(now: Date()))
                }

                HStack {
                    Button("保存") {
                        coordinator.saveEdits()
                    }
                    .keyboardShortcut(.defaultAction)
                    Button("打开数据目录") { coordinator.openDataDirectory() }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 6)
        }
        .scrollDisabled(draggingTodoIndex != nil)
        .onAppear {
            if coordinator.editDrafts == .empty && coordinator.document != .empty {
                coordinator.beginEditing()
            }
            syncTodoIDs()
        }
    }

    private func editorTodoRow(id: UUID, index: Int) -> some View {
        let colors = BriefingCardPalette.todo(
            todo(at: index)?.priority ?? .medium,
            surface: .window,
            darkWindow: colorScheme == .dark
        )
        let canDrag = coordinator.editDrafts.todos.count > 1
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(colors.text.opacity(0.55))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .gesture(todoDragGesture(index: index, enabled: canDrag))
                    .onHover { hovering in
                        applyDragCursor(hovering && canDrag)
                    }
                    .help("拖动排序")
                TextField("待办", text: todoTextBinding(index))
                    .textFieldStyle(.plain)
                    .focused($focusedTodoID, equals: id)
                    .foregroundColor(colors.text)
                priorityPicker(index)
                Button("删除") { removeTodo(at: index) }
            }
        }
        .padding(12)
        .briefingCardSurface(fill: colors.fill, border: colors.border)
        .onTapGesture { selectedTodoIndex = index }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("待办，优先级\(todo(at: index)?.priority.label ?? "中")，第 \(index + 1) / \(max(coordinator.editDrafts.todos.count, 1))")
    }

    private func priorityPicker(_ index: Int) -> some View {
        Picker("优先级", selection: todoPriorityBinding(index)) {
            ForEach(TodoPriority.allCases, id: \.self) { priority in
                Text(priority.label).tag(priority)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 120)
        .labelsHidden()
    }

    private func editorCountdownRow(_ index: Int) -> some View {
        let item = countdown(at: index)
        let dateValid = item.map { BriefingEngine.parseLocalDate($0.date) != nil } ?? false
        let startValid = item?.start.map { $0.isEmpty || BriefingEngine.parseLocalDate($0) != nil } ?? true
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("标题", text: titleBinding(index))
                Button("删除") { removeCountdown(at: index) }
            }
            HStack {
                TextField("YYYY-MM-DD", text: dateBinding(index))
                    .frame(width: 130)
                if dateValid {
                    DatePicker(
                        "",
                        selection: parsedDateBinding(index),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .frame(width: 120)
                } else {
                    Button("选择日期") { setDateField(index, key: .date, to: Date()) }
                }
            }
            HStack {
                TextField("开始日（可选）", text: startBinding(index))
                    .frame(width: 130)
                if let item, let start = item.start, BriefingEngine.parseLocalDate(start) != nil {
                    DatePicker(
                        "",
                        selection: parsedStartBinding(index),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .frame(width: 120)
                    Button("清除") {
                        guard coordinator.editDrafts.countdowns.indices.contains(index) else { return }
                        coordinator.editDrafts.countdowns[index].start = nil
                    }
                } else {
                    Button("设置开始日") { setDateField(index, key: .start, to: Date()) }
                }
            }
            if let item, !item.date.isEmpty, !dateValid {
                Text("日期无效")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            if !startValid {
                Text("开始日无效")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .briefingCardSurface(
            fill: Color(nsColor: .controlBackgroundColor).opacity(0.88),
            border: Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.10)
        )
    }

    private func browseTodoStack(_ items: [TodoItem]) -> some View {
        let canDrag = items.count > 1
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(zip(alignedIDs(count: items.count), items).enumerated()), id: \.element.0) { index, pair in
                TodoCardView(
                    item: pair.1,
                    index: index,
                    total: items.count,
                    surface: .window,
                    darkWindow: colorScheme == .dark,
                    showsHandle: canDrag
                )
                .background(todoFrameReader(index))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .opacity(draggingTodoIndex == index ? 0.55 : 1)
                .offset(y: draggingTodoIndex == index ? dragTranslation : 0)
                .zIndex(draggingTodoIndex == index ? 10 : 0)
                .overlay(alignment: .top) {
                    if shouldShowInsertion(before: index) {
                        insertionLine.offset(y: -6)
                    }
                }
                .overlay(alignment: .bottom) {
                    if index == items.count - 1, shouldShowInsertion(before: items.count) {
                        insertionLine.offset(y: 6)
                    }
                }
                .highPriorityGesture(todoDragGesture(index: index, enabled: canDrag))
                .onTapGesture { selectedTodoIndex = index }
                .onHover { hovering in
                    applyDragCursor(hovering && canDrag && draggingTodoIndex == nil)
                }
            }
        }
        .coordinateSpace(name: "todoStack")
        .onPreferenceChange(TodoRowFrameKey.self) { todoFrames = $0 }
    }

    private var editorTodoStack: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(zip(alignedIDs(count: coordinator.editDrafts.todos.count), coordinator.editDrafts.todos.indices)), id: \.0) { id, index in
                editorTodoRow(id: id, index: index)
                    .background(todoFrameReader(index))
                    .opacity(draggingTodoIndex == index ? 0.55 : 1)
                    .offset(y: draggingTodoIndex == index ? dragTranslation : 0)
                    .zIndex(draggingTodoIndex == index ? 10 : 0)
                    .overlay(alignment: .top) {
                        if shouldShowInsertion(before: index) {
                            insertionLine.offset(y: -6)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if index == coordinator.editDrafts.todos.count - 1,
                           shouldShowInsertion(before: coordinator.editDrafts.todos.count) {
                            insertionLine.offset(y: 6)
                        }
                    }
            }
        }
        .coordinateSpace(name: "todoStack")
        .onPreferenceChange(TodoRowFrameKey.self) { todoFrames = $0 }
    }

    private var insertionLine: some View {
        Capsule()
            .fill(Color.orange.opacity(0.95))
            .frame(height: 3)
            .shadow(color: Color.orange.opacity(0.35), radius: 2, y: 0)
    }

    private func todoFrameReader(_ index: Int) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: TodoRowFrameKey.self,
                value: [index: geo.frame(in: .named("todoStack"))]
            )
        }
    }

    private func todoDragGesture(index: Int, enabled: Bool) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard enabled else { return }
                if draggingTodoIndex == nil {
                    draggingTodoIndex = index
                    selectedTodoIndex = index
                    dragStartFrames = (0..<currentTodoCount).map { todoFrames[$0] ?? .zero }
                    NSCursor.closedHand.set()
                }
                dragTranslation = value.translation.height
                insertionIndex = destinationIndex(
                    origin: draggingTodoIndex ?? index,
                    translation: value.translation.height
                )
            }
            .onEnded { value in
                guard enabled else { return }
                let origin = draggingTodoIndex ?? index
                let dest = destinationIndex(origin: origin, translation: value.translation.height)
                resetTodoDrag()
                if let to = BriefingEngine.moveToOffset(origin: origin, destination: dest) {
                    moveTodos(from: IndexSet(integer: origin), to: to)
                }
            }
    }

    private func destinationIndex(origin: Int, translation: CGFloat) -> Int {
        let count = currentTodoCount
        let frames = dragStartFrames.count == count
            ? dragStartFrames
            : (0..<count).map { todoFrames[$0] ?? .zero }
        return BriefingEngine.dragDestinationIndex(
            origin: origin,
            translation: translation,
            frames: frames,
            count: count
        )
    }

    private var currentTodoCount: Int {
        coordinator.isEditing ? coordinator.editDrafts.todos.count : coordinator.document.todos.count
    }

    private func shouldShowInsertion(before index: Int) -> Bool {
        guard let dest = insertionIndex, dest != draggingTodoIndex else {
            return false
        }
        return index == dest
    }

    private func resetTodoDrag() {
        draggingTodoIndex = nil
        dragTranslation = 0
        insertionIndex = nil
        dragStartFrames = []
        NSCursor.arrow.set()
    }

    private func applyDragCursor(_ active: Bool) {
        if active {
            NSCursor.openHand.set()
        } else if draggingTodoIndex == nil {
            NSCursor.arrow.set()
        }
    }

    private var editorCountdownIndices: [Int] {
        BriefingEngine.editorCountdownOrder(coordinator.editDrafts.countdowns, now: Date())
    }

    private var keyboardMoveButtons: some View {
        Group {
            Button("上移待办") { moveSelected(by: -1) }
                .keyboardShortcut(.upArrow, modifiers: .option)
            Button("下移待办") { moveSelected(by: 1) }
                .keyboardShortcut(.downArrow, modifiers: .option)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func alignedIDs(count: Int) -> [UUID] {
        (0..<count).map { index in
            if todoIDs.indices.contains(index) {
                return todoIDs[index]
            }
            return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index)) ?? UUID()
        }
    }

    private func syncTodoIDs() {
        let count = coordinator.isEditing ? coordinator.editDrafts.todos.count : coordinator.document.todos.count
        if todoIDs.count < count {
            todoIDs.append(contentsOf: (0..<(count - todoIDs.count)).map { _ in UUID() })
        } else if todoIDs.count > count {
            todoIDs.removeLast(todoIDs.count - count)
        }
    }

    private func moveTodos(from source: IndexSet, to destination: Int) {
        todoIDs.move(fromOffsets: source, toOffset: destination)
        coordinator.reorderTodos(from: source, to: destination)
        if let selected = source.first {
            let dest = destination > selected ? destination - 1 : destination
            selectedTodoIndex = dest
        }
    }

    private func moveSelected(by offset: Int) {
        let count = coordinator.isEditing ? coordinator.editDrafts.todos.count : coordinator.document.todos.count
        guard count > 1, let selected = selectedTodoIndex, selected >= 0, selected < count else { return }
        let destIndex = selected + offset
        guard destIndex >= 0, destIndex < count else { return }
        let to = destIndex > selected ? destIndex + 1 : destIndex
        moveTodos(from: IndexSet(integer: selected), to: to)
    }

    private func addTodo() {
        coordinator.editDrafts.todos.append(TodoItem(text: "", priority: .medium))
        let newID = UUID()
        todoIDs.append(newID)
        selectedTodoIndex = coordinator.editDrafts.todos.count - 1
        focusedTodoID = newID
    }

    private func todo(at index: Int) -> TodoItem? {
        coordinator.editDrafts.todos.indices.contains(index) ? coordinator.editDrafts.todos[index] : nil
    }

    private func countdown(at index: Int) -> CountdownItem? {
        coordinator.editDrafts.countdowns.indices.contains(index) ? coordinator.editDrafts.countdowns[index] : nil
    }

    private func todoTextBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { todo(at: index)?.text ?? "" },
            set: { value in
                guard coordinator.editDrafts.todos.indices.contains(index) else { return }
                coordinator.editDrafts.todos[index].text = value
            }
        )
    }

    private func todoPriorityBinding(_ index: Int) -> Binding<TodoPriority> {
        Binding(
            get: { todo(at: index)?.priority ?? .medium },
            set: { value in
                guard coordinator.editDrafts.todos.indices.contains(index) else { return }
                coordinator.editDrafts.todos[index].priority = value
            }
        )
    }

    private func titleBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { countdown(at: index)?.title ?? "" },
            set: { value in
                guard coordinator.editDrafts.countdowns.indices.contains(index) else { return }
                coordinator.editDrafts.countdowns[index].title = value
            }
        )
    }

    private func dateBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { countdown(at: index)?.date ?? "" },
            set: { value in
                guard coordinator.editDrafts.countdowns.indices.contains(index) else { return }
                coordinator.editDrafts.countdowns[index].date = value
            }
        )
    }

    private func startBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { countdown(at: index)?.start ?? "" },
            set: { value in
                guard coordinator.editDrafts.countdowns.indices.contains(index) else { return }
                coordinator.editDrafts.countdowns[index].start = value.isEmpty ? nil : value
            }
        )
    }

    private enum DateField {
        case date
        case start
    }

    private func parsedDateBinding(_ index: Int) -> Binding<Date> {
        Binding(
            get: {
                BriefingEngine.parseLocalDate(countdown(at: index)?.date)
                    ?? Calendar.current.startOfDay(for: Date())
            },
            set: { setDateField(index, key: .date, to: $0) }
        )
    }

    private func parsedStartBinding(_ index: Int) -> Binding<Date> {
        Binding(
            get: {
                BriefingEngine.parseLocalDate(countdown(at: index)?.start)
                    ?? Calendar.current.startOfDay(for: Date())
            },
            set: { setDateField(index, key: .start, to: $0) }
        )
    }

    private func setDateField(_ index: Int, key: DateField, to date: Date) {
        guard coordinator.editDrafts.countdowns.indices.contains(index) else { return }
        let text = BriefingEngine.todayString(for: date)
        switch key {
        case .date:
            coordinator.editDrafts.countdowns[index].date = text
        case .start:
            coordinator.editDrafts.countdowns[index].start = text
        }
    }

    private func removeTodo(at index: Int) {
        guard coordinator.editDrafts.todos.indices.contains(index) else { return }
        coordinator.editDrafts.todos.remove(at: index)
        if todoIDs.indices.contains(index) {
            todoIDs.remove(at: index)
        }
        if let selected = selectedTodoIndex {
            if selected == index {
                selectedTodoIndex = nil
            } else if selected > index {
                selectedTodoIndex = selected - 1
            }
        }
    }

    private func removeCountdown(at index: Int) {
        guard coordinator.editDrafts.countdowns.indices.contains(index) else { return }
        coordinator.editDrafts.countdowns.remove(at: index)
    }
}

private struct TodoRowFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

