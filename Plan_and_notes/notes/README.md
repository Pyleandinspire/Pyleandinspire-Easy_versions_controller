# 开发笔记 - 总索引

> 按开发阶段整理，每篇笔记对应 processes 文档中的一个阶段或功能模块。

---

## 阶段笔记 (最新版)

| 编号 | 笔记 | 对应阶段 | 内容概要 |
|------|------|---------|---------|
| 1 | [01_project_init.md](01_project_init.md) | 阶段一：项目初始化 | Flutter 项目验证、核心依赖集成、移除 git2dart |
| 2 | [02_core_features_add_tracking.md](02_core_features_add_tracking.md) | 阶段二：添加版本追踪 | 文件选择器、数据库设计、快照初始化、文件扫描 |
| 3 | [03_core_features_ui_interactions.md](03_core_features_ui_interactions.md) | 阶段三：切换/删除/设置/引导 | 文件列表、切换交互、删除、设置页、引导页 |
| 4 | [04_core_features_auto_save.md](04_core_features_auto_save.md) | 阶段四：自动保存 | 文件监听、短/长计时器、自动快照、状态指示器 |
| 5 | [05_core_features_advanced.md](05_core_features_advanced.md) | 阶段五：展示/对比/回退/编辑 | 文件预览、时间轴、差异算法、对比视图、版本回退、文本编辑 |
| 6 | [06_integration_test_and_bugfix.md](06_integration_test_and_bugfix.md) | 阶段六：整合测试与 Bug 修复 | 时间戳碰撞修复、测试数据冲突修复、端到端测试 |

---

## 详细专题笔记

以下笔记记录了开发过程中特定功能或模块的深入细节，已包含在上述阶段笔记中。

| 编号 | 笔记 | 专题 |
|------|------|------|
| 02 | [dependencies](02_dependencies.md) | 依赖库集成详情 |
| 03 | [project_structure](03_project_structure.md) | 项目目录结构设计 |
| 04 | [theme](04_theme.md) | UI 主题设计 |
| 05 | [add_version_tracking](05_add_version_tracking.md) | 添加文件追踪实现 |
| 06 | [switch_version_tracking](06_switch_version_tracking.md) | 文件切换追踪实现 |
| 07 | [auto_save](07_auto_save.md) | 自动保存功能详解 |
| 08 | [settings](08_settings.md) | 设置页面实现 |
| 09 | [help](09_help.md) | 帮助引导页实现 |
| 10 | [diff](10_diff.md) | 文件差异对比算法 |
| 11 | [ai_commit](11_ai_commit.md) | AI 提交信息生成 |
| 12 | [ai_agent](12_ai_agent.md) | AI 助手实现 |
| 13 | [text_editor](13_text_editor.md) | 文本编辑器实现 |
| 14 | [testing](14_testing.md) | 测试策略与用例 |
| 15 | [file_watcher](15_file_watcher.md) | 文件系统监听 |
| 16 | [auto_save_timer](16_auto_save_timer.md) | 自动保存计时器 |
| 17 | [layout_adjustment](17_layout_adjustment.md) | 布局调整记录 |
| 18 | [phase_summary](18_phase_summary.md) | 阶段性总结 |
| 19 | [cross_check_report](19_cross_check_report.md) | 交叉检查报告 |
| 20 | [code_review_report](20_code_review_report.md) | 代码审查报告 |
| 21 | [document_changes_record](21_document_changes_record.md) | 文档变更记录 |
| 22 | [second_cross_check_report](22_second_cross_check_report.md) | 第二次交叉检查 |
| 23 | [bug_fix_report_high_priority](23_bug_fix_report_high_priority.md) | 高优先级 Bug 修复 |
| 24 | [medium_priority_development_report](24_medium_priority_development_report.md) | 中优先级开发报告 |

---

## 技术栈总览

| 层级 | 技术 | 用途 |
|------|------|------|
| 框架 | Flutter 3.44 / Dart 3.12 | 跨平台 UI |
| 状态管理 | Riverpod | 全局状态管理 |
| 数据库 | sqflite (SQLite) | 本地元数据持久化 |
| 文件系统 | dart:io + watcher | 文件监听与操作 |
| 哈希计算 | crypto | SHA-256 快照去重 |
| 差异算法 | Myers LCS (纯 Dart) | 文本版本对比 |
| 目标平台 | Windows, macOS, Linux | 桌面三端 |

## 版本控制方案

采用 **时间戳快照 + 文件副本** 方案，替代了原来不可用的 git2dart：
- 文件副本存储于应用数据目录下的 `easy_versions_snapshots/` 
- 文件名格式: `{timestamp}_{原始文件名}` (精确到毫秒)
- 数据库记录快照元数据 (sha256 hash, 文件大小, 时间戳)
- 支持自动保存、手动保存、版本回退