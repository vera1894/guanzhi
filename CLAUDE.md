# CLAUDE.md — 观之（guanzhi）

> 通用规则见 `~/.claude/CLAUDE.md`（语言、代码原则、工作模式、记忆回流）
> 本文件只含项目特有信息。

---

## 文档索引（按需查阅，不要全部阅读）

MEMORY.md 和 `.claude/rules/` 已自动加载，包含关键经验和查找策略。
根据任务类型查阅对应文档即可：

| 文档 | 何时需要 |
|------|---------|
| `projectBasicInfo/00_AGENT_RULES.md` | 不确定操作规范时 |
| `projectBasicInfo/01_PROJECT_OVERVIEW.md` | 不了解项目结构时 |
| `projectBasicInfo/02_CONNECTIONS.private.md` | 需要服务器连接信息时 |
| `projectBasicInfo/03_CREDENTIALS.private.md` | 需要凭证信息时 |
| `projectBasicInfo/04_TERMINOLOGY.md` | 涉及 UI 文案时 |
| `projectBasicInfo/05_DEPLOYMENT_SSOT.md` | 后端部署时 |
| `projectBasicInfo/99_SERVER_OPERATIONS_RULES.md` | 服务器操作时 |
| `projectBasicInfo/logs/` | 需要了解历史操作时 |

---

## Terminology / 术语规范

**详细规范请参阅** `projectBasicInfo/04_TERMINOLOGY.md`

- **UI 文案**：用户可见层统一使用「观之」（如"发布观之"、"暂无观之"）
- **代码层**：类型名/变量名保持 `Share`（如 `ShareService`、`shareId`）
- **禁止改动**：Swift 类型名、API 路径、数据库结构

## Project Overview
This is a SwiftUI iOS application called "guanzhi" (观之) - a social mapping application with camera functionality. Users can publish location-based content called "观之" (internally modeled as `Share`), view them on a map, and interact with others.

## Architecture & 代码快速定位

> 遇到 iOS 任务时直接用 Grep/Glob 搜索，不需要 Explore 整个项目。

| 要找什么 | 搜索方式 |
|---------|---------|
| 某个功能的代码 | `Grep pattern="关键词" type="swift"` |
| 某个 View | `Glob pattern="guanzhi/View/**/*.swift"` |
| 网络模型/API 定义 | `Glob pattern="guanzhi/ModelsForNetwork/**/*.swift"` |
| 地图相关模型 | `Glob pattern="guanzhi/ModelsForMap/**/*.swift"` |
| 全局状态 | 读 `guanzhi/AppStateModel.swift` |
| 相机功能 | `Glob pattern="guanzhi/CameraViews/**/*.swift"` 或 `guanzhi/CaptureFunctions/` |
| Core Data 模型 | `Glob pattern="guanzhi/Data/**/*.swift"` |
| 后端 Java 代码 | `Grep pattern="关键词" path="Server/onettoo/src" type="java"` |

**iOS 目录结构**：
- `guanzhi/View/FrontPage/` — 主页、地图、搜索
- `guanzhi/View/LoginViews/` — 登录注册
- `guanzhi/View/MyPages/` — 个人页、设置
- `guanzhi/View/UIElement/` — 可复用组件
- `guanzhi/CameraViews/` + `guanzhi/CaptureFunctions/` — 相机
- `guanzhi/Data/` — Core Data 模型、用户数据

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

---

## 任务专用文档索引

根据任务类型，阅读对应的专用文档：

| 任务类型 | 必读文档 |
|----------|----------|
| **后端开发**（写 Java 代码） | `Server/onettoo/重要项目信息/项目结构说明.md` |
| **后端部署**（部署 JAR 到服务器） | `projectBasicInfo/05_DEPLOYMENT_SSOT.md`（部署 SSOT）<br>`projectBasicInfo/02_CONNECTIONS.private.md`（连接信息） |
| **服务器操作**（Nginx/MySQL/排查） | `projectBasicInfo/99_SERVER_OPERATIONS_RULES.md` |
| **iOS 开发**（写 Swift 代码） | 本文件（CLAUDE.md） |

> **重要**：后端部署必须遵循 `05_DEPLOYMENT_SSOT.md` 中的流程，使用 systemd 管理服务，禁止使用旧的 `start.sh` 或 `pkill` 方式。

> 记忆回流规则已移至 `.claude/rules/memory-reflux.md`（自动加载）。