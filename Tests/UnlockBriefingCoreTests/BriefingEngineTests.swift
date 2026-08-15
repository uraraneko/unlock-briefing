import XCTest
@testable import UnlockBriefingCore

/// Drives shipped `BriefingEngine` with the same fixtures and expected strings as `tests/test_briefing.lua`.
final class BriefingEngineTests: XCTestCase {
    func testParseContentUnifiedJSON() {
        let raw = """
        {
          "todos": ["完成报告初稿", "回复客户邮件"],
          "countdowns": [
            { "title": "项目上线", "date": "2026-08-20" },
            { "title": "生日", "date": "2026-09-15" }
          ]
        }
        """
        let content = BriefingEngine.parseContent(raw)
        XCTAssertEqual(content.todos.count, 2, "parses two todos from content.json shape")
        XCTAssertEqual(content.todos[0], "完成报告初稿", "first todo text")
        XCTAssertEqual(content.countdowns.count, 2, "parses two countdowns")
        XCTAssertEqual(content.countdowns[0].title, "项目上线", "countdown title")
        XCTAssertEqual(content.countdowns[0].date, "2026-08-20", "countdown date")

        XCTAssertEqual(BriefingEngine.parseContent(nil).todos.count, 0, "nil content -> empty todos")
        XCTAssertEqual(BriefingEngine.parseContent("").todos.count, 0, "empty content -> empty")
        XCTAssertEqual(BriefingEngine.parseContent("not json").todos.count, 0, "invalid json -> empty")

        let legacy = BriefingEngine.parseContent("[\"a\", \"b\"]")
        XCTAssertEqual(legacy.todos.count, 2, "legacy array -> todos")
        XCTAssertEqual(legacy.todos, ["a", "b"])
        XCTAssertEqual(legacy.countdowns.count, 0, "legacy array -> no countdowns")
    }

    func testParseTodosLegacy() {
        let todos = BriefingEngine.parseTodos("[\"完成报告初稿\", \"回复客户邮件\"]")
        XCTAssertEqual(todos.count, 2, "parses two todos")
        XCTAssertEqual(todos[0], "完成报告初稿", "first todo text")
        XCTAssertEqual(todos[1], "回复客户邮件", "second todo text")

        XCTAssertEqual(BriefingEngine.parseTodos(nil).count, 0, "nil content -> empty")
        XCTAssertEqual(BriefingEngine.parseTodos("").count, 0, "empty content -> empty")
        XCTAssertEqual(BriefingEngine.parseTodos("not json").count, 0, "invalid json -> empty")
        XCTAssertEqual(BriefingEngine.parseTodos("[]").count, 0, "empty array -> empty")
    }

    func testFormatCountdownMatchesLuaFixtures() {
        // Fixed "now": 2026-08-05 12:00:00 local — same as tests/test_briefing.lua
        let now = RepoFixtures.localDate(year: 2026, month: 8, day: 5, hour: 12)

        let future = BriefingEngine.formatCountdown(title: "项目上线", date: "2026-08-20", now: now)
        XCTAssertEqual(future, "项目上线：还剩 2 周 0 天", ">=1 week uses weeks/days for 项目上线")
        XCTAssertTrue(future?.contains("项目上线：还剩") == true, "future has title and 还剩")

        let soon = BriefingEngine.formatCountdown(title: "周会", date: "2026-08-10", now: now)
        XCTAssertEqual(soon, "周会：还剩 4 天 12 小时", "<1 week uses days/hours")

        let weekBoundary = BriefingEngine.formatCountdown(title: "里程碑", date: "2026-08-13", now: now)
        XCTAssertEqual(weekBoundary, "里程碑：还剩 1 周 0 天", "7 days formats as weeks/days")

        let past = BriefingEngine.formatCountdown(title: "考试", date: "2026-01-01", now: now)
        XCTAssertEqual(past, "考试：已到期", "past date -> 已到期")

        XCTAssertNil(BriefingEngine.formatCountdown(title: "x", date: "bad-date", now: now), "invalid date -> nil")
        XCTAssertNil(BriefingEngine.formatCountdown(title: nil, date: "2026-01-01", now: now), "nil title -> nil")
    }

    func testGetCountdowns() {
        let now = RepoFixtures.localDate(year: 2026, month: 8, day: 5, hour: 12)
        let items = [
            CountdownItem(title: "生日", date: "2026-09-15"),
            CountdownItem(title: "过期", date: "2020-01-01"),
        ]
        let lines = BriefingEngine.getCountdowns(items, now: now)
        XCTAssertEqual(lines.count, 2, "two countdown lines")
        let birthday = BriefingEngine.formatCountdown(title: "生日", date: "2026-09-15", now: now)
        XCTAssertEqual(lines[0], birthday, "first is birthday remaining from formatCountdown")
        XCTAssertTrue(lines[0].contains("生日：还剩"), "first is birthday remaining")
        XCTAssertEqual(lines[1], "过期：已到期", "second is expired")
        XCTAssertEqual(BriefingEngine.getCountdowns(nil, now: now).count, 0, "nil list -> empty")
        XCTAssertEqual(BriefingEngine.getCountdowns([], now: now).count, 0, "empty list -> empty")
    }

    func testGreetingForHour() {
        XCTAssertEqual(BriefingEngine.greetingForHour(8), "早上好", "morning")
        XCTAssertEqual(BriefingEngine.greetingForHour(14), "下午好", "afternoon")
        XCTAssertEqual(BriefingEngine.greetingForHour(20), "晚上好", "evening")
        XCTAssertEqual(BriefingEngine.greetingForHour(0), "早上好", "midnight morning")
        XCTAssertEqual(BriefingEngine.greetingForHour(11), "早上好", "11 morning")
        XCTAssertEqual(BriefingEngine.greetingForHour(12), "下午好", "12 afternoon")
        XCTAssertEqual(BriefingEngine.greetingForHour(17), "下午好", "17 afternoon")
        XCTAssertEqual(BriefingEngine.greetingForHour(18), "晚上好", "18 evening")
    }

    func testBuildMessage() {
        let now = RepoFixtures.localDate(year: 2026, month: 8, day: 5, hour: 9)

        let empty = BriefingEngine.buildMessage(todos: [], countdowns: [], now: now)
        XCTAssertTrue(empty.contains("早上好"), "empty uses morning greeting")
        XCTAssertTrue(empty.contains("今天暂无特别安排"), "empty quiet message")
        XCTAssertEqual(empty, "早上好！今天暂无特别安排，保持专注。")
        XCTAssertFalse(empty.contains("【今日待办】"), "empty has no todo section")
        XCTAssertFalse(empty.contains("【关键倒计时】"), "empty has no countdown section")

        let full = BriefingEngine.buildMessage(
            todos: ["完成报告初稿", "回复客户邮件"],
            countdowns: ["项目上线：还剩 14 天 12 小时"],
            now: now,
            dateLabel: "2026年08月05日"
        )
        XCTAssertTrue(full.contains("早上好！今天是 2026年08月05日"), "header with date")
        XCTAssertTrue(full.contains("【今日待办】"), "has todo section")
        XCTAssertTrue(full.contains("1. 完成报告初稿"), "todo 1")
        XCTAssertTrue(full.contains("2. 回复客户邮件"), "todo 2")
        XCTAssertTrue(full.contains("【关键倒计时】"), "has countdown section")
        XCTAssertTrue(full.contains("• 项目上线：还剩 14 天 12 小时"), "countdown bullet")

        let todosOnly = BriefingEngine.buildMessage(todos: ["唯一待办"], countdowns: [], now: now)
        XCTAssertTrue(todosOnly.contains("【今日待办】"), "todos only has section")
        XCTAssertFalse(todosOnly.contains("【关键倒计时】"), "todos only no countdown section")

        let cdsOnly = BriefingEngine.buildMessage(
            todos: [],
            countdowns: ["生日：还剩 1 天 0 小时"],
            now: now
        )
        XCTAssertTrue(cdsOnly.contains("【关键倒计时】"), "cds only has section")
        XCTAssertFalse(cdsOnly.contains("【今日待办】"), "cds only no todo section")
    }

    func testShouldShowFirstOfDayGate() {
        XCTAssertTrue(BriefingEngine.shouldShow(onlyFirst: true, lastShownDate: nil, today: "2026-08-05"), "first unlock of day shows")
        XCTAssertFalse(BriefingEngine.shouldShow(onlyFirst: true, lastShownDate: "2026-08-05", today: "2026-08-05"), "same day suppressed")
        XCTAssertTrue(BriefingEngine.shouldShow(onlyFirst: true, lastShownDate: "2026-08-04", today: "2026-08-05"), "new day shows")
        XCTAssertTrue(BriefingEngine.shouldShow(onlyFirst: false, lastShownDate: "2026-08-05", today: "2026-08-05"), "flag off always shows")
        XCTAssertTrue(BriefingEngine.shouldShow(onlyFirst: false, lastShownDate: nil, today: "2026-08-05"), "flag off with nil last")
    }

    func testSampleFixturesFromRepo() throws {
        let exampleRaw = try RepoFixtures.read("content.json.example")
        let example = BriefingEngine.parseContent(exampleRaw)
        XCTAssertGreaterThanOrEqual(example.todos.count, 1, "demo content has at least one todo")
        XCTAssertEqual(example.todos[0], "完成报告初稿", "demo first todo")
        XCTAssertGreaterThanOrEqual(example.countdowns.count, 1, "demo content has countdowns")

        let now = RepoFixtures.localDate(year: 2026, month: 8, day: 5, hour: 12)
        let lines = BriefingEngine.getCountdowns(example.countdowns, now: now)
        XCTAssertGreaterThanOrEqual(lines.count, 1, "demo countdowns produce lines")

        let contentURL = RepoFixtures.root.appendingPathComponent("content.json")
        if FileManager.default.fileExists(atPath: contentURL.path) {
            let liveRaw = try String(contentsOf: contentURL, encoding: .utf8)
            let live = BriefingEngine.parseContent(liveRaw)
            XCTAssertFalse(live.todos.isEmpty && live.countdowns.isEmpty, "content.json shape parses")
            XCTAssertEqual(live.todos.first, "完成报告初稿")
        }

        XCTAssertEqual(AppSettings.default.showDuration, 8, "config showDuration default 8")
        XCTAssertEqual(AppSettings.default.onlyFirstUnlockOfDay, true, "config onlyFirstUnlockOfDay true")
        XCTAssertEqual(AppSettings.default.alsoOnWake, false)
        XCTAssertEqual(AppSettings.default.unlockDelay, 0.8)
        XCTAssertEqual(AppSettings.default.autoSyncOnToggle, true)
        XCTAssertEqual(AppSettings.default.showMenuBar, true)
    }

    func testDefaultDateLabelZeroPadded() {
        let now = RepoFixtures.localDate(year: 2026, month: 8, day: 5, hour: 9)
        XCTAssertEqual(BriefingEngine.dateLabel(for: now), "2026年08月05日")
        XCTAssertEqual(BriefingEngine.todayString(for: now), "2026-08-05")
        XCTAssertEqual(BriefingEngine.hour(for: now), 9)
    }
}
