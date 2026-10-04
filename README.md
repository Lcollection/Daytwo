# Daytwo

**为 macOS 打造的本地优先 Markdown 日记应用**
A local-first Markdown journal for macOS.

> Day One 的极简体验 + 完全的本地存储 + 开放的 Markdown 数据格式。
> 灵感来自 Day One，取名 Daytwo —— 每一天都值得被记录，第二天也是。

![Platform](https://img.shields.io/badge/platform-macOS%2014+-blue)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Swift](https://img.shields.io/badge/Swift-5.10-orange)

## ✨ 特性

### 📝 Markdown 日记
- 原生编辑器：标题 / 加粗 / 斜体 / 删除线 / 行内代码 / 引用 / 有序与无序列表 / 待办 / 链接 / 分隔线，一键插入，自动处理选区
- 编辑 / 预览双模式切换，预览使用 [MarkdownUI](https://github.com/gonzalezreal/MarkdownUI) 渲染
- 保存时自动从首行提取标题，支持 `⌘N` 快捷新建

### 🔒 完全本地存储
- 数据使用 SwiftData（本地 SQLite）保存在电脑上，**没有任何云端同步、没有账号体系**
- 创建容器时显式关闭 CloudKit（`cloudKitDatabase: .none`），杜绝数据意外上云
- 随时导出：JSON 完整备份（可再导入）、或按篇导出为带 front matter 的 `.md` 文件

### 🗓 按创建日期分类（Day One 式时间线）
- 时间线按创建日期自动分组：**今天 / 昨天 / 2025年10月3日 星期五**
- 统计面板：日记篇数、总字数、记录天数、连续记录天数（🔥 连续打卡）
- 全文搜索（标题 / 正文 / 位置）

### 📍 按地理位置分类
- 写日记时自动记录当前位置（CoreLocation），逆地理编码为「城市 · 区县」
- **地图视图**：所有带位置的日记以标记展示，点选直达详情
- **位置视图**：按地点名称分组浏览
- 详情页点击位置胶囊可跳转系统地图查看

### 其他
- ⭐️ 收藏（星标），列表右键即可收藏 / 删除
- 🌙 深色模式、动态字体

## 🚀 构建要求

- macOS 14.0+（Apple Silicon）
- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（可选，重新生成工程时需要）

## 📦 快速开始

```bash
git clone git@github.com:Lcollection/Daytwo.git
cd Daytwo
open Daytwo.xcodeproj        # 直接打开即可运行
```

首次打开会自动解析 Swift Package 依赖（MarkdownUI），选择 *My Mac*，`⌘R` 运行。

### 使用 XcodeGen 重新生成工程（可选）

工程文件 `Daytwo.xcodeproj` 由 [project.yml](project.yml) 生成，如果你修改了工程结构：

```bash
xcodegen generate
```

### 命令行构建与测试

```bash
xcodebuild -project Daytwo.xcodeproj -scheme Daytwo \
  -destination 'platform=macOS' build

xcodebuild -project Daytwo.xcodeproj -scheme Daytwo \
  -destination 'platform=macOS' test
```

## 🏗 项目结构

```
Daytwo/
├── DaytwoApp.swift              # 入口，创建本地 ModelContainer
├── Models/
│   ├── JournalEntry.swift       # 日记模型（SwiftData）
│   └── EntryBackup.swift        # JSON 备份文档（FileDocument）
├── Services/
│   └── LocationService.swift    # 定位 + 逆地理编码
├── Utilities/
│   ├── MarkdownFormatter.swift  # 纯函数式 Markdown 文本变换
│   ├── StatsCalculator.swift    # 统计（篇数/字数/天数/连续记录）
│   ├── DateFormatters.swift     # 中文日期格式化
│   └── ViewExtensions.swift
├── Views/
│   ├── ContentView.swift        # 侧边栏 + 统计
│   ├── TimelineView.swift       # 时间线（按日期分组）
│   ├── ComposerView.swift       # 新建/编辑（工具栏 + 预览 + 位置栏）
│   ├── EntryDetailView.swift    # 详情（Markdown 渲染）
│   ├── EntriesMapView.swift     # 地图足迹
│   ├── LocationListView.swift   # 位置分类 / 收藏列表
│   ├── SettingsView.swift       # 导出/导入/清空/隐私说明
│   └── Editor/
│       └── MarkdownEditorView.swift  # NSTextView 封装
└── Assets.xcassets/
Tests/DaytwoTests/               # 单元测试（Markdown 变换 / 统计）
project.yml                      # XcodeGen 工程定义
tools/make_appicon.swift         # 图标生成脚本
```

## 🔐 数据与隐私

| 项目 | 说明 |
| --- | --- |
| 存储位置 | App 沙盒容器内的 SwiftData SQLite 数据库，随 App 删除 |
| 网络请求 | 仅两处且均为只读：地图底图瓦片（MapKit）、位置名称解析（CLGeocoder） |
| 数据上传 | **无**。没有任何统计 SDK、崩溃上报、账号服务 |
| 导出格式 | `.md`（YAML front matter：created / location / coordinates）或 `.json` 完整备份 |

## 🗺 Roadmap

- [ ] 图片与照片附件
- [ ] 标签系统
- [ ] 写作目标与提醒
- [ ] 菜单栏速记（Quick Capture）
- [ ] 多语言（i18n）
- [ ] 可选端到端加密同步（用户自选，默认关闭）

## 🤝 贡献

欢迎 Issue 与 PR！提交 PR 前请确保：

```bash
xcodebuild -scheme Daytwo -destination 'platform=macOS' test
```

## 📄 许可证

[MIT](LICENSE) © 2026 LatteInfra
