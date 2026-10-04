import Foundation
import SwiftData
import CoreLocation

/// 一篇日记。默认保存在本地数据库；启用日记文件夹后，
/// 同时以 Markdown 文件形式保存在用户选择的文件夹中。
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
    /// 日记文件夹模式下对应的文件名（用于稳定回写）
    var vaultFilename: String?

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

    // MARK: - Markdown 序列化（日记文件夹 / 分享 / 导出共用）

    /// 序列化为带 YAML front matter 的 Markdown 文本
    func vaultMarkdown() -> String {
        var lines: [String] = []
        lines.append("---")
        lines.append("id: \(id.uuidString)")
        lines.append("created: \(DateFormatters.iso8601.string(from: createdAt))")
        lines.append("modified: \(DateFormatters.iso8601.string(from: modifiedAt))")
        lines.append("favorite: \(favorite ? "true" : "false")")
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            lines.append("title: \(trimmedTitle)")
        }
        if let locationName {
            lines.append("location: \(locationName)")
        }
        if let locality {
            lines.append("locality: \(locality)")
        }
        if let latitude, let longitude {
            lines.append("coordinates: \(latitude), \(longitude)")
        }
        lines.append("---")
        lines.append("")
        lines.append(content)
        return lines.joined(separator: "\n")
    }

    /// 从 Markdown 文本解析（front matter 中必须有合法 id 与 created）
    static func parse(vaultMarkdown text: String) -> ParsedEntry? {
        var lines = text.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }
        lines.removeFirst()
        guard let closing = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return nil
        }

        var meta: [String: String] = [:]
        for line in lines[..<closing] {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            meta[key] = value
        }

        let content = lines[(closing + 1)...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        guard let idString = meta["id"],
              let id = UUID(uuidString: idString),
              let createdAt = parseDate(meta["created"]) else { return nil }

        var latitude: Double?
        var longitude: Double?
        if let coordinates = meta["coordinates"] {
            let parts = coordinates.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                latitude = Double(parts[0])
                longitude = Double(parts[1])
            }
        }

        return ParsedEntry(
            id: id,
            title: meta["title"].flatMap { $0.isEmpty ? nil : $0 },
            createdAt: createdAt,
            modifiedAt: parseDate(meta["modified"]),
            favorite: meta["favorite"] == "true",
            latitude: latitude,
            longitude: longitude,
            locationName: meta["location"].flatMap { $0.isEmpty ? nil : $0 },
            locality: meta["locality"].flatMap { $0.isEmpty ? nil : $0 },
            content: content
        )
    }

    /// 用文件内容覆盖模型字段（文件夹是数据的最终归属）
    func apply(parsed: ParsedEntry) {
        title = parsed.title ?? ""
        content = parsed.content
        createdAt = parsed.createdAt
        modifiedAt = parsed.modifiedAt ?? parsed.createdAt
        favorite = parsed.favorite
        latitude = parsed.latitude
        longitude = parsed.longitude
        locationName = parsed.locationName
        locality = parsed.locality
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        if let date = DateFormatters.iso8601.date(from: string) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: string)
    }
}

/// 从 Markdown 文件解析出的日记数据
struct ParsedEntry {
    let id: UUID
    let title: String?
    let createdAt: Date
    let modifiedAt: Date?
    let favorite: Bool
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let locality: String?
    let content: String
}
