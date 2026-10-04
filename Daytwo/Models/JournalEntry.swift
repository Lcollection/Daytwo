import Foundation
import SwiftData
import CoreLocation

/// 一篇日记。所有数据仅保存在本地设备上。
@Model
final class JournalEntry {
    @Attribute(.unique) var id: UUID
    /// 创建时间，时间线按此分组
    var createdAt: Date
    /// 最后修改时间
    var modifiedAt: Date
    /// 标题（保存时自动从 Markdown 首行提取，可为空）
    var title: String
    /// 正文原始 Markdown 文本
    var content: String
    /// 收藏（类似 Day One 的星标）
    var favorite: Bool
    /// 位置信息（可空）
    var latitude: Double?
    var longitude: Double?
    /// 逆地理编码得到的可读位置名，如 "北京市 · 海淀区"
    var locationName: String?
    /// 用于位置分组的主要地名，如 "北京市"
    var locality: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        modifiedAt: Date = .now,
        title: String = "",
        content: String = "",
        favorite: Bool = false,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil,
        locality: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.title = title
        self.content = content
        self.favorite = favorite
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.locality = locality
    }

    // MARK: - 计算属性（不持久化）

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// 列表中显示的标题
    var displayName: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "无标题" : t
    }

    /// 列表中的纯文本预览
    var previewText: String {
        MarkdownFormatter.plainPreview(from: content, limit: 120)
    }

    var wordCount: Int {
        MarkdownFormatter.wordCount(of: content)
    }

    /// 在系统地图中查看的链接
    var mapURL: URL? {
        guard let latitude, let longitude else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: locationName ?? displayName),
        ]
        return components.url
    }

    /// 导出为带 YAML front matter 的 Markdown 文本
    func exportMarkdown() -> String {
        var lines: [String] = []
        lines.append("---")
        lines.append("created: \(DateFormatters.iso8601.string(from: createdAt))")
        lines.append("modified: \(DateFormatters.iso8601.string(from: modifiedAt))")
        if !title.isEmpty {
            lines.append("title: \(title)")
        }
        if let locationName {
            lines.append("location: \(locationName)")
        }
        if let latitude, let longitude {
            lines.append("coordinates: \(latitude), \(longitude)")
        }
        lines.append("---")
        lines.append("")
        lines.append(content)
        return lines.joined(separator: "\n")
    }
}
