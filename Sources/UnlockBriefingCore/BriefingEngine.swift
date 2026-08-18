import CoreGraphics
import Foundation

/// Pure briefing logic ported from `briefing.lua`.
public enum BriefingEngine {
    public static let defaultProgressWindowDays = 90

    public static func normalizeTodos(_ list: [TodoItem]?) -> [TodoItem] {
        guard let list else { return [] }
        return list.filter { !$0.text.isEmpty }
    }

    public static func normalizeCountdowns(_ list: [CountdownItem]?) -> [CountdownItem] {
        guard let list else { return [] }
        return list.compactMap { item in
            guard !item.title.isEmpty, !item.date.isEmpty else { return nil }
            var next = item
            if let start = next.start, start.isEmpty {
                next.start = nil
            }
            return next
        }
    }

    /// Parse unified `content.json`: `{ "todos": [...], "countdowns": [{title,date,start?}] }`.
    /// Legacy bare string array becomes todos only. String todos become medium priority.
    public static func parseContent(_ raw: String?) -> ContentDocument {
        let empty = ContentDocument.empty
        guard let raw, !raw.isEmpty, let data = raw.data(using: .utf8) else {
            return empty
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return empty
        }
        if let array = object as? [Any] {
            if let first = array.first, first is String {
                return ContentDocument(todos: normalizeTodos(todoList(from: array)), countdowns: [])
            }
            return empty
        }
        guard let dict = object as? [String: Any] else {
            return empty
        }
        return ContentDocument(
            todos: normalizeTodos(todoList(from: dict["todos"])),
            countdowns: normalizeCountdowns(countdownList(from: dict["countdowns"]))
        )
    }

    public static func parseTodos(_ raw: String?) -> [TodoItem] {
        parseContent(raw).todos
    }

    public static func newCountdown(now: Date) -> CountdownItem {
        CountdownItem(title: "", date: "", start: todayString(for: now))
    }

    /// Parse `YYYY-M-D` as local midnight. Invalid → nil.
    public static func parseLocalDate(_ dateStr: String?) -> Date? {
        guard let dateStr else { return nil }
        guard dateStr.range(of: #"^\d+-\d+-\d+$"#, options: .regularExpression) != nil else {
            return nil
        }
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            return nil
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components)
    }

    /// Format remaining time for one countdown. `now` is a local wall-clock instant.
    /// Date string must match `YYYY-M-D` (`%d+-%d+-%d+`). Invalid date → nil.
    public static func formatCountdown(title: String?, date dateStr: String?, now: Date) -> String? {
        guard let title else { return nil }
        guard let parts = remainingParts(date: dateStr, now: now) else { return nil }
        if parts.seconds > 0 {
            return "\(title)：还剩 \(parts.label)"
        }
        return "\(title)：已到期"
    }

    public static func remainingTimeLabel(date dateStr: String?, now: Date) -> String? {
        guard let parts = remainingParts(date: dateStr, now: now) else { return nil }
        if parts.seconds > 0 {
            return "还剩 \(parts.label)"
        }
        return "已到期"
    }

    public static func getCountdowns(_ countdowns: [CountdownItem]?, now: Date) -> [String] {
        guard let countdowns else { return [] }
        return countdowns.compactMap { formatCountdown(title: $0.title, date: $0.date, now: now) }
    }

    /// Display order only. Does not mutate JSON order.
    /// Upcoming first by remaining seconds ascending; expired after, newest expiry first.
    /// Same date keeps original relative order. Invalid dates are omitted.
    public static func sortedCountdownsForDisplay(_ items: [CountdownItem], now: Date) -> [CountdownItem] {
        items.enumerated()
            .compactMap { index, item -> (Int, CountdownItem, Date, TimeInterval)? in
                guard !item.title.isEmpty, let target = parseLocalDate(item.date) else { return nil }
                return (index, item, target, target.timeIntervalSince(now))
            }
            .sorted { lhs, rhs in
                let lhsExpired = lhs.3 <= 0
                let rhsExpired = rhs.3 <= 0
                if lhsExpired != rhsExpired {
                    return !lhsExpired && rhsExpired
                }
                if lhsExpired {
                    if lhs.2 != rhs.2 { return lhs.2 > rhs.2 }
                    return lhs.0 < rhs.0
                }
                if lhs.3 != rhs.3 { return lhs.3 < rhs.3 }
                return lhs.0 < rhs.0
            }
            .map(\.1)
    }

    /// Editor rows follow display order; incomplete or invalid items stay at the end.
    public static func editorCountdownOrder(_ items: [CountdownItem], now: Date) -> [Int] {
        let sorted = sortedCountdownsForDisplay(items, now: now)
        var used = Set<Int>()
        var order: [Int] = []
        for item in sorted {
            if let idx = items.indices.first(where: { !used.contains($0) && items[$0] == item }) {
                used.insert(idx)
                order.append(idx)
            }
        }
        for idx in items.indices where !used.contains(idx) {
            order.append(idx)
        }
        return order
    }

    /// Remaining whole days using the same floor-seconds rule as `formatCountdown`.
    /// Expired or due now → 0. Invalid date → nil.
    public static func remainingWholeDays(date dateStr: String?, now: Date) -> Int? {
        guard let parts = remainingParts(date: dateStr, now: now) else { return nil }
        if parts.seconds <= 0 { return 0 }
        return parts.days
    }

    /// 0...1. Missing `start` uses a 90-day window before `date` and is not persisted.
    /// `now` before that window clamps to 1. Expired → 0. Invalid `date` → nil.
    public static func countdownProgress(start: String?, date: String, now: Date) -> Double? {
        guard let target = parseLocalDate(date) else { return nil }
        if target.timeIntervalSince(now) <= 0 {
            return 0
        }
        let startDate: Date
        if let start, let parsed = parseLocalDate(start) {
            startDate = parsed
        } else if let window = Calendar.current.date(
            byAdding: .day,
            value: -defaultProgressWindowDays,
            to: target
        ) {
            startDate = window
        } else {
            return nil
        }
        if startDate >= target {
            return 1
        }
        if now < startDate {
            return 1
        }
        let remaining = target.timeIntervalSince(now)
        let total = target.timeIntervalSince(startDate)
        guard total > 0 else { return 0 }
        return min(1, max(0, remaining / total))
    }

    public static func progressColorBand(_ percent: Double) -> CountdownColorBand {
        if percent > 0.75 { return .green }
        if percent > 0.50 { return .yellow }
        if percent > 0.25 { return .orange }
        return .red
    }

    public static func remainingDaysBand(remainingDays: Int, preset: CountdownUrgencyPreset) -> CountdownColorBand {
        if remainingDays > preset.greenAbove { return .green }
        if remainingDays > preset.yellowAbove { return .yellow }
        if remainingDays > preset.orangeAbove { return .orange }
        return .red
    }

    public static func presentation(
        document: ContentDocument,
        now: Date,
        preset: CountdownUrgencyPreset = .standard
    ) -> BriefingPresentation {
        let greeting = greetingForHour(hour(for: now))
        let label = dateLabel(for: now)
        let todos = normalizeTodos(document.todos)
        let cards = sortedCountdownsForDisplay(document.countdowns, now: now).compactMap {
            countdownPresentation(item: $0, now: now, preset: preset)
        }
        let isEmpty = todos.isEmpty && cards.isEmpty
        let emptyMessage = "\(greeting)！今天暂无特别安排，保持专注。"
        return BriefingPresentation(
            greetingLine: isEmpty ? emptyMessage : "\(greeting)！今天是 \(label)",
            isEmpty: isEmpty,
            emptyMessage: emptyMessage,
            todos: todos,
            countdowns: cards
        )
    }

    public static func countdownPresentation(
        item: CountdownItem,
        now: Date,
        preset: CountdownUrgencyPreset
    ) -> CountdownPresentation? {
        guard let line = formatCountdown(title: item.title, date: item.date, now: now),
              let remainingLabel = remainingTimeLabel(date: item.date, now: now),
              let remainingDays = remainingWholeDays(date: item.date, now: now),
              let progress = countdownProgress(start: item.start, date: item.date, now: now)
        else {
            return nil
        }
        let expired = remainingLabel == "已到期"
        return CountdownPresentation(
            item: item,
            line: line,
            remainingLabel: remainingLabel,
            isExpired: expired,
            remainingDays: remainingDays,
            progress: progress,
            progressBand: progressColorBand(progress),
            remainingDaysBand: remainingDaysBand(remainingDays: remainingDays, preset: preset)
        )
    }

    public static func greetingForHour(_ hour: Int) -> String {
        if hour < 12 {
            return "早上好"
        }
        if hour < 18 {
            return "下午好"
        }
        return "晚上好"
    }

    public static func dateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }

    public static func todayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    public static func hour(for date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    public static func buildMessage(
        todos: [String],
        countdowns: [String],
        now: Date,
        dateLabel overrideLabel: String? = nil
    ) -> String {
        let greeting = greetingForHour(hour(for: now))
        let label = overrideLabel ?? dateLabel(for: now)
        if todos.isEmpty && countdowns.isEmpty {
            return "\(greeting)！今天暂无特别安排，保持专注。"
        }
        var lines: [String] = ["\(greeting)！今天是 \(label)"]
        if !todos.isEmpty {
            lines.append("")
            lines.append("【今日待办】")
            for (index, todo) in todos.enumerated() {
                lines.append("\(index + 1). \(todo)")
            }
        }
        if !countdowns.isEmpty {
            lines.append("")
            lines.append("【关键倒计时】")
            for line in countdowns {
                lines.append("• \(line)")
            }
        }
        return lines.joined(separator: "\n")
    }

    public static func shouldShow(onlyFirst: Bool, lastShownDate: String?, today: String) -> Bool {
        if onlyFirst && lastShownDate == today {
            return false
        }
        return true
    }

    /// Destination index for a card-body drag.
    /// Uses the dragged card's visual center (`origin.midY + translation`) so grabbing
    /// the lower half of a card does not immediately jump to the next row.
    public static func dragDestinationIndex(
        origin: Int,
        translation: CGFloat,
        frames: [CGRect],
        count: Int
    ) -> Int {
        guard count > 0 else { return 0 }
        let originIndex = min(max(origin, 0), count - 1)
        if let mids = stackedMidYs(frames: frames, count: count) {
            let draggedCenterY = mids[originIndex] + translation
            var best = originIndex
            var bestDistance = CGFloat.greatestFiniteMagnitude
            for index in 0..<count {
                let distance = abs(draggedCenterY - mids[index])
                if distance < bestDistance {
                    bestDistance = distance
                    best = index
                }
            }
            return best
        }
        let rowHeight: CGFloat
        if originIndex < frames.count, frames[originIndex].height > 1 {
            rowHeight = frames[originIndex].height + 8
        } else {
            rowHeight = 56
        }
        let steps = Int((translation / rowHeight).rounded())
        return min(max(originIndex + steps, 0), count - 1)
    }

    private static func stackedMidYs(frames: [CGRect], count: Int) -> [CGFloat]? {
        guard frames.count >= count, count > 0 else { return nil }
        let mids = (0..<count).map { frames[$0].midY }
        let heightsOK = (0..<count).allSatisfy { frames[$0].height > 1 }
        let spread = (mids.max() ?? 0) - (mids.min() ?? 0)
        guard heightsOK, spread > 10 else { return nil }
        return mids
    }

    /// `Array.move(fromOffsets:toOffset:)` argument that makes `origin` occupy `destination`.
    public static func moveToOffset(origin: Int, destination: Int) -> Int? {
        guard origin != destination else { return nil }
        return destination > origin ? destination + 1 : destination
    }

    private struct RemainingParts {
        var seconds: TimeInterval
        var days: Int
        var label: String
    }

    private static func remainingParts(date dateStr: String?, now: Date) -> RemainingParts? {
        guard let target = parseLocalDate(dateStr) else { return nil }
        let diff = target.timeIntervalSince(now)
        if diff > 0 {
            let days = Int(floor(diff / 86_400))
            let label: String
            if days >= 7 {
                let weeks = days / 7
                let remDays = days % 7
                label = "\(weeks) 周 \(remDays) 天"
            } else {
                let hours = Int(floor(diff.truncatingRemainder(dividingBy: 86_400) / 3_600))
                label = "\(days) 天 \(hours) 小时"
            }
            return RemainingParts(seconds: diff, days: days, label: label)
        }
        return RemainingParts(seconds: diff, days: 0, label: "已到期")
    }

    private static func todoList(from value: Any?) -> [TodoItem] {
        guard let array = value as? [Any] else { return [] }
        return array.compactMap { item in
            if let text = item as? String {
                return text.isEmpty ? nil : TodoItem(text: text, priority: .medium)
            }
            guard let dict = item as? [String: Any] else { return nil }
            if dict["text"] == nil, dict["title"] != nil {
                return nil
            }
            guard let text = dict["text"] as? String, !text.isEmpty else { return nil }
            let rawPriority = dict["priority"] as? String ?? ""
            let priority = TodoPriority(rawValue: rawPriority) ?? .medium
            return TodoItem(text: text, priority: priority)
        }
    }

    private static func countdownList(from value: Any?) -> [CountdownItem] {
        guard let array = value as? [Any] else { return [] }
        return array.compactMap { item in
            guard let dict = item as? [String: Any],
                  let title = dict["title"] as? String,
                  let date = dict["date"] as? String
            else {
                return nil
            }
            let start = (dict["start"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return CountdownItem(title: title, date: date, start: start)
        }
    }
}
