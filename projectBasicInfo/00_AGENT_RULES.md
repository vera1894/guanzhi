# AI Agent 使用规则

**文档版本**: v1.6
**最后更新**: 2026-01-22

---

## 文档查阅方式

**不要在每次会话开始时阅读全部文档。** 按任务需要查阅对应文档即可。

MEMORY.md（自动注入）和 `.claude/rules/`（自动加载）已包含关键经验和信息查找策略。
根目录 `CLAUDE.md` 包含任务索引表和文档索引表。

### 本目录文档说明

| 文档 | 何时需要阅读 |
|------|-------------|
| `00_AGENT_RULES.md`（本文件） | 不确定操作规范时 |
| `01_PROJECT_OVERVIEW.md` | 不了解项目结构时 |
| `02_CONNECTIONS.private.md` | 需要服务器连接信息时 |
| `03_CREDENTIALS.private.md` | 需要凭证信息时 |
| `04_TERMINOLOGY.md` | 涉及 UI 文案时 |
| `05_DEPLOYMENT_SSOT.md` | 后端部署时 |
| `99_SERVER_OPERATIONS_RULES.md` | 服务器操作时 |
| `logs/` | 需要了解历史操作时 |

### Claude Skills

- `.claude/skills/*/SKILL.md` — 当任务命中某个 Skill 描述时，阅读对应 SKILL.md 并按其流程执行

---

## 语言规则

1. **所有 Agent 对话回复必须使用简体中文**
2. 代码注释可以根据上下文使用中文或英文
3. 技术术语可以使用英文，但需要提供中文解释
4. 文件名和目录名保持原有的命名方式

---

## 术语规范

**详细规范请参阅** `04_TERMINOLOGY.md`（术语字典 SSOT）

### 核心术语：「观之」

| 层面 | 使用术语 | 示例 |
|------|----------|------|
| **UI 文案**（用户可见） | 观之 | "发布观之"、"暂无观之"、"删除这条观之" |
| **代码类型/变量名** | Share | `struct Share`、`shareId`、`ShareService` |
| **API/数据库** | share | `/shares/`、`share` 表 |

### 动词 vs 名词

| 类型 | 使用术语 | 示例 |
|------|----------|------|
| **名词**（用户发的内容） | 观之 | "发一条观之" |
| **动词**（系统分享动作） | 分享/转发 | "分享到微信" |

### 禁止改动

- Swift 类型/文件/变量名（`Share`、`ShareService`、`shareId`...）
- API 路径、JSON key、数据库表/字段

---

## 操作规范

### 1. 执行命令而非让用户手动操作

- 能直接执行的命令，直接执行（如 `npm run build`、`git push`）
- 不要输出命令让用户复制粘贴
- 如果命令需要特殊权限或可能有风险，先说明再执行

### 2. 信息来源优先级

1. **优先从现有文件中检索**（本目录、`重要项目信息/`、代码文件）
2. 不够再问用户
3. **禁止凭记忆猜测**，尤其是密码、密钥、IP等敏感信息

### 3. 变更记录

- 重大操作完成后，在 `logs/` 目录创建操作日志
- 日志命名格式：`YYYY-MM-DD-英文主题-角色.md`
  - 示例：`2025-12-08-admin-web-deploy-cc.md`
  - 角色：`cc` (Claude Code), `gpt`, `gemini`, `human` 等
- 记录：做了什么、为什么做、结果如何

### 4. 代码修改原则

- **先读后改**：修改文件前必须先读取文件内容
- **最小改动**：只改需要改的地方，不做不必要的"优化"
- **不加多余功能**：用户没要求的功能不要加
- **不删有用代码**：除非明确要求，否则不要删除现有功能

### 5. 前后端时间处理规范

**重要**：服务器时区为 UTC，iOS 客户端显示北京时间。时区处理不当会导致 8 小时偏差！

#### 5.1 后端规范（Java）

在 VO/DTO 中的 `LocalDateTime` 字段必须添加 `@JsonFormat` 注解：

```java
import com.fasterxml.jackson.annotation.JsonFormat;

@JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss", timezone = "Asia/Shanghai")
private LocalDateTime createdAt;
```

**后端检查清单**：
- [ ] 导入 `com.fasterxml.jackson.annotation.JsonFormat`
- [ ] 在所有 `LocalDateTime` 字段上添加 `@JsonFormat` 注解
- [ ] 设置 `timezone = "Asia/Shanghai"`
- [ ] 设置统一的日期格式 `pattern = "yyyy-MM-dd'T'HH:mm:ss"`

#### 5.2 iOS 前端规范（Swift）

**推荐做法**：在各模块中创建私有的时间处理 helper，参考 `NotificationModels.swift` 中的 `NotificationDateHelper`。

```swift
// 后端返回格式判断：
// - 数组格式 [year, month, day, hour, minute, second] → 通常是 UTC 时间
// - 字符串格式 "yyyy-MM-dd'T'HH:mm:ss" → 看后端是否有 @JsonFormat 注解

// 解析 UTC 时间数组
private static func parseLocalDateTimeArray(_ arr: [Int], timezone: String) -> Date {
    guard arr.count >= 5 else { return Date() }
    var components = DateComponents()
    components.year = arr[0]
    components.month = arr[1]
    components.day = arr[2]
    components.hour = arr[3]
    components.minute = arr[4]
    components.second = arr.count > 5 ? arr[5] : 0
    components.timeZone = TimeZone(identifier: timezone)  // "UTC" 或 "Asia/Shanghai"
    return Calendar.current.date(from: components) ?? Date()
}

// 格式化相对时间显示（参考 NotificationDateHelper.formatRelativeTime）
```

**iOS 检查清单**：
- [ ] 明确后端返回的是 UTC 还是北京时间
- [ ] 数组格式通常是 UTC（后端默认行为），使用 `TimeZone(identifier: "UTC")`
- [ ] 字符串格式看后端 `@JsonFormat` 注解的 timezone 设置
- [ ] 参考 `NotificationModels.swift` 中的实现模式

#### 5.3 时区对照表

| 后端配置 | 返回格式 | iOS 解析 timezone |
|---------|---------|------------------|
| 无 @JsonFormat | `[2026,1,1,8,0,0]` 数组 | `.utc` |
| @JsonFormat timezone="Asia/Shanghai" | `"2026-01-01T16:00:00"` 字符串 | `.shanghai` |
| @JsonFormat 无 timezone | `"2026-01-01T08:00:00"` 字符串 | `.utc` |

**历史问题**：2026-01-01 发现 `NotificationVO.java` 缺少时区配置，导致 iOS 端显示时间早 8 小时。

---

## 敏感信息处理

### 禁止外泄的信息类型

- 服务器 IP、SSH 密钥路径
- 数据库密码、JWT 密钥
- AWS 凭证、API Token
- 用户手机号、验证码

### 存储位置

- 所有敏感信息存放在 `.private.md` 后缀的文件中
- 这些文件已在 `.gitignore` 中排除，不会被提交到 Git

---

## 项目目录说明

```
guanzhi/                          # 项目根目录（Monorepo）
├── projectBasicInfo/             # 【本目录】项目基础信息
│   ├── 00_AGENT_RULES.md        # Agent 使用规则
│   ├── 01_PROJECT_OVERVIEW.md   # 项目概述
│   ├── 02_CONNECTIONS.private.md # 连接信息（敏感）
│   ├── 03_CREDENTIALS.private.md # 凭证信息（敏感）
│   ├── 04_TERMINOLOGY.md        # 术语规范
│   ├── 05_DEPLOYMENT_SSOT.md    # 部署操作 SSOT（SSM/S3 最佳实践）
│   ├── 99_SERVER_OPERATIONS_RULES.md # 服务器操作通用规则
│   └── logs/                     # 操作日志
│
├── guanzhi/                      # iOS 客户端（SwiftUI）
├── Server/onettoo/               # Java 后端（Spring Boot）
├── admin-web/                    # 管理后台前端（Vue 3）
├── 重要项目信息/                  # 开发文档
└── 后端升级设计文档/              # 设计文档
```

---

## 常见任务快速参考

| 任务 | 关键信息来源 |
|------|-------------|
| **后端部署** | **`05_DEPLOYMENT_SSOT.md`**（SSM/S3 命令模板、验收清单） |
| 服务器操作 | `99_SERVER_OPERATIONS_RULES.md`、`02_CONNECTIONS.private.md` |
| 部署 admin-web | `02_CONNECTIONS.private.md`、`logs/` 下的部署日志 |
| 后端开发 | `Server/onettoo/`、`重要项目信息/项目结构说明.md` |
| iOS 开发 | `guanzhi/`、根目录 `CLAUDE.md` |
| 查看历史操作 | `logs/` 目录 |
| **时间处理** | **本文件第5节**、`guanzhi/ModelsForNetwork/NotificationModels.swift` 中的 `NotificationDateHelper` |

---

## 联系方式

- 项目负责人：Zaptain
- 如有疑问，直接在对话中询问用户
