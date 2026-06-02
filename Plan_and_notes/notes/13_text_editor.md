# 文本编辑器功能开发笔记

## 概述

实现了文本文件编辑器功能，支持直接编辑追踪的文本文件，包括撤销/重做、自动保存等功能。

## 核心组件

### 1. TextEditorService (`lib/views/text_editor_view.dart`)

**核心方法：**

```dart
// 读取文件内容
Future<String> readFile(String filePath)

// 写入文件内容
Future<void> writeFile(String filePath, String content)

// 自动保存到版本仓库
Future<void> autoSave(String repoPath, String fileName, String originalFilePath)
```

### 2. TextEditorView (`lib/views/text_editor_view.dart`)

**功能特性：**

- **语法高亮准备**：预留行号显示区域
- **撤销/重做**：支持最多50步历史记录
- **更改检测**：实时检测文件是否有修改
- **保存状态**：显示保存进度和结果提示
- **版本恢复**：支持从历史版本恢复

**界面布局：**

```
┌─────────────────────────────────────────────────────────┐
│  [返回] 编辑图标 文件名 ● [撤销] [重做]                │
├─────────────────────────────────────────────────────────┤
│ 1 │                                                     │
│ 2 │                                                     │
│ 3 │      编辑区域                                         │
│...│                                                     │
└─────────────────────────────────────────────────────────┘
                           [保存按钮]
```

## 技术实现

### 历史记录管理

使用 List 存储历史状态，支持撤销/重做操作：

```dart
final List<String> _history = [];
int _historyIndex = -1;

void _saveToHistory() {
  // 移除当前位置之后的历史
  _history.removeRange(_historyIndex + 1, _history.length);
  // 添加新状态
  _history.add(_textController.text);
  _historyIndex = _history.length - 1;
  
  // 限制历史记录数量
  if (_history.length > 50) {
    _history.removeAt(0);
    _historyIndex--;
  }
}
```

### 撤销/重做逻辑

```dart
void _undo() {
  if (_historyIndex > 0) {
    _historyIndex--;
    _textController.text = _history[_historyIndex];
  }
}

void _redo() {
  if (_historyIndex < _history.length - 1) {
    _historyIndex++;
    _textController.text = _history[_historyIndex];
  }
}
```

### 行号显示

根据文本内容动态生成行号：

```dart
List<int> _getLineNumbers() {
  final lines = _textController.text.split('\n');
  return List.generate(lines.length, (index) => index + 1);
}
```

## 集成方式

### 在主页面添加编辑按钮

```dart
IconButton(
  icon: const Icon(Icons.edit_note, size: 18),
  tooltip: '编辑',
  onPressed: _selectedFile != null ? () => _showEditorView() : null,
)
```

### 打开编辑器视图

```dart
void _showEditorView() {
  if (_selectedFile != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TextEditorView(file: _selectedFile!),
      ),
    );
  }
}
```

## 保存流程

```
用户编辑 → 检测更改 → 点击保存按钮 → 写入文件 → 提交到版本仓库 → 更新历史记录
```

```dart
Future<void> _saveFile() async {
  // 1. 写入本地文件
  await editorService.writeFile(widget.file.filePath, _textController.text);
  
  // 2. 提交到版本仓库
  if (widget.file.repoPath != null) {
    await editorService.autoSave(...);
  }
  
  // 3. 更新历史记录
  _saveToHistory();
}
```

## 状态管理

| 状态 | 显示方式 |
|------|----------|
| 有更改 | 红色小圆点 |
| 保存中 | 加载动画 |
| 无更改 | 正常显示 |

## 测试要点

1. **文件读写**：测试打开和保存文件功能
2. **撤销/重做**：测试撤销和重做操作
3. **更改检测**：测试修改后显示更改标记
4. **保存功能**：测试保存到文件和版本仓库
5. **历史恢复**：测试从历史版本恢复文件

## 待优化项

1. **语法高亮**：添加代码语法高亮支持
2. **搜索替换**：添加搜索和替换功能
3. **行号同步**：行号列表与编辑区域同步滚动
4. **快捷键支持**：支持 Ctrl+S 保存、Ctrl+Z 撤销等
5. **编辑器配置**：支持自定义字体大小、主题等
6. **大文件优化**：优化大文件的加载和编辑性能