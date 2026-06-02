# AI 功能开发笔记

## 概述

实现了 AI 生成 commit 消息功能，包括：
1. AI 配置管理（API Key 和 Endpoint）
2. AI 服务封装（调用 OpenAI API）
3. 提交弹窗（带 AI 生成消息）

## 核心组件

### 1. SettingsService 更新 (`lib/views/settings_dialog.dart`)

**新增配置项：**
- `_aiApiKeyKey` - AI API Key 存储键
- `_aiEndpointKey` - AI API 地址存储键

**新增方法：**
```dart
saveAiApiKey(String apiKey) - 保存 API Key
saveAiEndpoint(String endpoint) - 保存 API 地址
hasAiConfig - 检查是否配置了 AI
```

**配置界面功能：**
- API Key 输入框（可切换显示/隐藏）
- API Endpoint 输入框（默认 OpenAI 地址）
- 测试连接按钮（模拟连接测试）

### 2. AiService (`lib/services/ai_service.dart`)

**核心功能：**

1. **generateCommitMessage** - 根据代码差异生成 commit 消息
   - 调用 OpenAI Chat Completions API
   - 使用 gpt-3.5-turbo 模型
   - 提示词设计：让 AI 作为代码提交助手

2. **askQuestion** - 通用问题问答
   - 用于 AI Agent 辅助功能
   - 专门针对 Git 相关问题

3. **rewriteText** - 文本重写
   - 用于优化 commit 消息
   - 支持自定义指令

**API 调用流程：**
```
用户点击提交 → 获取文件差异 → 调用 generateCommitMessage → 显示生成的消息
```

### 3. CommitDialog (`lib/views/commit_dialog.dart`)

**功能特性：**
- 自动调用 AI 生成 commit 消息
- 显示更改预览（前10行）
- 支持自定义修改消息
- 提交状态反馈

**界面布局：**
- 顶部：标题和关闭按钮
- 中部：消息输入框 + 差异预览
- 底部：取消和提交按钮

## 技术要点

### HTTP 调用封装

使用 `http` 包进行 API 调用：

```dart
final response = await http.post(
  Uri.parse(settings.aiEndpoint),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${settings.aiApiKey}',
  },
  body: jsonEncode({...}),
).timeout(const Duration(seconds: 30));
```

### 异步状态管理

在提交弹窗中处理异步生成消息：

```dart
Future<String?> aiMessage;
try {
  aiMessage = await aiService.generateCommitMessage(diff);
} catch (_) {
  aiMessage = null;
}
```

### 错误处理

- 网络超时处理（30秒超时）
- API 配置检查（无配置时返回 null）
- 提交失败提示（SnackBar）

## 集成方式

### 在主页面添加提交按钮

```dart
IconButton(
  icon: const Icon(Icons.commit, size: 18),
  tooltip: '提交',
  onPressed: _selectedFile != null ? () => _showCommitDialog() : null,
)
```

### 调用提交弹窗

```dart
final commitDialog = ref.read(commitDialogProvider);
final result = await commitDialog.show(
  context: context,
  repoPath: _selectedFile!.repoPath ?? '',
  diff: '',
  fileName: _selectedFile!.fileName,
);
```

## 测试要点

1. **配置验证**：测试 API Key 和 Endpoint 的保存和加载
2. **连接测试**：测试连接状态的正确显示
3. **消息生成**：验证 AI 生成消息的功能（需要真实 API Key）
4. **提交流程**：验证提交功能正常工作
5. **错误处理**：测试无配置时的降级行为

## 待优化项

1. **真实连接测试**：当前仅检查配置是否存在，需要实现真实 API 调用测试
2. **消息优化**：支持让 AI 重写/优化现有消息
3. **多语言支持**：支持中英文消息生成
4. **模型选择**：支持选择不同的 AI 模型
5. **本地缓存**：缓存生成的消息避免重复调用