import Foundation

/// Pure briefing logic ported from `briefing.lua`.
public enum BriefingEngine {
    public static func normalizeTodos(_ list: [String]?) -> [String] {
        guard let list else { return [] }
        return list.filter { !$0.isEmpty }
    }

    public static func normalizeCountdowns(_ list: [CountdownItem]?) -> [CountdownItem] {
        guard let list else { return [] }
        return list.filter { !$0.title.isEmpty && !$0.date.isEmpty }
    }

    /// Parse unified `content.json`: `{ "todos": [...], "countdowns": [{title,date}] }`.
    /// Legacy bare string array becomes todos only.
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
                return ContentDocument(todos: normalizeTodos(stringList(from: array)), countdowns: [])
            }
            return empty
        }
        guard let dict = object as? [String: Any] else {
            return empty
        }
        return ContentDocument(
            todos: normalizeTodos(stringList(from: dict["todos"])),
            countdowns: normalizeCountdowns(countdownList(from: dict["countdowns"]))
        )
    }

    public static func parseTodos(_ raw: String?) -> [String] {
        parseContent(raw).todos
    }

    /// Format remaining time for one countdown. `now` is a local wall-clock instant.
    /// Date string must match `YYYY-M-D` (`%d+-%d+-%d+`). Invalid date → nil.
    public static func formatCountdown(title: String?, date dateStr: String?, now: Date) -> String? {
        guard let title, let dateStr else { return nil }
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
        guard let target = Calendar.current.date(from: components) else {
            return nil
        }
        let diff = target.timeIntervalSince(now)
        if diff > 0 {
            let days = Int(floor(diff / 86_400))
            if days >= 7 {
                let weeks = days / 7
                let remDays = days % 7
                return "\(title)：还剩 \(weeks) 周 \(remDays) 天"
            }
            let hours = Int(floor(diff.truncatingRemainder(dividingBy: 86_400) / 3_600))
            return "\(title)：还剩 \(days) 天 \(hours) 小时"
        }
        return "\(title)：已到期"
    }

    public static func getCountdowns(_ countdowns: [CountdownItem]?, now: Date) -> [String] {
        guard let countdowns else { return [] }
        return countdowns.compactMap { formatCountdown(title: $0.title, date: $0.date, now: now) }
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

    private static func stringList(from value: Any?) -> [String] {
        guard let array = value as? [Any] else { return [] }
        return array.compactMap { $0 as? String }
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
            return CountdownItem(title: title, date: date)
        }
    }
}
