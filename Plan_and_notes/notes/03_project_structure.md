# 项目结构笔记

## 步骤 1.3 搭建项目目录结构和基础框架

### 目录结构
```
lib/
├── main.dart          # 应用入口，配置 Riverpod 和窗口管理
├── models/            # 数据模型
├── views/             # UI 视图
│   └── main_page.dart # 主页面（左右分栏布局）
├── viewmodels/        # 视图模型（Riverpod Provider）
├── services/          # 服务层（Git、数据库、AI等）
└── utils/             # 工具类
```

### 主页面布局
- **顶部导航栏**（48px高）：logo "简控"、帮助按钮、设置按钮
- **左侧面板**（300px宽）：文件列表 + 添加文件按钮
- **右侧面板**（剩余宽度）：时间轴视图
- **底部状态栏**（28px高）：状态指示器

### 窗口配置
- 默认大小：1200x800
- 最小大小：900x600
- 窗口标题：简控
- 使用 window_manager 管理桌面窗口

### Riverpod 配置
- 使用 ProviderScope 包裹根组件
- MyApp 使用 ConsumerWidget
- 后续各功能模块使用 Riverpod Provider 管理状态

### 构建注意事项
- macOS 构建有 linker warning（libgit2 和 libssh2 版本兼容性），不影响运行
- git2dart_binaries 不支持 Swift Package Manager，使用 CocoaPods
