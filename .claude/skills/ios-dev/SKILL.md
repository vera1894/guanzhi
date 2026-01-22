---
name: ios-dev
description: iOS 客户端开发指南。进入 Swift 代码前的必读清单与操作要点。
---

# iOS 客户端开发技能

当用户进行 iOS 相关开发时，按以下顺序执行：

## 先读文档（必做）
1. `projectBasicInfo/00_AGENT_RULES.md` - 项目通用规则、术语约束、日志位置
2. `projectBasicInfo/01_PROJECT_OVERVIEW.md` - 客户端结构、时区与缓存注意事项
3. `projectBasicInfo/04_TERMINOLOGY.md` - 「观之/Share/share」术语字典

## 术语与命名
- UI 文案统一使用「观之」
- 代码模型与类型名保持 `Share`，API/DB 使用 `share`
- 禁止随意改动 Swift 类型名、接口路径、字段名

## 目录与入口
- 代码根目录：`guanzhi/`
- 主要子目录：`View/`（含 `UIElement/`）、`Models/`、`ModelsForNetwork/`、`ModelsForMap/`、`CameraViews/`、`CaptureFunctions/`
- 打开/构建：`open guanzhi.xcworkspace` 或 `xcodebuild -workspace guanzhi.xcworkspace -scheme guanzhi -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build`

## 时间与时区处理（高频易错）
- 后端返回数组格式通常为 UTC，解析时使用 `TimeZone(identifier: "UTC")`
- 字符串格式需查看后端 `@JsonFormat` 的 timezone（常见 `Asia/Shanghai` 或默认 UTC）
- 参考 `NotificationDateHelper`（`NotificationModels.swift`）的解析和相对时间格式化模式
- 显示层使用北京时间，注意 8 小时偏差

## 缓存与文件
- 媒体/缩略图缓存位于 `Library/Caches/`，系统可能清理；访问前先 `FileManager.fileExists`
- 涉及文件操作时，先检查存在性与可访问性，避免崩溃

## 操作规范
- 先读代码再改，保持最小改动
- UI 文案遵循术语规范；不要自行改 API/模型结构
- 重大操作或修复需在 `projectBasicInfo/logs/` 记录，文件名格式 `YYYY-MM-DD-主题-角色.md`

## 更新项目信息（当用户说"更新项目信息"时）
1. **检查并更新过时信息**：查找项目文档（`projectBasicInfo/01_PROJECT_OVERVIEW.md`、代码注释等）中与本次修改相关的描述，覆盖过时内容
2. **添加日志**：在 `projectBasicInfo/logs/` 目录下创建日志文件，记录修改内容、原因和解决方案
