# CLAUDE.md

此文件为Claude Code (claude.ai/code)在此代码库中工作时提供指导。

## 项目概述
这是一个名为"guanzhi"的SwiftUI iOS应用程序，似乎是一个具有相机功能的社交地图应用。该应用允许用户拍摄照片/视频，在地图上查看它们，并与他人分享内容。

## 架构
- **主应用入口**: `guanzhiApp.swift` - 包含带有导航堆栈的主应用结构
- **核心模型**:
  - `AppStateModel.swift` - 全局应用状态管理
  - `CameraModel.swift` - 相机功能状态
  - `LocationManager.swift` - 位置服务
  - `ModelsForNetwork/`中的网络模型用于API通信
  - `ModelsForMap/`中的地图模型用于地图相关功能
- **视图**: 组织在`View/`目录中，子目录用于不同部分:
  - `FrontPage/` - 主地图和搜索视图
  - `LoginViews/` - 认证界面
  - `MyPages/` - 用户个人资料和设置
  - `UIElement/` - 可重用的UI组件
- **相机功能**: 位于`CameraViews/`和`CaptureFunctions/`目录中
- **数据**: `Data/`中的Core Data模型和用户个人资料管理

## 开发环境
- iOS部署目标: 17.0
- 使用SwiftUI的Swift项目
- 使用CocoaPods进行依赖管理
- 主要依赖: Alamofire用于网络通信

## 常见开发任务

### 构建项目
```bash
# 在Xcode中打开工作区
open guanzhi.xcworkspace

# 或从命令行构建
xcodebuild -workspace guanzhi.xcworkspace -scheme guanzhi -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

### 依赖管理
```bash
# 安装/更新pods
pod install

# 更新pods
pod update
```

### 项目结构要点
- 使用Core Data进行本地数据持久化
- 遵循MVVM模式与ObservableObjects
- 使用Environment和EnvironmentObject进行状态管理
- 通过自定义NavigationCoordinator处理导航
- 位置服务与地图视图集成
- 使用AVFoundation实现相机功能