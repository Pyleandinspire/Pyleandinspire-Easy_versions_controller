# 文件监听功能实现笔记

## 概述

实现了文件系统事件监听功能，支持自动保存和防抖机制。

## 核心组件

### FileWatcherService (`lib/services/file_watcher_service.dart`)

**功能特性：**

1. **文件监听**：使用 `watcher` 包监听文件变更
2. **防抖机制**：1秒内重复修改不触发事件
3. **延迟提交**：用户停止编辑指定秒数后自动提交
4. **订阅管理**：正确管理 StreamSubscription，避免内存泄漏

**关键方法：**

```dart
void startWatching(TrackedFile file) - 开始监听文件
void stopWatching(String fileId) - 停止监听指定文件
void stopAllWatching() - 停止所有监听
void _handleFileChange(TrackedFile file, WatchEvent event) - 处理文件变更
Future<void> _triggerAutoSave(TrackedFile file) - 触发自动保存
```

## 技术实现

### StreamSubscription 管理

使用 Map 存储 StreamSubscription，确保正确取消订阅：

```dart
final Map<String, StreamSubscription> _subscriptions = {};

final subscription = watcher.events.listen((event) {
  if (event.path == file.filePath) {
    _handleFileChange(file, event);
  }
});

_subscriptions[file.id] = subscription;
```

### 防抖机制

使用 `lastModified` Map 记录最后修改时间，1秒内重复修改不触发：

```dart
final now = DateTime.now();
final lastTime = _lastModified[file.id];

if (lastTime != null && now.difference(lastTime).inSeconds < 1) {
  return;
}

_lastModified[file.id] = now;
```

### 延迟提交

使用 Timer 实现延迟提交，连续修改会重置计时器：

```dart
final existingTimer = _debounceTimers[file.id];
if (existingTimer != null) {
  existingTimer.cancel();
}

final settings = _ref.read(settingsProvider);
final delaySeconds = settings.autoSaveDelay;

_debounceTimers[file.id] = Timer(Duration(seconds: delaySeconds), () {
  _triggerAutoSave(file);
});
```

## 测试要点

1. **文件监听**：测试修改文件能被检测到
2. **防抖机制**：测试频繁修改不会产生过多事件
3. **延迟提交**：测试修改文件后开始倒计时
4. **重置计时器**：测试连续修改会重置计时器
5. **提交触发**：测试倒计时结束后能触发提交
6. **自定义时间**：测试自定义时间设置生效

## 集成方式

### 在主页面集成

需要在主页面中启动和停止文件监听：

```dart
@override
void initState() {
  super.initState();
  final fileWatcher = ref.read(fileWatcherProvider);
  if (_selectedFile != null) {
    fileWatcher.startWatching(_selectedFile!);
  }
}

@override
void dispose() {
  final fileWatcher = ref.read(fileWatcherProvider);
  fileWatcher.stopAllWatching();
  super.dispose();
}
```

## 待优化项

1. **长计时器**：实现每3分钟强制保存功能
2. **状态指示器**：在底部状态栏显示保存状态
3. **错误处理**：完善错误提示和日志记录
4. **性能优化**：优化大量文件的监听性能