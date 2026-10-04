import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case timeline
    case map
    case locations
    case favorites
}

/// 主界面：侧边栏（浏览入口 + 统计）+ 详情区
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: SidebarItem = .timeline
    @State private var showSettings = false
    @Query(sort: \JournalEntry.createdAt, order: .reverse)
    private var allEntries: [JournalEntry]

    init() {
        if SampleData.openMap {
            _selection = State(initialValue: .map)
        }
    }

    private var stats: JournalStats {
        StatsCalculator.compute(entries: allEntries)
    }

    private var placedCount: Int {
        allEntries.filter(\.hasLocation).count
    }

    private var favoriteCount: Int {
        allEntries.filter(\.favorite).count
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .appMinFrame()
        .task {
            // 先吸收日记文件夹中外部编辑器做的修改，再做其它初始化
            VaultService.shared.syncFromFolder(context: modelContext)
            SampleData.seedIfNeeded(context: modelContext)
            if SampleData.isEnabled, VaultService.shared.isVaultActive {
                // 演示数据中还没有落盘的日记补写文件
                let unwritten = (try? modelContext.fetch(FetchDescriptor<JournalEntry>()))?
                    .filter { $0.vaultFilename?.isEmpty != false } ?? []
                VaultService.shared.writeAll(unwritten)
                try? modelContext.save()
            }
        }
    }

    // MARK: - 侧边栏

    private var sidebar: some View {
        List(selection: $selection) {
            Section("浏览") {
                Label("时间线", systemImage: "calendar.day.timeline.left")
                    .badge(allEntries.count)
                    .tag(SidebarItem.timeline)
                Label("地图", systemImage: "map")
                    .badge(placedCount)
                    .tag(SidebarItem.map)
                Label("位置", systemImage: "mappin.and.ellipse")
                    .tag(SidebarItem.locations)
                Label("收藏", systemImage: "star")
                    .badge(favoriteCount)
                    .tag(SidebarItem.favorites)
            }

            Section("统计") {
                statsGrid
            }

            Section {
                Button {
                    showSettings = true
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Daytwo")
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            statCard(value: "\(stats.entryCount)", label: "日记", icon: "book.closed")
            statCard(value: abbreviate(stats.wordCount), label: "字数", icon: "character.cursor.ibeam")
            statCard(value: "\(stats.dayCount)", label: "记录天数", icon: "calendar")
            statCard(value: "\(stats.streakDays)", label: "连续记录", icon: "flame")
        }
        .padding(.vertical, 4)
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func abbreviate(_ count: Int) -> String {
        count >= 10000 ? String(format: "%.1fw", Double(count) / 10000) : "\(count)"
    }

    // MARK: - 详情区

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .timeline:
            TimelineView()
        case .map:
            EntriesMapView()
        case .locations:
            LocationListView()
        case .favorites:
            NavigationStack {
                EntryListView(
                    title: "收藏",
                    entries: allEntries.filter(\.favorite),
                    emptyIcon: "star",
                    emptyMessage: "在日记详情中点收藏，喜欢的内容会出现在这里"
                )
            }
        }
    }
}
