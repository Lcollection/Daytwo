import XCTest
@testable import Daytwo

final class StatsCalculatorTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func entry(on date: Date) -> JournalEntry {
        JournalEntry(createdAt: date, content: "内容")
    }

    func testEmptyStats() {
        let stats = StatsCalculator.compute(entries: [], now: date(2025, 10, 4), calendar: calendar)
        XCTAssertEqual(stats.entryCount, 0)
        XCTAssertEqual(stats.wordCount, 0)
        XCTAssertEqual(stats.dayCount, 0)
        XCTAssertEqual(stats.streakDays, 0)
    }

    func testBasicCounts() {
        let entries = [
            entry(on: date(2025, 10, 1)),
            entry(on: date(2025, 10, 2)),
            entry(on: date(2025, 10, 2, hour: 20)), // 同一天两篇
        ]
        let stats = StatsCalculator.compute(entries: entries, now: date(2025, 10, 4), calendar: calendar)
        XCTAssertEqual(stats.entryCount, 3)
        XCTAssertEqual(stats.dayCount, 2)
    }

    func testWordCountAggregation() {
        var e1 = entry(on: date(2025, 10, 2))
        e1.content = "你好世界"            // 4 字
        var e2 = entry(on: date(2025, 10, 3))
        e2.content = "hello world"        // 2 词
        let stats = StatsCalculator.compute(entries: [e1, e2], now: date(2025, 10, 4), calendar: calendar)
        XCTAssertEqual(stats.wordCount, 6)
    }

    func testStreakEndedToday() {
        let entries = [
            entry(on: date(2025, 10, 1)),
            entry(on: date(2025, 10, 2)),
            entry(on: date(2025, 10, 3)),
        ]
        // 今天是 10.3 且写了 → 连续 3 天
        let stats = StatsCalculator.compute(entries: entries, now: date(2025, 10, 3), calendar: calendar)
        XCTAssertEqual(stats.streakDays, 3)
    }

    func testStreakBroken() {
        let entries = [
            entry(on: date(2025, 10, 1)),
            entry(on: date(2025, 10, 2)),
            // 10.3 缺卡
            entry(on: date(2025, 10, 4)),
        ]
        let stats = StatsCalculator.compute(entries: entries, now: date(2025, 10, 4), calendar: calendar)
        XCTAssertEqual(stats.streakDays, 1)
    }

    func testStreakToleratesTodayNotWritten() {
        let entries = [
            entry(on: date(2025, 10, 1)),
            entry(on: date(2025, 10, 2)),
        ]
        // 今天 10.3 还没写，但昨天 10.2 写了 → 连续 2 天
        let stats = StatsCalculator.compute(entries: entries, now: date(2025, 10, 3), calendar: calendar)
        XCTAssertEqual(stats.streakDays, 2)
    }

    func testTimelineHeader() {
        let now = date(2025, 10, 4, hour: 15)
        XCTAssertEqual(DateFormatters.timelineHeader(for: date(2025, 10, 4, hour: 8), now: now, calendar: calendar), "今天")
        XCTAssertEqual(DateFormatters.timelineHeader(for: date(2025, 10, 3), now: now, calendar: calendar), "昨天")
        let older = DateFormatters.timelineHeader(for: date(2025, 10, 1), now: now, calendar: calendar)
        XCTAssertTrue(older.contains("2025年10月1日"))
        XCTAssertTrue(older.contains("星期"))
    }
}
