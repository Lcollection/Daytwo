# Daytwo

**为 macOS 打造的本地优先 Markdown 日记应用**
A local-first Markdown journal for macOS.

> 灵感来自 Day One，取名 Daytwo —— 每一天都值得被记录，第二天也是。

![Platform](https://img.shields.io/badge/platform-macOS%2014+-blue)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Swift](https://img.shields.io/badge/Swift-5.10-orange)

## ✨ 特性

### 📝 Markdown 日记
- Day One 式创作流：点 ✎ 瞬间创建日记（保留真实创建时间），输入自动保存，空草稿自动丢弃
- 原生编辑器：标题 / 加粗 / 斜体 / 删除线 / 行内代码 / 引用 / 有序与无序列表 / 待办 / 链接 / 分隔线，一键插入，自动处理选区
- 编辑 / 预览双模式切换，预览使用 [MarkdownUI](https://github.com/gonzalezreal/MarkdownUI) 渲染
- 保存时自动从首行提取标题，支持 `⌘N` 快捷新建

### 🔒 完全本地存储
- 数据使用 SwiftData（本地 SQLite）保存在电脑上，**没有任何云端同步、没有账号体系**
- 创建容器时显式关闭 CloudKit（`cloudKitDatabase: .none`），杜绝数据意外上云
- 随时导出：JSON 完整备份（可再导入）、或按篇导出为带 front matter 的 `.md` 文件
- **日记文件夹（Obsidian 式）**：可选任意文件夹作为日记库，每篇日记保存为带 front matter 的普通 `.md` 文件，可用其他编辑器打开，外部修改会在启动时自动吸收

### 🗓 按创建日期分类（Day One 式时间线）
- 时间线按创建日期自动分组：**今天 / 昨天 / 2025年10月3日 星期五**
- 统计面板：日记篇数、总字数、记录天数、连续记录天数（🔥 连续打卡）
- 全文搜索（标题 / 正文 / 位置）

### 📍 按地理位置分类
- 写日记时自动记录当前位置：立即采用系统缓存位置，同时异步刷新更精确的定位，不阻塞创作
- 地名解析带缓存（约 200 米内复用），逆地理编码为「城市 · 区县」
- **地图视图**：所有带位置的日记以标记展示，点选直达详情
- **位置视图**：按地点名称分组浏览
- 详情页点击位置胶囊可跳转系统地图查看

### 其他
- ⭐️ 收藏（星标），列表右键即可收藏 / 删除
- 🌙 深色模式、动态字体
