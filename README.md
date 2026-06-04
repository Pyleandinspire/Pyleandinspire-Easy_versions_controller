# 简控 (Easy Versions Controller)

轻量级、跨平台的个人文档版本控制工具。专注于对单个文件进行版本追踪，内置版本控制引擎，打开即用，零外部依赖。

## 项目背景

现有的版本控制工具（如 Git）虽然功能强大，但对于普通用户来说学习成本高、操作不够直观。**简控** 旨在解决这一问题：

- **不够方便** → 无需命令行，全部图形化操作
- **不够简单** → 版本控制功能按钮化，清晰直观
- **不够轻量** → 不依赖 Git 等外部工具，纯 Dart 实现版本控制引擎

## 核心特性

### 版本控制

- **文件追踪**：添加任意类型文件进行版本追踪，不限制文件类型和大小
- **自动保存**：检测到文件变更后自动创建版本快照（用户停止操作后 10 秒），同时支持每 5 分钟强制保存
- **智能去重**：基于 SHA-256 哈希去重，内容无变化时自动跳过，避免冗余快照
- **版本回退**：选择任意历史版本恢复到当前文件

### 版本浏览

- **时间轴视图**：右侧面板按时间倒序展示所有版本快照，每条记录显示时间戳和更改摘要
- **差异对比**：双栏并排对比两个历史版本，新增/删除/修改内容分别以绿色/红色/黄色高亮
- **文件预览**：中间面板实时预览文件内容，支持文本、图片、PDF、Excel、DOCX 等多种格式

### 多格式支持

| 格式        | 预览方式                                                  | 编辑方式           |
| ----------- | --------------------------------------------------------- | ------------------ |
| 文本 / 代码 | 内置编辑器，语法高亮，支持 Markdown 预览                  | 内置编辑器直接编辑 |
| PDF         | pdfrx 引擎渲染，支持缩放/翻页/文本选择                    | 系统默认程序打开   |
| DOCX        | docx_file_viewer 高保真渲染，支持表格/图片/样式/搜索/缩放 | 系统默认程序打开   |
| Excel       | 自定义 XLSX 解析 + DataTable 展示，支持工作表切换         | 系统默认程序打开   |
| PPTX        | 系统默认程序打开                                          | 系统默认程序打开   |
| 图片        | Image.file 直接渲染（JPG/PNG/GIF 等）                     | 系统默认程序打开   |

### AI 辅助

- **AI 生成 Commit 消息**：自动保存时由 AI 生成更改摘要，用户可自行接入 API（支持 OpenAI 兼容接口）
- **AI Agent 对话**：操作失败时弹出通知，可一键跳转到 AI 对话页面寻求帮助
- **高危操作确认**：涉及删除等不可逆操作时弹出确认弹窗

### 数据管理

- **导入/导出**：支持配置和快照数据的导入导出，方便迁移
- **文件扫描**：文件移动后自动智能扫描定位（优先桌面/文档/下载目录，再扩展全盘）
- **SQLite 持久化**：元数据存储在 SQLite 数据库，快照以文件副本形式保存

## 技术架构

| 层级          | 技术选型                    |
| ------------- | --------------------------- |
| 框架          | Flutter (Dart)              |
| 状态管理      | Riverpod                    |
| 数据存储      | SQLite (sqflite) + 文件系统 |
| 文件监听      | watcher                     |
| 文件选择      | file_picker                 |
| 设置持久化    | shared_preferences          |
| 哈希去重      | crypto (SHA-256)            |
| PDF 渲染      | pdfrx (基于 PDFium)         |
| DOCX 渲染     | docx_file_viewer            |
| 语法高亮      | flutter_highlight           |
| Markdown 渲染 | flutter_markdown            |
| 窗口管理      | window_manager              |
| 平台支持      | Windows / macOS / Linux     |

## 项目结构

```
lib/
├── main.dart                 # 应用入口，窗口管理
├── models/
│   ├── tracked_file.dart     # 追踪文件数据模型
│   └── snapshot.dart         # 快照数据模型
├── services/
│   ├── database_service.dart         # SQLite 数据库服务
│   ├── snapshot_service.dart         # 快照管理服务
│   ├── file_watcher_service.dart     # 文件变更监听
│   ├── auto_save_timer_service.dart  # 自动保存定时器
│   ├── file_picker_service.dart      # 文件选择服务
│   ├── file_scan_service.dart        # 文件扫描定位
│   ├── diff_service.dart             # 差异对比算法
│   ├── editor_service.dart           # 编辑器服务
│   ├── ai_service.dart               # AI 对话服务
│   ├── ai_commit_service.dart        # AI Commit 消息生成
│   ├── backup_service.dart           # 导入导出服务
│   ├── notification_service.dart     # 通知服务
│   └── xlsx_parser_service.dart      # Excel 解析服务
├── viewmodels/               # Riverpod Provider 层
│   ├── tracked_file_provider.dart
│   ├── file_picker_provider.dart
│   ├── file_scan_provider.dart
│   ├── file_watcher_provider.dart
│   ├── snapshot_timeline_provider.dart
│   └── auto_save_status_provider.dart
├── views/                    # UI 视图层
│   ├── main_page.dart                # 主页面（三栏布局）
│   ├── text_editor_view.dart         # 文本编辑器
│   ├── compare_view.dart             # 版本对比视图
│   ├── snapshot_preview_view.dart    # 快照预览
│   ├── ai_agent_view.dart            # AI Agent 对话
│   ├── settings_dialog.dart          # 设置对话框
│   ├── help_dialog.dart              # 帮助说明
│   ├── onboarding_page.dart          # 首次使用引导
│   └── file_not_found_dialog.dart    # 文件未找到提示
└── utils/
    ├── app_theme.dart        # 主题样式
    └── platform_utils.dart   # 平台工具函数
```

## 快速开始

### 环境要求

- Flutter SDK >= 3.12.0
- Dart SDK >= 3.12.0

### 运行

```bash
git clone <repo-url>
cd easy_versions_controller
flutter pub get
flutter run
```

### 构建

```bash
# Windows
flutter build windows

# macOS
flutter build macos

# Linux
flutter build linux
```

## 使用说明

1. **首次使用**：启动后会进入引导页，介绍软件功能
2. **添加文件**：点击左下角「+ 添加文件」按钮，选择要追踪的文件
3. **自动保存**：软件会在后台监听文件变更，自动创建版本快照
4. **查看历史**：点击文件列表中的文件，右侧时间轴显示所有版本
5. **对比版本**：选中文件后点击「对比」按钮，选择两个版本进行差异对比
6. **版本回退**：在时间轴中点击版本旁的「回退」按钮
7. **AI 功能**：在设置中配置 API Key 后，可使用 AI 生成 Commit 消息和 AI Agent 对话

---

## 待完善功能与未来目标

以下为当前版本的已知限制和未来计划改进的方向：

### 已知问题

1. **自动追踪在文件移动后无法正常工作**  
   当前文件追踪机制依赖于文件路径，当被追踪的文件被移动到其他目录后，系统无法自动追踪到文件的新位置。虽然已实现智能扫描功能（优先常见目录，再扩展全盘），但扫描耗时较长且成功率有限，用户体验有待优化。

2. **快照数据因文件移动而丢失关联**  
   当文件被移动后，该文件的历史快照数据虽然仍保留在磁盘上，但由于文件路径变化导致快照与文件失去关联，用户无法在时间轴中查看历史版本。需要手动重新定位文件才能恢复关联。

3. AI 目前兼容性不太好
    对国产ai的兼容性差，会在近期进行修复

### 远期目标

- [ ] DOCX 分页视图模式切换（当前默认连续滚动）
- [ ] PPTX 内置预览（当前使用系统默认程序打开）
- [ ] 代码编辑器代码折叠支持
- [ ] AI 辅助写作（润色、总结、扩写、翻译）
- [ ] AI 执行 Git 操作（自动创建分支、合并等）
- [ ] 文件移动后自动追踪恢复（基于文件哈希或 inode 的追踪）
- [ ] 快照数据与文件位置解耦（通过文件标识而非路径关联）

## 许可证

本项目使用 GNU General Public License v3.0 开源许可证。详见 [LICENSE](LICENSE) 文件。
