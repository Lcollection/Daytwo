import Foundation
import SwiftData
import Observation

/// 可选的「日记文件夹」存储（Obsidian 风格）：
/// 启用后，每篇日记以 Markdown 文件（含 YAML front matter）保存在用户选择的文件夹中，
/// 文件夹是数据的最终归属；SwiftData 继续作为索引/缓存以支持快速检索与统计。
///
/// - 每次保存 / 收藏 / 删除都会同步写文件
/// - 启动时扫描文件夹，外部编辑器做的修改会被吸收进应用
@MainActor
@Observable
final class VaultService {
    static let shared = VaultService()
    private static let bookmarkKey = "daytwo.vault.bookmark"

    /// 当前日记文件夹（nil 表示使用 App 默认存储）
    private(set) var vaultURL: URL?
    private(set) var lastError: String?

    var isVaultActive: Bool { vaultURL != nil }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.bookmarkKey) {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
                _ = url.startAccessingSecurityScopedResource()   // 保持整个会话的访问权限
                vaultURL = url
                // 书签失效时重建，避免下次无法恢复
                if isStale {
                    try? Self.recreateBookmark(for: url, defaults: defaults)
                }
            } catch {
                lastError = "无法恢复日记文件夹：\(error.localizedDescription)"
            }
        }
    }

    private static func recreateBookmark(for url: URL, defaults: UserDefaults) throws {
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(bookmark, forKey: bookmarkKey)
    }

    // MARK: - 启用 / 关闭

    /// 启用日记文件夹：先吸收文件夹中已有的 Markdown，再把全部日记写成文件
    func enableVault(at url: URL, context: ModelContext) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(bookmark, forKey: Self.bookmarkKey)
        vaultURL = url

        syncFromFolder(context: context)
        // 只写还未落盘的日记，避免覆盖刚从文件吸收的内容
        let all = (try? context.fetch(FetchDescriptor<JournalEntry>())) ?? []
        writeAll(all.filter { $0.vaultFilename?.isEmpty != false })
        try? context.save()
    }

    /// 恢复默认存储（文件夹中的既有文件保留不动）
    func clearVault() {
        defaults.removeObject(forKey: Self.bookmarkKey)
        vaultURL = nil
    }

    // MARK: - 写入 / 删除

    func writeEntry(_ entry: JournalEntry) {
        guard let vault = vaultURL else { return }
        let filename = resolvedFilename(for: entry, in: vault)
        let url = vault.appending(path: filename)
        do {
            try entry.vaultMarkdown().write(to: url, atomically: true, encoding: .utf8)
            if entry.vaultFilename != filename {
                entry.vaultFilename = filename
            }
        } catch {
            lastError = "写入日记文件失败：\(error.localizedDescription)"
        }
    }

    func writeAll(_ entries: [JournalEntry]) {
        entries.forEach(writeEntry)
    }

    func deleteEntry(_ entry: JournalEntry) {
        guard let vault = vaultURL,
              let filename = entry.vaultFilename,
              !filename.isEmpty else { return }
        try? FileManager.default.removeItem(at: vault.appending(path: filename))
    }

    private func resolvedFilename(for entry: JournalEntry, in vault: URL) -> String {
        if let existing = entry.vaultFilename, !existing.isEmpty {
            return existing
        }
        let fileManager = FileManager.default
        let date = DateFormatters.exportFile.string(from: entry.createdAt)
        let base = "\(date) \(sanitize(entry.title.isEmpty ? "日记" : entry.title))"
        var candidate = base + ".md"
        var counter = 2
        while fileManager.fileExists(atPath: vault.appending(path: candidate).path) {
            candidate = "\(base) \(counter).md"
            counter += 1
        }
        return candidate
    }

    private func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = cleaned.count > 40 ? String(cleaned.prefix(40)) : cleaned
        return limited.isEmpty ? "日记" : limited
    }

    // MARK: - 从文件夹同步（启动时 / 启用文件夹时）

    func syncFromFolder(context: ModelContext) {
        guard let vault = vaultURL else { return }
        let fileManager = FileManager.default

        var filesByID: [UUID: (name: String, parsed: ParsedEntry)] = [:]
        if let enumerator = fileManager.enumerator(
            at: vault,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension.lowercased() == "md" {
                guard let text = try? String(contentsOf: fileURL, encoding: .utf8),
                      let parsed = JournalEntry.parse(vaultMarkdown: text) else { continue }
                filesByID[parsed.id] = (fileURL.lastPathComponent, parsed)
            }
        }

        let all = (try? context.fetch(FetchDescriptor<JournalEntry>())) ?? []
        var byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

        // 文件 → 数据库（文件夹是最终归属）
        for (id, file) in filesByID {
            let parsed = file.parsed
            if let entry = byID[id] {
                entry.apply(parsed: parsed)
            } else {
                let entry = JournalEntry(
                    id: id,
                    createdAt: parsed.createdAt,
                    modifiedAt: parsed.modifiedAt ?? parsed.createdAt,
                    title: parsed.title ?? "",
                    content: parsed.content,
                    favorite: parsed.favorite,
                    latitude: parsed.latitude,
                    longitude: parsed.longitude,
                    locationName: parsed.locationName,
                    locality: parsed.locality
                )
                byID[id] = entry
                context.insert(entry)
            }
            byID[id]?.vaultFilename = file.name
        }

        // 数据库中登记过文件但文件已被外部删除 → 移除条目
        for entry in all where entry.vaultFilename?.isEmpty == false {
            if filesByID[entry.id] == nil {
                context.delete(entry)
            }
        }

        try? context.save()
    }
}
