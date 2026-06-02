# 长计时器功能实现笔记

## 概述

实现了每3分钟强制保存功能，确保文件修改不会丢失。

## 核心组件

### AutoSaveTimerService (`lib/services/auto_save_timer_service.dart`)

**功能特性：**

1. **定时检查**：每3分钟检查一次所有追踪的文件
2. **变更标记**：标记有修改的文件
3. **强制保存**：有修改时触发提交
4. **间隔配置**：支持自定义保存间隔

**关键方法：**

```dart
void startForceSaveTimer() - 启动强制保存定时器
void stopForceSaveTimer() - 停止强制保存定时器
void markFileChanged(TrackedFile file) - 标记文件已修改
void markFileSaved(TrackedFile file) - 标记文件已保存
Future<void> _checkAndSaveAll() - 检查并保存所有有修改的文件
```

## 技术实现

### Timer.periodic 定时器

使用 Timer.periodic 实现定时检查：

```dart
_forceSaveTimer = Timer.periodic(
  Duration(minutes: intervalMinutes),
  (_) => _checkAndSaveAll(),
);
```

### 变更标记

使用 Map 记录文件的变更状态：

```dart
final Map<String, bool> _hasChanges = {};

void markFileChanged(TrackedFile file) {
  _hasChanges[file.id] = true;
}

void markFileSaved(TrackedFile file) {
  _hasChanges[file.id] = false;
  _lastSaveTime[file.id] = DateTime.now();
}
```

### 检查并保存

遍历所有追踪的文件，只保存有修改的文件：

```dart
Future<void> _checkAndSaveAll() async {
  final trackedFiles = ref.read(trackedFileListProvider);
  final files = trackedFiles.value ?? [];

  for (final file in files) {
    if (_hasChanges[file.id] == true) {
      await _triggerForceSave(file);
    }
  }
}
```

## 测试要点

1. **定时检查**：测试每3分钟检查一次是否有修改
2. **有修改时提交**：测试有修改时触发提交
3. **无修改不提交**：测试3分钟内无修改不触发提交
4. **自定义间隔**：测试自定义间隔设置生效
5. **停止定时器**：测试停止定时器功能

## 集成方式

### 在主页面集成

需要在主页面中启动和停止强制保存定时器：

```dart
@override
void initState() {
  super.initState();
  final autoSaveTimer = ref.read(autoSaveTimerProvider);
  autoSaveTimer.startForceSaveTimer();
}

@override
void dispose() {
  final autoSaveTimer = ref.read(autoSaveTimerProvider);
  autoSaveTimer.dispose();
  super.dispose();
}
```

### 与文件监听集成

在文件监听服务中标记文件变更：

```dart
void _handleFileChange(TrackedFile file, WatchEvent event) {
  final autoSaveTimer = _ref.read(autoSaveTimerProvider);
  autoSaveTimer.markFileChanged(file);
  
  // ... 其他逻辑
}
```

在自动保存完成后标记文件已保存：

```dart
Future<void> _triggerAutoSave(TrackedFile file) async {
  try {
    final gitService = GitService();
    await gitService.commitChanges(...);
    
    final autoSaveTimer = _ref.read(autoSaveTimerProvider);
    autoSaveTimer.markFileSaved(file);
  } catch (e) {
    print('Auto save failed: $e');
  }
}
```

## 待优化项

1. **状态指示器**：在底部状态栏显示保存状态
2. **错误处理**：完善错误提示和日志记录
3. **性能优化**：优化大量文件的检查性能
4. **配置验证**：验证间隔时间的合法性