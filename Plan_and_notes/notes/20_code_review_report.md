# 20 - 代码审查：实际代码与文档对比分析

**日期**：2026-06-02
**目的**：阅读实际代码，对比开发笔记和文档描述，找出问题

---

## 一、代码中发现的问题（文档未记录）

### 🔴 严重问题

#### 1. AutoSaveTimerService 长计时器（强制保存）从未被启动
- `main.dart` 中监听了 `trackedFileListProvider`，对每个文件调用 `watcherService.startWatching(file)`
- 但 `AutoSaveTimerService.startForceSaveTimer()` **从未被调用**
- 长计时器（每3分钟强制保存）完全不工作
- **影响**：功能5的核心需求"每3分钟自动进行一次保存"未实现

#### 2. FileWatcherService 与 AutoSaveTimerService 没有联动
- `FileWatcherService` 有自己的 `_debounceTimers`，文件变更后延迟提交
- `AutoSaveTimerService` 有 `markFileChanged()` / `markFileSaved()` 方法
- 但 `FileWatcherService._triggerAutoSave()` 成功后**没有调用** `AutoSaveTimerService.markFileSaved()`
- 这意味着 `_hasChanges` 永远不会被重置，强制保存会重复提交
- **影响**：自动保存逻辑存在严重缺陷

#### 3. GitService 被多处直接实例化，不通过 Provider
- `file_watcher_service.dart`：`final gitService = GitService();`
- `auto_save_timer_service.dart`：`final gitService = GitService();`
- `text_editor_view.dart`：`final gitService = GitService();`
- `commit_dialog.dart`：`final gitService = GitService();`
- 而 `git_provider.dart` 定义了 `gitServiceProvider`
- **影响**：GitService 不受 Riverpod 管理，无法统一生命周期，可能导致资源泄漏

#### 4. TextEditorView 行号滚动与文本滚动不同步
- 行号和文本区域使用同一个 `_scrollController`
- 但行号用 `ListView.builder`，文本用 `SingleChildScrollView` 包裹 `TextField`
- 两个组件的滚动行为不同，行号不会与文本同步滚动
- **影响**：编辑器体验差，行号错位

#### 5. CompareView 差异导航不工作
- `_navigateToDiff()` 方法只更新了 `_currentDiffIndex` 状态
- 但**没有实际滚动到对应的差异行**
- 点击上/下一个差异按钮只是更新了文字显示，视图不会跳转
- **影响**：对比视图的导航功能形同虚设

---

### 🟡 中等问题

#### 6. SettingsService 的"测试连接"是假的
- `settings_dialog.dart` 中：`await Future.delayed(const Duration(seconds: 2))` 然后直接根据 `hasAiConfig` 判断
- 并没有真正调用 AI API 测试连接
- **影响**：与 PLAN.md 要求的"测试连接按钮：点击后验证配置有效性"不符

#### 7. AiService 硬编码了 gpt-3.5-turbo 模型
- `ai_service.dart` 中三个方法都写死了 `'model': 'gpt-3.5-turbo'`
- 如果用户使用其他兼容 API（如 Claude、本地模型），无法自定义模型名称
- **影响**：AI 配置灵活性不足

#### 8. DiffService 的 LCS 算法对大文件性能差
- `_computeLCS` 使用 O(m*n) 的动态规划，空间复杂度也是 O(m*n)
- 对于几百 KB 的文件，可能产生内存问题
- **影响**：大文件差异计算可能卡顿或崩溃

#### 9. FileScanService 全盘扫描是递归同步的
- `_scanDirectory` 方法递归遍历所有子目录
- 对于大容量磁盘，即使有 3 分钟超时，也可能在扫描深层目录时卡住
- 没有优先扫描常用目录的逻辑
- **影响**：文件扫描功能可能超时或卡住

#### 10. _FilePreviewContent 尝试用 readAsString() 读取所有文件
- 对于二进制文件（PDF、Excel、图片等），`readAsString()` 会失败或显示乱码
- 应该先判断文件类型，二进制文件显示"不支持预览"
- **影响**：预览二进制文件会报错

---

### 🟢 小问题

#### 11. main_page.dart 中 _buildNoSelectionState() 方法未被使用
- 定义了 `_buildNoSelectionState()`，但没有任何地方调用它
- 这是旧版两栏布局的遗留代码

#### 12. DiffLineType 有 context 枚举值但从未使用
- `diff_service.dart` 定义了 `DiffLineType.context`，但 `_computeDiff` 中从未生成 context 类型的行
- `compare_view.dart` 中有对 context 的处理代码，但永远不会执行

#### 13. TrackedFile 模型缺少文件大小字段
- PLAN.md 要求显示"文件名、大小、修改日期"
- 数据库表和模型都没有 `fileSize` 字段

---

## 二、代码与文档描述不一致

| 代码实际 | 文档描述 | 差异 |
|----------|----------|------|
| 设置页面是一个弹窗，没有侧边导航 | PLAN.md 要求"侧边导航分类（通用、自动保存、AI配置）" | 缺少侧边导航 |
| AI 对话是独立页面 | PLAN.md 和 processes.md 要求"右侧滑出面板" | 交互形式不同 |
| 文件选择用系统原生对话框 | PLAN.md 描述自定义模态对话框 | 实现方式不同 |
| 帮助弹窗只有简单列表 | PLAN.md 要求"左侧目录树+右侧内容+底部搜索+AI输入" | 功能严重不足 |
| 状态栏只有静态"已保存" | PLAN.md 要求三种动态状态图标 | 未实现 |
| Onboarding 代码存在但未集成 | processes.md 要求"首次打开软件时显示引导" | 未集成 |
| 编辑器用 TextField | processes.md 要求"集成 flutter_quill 富文本编辑器" | 实现方式不同 |
| 测试连接是假的 | PLAN.md 要求"验证配置有效性" | 未真正实现 |
| GitService 直接实例化 | 应通过 Provider 管理 | 架构不一致 |

---

## 三、问题分类

### 功能缺陷（需要修复）
1. 自动保存计时器未启动
2. FileWatcher 和 AutoSaveTimer 没有联动
3. 差异导航不工作
4. 行号滚动不同步
5. 二进制文件预览崩溃

### 架构问题（需要重构）
1. GitService 直接实例化，不通过 Provider
2. FileWatcher 和 AutoSaveTimer 的联动机制缺失

### 与文档不一致（需要决定以谁为准）
1. 设置页面形式：弹窗 vs 侧边导航
2. AI 对话形式：独立页面 vs 滑出面板
3. 编辑器实现：TextField vs flutter_quill
4. 帮助弹窗功能：简单列表 vs 完整说明书
5. 状态栏：静态 vs 动态
