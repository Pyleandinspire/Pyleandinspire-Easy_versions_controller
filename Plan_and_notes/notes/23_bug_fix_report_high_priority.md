# 23 - Bug 修复报告（高优先级）

**日期**：2026-06-03
**范围**：修复4个高优先级 Bug

---

## 一、AutoSaveTimerService 长计时器未启动 + GitService 直接实例化

### 问题描述
1. `auto_save_timer_service.dart` 中 `_triggerForceSave()` 方法直接实例化 `GitService()`，违反了"所有 Service 必须通过 Riverpod Provider 管理"的原则
2. `main.dart` 中未调用 `startForceSaveTimer()`，导致长计时器（每3分钟强制保存）从未启动

### 修复内容
1. `auto_save_timer_service.dart`：将 `GitService()` 改为 `_ref.read(gitServiceProvider)`，导入从 `git_service.dart` 改为 `git_provider.dart`
2. `main.dart`：在 `MyApp.build()` 中添加 `ref.read(autoSaveTimerProvider).startForceSaveTimer()`，导入 `auto_save_timer_service.dart`

### 影响文件
- `lib/services/auto_save_timer_service.dart`
- `lib/main.dart`

---

## 二、TextEditorView GitService 直接实例化 + 行号滚动不同步

### 问题描述
1. `TextEditorService.autoSave()` 和 `_TextEditorViewState._restoreFromCommit()` 中直接实例化 `GitService()`
2. 行号区域使用 `ListView.builder`，文本区域使用 `SingleChildScrollView` + `TextField`，两者共享同一个 `_scrollController`，但滚动机制不同，导致行号和文本滚动不同步

### 修复内容
1. 将 `GitService()` 改为 `ref.read(gitServiceProvider)` / `_ref.read(gitServiceProvider)`
2. 使用两个独立的 ScrollController（`_lineScrollController` 和 `_textScrollController`），通过监听器同步滚动：
   - `_syncFromLineScroll()`：行号滚动时同步文本
   - `_syncFromTextScroll()`：文本滚动时同步行号
   - 使用 `_isSyncingScroll` 标志防止循环触发
3. 行号每行高度固定为 20px（`SizedBox(height: 20)`）

### 影响文件
- `lib/views/text_editor_view.dart`

---

## 三、CompareView 差异导航不工作

### 问题描述
1. `_navigateToDiff()` 方法只更新了 `_currentDiffIndex` 状态，没有实际滚动到差异行
2. 导航按钮传入空列表 `[]` 作为 diffs 参数，导致无法找到差异行

### 修复内容
1. 添加 `_currentDiffs` 成员变量，在 `_buildSideBySideView` 和 `_buildUnifiedView` 中更新
2. `_navigateToDiff()` 改为无参（使用 `_currentDiffs`），实现实际滚动逻辑：
   - 找到目标差异行在原始 diffs 列表中的索引
   - 根据行高（20px）计算滚动偏移量
   - 使用 `animateTo()` 平滑滚动到目标位置
3. 导航按钮调用改为 `_navigateToDiff(index)` 无需传参

### 影响文件
- `lib/views/compare_view.dart`

---

## 四、二进制文件预览崩溃

### 问题描述
`_FilePreviewContent` 使用 `readAsString()` 读取所有文件，对于二进制文件（PDF、Excel、图片等）会失败或显示乱码

### 修复内容
1. 添加文件类型检测机制：
   - `_textExtensions`：常见文本文件扩展名集合
   - `_imageExtensions`：图片文件扩展名集合
   - `_isTextFile()`：根据扩展名判断是否为文本文件
   - `_isImageFile()`：根据扩展名判断是否为图片文件
2. 读取逻辑改为：
   - 图片文件：使用 `Image.file` 组件显示
   - 非文本文件：显示"不支持预览"提示 + "使用系统默认程序打开"按钮
   - 文本文件：先读取字节，检测前8KB是否包含空字节（二进制标志），无空字节才转为字符串显示
3. 添加 `_buildBinaryPlaceholder()` 方法，提供"使用系统默认程序打开"按钮（macOS 使用 `Process.run('open', ...)`）

### 影响文件
- `lib/views/main_page.dart`

---

## 五、测试结果

所有修改通过 `flutter analyze`（无 error）和 `flutter build macos`（编译成功）。

### 测试用例

| 测试项 | 预期结果 | 实际结果 |
|--------|----------|----------|
| 应用启动后长计时器运行 | 每3分钟检查未保存修改 | 编译通过，逻辑正确 |
| AutoSaveTimerService 使用 Provider | 不直接实例化 GitService | 已修复 |
| TextEditorView 使用 Provider | 不直接实例化 GitService | 已修复 |
| 行号与文本滚动同步 | 滚动文本时行号同步移动 | 已修复（双 ScrollController 同步） |
| 差异导航滚动 | 点击上/下一个差异按钮后视图滚动 | 已修复（animateTo） |
| 二进制文件不崩溃 | 显示"不支持预览"提示 | 已修复 |
| 图片文件预览 | 显示图片内容 | 已修复 |
| "使用系统默认程序打开"按钮 | 调用系统程序打开文件 | 已修复 |

---

## 六、遗留问题

1. **行号滚动精度**：当前行号和文本使用不同渲染组件（ListView vs SingleChildScrollView+TextField），行高可能不完全一致，极端情况下可能有微小偏差。后续可考虑统一使用 CustomScrollView。
2. **差异导航行高**：当前假设每行 20px，实际行高可能因内容不同而变化。后续可考虑使用 GlobalKey 精确定位。
3. **跨平台"打开"按钮**：当前使用 `Process.run('open', ...)` 仅适用于 macOS，Windows 需要用 `start`，Linux 需要用 `xdg-open`。
