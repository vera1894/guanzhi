# Claude Code 操作指南

**版本**: 1.0.0
**创建日期**: 2026-02-03
**配置文件**: `cc-behavior-config.json`

---

## 核心原则

**Claude Code (cc) 的所有操作默认使用 Agent 系统进行追踪和记录。**

```
┌─────────────────────────────────────────┐
│  用户请求                                │
└──────────────┬──────────────────────────┘
               │
               ▼
         是否说了"快速模式"？
               │
       ┌───────┴───────┐
       │               │
      是              否
       │               │
       ▼               ▼
   是否只读操作？   Agent 系统模式
       │           （默认）
   ┌───┴───┐
   │       │
  是      否
   │       │
   ▼       ▼
快速模式  Agent 系统模式
         （强制切换）
```

---

## 默认模式：Agent 系统追踪

### 适用范围

**所有操作**，包括但不限于：

- ✅ **读操作**：Read、Glob、Grep
- ✅ **写操作**：Write、Edit
- ✅ **代码修改**：任何文件修改
- ✅ **配置修改**：配置文件更新
- ✅ **部署操作**：部署脚本执行
- ✅ **Git 操作**：commit, push, rebase 等
- ✅ **Bash 命令**：任何可能改变系统状态的命令
- ✅ **数据库操作**：迁移、数据修改等

**所有 workspace**：
- backend
- ios
- admin-web
- meta
- 任何其他 workspace

### 操作流程

当你提出任何操作请求时，Claude Code 会：

#### 1️⃣ 通知使用 Agent 系统

```
我将使用 Agent 系统执行此操作。

Task ID: config-nginx-port-20260203
Workspace: backend
Task Type: configuration
```

#### 2️⃣ 创建 task-input JSON

```bash
.task-inputs/config-nginx-port-20260203-input.json
```

内容包括：
- task_id, run_id, workspace, actor, task_type
- input.description: 操作描述
- input.files: 涉及的文件（如果已知）
- input.context: 相关上下文

#### 3️⃣ 准备任务（获取锁）

```bash
tools/run_agent.sh --prepare --task-id=config-nginx-port-20260203
```

- 检查 workspace 锁
- 如果已被占用，等待或报错
- 获取锁成功后继续

#### 4️⃣ 执行实际操作

- 读取文件（Read）
- 修改文件（Edit/Write）
- 运行命令（Bash）
- 任何用户请求的操作

#### 5️⃣ 收集 Evidence

自动记录：
- **修改的文件**: 路径 + 行号范围
- **执行的命令**: 命令及其输出
- **Git commit**: commit hash（如果有）
- **相关日志**: 操作日志片段

#### 6️⃣ 完成任务（释放锁）

```bash
tools/run_agent.sh --complete --task-id=config-nginx-port-20260203
```

生成 `task-output JSON`:
```json
{
  "task_id": "config-nginx-port-20260203",
  "output": {
    "status": "completed",
    "conclusion": "成功修改 nginx 端口为 8080",
    "evidence": [
      {
        "kind": "file",
        "path": "/etc/nginx/nginx.conf",
        "line_range": {"start": 45, "end": 47}
      }
    ]
  }
}
```

#### 7️⃣ 自动生成 Markdown 日志

```bash
tools/generate_log.sh 自动执行
```

生成日志：
```
projectBasicInfo/logs/2026-02-03-config-nginx-port-20260203-cc.md
```

#### 8️⃣ 通知用户完成

```
✅ 操作完成！

📄 日志：projectBasicInfo/logs/2026-02-03-config-nginx-port-20260203-cc.md
📋 输出：.task-outputs/config-nginx-port-20260203-output.json
```

---

## 快速模式：仅只读操作

### 触发方式

用户在请求中明确说：
- "快速模式"
- "快速"
- "quick mode"
- "quick"

### 限制规则

**仅允许只读/查询操作**：

✅ **允许的操作**：
- Read（查看文件）
- Glob（查找文件）
- Grep（搜索内容）
- Bash 只读命令：
  - `ls`, `cat`, `head`, `tail`
  - `grep`, `find`
  - `git log`, `git status`, `git diff`
  - `ps`, `top`, `df`, `du`
  - 任何不修改文件系统的命令

❌ **禁止的操作**：
- Write（写文件）
- Edit（编辑文件）
- Bash 写入命令：
  - `echo >`, `sed -i`, `awk`
  - `rm`, `mv`, `cp`, `mkdir`
  - `git commit`, `git push`, `git rebase`
  - 任何会修改文件系统的命令

### 强制切换规则

**即使用户说了"快速模式"，如果操作涉及写入，自动切换到 Agent 系统模式。**

#### 示例：自动切换

```
用户："快速模式，修改 nginx 端口为 8080"

Claude Code：
⚠️  检测到写入操作，已自动切换到 Agent 系统模式（快速模式仅支持只读操作）

我将使用 Agent 系统执行此操作。

Task ID: config-nginx-port-20260203
Workspace: backend
Task Type: configuration

[继续 Agent 系统流程...]
```

### 快速模式行为

- ❌ **不生成日志**
- ❌ **不获取锁**
- ❌ **不创建 task-input/output**
- ✅ **直接执行查询**
- ✅ **快速返回结果**

#### 示例：正常快速模式

```
用户："快速模式，查看 nginx 配置文件"

Claude Code：
[直接使用 Read 工具读取文件]
[显示文件内容]
```

---

## 示例对话

### 示例 1：默认模式（配置修改）

```
用户："修改后端 API 超时时间为 60 秒"

Claude Code：
我将使用 Agent 系统执行此操作。

Task ID: config-api-timeout-20260203
Workspace: backend
Task Type: configuration

[创建 task-input JSON]
[run_agent.sh --prepare]
[读取配置文件]
[修改超时参数]
[run_agent.sh --complete]
[自动生成日志]

✅ 操作完成！

修改内容：
- 文件：backend/config/api.yaml
- 修改：timeout: 30s → timeout: 60s

📄 日志：projectBasicInfo/logs/2026-02-03-config-api-timeout-20260203-cc.md
```

### 示例 2：默认模式（代码修复）

```
用户："修复 iOS 地图交互 bug"

Claude Code：
我将使用 Agent 系统执行此操作。

Task ID: bug-fix-map-interaction-20260203
Workspace: ios
Task Type: bug-fix

[创建 task-input JSON]
[run_agent.sh --prepare]
[探索代码，定位 bug]
[修改代码]
[测试验证]
[run_agent.sh --complete]
[自动生成日志]

✅ 操作完成！

修改内容：
- 文件：ios/MapViewController.swift:156-178
- 修复：修正手势识别器冲突逻辑

Evidence:
- 修改的代码行：L156-L178
- 测试输出：手势识别正常工作

📄 日志：projectBasicInfo/logs/2026-02-03-bug-fix-map-interaction-20260203-cc.md
```

### 示例 3：快速模式（只读操作）

```
用户："快速模式，查看当前 API 超时配置"

Claude Code：
[直接读取 backend/config/api.yaml]

当前配置：
timeout: 30s
```

### 示例 4：快速模式自动切换

```
用户："快速模式，把超时改成 60 秒"

Claude Code：
⚠️  检测到写入操作，已自动切换到 Agent 系统模式（快速模式仅支持只读操作）

我将使用 Agent 系统执行此操作。

Task ID: config-api-timeout-20260203
Workspace: backend
Task Type: configuration

[继续 Agent 系统流程...]
```

### 示例 5：快速模式（查询状态）

```
用户："快速模式，看看有没有正在运行的 Agent 任务"

Claude Code：
[检查 .locks/ 目录]

当前无正在运行的 Agent 任务。
所有 workspace 锁都已释放。
```

### 示例 6：多任务自动建议 Coordinator

```
用户："修复 iOS bug 然后部署后端 v3.8.1"

Claude Code：
检测到多个任务，建议使用 Multi-Agent Coordinator 协调执行。

建议的任务拆分：
1. bug-rootcause-ios-map-20260203 (ios workspace)
   - 分析地图交互 bug 根因

2. bug-fix-ios-map-20260203 (ios workspace)
   - 修复 bug（依赖任务 1）

3. deployment-backend-v381-20260203 (backend workspace)
   - 部署后端 v3.8.1（可与任务 1-2 并行）

是否使用 coordinator 执行？
（如果是，我将创建 coordinator-config.json 并使用 coordinator.sh 管理执行流程）
```

---

## Task Type 自动推断

Claude Code 会根据用户请求自动推断 task_type：

| 用户请求关键词 | Task Type | 说明 |
|--------------|-----------|------|
| "分析 bug", "找根因" | bug-rootcause | Bug 根因分析 |
| "修复 bug", "fix bug" | bug-fix | Bug 修复 |
| "打补丁" | bug-patch | 补丁修复 |
| "计划修复方案" | patch-plan | 修复计划 |
| "部署", "deploy" | deployment | 部署操作 |
| "修改配置", "配置" | configuration | 配置修改 |
| "重构", "refactor" | refactoring | 代码重构 |
| "探索", "分析代码结构" | exploration | 代码探索 |
| "新功能", "添加功能" | feature | 功能开发 |
| "测试", "test" | testing | 测试相关 |
| "数据库", "迁移" | database | 数据库操作 |
| "写文档", "文档" | documentation | 文档编写 |
| "审查", "review" | review | 代码审查 |

---

## Workspace 自动检测

Claude Code 会根据操作涉及的文件路径自动检测 workspace：

| 文件路径关键词 | Workspace |
|--------------|-----------|
| `backend/`, `server/`, `api/` | backend |
| `ios/`, `swift/`, `xcode/` | ios |
| `admin-web/`, `admin/`, `vue/` | admin-web |
| `projectBasicInfo/`, `tools/`, `docs/`, `.md` | meta |

如果无法推断，默认使用 `meta` workspace。

---

## Evidence 自动收集

Agent 系统模式下，Claude Code 会自动收集 evidence：

### Evidence 类型

1. **file**（文件修改）
   ```json
   {
     "kind": "file",
     "path": "backend/config/api.yaml",
     "line_range": {"start": 45, "end": 47},
     "description": "修改 API 超时配置"
   }
   ```

2. **commit**（Git 提交）
   ```json
   {
     "kind": "commit",
     "commit_hash": "a1b2c3d",
     "message": "config: update API timeout to 60s"
   }
   ```

3. **command_output**（命令输出）
   ```json
   {
     "kind": "command_output",
     "command": "npm test",
     "snippet": "All tests passed (15/15)"
   }
   ```

4. **log**（日志片段）
   ```json
   {
     "kind": "log",
     "source": "application.log",
     "snippet": "API timeout extended to 60s"
   }
   ```

---

## 日志结构

自动生成的 Markdown 日志包含：

```markdown
# [Task Type]: [Task ID]

**执行日期**: 2026-02-03
**执行者**: cc (Claude Code)
**Workspace**: backend
**任务类型**: configuration

## 任务描述

修改后端 API 超时时间为 60 秒

## 执行结果

**状态**: completed
**结论**: 成功修改 API 超时配置

## Evidence

### 1. 文件修改

- **路径**: `backend/config/api.yaml`
- **行号**: L45-L47
- **描述**: 修改 API 超时配置

## 执行信息

- **Task ID**: config-api-timeout-20260203
- **Run ID**: run-20260203-001
- **开始时间**: 2026-02-03T10:30:00Z
- **完成时间**: 2026-02-03T10:32:15Z
- **输出文件**: .task-outputs/config-api-timeout-20260203-output.json
- **Schema 版本**: 1.0.0
```

---

## 什么时候不使用 Agent 系统？

**几乎没有例外。**

唯一例外是用户明确说"快速模式"且操作为只读/查询：

- ✅ 快速查看文件内容
- ✅ 快速查找文件
- ✅ 快速搜索关键词
- ✅ 快速查看 git 状态/日志/diff
- ✅ 快速查看系统状态

**所有写入操作都必须走 Agent 系统。**

---

## 总结

### 默认行为

```
任何操作请求 → Agent 系统模式 → 完整追踪和日志
```

### 快速模式例外

```
"快速模式" + 只读操作 → 快速模式 → 无日志
"快速模式" + 写入操作 → 自动切换到 Agent 系统模式
```

### 核心价值

- ✅ **完整追溯**：所有修改都有记录
- ✅ **防止冲突**：workspace 锁机制
- ✅ **审计合规**：满足生产环境要求
- ✅ **团队协作**：human 和 cc 的操作都可见
- ✅ **错误恢复**：有完整 evidence 方便回滚

---

**配置文件**: `projectBasicInfo/cc-behavior-config.json`
**最后更新**: 2026-02-03
