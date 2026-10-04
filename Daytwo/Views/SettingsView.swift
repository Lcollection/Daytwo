import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 设置：数据导出 / 导入 / 清空，隐私说明，关于
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \JournalEntry.createdAt, order: .reverse)
    private var entries: [JournalEntry]

    @State private var showFolderExport = false
    @State private var showJSONExport = false
    @State private var showJSONImport = false
    @State private var showWipeConfirm = false
    @State private var notice: String?
    @State private var showNotice = false

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showFolderExport = true
                    } label: {
                        Label("导出为 Markdown 文件", systemImage: "doc.text")
                    }
                    Button {
                        showJSONExport = true
                    } label: {
                        Label("导出 JSON 备份", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showJSONImport = true
                    } label: {
                        Label("导入 JSON 备份", systemImage: "square.and.arrow.down")
                    }
                    Button(role: .destructive) {
                        showWipeConfirm = true
                    } label: {
                        Label("清空所有日记", systemImage: "trash")
                    }
                    .disabled(entries.isEmpty)
                } header: {
                    Text("数据")
                } footer: {
                    Text("Markdown 导出包含日记正文与位置等元信息（front matter），可直接导入其他 Markdown 工具。")
                }

                Section {
                    Label("所有日记仅保存在本机，不上传云端", systemImage: "lock.shield")
                    Text("地图底图与地点名称解析需要联网，但日记内容与位置数据永远不会离开你的设备。应用也没有任何账号体系。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("隐私")
                }

                Section {
                    LabeledContent("版本", value: versionString)
                    Link(destination: URL(string: "https://github.com/Lcollection/Daytwo")!) {
                        Label("GitHub 仓库", systemImage: "link")
                    }
                    LabeledContent("开源协议", value: "MIT")
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFolderExport,
                allowedContentTypes: [.folder]
            ) { handleFolderExport($0) }
            .fileExporter(
                isPresented: $showJSONExport,
                document: BackupFile(entries: entries.map(EntryBackup.init)),
                contentTypes: [.json],
                defaultFilename: "Daytwo-备份-\(DateFormatters.exportFile.string(from: .now))"
            ) { result in
                if case .success = result {
                    presentNotice("备份已导出（\(entries.count) 篇日记）")
                } else if case .failure(let error) = result {
                    presentNotice("导出失败：\(error.localizedDescription)")
                }
            }
            .fileImporter(
                isPresented: $showJSONImport,
                allowedContentTypes: [.json]
            ) { handleJSONImport($0) }
            .confirmationDialog(
                "将永久删除全部 \(entries.count) 篇日记，且无法恢复。确定吗？",
                isPresented: $showWipeConfirm,
                titleVisibility: .visible
            ) {
                Button("全部删除", role: .destructive) { wipeAll() }
                Button("取消", role: .cancel) {}
            }
            .alert("提示", isPresented: $showNotice) {
                Button("好", role: .cancel) {}
            } message: {
                Text(notice ?? "")
            }
        }
    }

    // MARK: - 导出 Markdown 文件夹

    private func handleFolderExport(_ result: Result<URL, Error>) {
        guard case .success(let folder) = result else { return }
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }

        do {
            let targetDir = folder.appending(
                component: "Daytwo 导出 \(DateFormatters.exportFile.string(from: .now))",
                directoryHint: .isDirectory
            )
            try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)

            var usedNames = Set<String>()
            let sorted = entries.sorted { $0.createdAt < $1.createdAt }
            for entry in sorted {
                let base = "\(DateFormatters.exportFile.string(from: entry.createdAt)) \(sanitizeFilename(entry.displayName))"
                var filename = base + ".md"
                var counter = 2
                while usedNames.contains(filename) {
                    filename = "\(base) \(counter).md"
                    counter += 1
                }
                usedNames.insert(filename)
                try entry.exportMarkdown().write(
                    to: targetDir.appending(path: filename),
                    atomically: true,
                    encoding: .utf8
                )
            }
            presentNotice("已导出 \(sorted.count) 篇日记为 Markdown 文件")
        } catch {
            presentNotice("导出失败：\(error.localizedDescription)")
        }
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = cleaned.count > 40 ? String(cleaned.prefix(40)) : cleaned
        return limited.isEmpty ? "日记" : limited
    }

    // MARK: - 导入 JSON

    private func handleJSONImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let backups = try BackupFile.decode(from: data)

            let existing = try modelContext.fetch(FetchDescriptor<JournalEntry>())
            var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
            var added = 0
            var updated = 0
            for backup in backups {
                if let target = byID[backup.id] {
                    backup.apply(to: target)
                    updated += 1
                } else {
                    let entry = backup.makeEntry()
                    byID[entry.id] = entry
                    modelContext.insert(entry)
                    added += 1
                }
            }
            try? modelContext.save()
            presentNotice("导入完成：新增 \(added) 篇，更新 \(updated) 篇")
        } catch {
            presentNotice("导入失败：文件格式不正确（\(error.localizedDescription)）")
        }
    }

    // MARK: - 清空

    private func wipeAll() {
        do {
            let all = try modelContext.fetch(FetchDescriptor<JournalEntry>())
            for entry in all {
                modelContext.delete(entry)
            }
            try modelContext.save()
            presentNotice("已删除 \(all.count) 篇日记")
        } catch {
            presentNotice("删除失败：\(error.localizedDescription)")
        }
    }

    private func presentNotice(_ message: String) {
        notice = message
        showNotice = true
    }
}
