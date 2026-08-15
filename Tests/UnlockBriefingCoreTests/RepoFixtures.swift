import Foundation

enum RepoFixtures {
    /// Repo root that contains `content.json.example`.
    static var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func read(_ name: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
    }

    static func localDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        guard let date = Calendar.current.date(from: components) else {
            fatalError("invalid local date \(year)-\(month)-\(day) \(hour):\(minute):\(second)")
        }
        return date
    }
}
