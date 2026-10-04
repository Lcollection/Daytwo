import Foundation
import SwiftData

/// 演示数据：仅当以 `-daytwo-sample-data` 启动参数运行时注入，
/// 且只在本 地数据为空时生效，不影响正常使用。
enum SampleData {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-daytwo-sample-data")
    static let openMap = ProcessInfo.processInfo.arguments.contains("-daytwo-open-map")

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        guard isEnabled else { return }
        let existing = (try? context.fetch(FetchDescriptor<JournalEntry>())) ?? []
        guard existing.isEmpty else { return }

        let calendar = Calendar.current
        func day(_ daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
            let start = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: .now))!
            return start.addingTimeInterval(TimeInterval(hour * 3600 + minute * 60))
        }

        struct Sample {
            let daysAgo: Int, hour: Int, minute: Int
            let content: String
            let lat: Double?, lon: Double?, place: String?, locality: String?
            let favorite: Bool
        }

        let samples: [Sample] = [
            Sample(
                daysAgo: 0, hour: 8, minute: 42,
                content: """
                # 周末的清晨

                  - [ ] 给阳台的绿萝浇水
                  - [x] 冲了一杯手冲，**耶加雪菲**，带点柑橘酸

                阳光正好落在书桌一角，适合把拖了很久的想法写下来。

                > 记录本身就是意义。
                """,
                lat: 39.9847, lon: 116.4663, place: "北京市 · 朝阳区", locality: "北京市",
                favorite: false
            ),
            Sample(
                daysAgo: 0, hour: 13, minute: 5,
                content: """
                ## 午后碎片

                  - 把 `MarkdownFormatter` 的边界情况都补了测试
                  - 晚上想试试新的意面配方

                *专注的感觉真好。*
                """,
                lat: nil, lon: nil, place: nil, locality: nil,
                favorite: false
            ),
            Sample(
                daysAgo: 1, hour: 21, minute: 30,
                content: """
                # 加班夜

                  - 上线前的最后回归测试
                  - 和老张在楼下便利店聊了十分钟

                `23:00` 前终于收拾完。走出大楼的时候风很凉，但脑子很清醒。

                ---

                明天要把设计稿过一遍。
                """,
                lat: 31.2304, lon: 121.4737, place: "上海市 · 黄浦区", locality: "上海市",
                favorite: false
            ),
            Sample(
                daysAgo: 2, hour: 10, minute: 15,
                content: """
                # 西湖边的半日闲

                  - 断桥人还是多
                  - 在孤山脚下的旧书店淘到一本《夜航船》

                走到 **平湖秋月** 的时候突然起风，湖面全是碎光。

                ![记忆](https://example.com/west-lake.jpg)
                """,
                lat: 30.2530, lon: 120.1399, place: "杭州市 · 西湖区", locality: "杭州市",
                favorite: true
            ),
            Sample(
                daysAgo: 3, hour: 19, minute: 48,
                content: """
                # 读书笔记：卡片盒写作法

                1. 记录时用自己的话改写
                2. 建立卡片之间的链接
                3. 定期回看，让想法自然生长

                ```
                写作 = 思考的外化
                ```
                """,
                lat: nil, lon: nil, place: nil, locality: nil,
                favorite: false
            ),
            Sample(
                daysAgo: 6, hour: 12, minute: 20,
                content: """
                # 朋友来家里吃饭

                  - 番茄牛腩 + 蒜蓉西兰花 + 米饭
                  - 饭后去楼下走了三圈

                聊到大学时候的事，笑到肚子疼。*要保持这样的聚会频率。*
                """,
                lat: 39.9847, lon: 116.4663, place: "北京市 · 朝阳区", locality: "北京市",
                favorite: false
            ),
            Sample(
                daysAgo: 8, hour: 9, minute: 5,
                content: """
                # 晨跑十公里

                配速 `5'38"`，比上周快了 10 秒。

                  - 天气：晴，18°C
                  - 路线：河边步道往返

                回来路上买了豆浆和油条，犒劳自己。
                """,
                lat: 30.6598, lon: 104.0633, place: "成都市 · 锦江区", locality: "成都市",
                favorite: true
            ),
            Sample(
                daysAgo: 13, hour: 22, minute: 10,
                content: """
                # 项目复盘会

                > 好的流程不是不犯错，而是让错误尽早暴露。

                  - [x] 输出复盘文档初稿
                  - [ ] 和产品对齐下个迭代范围

                会开到很晚，但值得。
                """,
                lat: 31.2304, lon: 121.4737, place: "上海市 · 黄浦区", locality: "上海市",
                favorite: false
            ),
            Sample(
                daysAgo: 21, hour: 16, minute: 40,
                content: """
                # 第一次用 Daytwo 写日记

                试试 Markdown 的各种语法：

                  - **加粗**、*斜体*、~~删除线~~、`行内代码`
                  - [链接](https://github.com/Lcollection/Daytwo)

                数据都存在本地，安心。
                """,
                lat: 39.9042, lon: 116.4074, place: "北京市 · 东城区", locality: "北京市",
                favorite: false
            ),
        ]

        for sample in samples {
            context.insert(JournalEntry(
                createdAt: day(sample.daysAgo, sample.hour, sample.minute),
                modifiedAt: day(sample.daysAgo, sample.hour, sample.minute),
                title: MarkdownFormatter.title(from: sample.content),
                content: sample.content,
                favorite: sample.favorite,
                latitude: sample.lat,
                longitude: sample.lon,
                locationName: sample.place,
                locality: sample.locality
            ))
        }
        try? context.save()

        // 日记文件夹模式下同步写出文件
        if VaultService.shared.isVaultActive {
            let all = (try? context.fetch(FetchDescriptor<JournalEntry>())) ?? []
            VaultService.shared.writeAll(all)
            try? context.save()
        }
    }
}
