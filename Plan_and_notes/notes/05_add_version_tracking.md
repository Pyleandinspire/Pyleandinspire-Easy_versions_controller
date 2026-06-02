# 功能1：添加版本追踪 - 笔记

## 步骤 2.1.1 实现文件选择对话框

### 实现内容
- 创建 `FilePickerService` 封装 file_picker 库
- 支持多选文件，不限制文件类型和大小
- 创建 `filePickerServiceProvider` Riverpod Provider
- MainPage 改为 ConsumerStatefulWidget，连接文件选择功能

### macOS 权限修复
- 需要在 `macos/Runner/DebugProfile.entitlements` 和 `Release.entitlements` 中添加：
  - `com.apple.security.files.user-selected.read-only`
  - `com.apple.security.files.user-selected.read-write`
- 否则 file_picker 会报 `ENTITLEMENT_NOT_FOUND` 错误

## 步骤 2.1.2 实现本地数据库和文件元数据存储

### 实现内容
- 创建 `TrackedFile` 数据模型（id, filePath, fileName, repoPath, addedAt, lastAccessedAt）
- 创建 `DatabaseService` 数据库服务
- 使用 sqflite + sqflite_common_ffi 实现跨平台数据库
- 数据库表：tracked_files
- CRUD 操作：insert, getAll, getById, getByPath, update, delete

### 跨平台数据库方案
- macOS: 使用 sqflite 默认的 databaseFactory
- Windows/Linux: 使用 sqflite_common_ffi 的 databaseFactoryFfi
- 通过 `Platform.isWindows || Platform.isLinux` 判断平台

### 注意事项
- 需要添加 `path` 依赖（pubspec.yaml）
- sqflite_common_ffi 已包含 sqflite 的所有 API，不需要同时 import

## 步骤 2.1.3 实现文件打标记和Git仓库初始化

### 实现内容
- 创建 `GitService` 封装 git2dart 库
- 为每个文件单独创建 Git 仓库（在 Application Support 目录下的 easy_versions_repos/{fileId}）
- 添加文件时自动：复制文件 → git init → git add → git commit（初始版本）
- 创建 `TrackedFileListNotifier`（AsyncNotifier）统一管理文件选择、数据库存储和 Git 初始化流程

### git2dart API 要点
- `Repository.init(path: repoPath)` - 初始化仓库
- `Repository.open(repoPath)` - 打开仓库
- `repo.index` - 获取暂存区
- `index.add(fileName)` - 添加文件到暂存区
- `index.write()` - 写入暂存区
- `index.writeTree()` - 生成 tree Oid
- `Tree.lookup(repo: repo, oid: treeOid)` - 查找 tree
- `Signature.create(name:, email:)` - 创建签名
- `Commit.create(repo:, updateRef:, message:, author:, committer:, tree:, parents:)` - 创建提交
- `RevWalk(repo)` - 创建提交遍历器（注意：构造函数直接传 repo）
- `walker.sorting({GitSort.time})` - 设置排序
- `walker.pushHead()` - 从 HEAD 开始遍历
- `walker.walk(limit: n)` - 遍历提交，返回 List<Commit>
- `Oid.fromSHA(repo, sha)` - 从 SHA 字符串创建 Oid
- `repo.statusFile(fileName)` - 获取单个文件状态，返回 Set<GitStatus>
- 所有 git2dart 对象使用后需调用 `.free()` 释放内存

### Riverpod v3 注意事项
- 不再使用 StateNotifier，改用 AsyncNotifier
- `AsyncNotifierProvider<NotifierType, StateType>` 定义 provider
- `state = AsyncData(newValue)` 更新状态
- `ref.read(provider.notifier).method()` 调用方法

### 文件添加完整流程
1. 用户点击"添加文件"按钮
2. FilePickerService.pickFiles() 打开文件选择对话框
3. 遍历选中的文件路径：
   - 检查数据库是否已存在（避免重复添加）
   - 生成 UUID 作为 fileId
   - GitService.initRepoForFile() 创建 Git 仓库并提交初始版本
   - 创建 TrackedFile 对象并存入数据库
4. 刷新文件列表

## 步骤 2.1.4 实现文件扫描和定位机制

### 实现内容
- 创建 `FileScanService` 文件扫描服务
- 创建 `FileNotFoundDialog` 对话框组件
- 更新 `TrackedFileListNotifier` 添加文件存在性检查、扫描、更新路径方法
- 更新 `MainPage` 添加文件缺失检测和对话框处理

### 文件扫描服务（FileScanService）
- `fileExists(String filePath)` - 检测文件是否存在
- `scanForFile(fileName, timeout)` - 全盘扫描文件，默认3分钟超时
- 扫描根目录：macOS(/Users)、Linux(/home)、Windows(C:\Users)
- 使用 async/await + timeout 实现超时机制

### 文件找不到对话框（FileNotFoundDialog）
- 显示错误图标和提示信息
- 显示上次已知路径
- 三个操作按钮：
  - "放弃追踪"：从数据库中移除文件
  - "提供路径"：打开文件选择对话框重新选择文件
  - "自动扫描"：启动全盘扫描（显示加载状态）

### 文件列表显示优化
- 文件存在时显示普通文件图标
- 文件缺失时显示红色错误图标，文件名也显示红色
- 点击缺失文件时弹出文件找不到对话框

### 完整流程
1. 启动应用时加载文件列表
2. 显示每个文件的存在状态（图标颜色区分）
3. 用户点击文件时：
   - 文件存在：更新最后访问时间
   - 文件不存在：弹出 FileNotFoundDialog
4. 用户选择操作：
   - 放弃追踪：从数据库删除记录
   - 提供路径：选择新路径并更新数据库
   - 自动扫描：扫描文件，找到则更新路径，未找到显示提示
