# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## 必读：首先阅读项目信息目录

**新 Agent 在开始工作前，必须先阅读 `projectBasicInfo/` 目录下的文档：**

```
projectBasicInfo/
├── 00_AGENT_RULES.md         # Agent 使用规则（必读）
├── 01_PROJECT_OVERVIEW.md    # 项目概述（必读）
├── 02_CONNECTIONS.private.md # 服务器连接信息（部署时需要）
├── 03_CREDENTIALS.private.md # 凭证信息（认证时需要）
├── 04_TERMINOLOGY.md         # 术语规范（UI 使用「观之」）
└── logs/                     # 历史操作日志（了解之前做过什么）
```

这些文档包含完整的项目结构、技术栈、部署信息和操作规范。

---

## Language Rule
- All responses from Claude Code should be in Chinese (Simplified) as specified in .rules/agent_rules.md
- Code comments may be in Chinese or English depending on context
- Technical terms may be in English but should include Chinese explanations when possible

## Terminology / 术语规范

**详细规范请参阅** `projectBasicInfo/04_TERMINOLOGY.md`

- **UI 文案**：用户可见层统一使用「观之」（如"发布观之"、"暂无观之"）
- **代码层**：类型名/变量名保持 `Share`（如 `ShareService`、`shareId`）
- **禁止改动**：Swift 类型名、API 路径、数据库结构

## Project Overview
This is a SwiftUI iOS application called "guanzhi" (观之) - a social mapping application with camera functionality. Users can publish location-based content called "观之" (internally modeled as `Share`), view them on a map, and interact with others.

## Architecture
- **Main App Entry**: `guanzhiApp.swift` - Contains the main app structure with navigation stack
- **Core Models**:
  - `AppStateModel.swift` - Global app state management
  - `CameraModel.swift` - Camera functionality state
  - `LocationManager.swift` - Location services
  - Network models in `ModelsForNetwork/` for API communication
  - Map models in `ModelsForMap/` for map-related functionality
- **Views**: Organized in the `View/` directory with subdirectories for different sections:
  - `FrontPage/` - Main map and search views
  - `LoginViews/` - Authentication screens
  - `MyPages/` - User profile and settings
  - `UIElement/` - Reusable UI components
- **Camera Functionality**: Located in `CameraViews/` and `CaptureFunctions/` directories
- **Data**: Core Data models and user profile management in `Data/`

## Development Environment
- iOS deployment target: 17.0
- Swift project using SwiftUI
- Uses CocoaPods for dependency management
- Primary dependency: Alamofire for networking

## Common Development Tasks

### Building the Project
```bash
# Open the workspace in Xcode
open guanzhi.xcworkspace

# Or build from command line
xcodebuild -workspace guanzhi.xcworkspace -scheme guanzhi -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

### Dependency Management
```bash
# Install/update pods
pod install

# Update pods
pod update
```

### Project Structure Key Points
- Uses Core Data for local data persistence
- Follows MVVM pattern with ObservableObjects
- Uses Environment and EnvironmentObject for state management
- Navigation is handled through a custom NavigationCoordinator
- Location services integrated with map views
- Camera functionality implemented with AVFoundation