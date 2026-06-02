# AI Agent 辅助功能开发笔记

## 概述

实现了 AI Agent 辅助功能，提供智能问答和代码分析能力，帮助用户更好地使用版本控制功能。

## 核心组件

### 1. AiAgentService (`lib/views/ai_agent_view.dart`)

**核心方法：**

1. **askQuestion** - 通用问题问答
   - 调用 AiService 的 askQuestion 方法
   - 支持传入当前文件上下文

2. **explainCode** - 代码解释
   - 使用 rewriteText 方法
   - 提示词："请解释这段代码的功能和实现逻辑："

3. **suggestOptimization** - 代码优化建议
   - 使用 rewriteText 方法
   - 提示词："请优化这段代码并说明优化理由："

4. **get faqItems** - 获取常见问题列表
   - 预定义6个常见问题
   - 分为不同类别（版本恢复、版本对比、自动保存等）

### 2. AiAgentView (`lib/views/ai_agent_view.dart`)

**功能特性：**

- **聊天界面**：类似 ChatGPT 的对话界面
- **实时反馈**：显示"正在思考..."状态
- **快速提问**：提供常见问题快捷按钮
- **上下文感知**：可以传递当前选中的文件信息

**界面布局：**

```
┌─────────────────────────────────┐
│         AI 助手标题栏           │
├─────────────────────────────────┤
│                                 │
│    [用户消息]                    │
│    [AI 回复]                     │
│    [正在思考...]                 │
│                                 │
├─────────────────────────────────┤
│    快速提问：                    │
│  [按钮] [按钮] [按钮]            │
├─────────────────────────────────┤
│  [输入框] [发送按钮]             │
└─────────────────────────────────┘
```

## 技术实现

### 聊天消息数据结构

```dart
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
}
```

### 消息发送流程

```dart
Future<void> _sendMessage() async {
  // 1. 添加用户消息到列表
  _messages.add(ChatMessage(...));
  
  // 2. 显示正在思考状态
  setState(() => _isTyping = true);
  
  // 3. 调用 AI 服务
  final response = await aiAgent.askQuestion(message);
  
  // 4. 添加 AI 回复
  _messages.add(ChatMessage(...));
  
  // 5. 隐藏正在思考状态
  setState(() => _isTyping = false);
}
```

### 自动滚动

使用 ScrollController 实现消息列表自动滚动到底部：

```dart
void _scrollToBottom() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });
}
```

## 集成方式

### 在主页面添加 AI 助手按钮

```dart
IconButton(
  icon: const Icon(Icons.chat_bubble_outline, size: 20),
  tooltip: 'AI 助手',
  onPressed: () => _showAiAgentView(),
)
```

### 打开 AI 助手视图

```dart
void _showAiAgentView() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AiAgentView(file: _selectedFile),
    ),
  );
}
```

## 常见问题列表

| 问题 | 类别 |
|------|------|
| 如何恢复到之前的版本？ | 版本恢复 |
| 如何比较两个版本的差异？ | 版本对比 |
| 自动保存是如何工作的？ | 自动保存 |
| 如何删除不需要的版本？ | 版本管理 |
| 如何导出版本历史？ | 数据导出 |
| 支持哪些文件类型？ | 文件支持 |

## 测试要点

1. **聊天功能**：测试发送消息和接收回复
2. **快速提问**：测试点击快捷按钮填充输入框
3. **状态显示**：测试"正在思考"状态的显示
4. **自动滚动**：测试消息列表自动滚动到底部
5. **错误处理**：测试无 AI 配置时的降级行为

## 待优化项

1. **代码分析**：支持直接分析当前文件的代码
2. **上下文记忆**：保持对话上下文，支持多轮对话
3. **文件上下文**：将当前文件内容传递给 AI
4. **代码建议**：根据文件内容提供优化建议
5. **命令执行**：支持让 AI 生成并执行 Git 命令