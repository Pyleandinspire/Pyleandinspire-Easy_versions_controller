# 核心依赖库笔记

## 步骤 1.2 集成核心依赖库

### 依赖库清单

| 库名 | 版本 | 用途 |
|------|------|------|
| flutter_riverpod | ^3.3.1 | 状态管理 |
| git2dart | ^0.4.0 | Git 操作（内置 libgit2，无需系统安装 Git） |
| watcher | ^1.2.1 | 文件系统事件监听 |
| sqflite | ^2.4.2 | 本地 SQLite 数据库（macOS 原生支持） |
| sqflite_common_ffi | ^2.3.5 | SQLite FFI 实现（Windows/Linux 桌面端支持） |
| shared_preferences | ^2.5.3 | 偏好设置存储 |
| file_picker | ^9.2.3 | 文件选择对话框 |
| path_provider | ^2.1.5 | 获取系统路径 |
| uuid | ^4.5.1 | 生成唯一标识符 |
| intl | ^0.20.2 | 国际化和日期格式化 |
| window_manager | ^0.5.1 | 桌面窗口管理 |

### 重要决策
- **Git 库选择**：使用 git2dart 而非 git.dart
  - git2dart 是 libgit2 的 Dart 绑定，内置 Git 功能
  - 符合 PLAN.md "内置Git程序，打开即用" 的要求
  - 用户无需单独安装 Git
  - 支持 macOS、Windows、Linux 桌面平台

- **数据库跨平台方案**：sqflite + sqflite_common_ffi
  - sqflite 原生支持 macOS（通过 CocoaPods）
  - sqflite_common_ffi 提供 Windows/Linux 的 FFI 实现
  - 需要在代码中根据平台选择数据库工厂

### 注意事项
- git2dart 在 Linux 上需要安装 libssl-dev 和 libpcre3
- git2dart 在 macOS 上需要安装 openssl（brew install openssl）
- git2dart 和 screen_retriever_macos 目前不支持 Swift Package Manager，未来可能需要处理
- 数据库初始化时需要平台判断：
  - macOS/iOS: 使用 sqflite 默认的 databaseFactory
  - Windows/Linux: 使用 sqflite_common_ffi 的 databaseFactory
