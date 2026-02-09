# 记忆回流规则

> 本文件自动加载。完成一个问题系列后，Agent 必须执行以下检查。

## 何时回流

- 修复了一个 bug（记录根因 + 正确做法）
- 做了架构决策（记录选择 + 理由）
- 发现了非直觉行为（文档没写但实际会遇到的）
- 完成了一次部署（记录过程中的意外和解决方案）

## 写到哪里

本项目的 memory 主题文件：
- iOS 相关 → `memory/ios-dev.md`
- 后端/部署 → `memory/backend-deploy.md`
- 通知系统 → `memory/notification.md`
- 架构决策 → `memory/architecture.md`
- 关键经验 → 同时更新 `memory/MEMORY.md` 的「关键经验速查」

操作日志 → `projectBasicInfo/logs/`

## 怎么写

- **替换过时信息**，不要无限追加
- 一条经验一句话 + 必要上下文
- 不重复已在 `projectBasicInfo/` 中详细记录的操作流程

## memory 文件位置

`~/.claude/projects/` 下的 `memory/` 目录。MEMORY.md 前 200 行每次会话自动加载。
