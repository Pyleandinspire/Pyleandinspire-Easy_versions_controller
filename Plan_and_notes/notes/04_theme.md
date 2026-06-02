# 主题和设计规范笔记

## 步骤 1.4 实现浅色主题和设计规范

### 设计规范（来自 PLAN.md）
| 项目 | 值 |
|------|-----|
| 主色调 | #f8fafc (AppColors.primary) |
| 次级色 | #f1f5f9 (AppColors.secondary) |
| 蓝色强调色 | #3b82f6 (AppColors.accent) |
| 绿色成功 | #22c55e (AppColors.success) |
| 红色警告 | #ef4444 (AppColors.error) |
| 黄色提示 | #eab308 (AppColors.warning) |
| 文字颜色 | #1e293b (AppColors.textPrimary) |
| 次要文字 | #64748b (AppColors.textSecondary) |
| 边框色 | #e2e8f0 (AppColors.border) |

### diff 高亮色
| 类型 | 颜色 |
|------|------|
| 新增 | #dcfce7 (AppColors.diffAdded) |
| 删除 | #fee2e2 (AppColors.diffDeleted) |
| 修改 | #fef9c3 (AppColors.diffModified) |

### AI 对话色
| 类型 | 颜色 |
|------|------|
| AI消息背景 | #f1f5f9 (AppColors.aiMessageBg) |
| 用户消息背景 | #dbeafe (AppColors.userMessageBg) |

### 间距规范 (AppSpacing)
- xs: 4px, sm: 8px, md: 12px, lg: 16px, xl: 24px, xxl: 32px

### 圆角规范 (AppRadius)
- card: 8px, button: 4px, input: 4px

### 阴影规范 (AppShadow)
- soft: blurRadius=8, offset=(0,2), alpha=0.1
- medium: blurRadius=16, offset=(0,4), alpha=0.1

### 文字样式 (AppTextStyles)
- heading1: 24px bold
- heading2: 18px w600
- heading3: 14px w600
- body: 14px regular
- bodySecondary: 14px secondary color
- caption: 12px secondary color
- timestamp: 13px accent color w500

### 主题配置
- 使用 Material 3
- 浅色主题 (Brightness.light)
- 全局使用 appTheme 函数生成 ThemeData
