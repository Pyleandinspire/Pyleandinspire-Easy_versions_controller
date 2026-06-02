# 功能5：自动保存 - 笔记

## 步骤 2.5.1 创建文件监听服务

### 实现内容
- 创建 `FileWatcherService` 文件监听服务
- 使用 `watcher` 库的 `DirectoryWatcher` 监听文件变化
- 为每个追踪文件启动一个监听器
- 监听文件目录而非单个文件（因为 watcher 库的限制）

### 核心功能
- `startWatching(TrackedFile file)` - 启动文件监听
- `stopWatching(String fileId)` - 停止指定文件的监听
- `stopAllWatching()` - 停止所有监听
- `_handleFileChange(TrackedFile file)` - 处理文件变化事件

### watcher 库使用要点
- 使用 `DirectoryWatcher` 监听文件所在目录
- 通过 `events.listen()` 监听文件系统事件
- `ChangeType` 枚举：`ADD`、`MODIFY`、`REMOVE`
- 需要过滤出目标文件的变化事件

## 步骤 2.5.2 实现自动提交逻辑

### 实现内容
- 更新 `GitService` 添加 `commitChanges()` 方法
- 在 `main.dart` 中初始化文件监听服务
- 使用 `ref.listen` 监听文件列表变化，自动启动监听

### 自动保存流程
1. 应用启动时，`MyApp` 组件监听 `trackedFileListProvider`
2. 当文件列表加载完成后，为每个文件启动 `DirectoryWatcher`
3. 监听器捕获文件变化事件（排除 REMOVE 事件）
4. 调用 `GitService.commitChanges()` 提交更改
5. 更新文件的最后访问时间

### Git 自动提交
- 提交消息格式：`自动保存: yyyy-MM-dd HH:mm:ss`
- 自动复制最新文件内容到仓库
- 自动 add、write、commit

### 注意事项
- watcher 库不支持直接监听单个文件，必须监听目录
- 需要过滤出目标文件的变化事件，避免无关文件触发提交
- 监听器会持续运行，应用退出时会自动清理
- 避免频繁提交，当前实现为每次变化都提交（可考虑后续添加防抖机制）
