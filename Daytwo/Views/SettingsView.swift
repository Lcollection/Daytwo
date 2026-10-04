import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 设置：数据导出 / 导入 / 清空，隐私说明，关于。
/// 采用卡片式分组布局，固定窗口宽度。
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \JournalEntry.createdAt, order: .reverse)
    private var entries: [JournalEntry]

    @State private var showFolderExport = false
    @State private var showJSONExport = false
    @State private var showJSONImport = false
    @State private var showVaultPicker = false
    @State private var showWipeConfirm = false
    @State private var notice: String?
    @State private var showNotice = false

    private var vault: VaultService { VaultService.shared }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    storageSection
                    dataSection
                    dangerSection
                    privacySection
                    aboutSection
                }
                .padding(24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .frame(width: 560, height: 660)
            .fileImporter(
                isPresented: $showFolderExport,
                allowedContentTypes: [.folder]
            ) { handleFolderExport($0) }
            .fileImporter(
                isPresented: $showVaultPicker,
                allowedContentTypes: [.folder]
            ) { handleVaultPick($0) }
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

    // MARK: - 区块

    /// 应用标识头
    private var header: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            Text("Daytwo")
                .font(.title3.weight(.bold))
            Text("本地优先的 Markdown 日记")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("版本 \(versionString)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    /// 存储位置（Obsidian 式日记文件夹）
    private var storageSection: some View {
        card("存储") {
            actionRow(
                icon: "folder", color: .brown,
                title: vault.isVaultActive
                    ? (vault.vaultURL?.lastPathComponent ?? "日记文件夹")
                    : "选择日记文件夹",
                subtitle: vault.isVaultActive
                    ? "日记以 Markdown 文件保存在所选文件夹，可用其他编辑器打开"
                    : "可选：像 Obsidian 一样把每篇日记保存为普通 Markdown 文件，便于备份与迁移"
            ) { showVaultPicker = true }

            if vault.isVaultActive {
                rowDivider
                actionRow(
                    icon: "arrow.uturn.backward", color: .gray,
                    title: "恢复默认存储",
                    subtitle: "新日记保存在 App 内部数据库；文件夹中的既有文件不受影响"
                ) {
                    vault.clearVault()
                    presentNotice("已恢复默认存储")
                }
            }
        }
    }

    /// 数据管理
    private var dataSection: some View {
        card("数据管理") {
            actionRow(
                icon: "doc.text", color: .accentColor,
                title: "导出为 Markdown 文件",
                subtitle: "每篇日记一个 .md 文件，含创建时间与位置元信息"
            ) { showFolderExport = true }

            rowDivider

            actionRow(
                icon: "square.and.arrow.up", color: .teal,
                title: "导出 JSON 备份",
                subtitle: "包含全部日记与位置的完整备份文件"
            ) { showJSONExport = true }

            rowDivider

            actionRow(
                icon: "square.and.arrow.down", color: .indigo,
                title: "导入 JSON 备份",
                subtitle: "按日记 ID 合并：已存在则更新，不存在则新增"
            ) { showJSONImport = true }
        }
    }

    /// 危险操作
    private var dangerSection: some View {
        card("危险操作") {
            actionRow(
                icon: "trash", color: .red,
                title: "清空所有日记",
                subtitle: entries.isEmpty
                    ? "当前没有日记"
                    : "将永久删除本机全部 \(entries.count) 篇日记，不可恢复",
                destructive: true
            ) { showWipeConfirm = true }
            .disabled(entries.isEmpty)
        }
    }

    /// 隐私说明
    private var privacySection: some View {
        card("隐私") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
                    .frame(width: 28, height: 28)
                    .background(Color.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 4) {
                    Text("日记只属于你")
                        .font(.body.weight(.medium))
                    Text("所有日记与位置数据仅保存在本机，没有任何云端同步和账号体系。地图底图与地点名称解析需要联网，但日记内容永远不会离开你的设备。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    /// 关于
    private var aboutSection: some View {
        card("关于") {
            infoRow(label: "开源协议", value: "MIT License")
            rowDivider
            infoRow(label: "项目主页", value: "github.com/Lcollection/Daytwo") {
                if let url = URL(string: "https://github.com/Lcollection/Daytwo") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // MARK: - 组件

    /// 卡片容器：外部小标题 + 圆角分组背景
    @ViewBuilder
    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 54)
    }

    /// 可点击的操作行：图标 + 标题/说明 + 箭头
    private func actionRow(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(destructive ? Color.white : color)
                    .frame(width: 28, height: 28)
                    .background(
                        destructive ? AnyShapeStyle(Color.red) : AnyShapeStyle(color.opacity(0.15)),
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(destructive ? Color.red : Color.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 静态信息行：标签 + 值（value 可点击时传 action）
    private func infoRow(label: String, value: String, action: (() -> Void)? = nil) -> some View {
        Button(action: { action?() }) {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Text(value)
                        .foregroundStyle(action == nil ? Color.primary : Color.accentColor)
                    if action != nil {
                        Image(systemName: "arrow.up.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.callout)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    // MARK: - 启用日记文件夹

    private func handleVaultPick(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        do {
            try VaultService.shared.enableVault(at: url, context: modelContext)
            presentNotice("日记库已启用：当前 \(entries.count) 篇日记已保存为 Markdown 文件")
        } catch {
            presentNotice("启用日记文件夹失败：\(error.localizedDescription)")
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
                try entry.vaultMarkdown().write(
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
