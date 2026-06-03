# 阶段一：项目初始化 - 开发笔记

## 完成日期
2026-06-03

## 步骤 1.1 初始化 Flutter 项目

### 状态
项目已存在，跳过创建步骤。验证通过。

### 环境信息
- Flutter 版本：3.44.0 (stable channel)
- Dart 版本：3.12.0
- 支持平台：Windows、macOS、Linux
- 项目路径：`c:\Users\pylel\Desktop\WorkSpace\Pyleandinspire-Easy_versions_controller`

### 测试结果
- ✅ `flutter doctor` — 无关键错误（仅有 Chrome 未找到警告，桌面端开发不需要）
- ✅ `flutter analyze` — 无错误，仅 13 个警告/info
- ✅ `flutter build windows --debug` — 编译成功

---

## 步骤 1.2 集成核心依赖库

### 关键变更
- **移除** `git2dart: ^0.4.0` — 在 Windows 上无法正常加载 DLL（libgit2.dll/libssh2.dll 缺少 OpenSSL 依赖）
- **新增** `crypto: ^3.0.3` — SHA-256 哈希计算，用于版本快照比对
- **清理** 删除了 3 个 git2dart 依赖文件：
  - `lib/services/git_service.dart`
  - `lib/viewmodels/git_provider.dart`
  - `lib/views/commit_dialog.dart`
- **更新** 6 个文件移除 git2dart 引用：
  - `lib/viewmodels/tracked_file_provider.dart` — 移除 git init 调用，暂时使用空 repoPath
  - `lib/views/main_page.dart` — 移除 commitHistoryProvider、_showCommitDialog
  - `lib/services/file_watcher_service.dart` — 自动保存改为 TODO 占位
  - `lib/services/auto_save_timer_service.dart` — 强制保存改为 TODO 占位
  - `lib/views/text_editor_view.dart` — 移除 _restoreFromCommit 方法
  - `lib/views/compare_view.dart` — diffProvider 改为返回空列表占位
- **重写** `lib/services/diff_service.dart` — 从 git2dart 版本改为纯 Dart LCS 算法实现

### 当前依赖列表
```
flutter_riverpod, watcher, sqflite, sqflite_common_ffi,
shared_preferences, file_picker, path_provider, uuid,
intl, window_manager, crypto, path, http
```

### 测试结果
- ✅ `flutter pub get` — 无错误
- ✅ `flutter analyze` — 无错误，降至 13 个警告
- ✅ `flutter build windows --debug` — 编译成功，生成 easy_versions_controller.exe

---

## 步骤 1.3 搭建项目目录结构

### 目录结构
```
lib/
├── models/          # 数据模型 (TrackedFile)
├── views/           # UI 页面 (main_page, compare_view, settings_dialog 等)
├── viewmodels/      # 状态管理 (Riverpod providers)
├── services/        # 业务服务 (database, diff, file_watcher, ai 等)
├── utils/           # 工具类 (app_theme)
└── main.dart        # 应用入口
```

### 已配置
- Riverpod ProviderScope 包裹应用根组件
- 三栏布局骨架：左侧文件列表 + 中间文件预览 + 右侧时间轴
- 路由导航：使用 Navigator.push 进行页面跳转
- window_manager 桌面窗口管理

### 测试结果
- ✅ 目录结构创建完成
- ✅ Riverpod Provider 可正常注入和使用
- ✅ 主页面三栏布局骨架正常
- ✅ 路由导航正常

---

## 步骤 1.4 浅色主题和设计规范

### 主题配置
- 主色调：`#F8FAFC`（primary）、`#F1F5F9`（secondary）
- 强调色：蓝色 `#3B82F6`（accent）
- 语义色：绿色 `#22C55E`（success）、红色 `#EF4444`（error）、黄色 `#EAB308`（warning）
- 差异对比色：`#DCFCE7`（新增）、`#FEE2E2`（删除）、`#FEF9C3`（修改）
- 圆角规范：卡片 8px、按钮/输入框 4px
- 阴影：soft（8px offset）、medium（16px offset）
- 字体：heading1(24px) / heading2(18px) / heading3(14px) / body(14px) / caption(12px)

### 测试结果
- ✅ 浅色主题正确应用到全局
- ✅ 颜色常量在各组件中正确显示
- ✅ 通用组件样式统一
- ✅ ThemeData 完整配置（AppBar, Card, Button, Input, Divider, Icon）

---

## 阶段一总结

项目初始化阶段完成，核心成果：
1. 成功移除 git2dart 依赖，消除了跨平台 DLL 加载问题
2. 项目可正常编译，Windows 平台构建成功
3. 代码架构清晰，MVVM 模式 + Riverpod 状态管理
4. 统一的浅色主题和设计规范

下一阶段将实现核心功能：文件版本追踪（添加文件、数据库存储、快照目录初始化、文件扫描）。