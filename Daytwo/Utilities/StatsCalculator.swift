import Foundation

struct JournalStats: Equatable {
    let entryCount: Int
    let wordCount: Int
    let dayCount: Int
    let streakDays: Int
}

/// 统计计算：总篇数、总字数、记录天数、连续记录天数
enum StatsCalculator {

    static func compute(
        entries: [JournalEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> JournalStats {
        let days = Set(entries.map { calendar.startOfDay(for: $0.createdAt) })

        // 连续记录：从今天（若今天没写则从昨天）往回数连续天数
        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return JournalStats(entryCount: entries.count, wordCount: 0, dayCount: days.count, streakDays: 0)
            }
            cursor = yesterday
        }
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return JournalStats(
            entryCount: entries.count,
            wordCount: entries.reduce(0) { $0 + $1.wordCount },
            dayCount: days.count,
            streakDays: streak
        )
    }
}
