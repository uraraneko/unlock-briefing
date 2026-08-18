import XCTest
@testable import UnlockBriefingCore

final class ArchiveLogicTests: XCTestCase {
    private let now = RepoFixtures.localDate(year: 2026, month: 8, day: 5, hour: 12)
    private let fm = FileManager.default

    func testParseArchivedMissingNullNonArrayAndMixed() {
        let missing = BriefingEngine.parseContent("""
        { "todos": ["a"], "countdowns": [] }
        """)
        XCTAssertEqual(missing.todos.map(\.text), ["a"])
        XCTAssertEqual(missing.archived, [])

        let nullArchived = BriefingEngine.parseContent("""
        { "todos": [], "archived": null, "countdowns": [] }
        """)
        XCTAssertEqual(nullArchived.archived, [])

        let objectArchived = BriefingEngine.parseContent("""
        { "todos": [], "archived": { "text": "nope" }, "countdowns": [] }
        """)
        XCTAssertEqual(objectArchived.archived, [])

        let mixed = BriefingEngine.parseContent("""
        {
          "todos": [],
          "countdowns": [],
          "archived": [
            { "text": "done", "priority": "high" },
            { "title": "Launch", "date": "2026-12-31", "start": "2026-08-01" },
            "legacy string",
            { "text": "bad prio", "priority": "urgent" },
            { "text": "" },
            { "title": "", "date": "2026-01-01" },
            { "title": "no date" }
          ]
        }
        """)
        XCTAssertEqual(mixed.archived.count, 4)
        XCTAssertEqual(mixed.archived[0], .todo(TodoItem(text: "done", priority: .high)))
        XCTAssertEqual(
            mixed.archived[1],
            .countdown(CountdownItem(title: "Launch", date: "2026-12-31", start: "2026-08-01"))
        )
        XCTAssertEqual(mixed.archived[2], .todo(TodoItem(text: "legacy string", priority: .medium)))
        XCTAssertEqual(mixed.archived[3], .todo(TodoItem(text: "bad prio", priority: .medium)))
    }

    func testSaveAlwaysWritesArchivedAndDropsEmptyText() throws {
        let store = try makeStore()
        try store.save(ContentDocument(
            todos: [TodoItem(text: "live", priority: .low)],
            archived: [
                .todo(TodoItem(text: "kept", priority: .high)),
                .todo(TodoItem(text: "", priority: .medium)),
                .countdown(CountdownItem(title: "", date: "2026-01-01")),
                .countdown(CountdownItem(title: "旧里程碑", date: "2026-07-01", start: "2026-06-01")),
            ],
            countdowns: []
        ))
        let raw = try String(contentsOf: store.fileURL, encoding: .utf8)
        XCTAssertTrue(raw.contains("\"archived\""), raw)
        XCTAssertTrue(raw.contains("kept"), raw)
        XCTAssertTrue(raw.contains("旧里程碑"), raw)
        XCTAssertFalse(raw.contains("\"text\" : \"\""), raw)

        let emptyStore = try makeStore()
        try emptyStore.save(ContentDocument(todos: [], archived: [], countdowns: []))
        let emptyRaw = try String(contentsOf: emptyStore.fileURL, encoding: .utf8)
        XCTAssertTrue(emptyRaw.contains("\"archived\""), emptyRaw)
        let emptyParsed = BriefingEngine.parseContent(emptyRaw)
        XCTAssertEqual(emptyParsed.archived, [])
    }

    func testSaveKeepsExistingArchivedOnSecondWrite() throws {
        let store = try makeStore()
        let original = ContentDocument(
            todos: [TodoItem(text: "live")],
            archived: [
                .todo(TodoItem(text: "done", priority: .high)),
                .countdown(CountdownItem(title: "旧", date: "2026-07-01", start: "2026-06-01")),
            ],
            countdowns: [CountdownItem(title: "考试", date: "2026-10-10")]
        )
        try store.save(original)
        let first = store.load()
        XCTAssertEqual(first.archived, original.archived)
        try store.save(first)
        XCTAssertEqual(store.load(), first)
        XCTAssertEqual(store.load().archived, original.archived)
    }

    func testArchiveTodoMovesToHeadAndUndoRestoresIndex() {
        let document = ContentDocument(
            todos: [
                TodoItem(text: "one"),
                TodoItem(text: "two", priority: .high),
                TodoItem(text: "three"),
            ],
            archived: [.todo(TodoItem(text: "two", priority: .high))],
            countdowns: []
        )
        guard let (archivedDoc, snapshot) = ArchiveTransform.archiveTodo(at: 1, in: document) else {
            return XCTFail("archiveTodo should succeed")
        }
        XCTAssertEqual(archivedDoc.todos.map(\.text), ["one", "three"])
        XCTAssertEqual(archivedDoc.archived.first, .todo(TodoItem(text: "two", priority: .high)))
        XCTAssertEqual(archivedDoc.archived.count, 2)
        XCTAssertEqual(archivedDoc.archived[1], .todo(TodoItem(text: "two", priority: .high)))
        XCTAssertEqual(snapshot.kind, .todo)
        XCTAssertEqual(snapshot.originalIndex, 1)

        guard let restored = ArchiveTransform.undo(snapshot, in: archivedDoc) else {
            return XCTFail("undo should succeed")
        }
        XCTAssertEqual(restored.todos, document.todos)
        XCTAssertEqual(restored.archived, [.todo(TodoItem(text: "two", priority: .high))])
    }

    func testArchiveCountdownAndOutOfRangeUndoAppends() {
        let document = ContentDocument(
            todos: [],
            archived: [],
            countdowns: [
                CountdownItem(title: "生日", date: "2026-09-15"),
                CountdownItem(title: "考试", date: "2026-08-10", start: "2026-08-01"),
            ]
        )
        guard let (archivedDoc, snapshot) = ArchiveTransform.archiveCountdown(at: 1, in: document) else {
            return XCTFail("archiveCountdown should succeed")
        }
        XCTAssertEqual(archivedDoc.countdowns.map(\.title), ["生日"])
        XCTAssertEqual(
            archivedDoc.archived.first,
            .countdown(CountdownItem(title: "考试", date: "2026-08-10", start: "2026-08-01"))
        )

        let stale = ArchiveUndoSnapshot(
            kind: .countdown,
            originalIndex: 9,
            item: snapshot.item
        )
        guard let restored = ArchiveTransform.undo(stale, in: archivedDoc) else {
            return XCTFail("out-of-range undo should still restore")
        }
        XCTAssertEqual(restored.countdowns.map(\.title), ["生日", "考试"])
        XCTAssertEqual(restored.countdowns.last?.start, "2026-08-01")
        XCTAssertTrue(restored.archived.isEmpty)
    }

    func testPresentationAndEmptyStateIgnoreArchived() {
        let document = ContentDocument(
            todos: [],
            archived: [
                .todo(TodoItem(text: "已归档", priority: .high)),
                .countdown(CountdownItem(title: "旧里程碑", date: "2026-07-01")),
            ],
            countdowns: []
        )
        let shown = BriefingEngine.presentation(document: document, now: now, preset: .standard)
        XCTAssertTrue(shown.isEmpty)
        XCTAssertTrue(shown.todos.isEmpty)
        XCTAssertTrue(shown.countdowns.isEmpty)
        XCTAssertEqual(shown.emptyMessage, "下午好！今天暂无特别安排，保持专注。")
        XCTAssertEqual(shown.greetingLine, shown.emptyMessage)
        XCTAssertFalse(shown.emptyMessage.contains("已归档"))
        XCTAssertFalse(shown.emptyMessage.contains("旧里程碑"))
    }

    func testHardDeleteSaveDoesNotWriteArchived() throws {
        let store = try makeStore()
        var document = ContentDocument(
            todos: [TodoItem(text: "a"), TodoItem(text: "b")],
            archived: [],
            countdowns: [CountdownItem(title: "x", date: "2026-12-31")]
        )
        document.todos.remove(at: 0)
        try store.save(document)
        let loaded = store.load()
        XCTAssertEqual(loaded.todos.map(\.text), ["b"])
        XCTAssertTrue(loaded.archived.isEmpty)
        XCTAssertEqual(loaded.countdowns.count, 1)
    }

    func testDisplayedCountdownIndicesFollowDisplayOrder() {
        let items = [
            CountdownItem(title: "生日", date: "2026-09-15"),
            CountdownItem(title: "考试", date: "2026-08-10"),
            CountdownItem(title: "坏日期", date: "not-a-date"),
        ]
        XCTAssertEqual(
            BriefingEngine.documentIndicesForDisplayedCountdowns(items, now: now),
            [1, 0]
        )
    }

    func testExampleFixtureRoundTripsArchived() throws {
        let example = BriefingEngine.parseContent(try RepoFixtures.read("content.json.example"))
        XCTAssertEqual(example.todos[0].text, "完成报告初稿")
        XCTAssertGreaterThanOrEqual(example.archived.count, 1)
        XCTAssertEqual(example.archived[0], .todo(TodoItem(text: "上周已完成的报告", priority: .medium)))

        let store = try makeStore()
        try store.save(example)
        XCTAssertEqual(store.load().archived, example.archived)
    }

    func testUndoTimingConstantIsFiveSeconds() {
        XCTAssertEqual(ArchiveUndoTiming.ringDuration, 5)
    }

    func testArchiveSurfacesStayBrowseOnly() throws {
        let browse = try source("Sources/UnlockBriefingApp/MainWindowView.swift")
        let coordinator = try source("Sources/UnlockBriefingApp/AppCoordinator.swift")
        let hud = try source("Sources/UnlockBriefingApp/UnlockHUDController.swift")
        let cards = try source("Sources/UnlockBriefingApp/BriefingCardsView.swift")
        let ring = try source("Sources/UnlockBriefingApp/ArchiveUndoRingView.swift")

        XCTAssertTrue(browse.contains("ArchiveCardButton"))
        XCTAssertTrue(browse.contains("archiveTodo"))
        XCTAssertTrue(browse.contains("archiveCountdown"))
        XCTAssertTrue(browse.contains("ArchiveUndoRingView"))
        XCTAssertTrue(browse.contains("toggleTodoSelection"))
        XCTAssertTrue(browse.contains("selectedTodoIndex == index ? nil : index"))

        XCTAssertTrue(coordinator.contains("persistDocument(result.0, endEditing: false, sync: .debounced)"))
        XCTAssertTrue(coordinator.contains("static let browseReorderSyncDelay: TimeInterval = 3"))
        XCTAssertTrue(coordinator.contains("ArchiveUndoTiming.ringDuration"))

        XCTAssertFalse(hud.contains("ArchiveCardButton"))
        XCTAssertFalse(hud.contains("archiveTodo"))
        XCTAssertFalse(hud.contains("archiveCountdown"))
        XCTAssertFalse(cards.contains("ArchiveCardButton"))
        XCTAssertFalse(cards.contains("archiveTodo"))

        XCTAssertTrue(browse.contains("coordinator.archiveTodo(at: index)"))
        if let range = browse.range(of: "func removeTodo") {
            let snippet = String(browse[range.lowerBound...].prefix(450))
            XCTAssertFalse(snippet.contains("archiveTodo"), snippet)
            XCTAssertFalse(snippet.contains("archiveCountdown"), snippet)
        } else {
            XCTFail("removeTodo must exist")
        }
        if let range = browse.range(of: "private var editor:") {
            let snippet = String(browse[range.lowerBound...].prefix(2800))
            XCTAssertFalse(snippet.contains("ArchiveCardButton"), snippet)
        } else {
            XCTFail("editor must exist")
        }

        XCTAssertTrue(ring.contains("allowsHitTesting(false)"))
        XCTAssertTrue(ring.contains("contentShape(Circle())"))
        XCTAssertTrue(ring.contains("static let duration: TimeInterval = ArchiveUndoTiming.ringDuration"))
    }

    private func makeStore() throws -> ContentStore {
        let dir = fm.temporaryDirectory.appendingPathComponent("ub-archive-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { [fm] in
            try? fm.removeItem(at: dir)
        }
        return ContentStore(fileURL: dir.appendingPathComponent("content.json"))
    }

    private func source(_ relative: String) throws -> String {
        try String(contentsOf: RepoFixtures.root.appendingPathComponent(relative), encoding: .utf8)
    }
}
