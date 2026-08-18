import XCTest
@testable import UnlockBriefingCore

final class CardLogicTests: XCTestCase {
    private let now = RepoFixtures.localDate(year: 2026, month: 8, day: 5, hour: 12)
    private let fm = FileManager.default

    func testParseObjectAndMixedTodos() {
        let raw = """
        {
          "todos": [
            "string-todo",
            { "text": "high one", "priority": "high" },
            { "text": "default object" },
            { "text": "bad prio", "priority": "urgent" },
            { "title": "not a todo", "date": "2026-01-01" },
            { "priority": "low" },
            { "text": "" }
          ],
          "countdowns": []
        }
        """
        let doc = BriefingEngine.parseContent(raw)
        XCTAssertEqual(doc.todos.map(\.text), ["string-todo", "high one", "default object", "bad prio"])
        XCTAssertEqual(doc.todos.map(\.priority), [.medium, .high, .medium, .medium])
    }

    func testSaveWritesTodoObjectsAndDropsEmptyText() throws {
        let dir = fm.temporaryDirectory.appendingPathComponent("ub-save-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let url = dir.appendingPathComponent("content.json")
        let store = ContentStore(fileURL: url)
        try store.save(ContentDocument(
            todos: [
                TodoItem(text: "完成报告初稿", priority: .high),
                TodoItem(text: "", priority: .low),
                TodoItem(text: "回复客户邮件", priority: .medium),
            ],
            countdowns: []
        ))
        let raw = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(raw.contains("\"text\""), raw)
        XCTAssertTrue(raw.contains("\"priority\""), raw)
        XCTAssertTrue(raw.contains("high"), raw)
        XCTAssertFalse(raw.contains("\"完成报告初稿\","), "must not write a string-only todo array")
        let parsed = BriefingEngine.parseContent(raw)
        XCTAssertEqual(parsed.todos.map(\.text), ["完成报告初稿", "回复客户邮件"])
        XCTAssertEqual(parsed.todos.map(\.priority), [.high, .medium])
    }

    func testNewCountdownRecordsStartAndOldStartIsNotWritten() throws {
        let created = BriefingEngine.newCountdown(now: now)
        XCTAssertEqual(created.start, "2026-08-05")
        XCTAssertEqual(created.title, "")
        XCTAssertEqual(created.date, "")

        let dir = fm.temporaryDirectory.appendingPathComponent("ub-start-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let url = dir.appendingPathComponent("content.json")
        let store = ContentStore(fileURL: url)
        try store.save(ContentDocument(
            todos: [],
            countdowns: [
                CountdownItem(title: "生日", date: "2026-09-15"),
                CountdownItem(title: "上线", date: "2026-12-31", start: "2026-08-01"),
            ]
        ))
        let raw = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(raw.contains("2026-08-01"), raw)
        XCTAssertEqual(raw.components(separatedBy: "\"start\"").count - 1, 1, raw)
        let parsed = BriefingEngine.parseContent(raw)
        XCTAssertNil(parsed.countdowns.first { $0.title == "生日" }?.start)
        XCTAssertEqual(parsed.countdowns.first { $0.title == "上线" }?.start, "2026-08-01")
    }

    func testSortedCountdownsUpcomingThenExpiredStable() {
        let items = [
            CountdownItem(title: "生日", date: "2026-09-15"),
            CountdownItem(title: "考试", date: "2026-08-10"),
            CountdownItem(title: "过期早", date: "2026-01-01"),
            CountdownItem(title: "过期近", date: "2026-07-01"),
            CountdownItem(title: "周会", date: "2026-08-10"),
            CountdownItem(title: "坏日期", date: "not-a-date"),
            CountdownItem(title: "", date: "2026-08-11"),
        ]
        let sorted = BriefingEngine.sortedCountdownsForDisplay(items, now: now)
        XCTAssertEqual(sorted.map(\.title), ["考试", "周会", "生日", "过期近", "过期早"])
    }

    func testCountdownProgressStartWindowAndExpired() {
        let withStart = BriefingEngine.countdownProgress(start: "2026-08-05", date: "2026-08-20", now: now)
        XCTAssertEqual(withStart ?? -1, 14.5 / 15.0, accuracy: 0.0001)

        let noStartSoon = BriefingEngine.countdownProgress(start: nil, date: "2026-08-20", now: now)
        XCTAssertEqual(noStartSoon ?? -1, 14.5 / 90.0, accuracy: 0.0001)

        let noStartFar = BriefingEngine.countdownProgress(start: nil, date: "2026-12-31", now: now)
        XCTAssertEqual(noStartFar, 1)

        let expired = BriefingEngine.countdownProgress(start: "2025-01-01", date: "2026-01-01", now: now)
        XCTAssertEqual(expired, 0)

        XCTAssertNil(BriefingEngine.countdownProgress(start: nil, date: "bad", now: now))
    }

    func testProgressColorBandBoundaries() {
        XCTAssertEqual(BriefingEngine.progressColorBand(0.76), .green)
        XCTAssertEqual(BriefingEngine.progressColorBand(0.75), .yellow)
        XCTAssertEqual(BriefingEngine.progressColorBand(0.51), .yellow)
        XCTAssertEqual(BriefingEngine.progressColorBand(0.50), .orange)
        XCTAssertEqual(BriefingEngine.progressColorBand(0.26), .orange)
        XCTAssertEqual(BriefingEngine.progressColorBand(0.25), .red)
        XCTAssertEqual(BriefingEngine.progressColorBand(0), .red)
    }

    func testRemainingDaysPresetBoundaries() {
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 31, preset: .standard), .green)
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 30, preset: .standard), .yellow)
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 8, preset: .standard), .yellow)
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 7, preset: .standard), .orange)
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 1, preset: .standard), .orange)
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 0, preset: .standard), .red)

        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 61, preset: .relaxed), .green)
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 60, preset: .relaxed), .yellow)
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 15, preset: .relaxed), .yellow)
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 14, preset: .relaxed), .orange)
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 4, preset: .relaxed), .orange)
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 3, preset: .relaxed), .red)

        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 15, preset: .tight), .green)
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 14, preset: .tight), .yellow)
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 4, preset: .tight), .yellow)
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 3, preset: .tight), .orange)
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 1, preset: .tight), .orange)
        XCTAssertEqual(BriefingEngine.remainingDaysBand(remainingDays: 0, preset: .tight), .red)
    }

    func testRemainingWholeDaysMatchesFormatCountdownFloor() {
        XCTAssertEqual(BriefingEngine.remainingWholeDays(date: "2026-08-20", now: now), 14)
        XCTAssertEqual(BriefingEngine.remainingWholeDays(date: "2026-08-13", now: now), 7)
        XCTAssertEqual(BriefingEngine.remainingWholeDays(date: "2026-01-01", now: now), 0)
        XCTAssertNil(BriefingEngine.remainingWholeDays(date: "bad", now: now))
    }

    func testPresentationSortsAndKeepsCopy() {
        let document = ContentDocument(
            todos: [TodoItem(text: "完成报告初稿", priority: .high)],
            countdowns: [
                CountdownItem(title: "生日", date: "2026-09-15"),
                CountdownItem(title: "考试", date: "2026-08-10"),
            ]
        )
        let shown = BriefingEngine.presentation(document: document, now: now, preset: .standard)
        XCTAssertFalse(shown.isEmpty)
        XCTAssertEqual(shown.greetingLine, "下午好！今天是 2026年08月05日")
        XCTAssertEqual(shown.todos.map(\.text), ["完成报告初稿"])
        XCTAssertEqual(shown.countdowns.map(\.item.title), ["考试", "生日"])
        XCTAssertEqual(shown.countdowns[0].remainingLabel, "还剩 4 天 12 小时")
        XCTAssertEqual(shown.countdowns[0].line, "考试：还剩 4 天 12 小时")
        XCTAssertEqual(shown.countdowns[0].remainingDays, 4)
        XCTAssertEqual(
            BriefingEngine.editorCountdownOrder(document.countdowns + [CountdownItem(title: "", date: "")], now: now),
            [1, 0, 2],
            "valid items keep display order; blank draft stays last"
        )
        XCTAssertEqual(shown.countdowns[0].remainingDaysBand, .orange)
        XCTAssertFalse(shown.countdowns[0].isExpired)

        let empty = BriefingEngine.presentation(document: .empty, now: now)
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty.emptyMessage, "下午好！今天暂无特别安排，保持专注。")
        XCTAssertEqual(empty.greetingLine, empty.emptyMessage)
    }

    func testDragDestinationStaysUntilHalfRow() {
        let frames = [
            CGRect(x: 0, y: 0, width: 400, height: 50),
            CGRect(x: 0, y: 58, width: 400, height: 50),
            CGRect(x: 0, y: 116, width: 400, height: 50),
        ]
        XCTAssertEqual(BriefingEngine.dragDestinationIndex(origin: 0, translation: 0, frames: frames, count: 3), 0)
        XCTAssertEqual(BriefingEngine.dragDestinationIndex(origin: 0, translation: 10, frames: frames, count: 3), 0)
        XCTAssertEqual(BriefingEngine.dragDestinationIndex(origin: 0, translation: 20, frames: frames, count: 3), 0)
        XCTAssertEqual(BriefingEngine.dragDestinationIndex(origin: 0, translation: 40, frames: frames, count: 3), 1)
        XCTAssertEqual(BriefingEngine.dragDestinationIndex(origin: 0, translation: 120, frames: frames, count: 3), 2)
        XCTAssertEqual(BriefingEngine.dragDestinationIndex(origin: 2, translation: -10, frames: frames, count: 3), 2)
        XCTAssertEqual(BriefingEngine.dragDestinationIndex(origin: 2, translation: -40, frames: frames, count: 3), 1)
        XCTAssertEqual(BriefingEngine.dragDestinationIndex(origin: 0, translation: 0, frames: [], count: 0), 0)
        let collapsed = Array(repeating: CGRect(x: 0, y: 0, width: 400, height: 50), count: 3)
        XCTAssertEqual(BriefingEngine.dragDestinationIndex(origin: 0, translation: 10, frames: collapsed, count: 3), 0)
        XCTAssertEqual(BriefingEngine.dragDestinationIndex(origin: 0, translation: 40, frames: collapsed, count: 3), 1)

        // Live frames that already include the drag offset double-count translation.
        var liveOffset = frames
        liveOffset[0] = liveOffset[0].offsetBy(dx: 0, dy: 58)
        XCTAssertEqual(
            BriefingEngine.dragDestinationIndex(origin: 0, translation: 58, frames: liveOffset, count: 3),
            2,
            "origin.midY + translation must use rest frames, not the moving card"
        )
        XCTAssertEqual(
            BriefingEngine.dragDestinationIndex(origin: 0, translation: 58, frames: frames, count: 3),
            1
        )

        XCTAssertEqual(BriefingEngine.moveToOffset(origin: 0, destination: 2), 3)
        XCTAssertEqual(BriefingEngine.moveToOffset(origin: 2, destination: 0), 0)
        XCTAssertNil(BriefingEngine.moveToOffset(origin: 1, destination: 1))
    }

    func testOldSettingsJSONFillsAppearanceDefaults() throws {
        let raw = """
        {"repoURL":"git@example.com:x.git","showMenuBar":true}
        """
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(raw.utf8))
        XCTAssertEqual(settings.countdownAppearance, .remainingDays)
        XCTAssertEqual(settings.countdownUrgencyPreset, .standard)
        XCTAssertEqual(settings.repoURL, "git@example.com:x.git")
    }
}
