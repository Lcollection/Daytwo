import Foundation

/// 应用内统一的日期格式化（中文）
enum DateFormatters {
    /// 时间线分组标题：2025年10月3日 星期五
    static let timelineDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日 EEEE"
        return f
    }()

    /// 详情页完整日期
    static let full: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateStyle = .long
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        return f
    }()

    /// 仅时间 HH:mm
    static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()

    /// 导出文件名用的日期 yyyy-MM-dd
    static let exportFile: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// 时间线分组标题：今天 / 昨天 / 具体日期
    static func timelineHeader(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "今天"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "昨天"
        }
        return timelineDate.string(from: date)
    }
}
