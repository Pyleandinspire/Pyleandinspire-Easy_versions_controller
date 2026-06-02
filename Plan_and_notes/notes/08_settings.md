# 功能3：自定义设置自动更改时间

## 实现概述

本功能实现了自动保存时间间隔的设置功能，用户可以自定义文件自动保存的时间间隔。

## 核心组件

### SettingsService

提供设置管理服务，使用 `shared_preferences` 存储设置：

- `loadSettings()`: 从本地存储加载设置
- `saveAutoSaveInterval(int minutes)`: 保存自动保存间隔设置
- 默认值：5分钟

### SettingsDialog

设置对话框组件，包含：
- 标题区域：设置图标 + "设置"文字
- 设置项区域：自动保存间隔输入框
- 操作按钮：取消、确定

### Provider 配置

使用 `Provider<SettingsService>` 提供全局设置服务，在 `main.dart` 中初始化加载设置。

## 关键代码

```dart
final settingsProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});
```

## 集成方式

1. 在 `main.dart` 的 `build` 方法中调用 `ref.read(settingsProvider).loadSettings()` 初始化
2. 在 `main_page.dart` 中添加设置按钮，点击弹出 `SettingsDialog`
3. 对话框中修改设置后自动保存到 `shared_preferences`

## 使用场景

用户点击顶部导航栏的设置图标，打开设置对话框，修改自动保存间隔时间（分钟），设置会自动保存并持久化。

## 注意事项

- 使用 `Provider` 而非 `StateProvider` 是因为 Riverpod v3 中 `StateProvider` 需要配合 `riverpod_annotation` 使用代码生成
- 设置值在修改时立即保存到本地存储，无需手动点击保存按钮
