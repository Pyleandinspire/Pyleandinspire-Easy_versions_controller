# processes.md 拆分索引

> 原始文件: `Plan_and_notes/processes.md`
> 拆分日期: 2026-06-03
> 更新日期: 2026-06-03
> 版本控制方案: **时间戳快照 + 文件副本**（纯 Dart，零外部依赖，跨平台）
> 详细分析: `../doc_review_analysis.md`

## 目录结构

### 一、项目初始化和基础框架搭建 (`01_project_init/`)
| 文件 | 步骤 | 状态 |
|------|------|------|
| [1.1_init_flutter.md](01_project_init/1.1_init_flutter.md) | 初始化 Flutter 项目 | ✅ |
| [1.2_integrate_deps.md](01_project_init/1.2_integrate_deps.md) | 集成核心依赖库 | ✅ (已移除git2dart) |
| [1.3_project_structure.md](01_project_init/1.3_project_structure.md) | 搭建项目目录结构 | ✅ |
| [1.4_theme.md](01_project_init/1.4_theme.md) | 实现浅色主题 | ✅ |

### 二、核心功能模块 (`02_core_features/`)

#### 功能1: 添加版本追踪 (`feature_01_add_tracking/`)
| 文件 | 步骤 | 状态 |
|------|------|------|
| [2.1.1_file_picker.md](02_core_features/feature_01_add_tracking/2.1.1_file_picker.md) | 文件选择对话框 | ✅ |
| [2.1.2_database.md](02_core_features/feature_01_add_tracking/2.1.2_database.md) | 本地数据库 | ✅ (已更新schema) |
| [2.1.3_init_repo.md](02_core_features/feature_01_add_tracking/2.1.3_init_repo.md) | 快照存储初始化 | ✅ (已重写为文件副本方案) |
| [2.1.4_file_scanning.md](02_core_features/feature_01_add_tracking/2.1.4_file_scanning.md) | 文件扫描和定位 | ✅ |

#### 功能2: 切换版本追踪 (`feature_02_switch_tracking/`)
| 文件 | 步骤 | 状态 |
|------|------|------|
| [2.2.1_file_list.md](02_core_features/feature_02_switch_tracking/2.2.1_file_list.md) | 文件列表展示 | ✅ |
| [2.2.2_switch_interaction.md](02_core_features/feature_02_switch_tracking/2.2.2_switch_interaction.md) | 文件切换交互 | ✅ |

#### 功能3: 删除版本追踪 (`feature_03_delete_tracking/`)
| 文件 | 步骤 | 状态 |
|------|------|------|
| [2.3.1_delete.md](02_core_features/feature_03_delete_tracking/2.3.1_delete.md) | 删除版本追踪 | ✅ (已更新快照删除逻辑) |

#### 功能4: 自定义设置 (`feature_04_auto_save_settings/`)
| 文件 | 步骤 | 状态 |
|------|------|------|
| [2.4.1_settings_layout.md](02_core_features/feature_04_auto_save_settings/2.4.1_settings_layout.md) | 设置页面布局 | ✅ |
| [2.4.2_auto_save_time.md](02_core_features/feature_04_auto_save_settings/2.4.2_auto_save_time.md) | 自动保存时间设置 | ✅ |

#### 功能5: 使用说明 (`feature_05_usage_guide/`)
| 文件 | 步骤 | 状态 |
|------|------|------|
| [2.5.1_onboarding.md](02_core_features/feature_05_usage_guide/2.5.1_onboarding.md) | 首次使用引导 | ✅ |
| [2.5.2_manual.md](02_core_features/feature_05_usage_guide/2.5.2_manual.md) | 说明书弹窗 | ✅ |

#### 功能6: 自动保存 (`feature_06_auto_save/`)
| 文件 | 步骤 | 状态 |
|------|------|------|
| [2.6.1_file_watcher.md](02_core_features/feature_06_auto_save/2.6.1_file_watcher.md) | 文件系统事件监听 | ✅ |
| [2.6.2_short_timer.md](02_core_features/feature_06_auto_save/2.6.2_short_timer.md) | 短计时器 | ✅ |
| [2.6.3_long_timer.md](02_core_features/feature_06_auto_save/2.6.3_long_timer.md) | 长计时器 | ✅ |
| [2.6.4_auto_commit.md](02_core_features/feature_06_auto_save/2.6.4_auto_commit.md) | 自动保存快照 | ✅ (已重写为文件副本方案) |
| [2.6.5_status_indicator.md](02_core_features/feature_06_auto_save/2.6.5_status_indicator.md) | 状态指示器 | ✅ |

#### 功能7: 展示更改 (`feature_07_show_changes/`)
| 文件 | 步骤 | 状态 |
|------|------|------|
| [2.7.0_file_preview.md](02_core_features/feature_07_show_changes/2.7.0_file_preview.md) | 中间文件预览面板 | ✅ |
| [2.7.1_timeline_data.md](02_core_features/feature_07_show_changes/2.7.1_timeline_data.md) | 时间轴数据读取 | ✅ (已重写为快照表查询) |
| [2.7.2_timeline_ui.md](02_core_features/feature_07_show_changes/2.7.2_timeline_ui.md) | 时间轴UI展示 | ✅ |
| [2.7.3_diff_algorithm.md](02_core_features/feature_07_show_changes/2.7.3_diff_algorithm.md) | 文本文件Diff对比 | ✅ (已重写为Myers diff + 高亮) |
| [2.7.4_compare_ui.md](02_core_features/feature_07_show_changes/2.7.4_compare_ui.md) | 文件对比视图UI | ✅ |
| [2.7.5_compare_navigation.md](02_core_features/feature_07_show_changes/2.7.5_compare_navigation.md) | 对比视图导航 | ✅ |
| [2.7.6_version_rollback.md](02_core_features/feature_07_show_changes/2.7.6_version_rollback.md) | 版本回退 | ✅ (已重写为快照文件替换) |

#### 功能8: AI生成commit消息 (`feature_08_ai_commit/`)
| 文件 | 步骤 | 状态 |
|------|------|------|
| [2.8.1_api_config.md](02_core_features/feature_08_ai_commit/2.8.1_api_config.md) | API配置界面 | ✅ |
| [2.8.2_api_service.md](02_core_features/feature_08_ai_commit/2.8.2_api_service.md) | AI API调用封装 | ✅ |
| [2.8.3_commit_dialog.md](02_core_features/feature_08_ai_commit/2.8.3_commit_dialog.md) | AI消息生成和提交弹窗 | ✅ |

#### 功能9: AI Agent辅助 (`feature_09_ai_agent/`)
| 文件 | 步骤 | 状态 |
|------|------|------|
| [2.9.1_error_notification.md](02_core_features/feature_09_ai_agent/2.9.1_error_notification.md) | 错误提示通知 | ✅ |
| [2.9.2_chat_panel.md](02_core_features/feature_09_ai_agent/2.9.2_chat_panel.md) | AI对话面板 | ✅ |
| [2.9.3_ai_git_ops.md](02_core_features/feature_09_ai_agent/2.9.3_ai_git_ops.md) | AI执行Git操作(远期) | P2 |

#### 功能10: 文本文件编辑 (`feature_10_text_editor/`)
| 文件 | 步骤 | 状态 |
|------|------|------|
| [2.10.1_editor_basic.md](02_core_features/feature_10_text_editor/2.10.1_editor_basic.md) | 编辑器基础组件 | ✅ |
| [2.10.2_edit_operations.md](02_core_features/feature_10_text_editor/2.10.2_edit_operations.md) | 基本编辑操作 | ✅ |
| [2.10.3_syntax_highlight.md](02_core_features/feature_10_text_editor/2.10.3_syntax_highlight.md) | 语法高亮 | ✅ |
| [2.10.4_markdown.md](02_core_features/feature_10_text_editor/2.10.4_markdown.md) | Markdown支持 | ✅ |
| [2.10.5_ai_writing.md](02_core_features/feature_10_text_editor/2.10.5_ai_writing.md) | AI辅助写作(远期) | P2 |
| [2.10.6_docx.md](02_core_features/feature_10_text_editor/2.10.6_docx.md) | DOCX文件支持 | ✅ |

#### 功能11: 多格式预览 (`feature_11_multi_format/`)
| 文件 | 步骤 | 状态 |
|------|------|------|
| [2.11.1_pdf.md](02_core_features/feature_11_multi_format/2.11.1_pdf.md) | PDF预览 | ✅ |
| [2.11.2_excel.md](02_core_features/feature_11_multi_format/2.11.2_excel.md) | Excel预览 | ✅ |
| [2.11.3_pptx.md](02_core_features/feature_11_multi_format/2.11.3_pptx.md) | PPTX预览 | ✅ |
| [2.11.4_image.md](02_core_features/feature_11_multi_format/2.11.4_image.md) | 图片预览 | ✅ |

#### 功能12: 数据迁移备份 (`feature_12_backup/`)
| 文件 | 步骤 | 状态 |
|------|------|------|
| [2.12.1_export.md](02_core_features/feature_12_backup/2.12.1_export.md) | 数据导出 | ✅ (已重写为快照文件打包) |
| [2.12.2_import.md](02_core_features/feature_12_backup/2.12.2_import.md) | 数据导入 | ✅ (已重写为快照文件恢复) |

### 三、整体集成和测试 (`03_integration_test/`)
| 文件 | 步骤 | 状态 |
|------|------|------|
| [3.1_e2e_test.md](03_integration_test/3.1_e2e_test.md) | 端到端测试 | ✅ |
| [3.2_performance_test.md](03_integration_test/3.2_performance_test.md) | 性能测试 | ✅ |
| [3.3_cross_platform_test.md](03_integration_test/3.3_cross_platform_test.md) | 跨平台测试 | ✅ (已更新为纯Dart方案) |

### 四、发布准备 (`04_release/`)
| 文件 | 步骤 | 状态 |
|------|------|------|
| [4.1_package.md](04_release/4.1_package.md) | 打包和签名 | ✅ |

---

**状态说明**:
- ✅ 内容已更新，与当前方案一致
- P2: 远期目标，当前版本不需要实现