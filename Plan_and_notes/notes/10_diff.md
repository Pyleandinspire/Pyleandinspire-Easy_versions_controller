# 文件对比功能开发笔记

## 概述

实现了文件版本对比功能，支持两个版本之间的差异展示，包括并排对比和上下对比两种模式。

## 核心组件

### 1. DiffService (`lib/services/diff_service.dart`)

**设计思路：**
- 使用 LCS（最长公共子序列）算法计算两个版本文件的差异
- 通过 git2dart 获取指定 commit 中的文件内容
- 将文件内容逐行对比，标记新增、删除、相同的行

**关键实现：**

```dart
// 获取文件在指定 commit 中的内容
Future<List<String>> _getFileContent(Repository repo, String commitOid, String fileName)

// 使用 LCS 算法计算差异
List<DiffLine> _computeDiff(List<String> oldLines, List<String> newLines)

// 计算最长公共子序列
List<String> _computeLCS(List<String> a, List<String> b)
```

**git2dart API 使用要点：**
- `Commit.lookup()` - 查找指定 commit
- `commit.parent(0)` - 获取第一个父 commit
- `parent.oid.sha` - 获取 commit 的 SHA 值
- `tree.entries` - 获取 tree 中的所有条目
- `Blob.lookup()` - 查找 blob 对象获取文件内容

### 2. CompareView (`lib/views/compare_view.dart`)

**功能特性：**
- 支持并排对比模式（左右双栏）
- 支持上下对比模式（单栏显示）
- 版本选择下拉菜单，可选择任意两个历史版本
- 差异导航（上一个/下一个差异）
- 同步滚动（并排模式下左右栏同步滚动）

**布局结构：**
- 顶部：版本选择区域（基准版本 VS 对比版本）
- 中部：差异内容展示区域
- 底部：导航工具栏

**差异高亮规则：**
- 新增行：绿色背景 (#dcfce7)
- 删除行：红色背景 (#fee2e2)
- 修改行：黄色背景 (#fef9c3)
- 相同行：无背景色

## 技术难点与解决方案

### 1. git2dart API 兼容性问题

**问题：** git2dart 0.4.0 版本的 API 与文档不一致，部分方法不存在。

**解决方案：**
- 不使用 `diff.patch()` 和 `diff.hunks()` 方法
- 改用手动获取两个版本的文件内容，使用 LCS 算法计算差异
- 使用 `commit.parent(0)` 获取父 commit，通过 `parent.oid.sha` 获取 SHA

### 2. 同步滚动实现

**问题：** 并排对比模式下需要实现左右栏同步滚动。

**解决方案：**
- 使用两个 ScrollController
- 在滚动监听器中同步两个控制器的滚动位置
- 通过标志位区分主动滚动和被动滚动，避免循环触发

```dart
void _syncScroll() {
  final left = _leftScrollController;
  final right = _rightScrollController;
  
  if (_isLeftScrolling) {
    if (right.position.pixels != left.position.pixels) {
      right.jumpTo(left.position.pixels);
    }
  } else {
    if (left.position.pixels != right.position.pixels) {
      left.jumpTo(right.position.pixels);
    }
  }
}
```

### 3. 初始 commit 处理

**问题：** 第一个 commit 没有父 commit，无法进行对比。

**解决方案：**
- 在获取父 commit 失败时，使用空列表作为对比基准
- 所有行都标记为新增状态（绿色）

## 状态管理

使用 Riverpod FutureProvider.family 提供差异数据：

```dart
final diffProvider = FutureProvider.family<List<DiffLine>, ({TrackedFile file, String? fromOid, String? toOid})>(
  (ref, args) async {
    // 根据 fromOid 是否为空决定调用哪个方法
    if (args.fromOid == null) {
      return await diffService.getDiffFromCommit(...);
    }
    return await diffService.getDiffBetweenVersions(...);
  },
);
```

## 主题颜色扩展

在 `AppColors` 中添加了差异对比所需的颜色：

```dart
static const Color diffAdded = Color(0xFFDCFCE7);   // 新增行背景
static const Color diffRemoved = Color(0xFFFEE2E2); // 删除行背景
static const Color diffModified = Color(0xFFFEF9C3); // 修改行背景
static const Color diffContext = Color(0xFFF1F5F9);  // 上下文行背景
static const Color background = Color(0xFFFFFFFF);   // 背景色
```

## 测试要点

1. **差异计算正确性**：确保新增、删除、修改的行正确标记
2. **版本选择功能**：验证可以选择任意两个版本进行对比
3. **视图切换**：验证并排对比和上下对比模式切换正常
4. **差异导航**：验证上一个/下一个差异按钮正常工作
5. **同步滚动**：验证并排模式下左右栏同步滚动
6. **错误处理**：测试文件不存在、仓库损坏等异常情况

## 待优化项

1. 差异导航时滚动到对应位置
2. 添加修改行的高亮（当前只有新增和删除）
3. 优化大文件的对比性能
4. 添加语法高亮支持