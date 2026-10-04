import SwiftUI
import SwiftData

/// 时间线：按创建日期分组的日记列表
struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.createdAt, order: .reverse)
    private var entries: [JournalEntry]

    @State private var searchText = ""
    @State private var showComposer = false

    private var filtered: [JournalEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }
        return entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(query)
                || entry.content.localizedCaseInsensitiveContains(query)
                || (entry.locationName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    /// 相邻同一天的日记归入同一组（今天 / 昨天 / 2025年10月3日 星期五）
    private var groups: [(header: String, entries: [JournalEntry])] {
        var result: [(String, [JournalEntry])] = []
        for entry in filtered {
            let header = DateFormatters.timelineHeader(for: entry.createdAt)
            if result.last?.0 == header {
                result[result.count - 1].1.append(entry)
            } else {
                result.append((header, [entry]))
            }
        }
        return result.map { (header: $0.0, entries: $0.1) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView {
                        Label("还没有日记", systemImage: "book.closed")
                    } description: {
                        Text("点击右上角的 ✎ 记录你的第一天")
                    }
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    entryList
                }
            }
            .navigationTitle("时间线")
            .searchable(text: $searchText, prompt: "搜索日记、位置")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showComposer = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    .help("写新日记")
                }
            }
            .sheet(isPresented: $showComposer) {
                ComposerView()
            }
        }
    }

    private var entryList: some View {
        List {
            ForEach(groups, id: \.header) { group in
                Section {
                    ForEach(group.entries) { entry in
                        NavigationLink {
                            EntryDetailView(entry: entry)
                        } label: {
                            EntryRow(entry: entry)
                        }
                        .contextMenu {
                            Button {
                                entry.favorite.toggle()
                                try? modelContext.save()
                            } label: {
                                Label(
                                    entry.favorite ? "取消收藏" : "收藏",
                                    systemImage: entry.favorite ? "star.slash" : "star"
                                )
                            }
                            Divider()
                            Button(role: .destructive) {
                                modelContext.delete(entry)
                                try? modelContext.save()
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(group.header)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - 单条日记行

struct EntryRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(entry.createdAt, formatter: DateFormatters.timeOnly)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                if entry.favorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }
            Text(entry.displayName)
                .font(.headline)
                .lineLimit(1)
            if !entry.previewText.isEmpty {
                Text(entry.previewText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if entry.hasLocation, let name = entry.locationName {
                Label(name, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
