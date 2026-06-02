# 功能2：切换版本追踪 - 笔记

## 步骤 2.2.1 实现文件列表展示

### 实现内容
- 更新 `MainPage`，添加文件列表展示功能
- 显示文件名称、路径和最后访问时间
- 添加选中状态高亮显示
- 使用 `ConsumerStatefulWidget` 管理选中状态

### 文件列表特性
- 显示文件图标（正常/错误状态）
- 显示完整文件路径（单行省略）
- 显示最后访问时间（格式：MM-dd HH:mm）
- 选中文件高亮显示（蓝色边框和背景）
- 文件缺失时显示红色错误图标和文字

## 步骤 2.2.2 实现文件切换交互

### 实现内容
- 添加 `commitHistoryProvider` FutureProvider 获取提交历史
- 实现时间轴视图展示版本历史
- 点击文件列表项切换到对应时间轴
- 更新最后访问时间记录

### 时间轴展示
- 显示提交消息（最多2行）
- 显示提交时间（格式：yyyy-MM-dd HH:mm:ss）
- 显示提交 SHA（前7位）
- 空状态提示：选择文件查看版本历史

### 交互流程
1. 用户点击文件列表中的文件
2. 如果文件存在：
   - 更新最后访问时间到数据库
   - 更新选中状态
   - 右侧显示该文件的版本历史时间轴
3. 如果文件不存在：
   - 弹出文件找不到对话框

### 关键代码实现
- 使用 `ConsumerState` 管理 `_selectedFile` 状态
- 使用 `FutureProvider.family` 根据选中文件动态获取提交历史
- `commitHistoryProvider` 依赖于 `gitServiceProvider` 和选中的文件

### 时间轴数据结构
```dart
List<Map<String, dynamic>> commits = [
  {
    'message': 'commit message',
    'time': 1234567890,  // Unix timestamp
    'oid': 'abc1234...'   // commit SHA
  }
];
```

## 注意事项
- 避免使用 `StateProvider`，直接在 Widget 状态中管理选中状态更简单
- 时间轴数据通过 `FutureProvider.family` 获取，支持自动刷新
- 使用 `DateFormat` 格式化时间显示
