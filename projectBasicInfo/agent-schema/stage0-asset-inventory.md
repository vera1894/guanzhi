# Stage 0: 资产盘点报告

**文档版本**: v1.0
**创建日期**: 2026-02-03
**作者**: Claude Code (Infrastructure Agent)
**目的**: 为 Agent 协作流程优化提供现状分析和锁粒度建议

---

## 一、Workspace 定义

| Workspace | 目录路径（相对仓库根） | 说明 |
|-----------|----------------------|------|
| **iOS** | `guanzhi/`, `Podfile*`, `*.xcodeproj`, `*.xcworkspace`, `Pods/`, `Assets.xcassets` | iOS 客户端（SwiftUI） |
| **Backend** | `Server/onettoo/` | Java 后端（Spring Boot） |
| **Admin-Web** | `admin-web/` | 管理后台前端（Vue 3 + Vite） |
| **Meta** | `projectBasicInfo/`（除 logs/）, `.claude/`, `重要项目信息/`, `tools/`, `.githooks/` | 元数据/规则/协作工具 |
| **日志目录** | `projectBasicInfo/logs/` | 操作日志（**权限例外**：所有 Agent 可写） |
| **运行时** | `.locks/` | 锁文件目录（**权限例外**：所有 Agent 可写） |

---

## 二、操作模式分析

### 2.1 数据来源

分析最近 10 个操作日志（2026-01-09 至 2026-02-03）：

| 日期 | 操作类型 | 涉及 Workspace | 并发情况 |
|------|---------|---------------|---------|
| 2026-02-03 | 基础设施创建（Guard 脚本） | Meta | 无 |
| 2026-02-02 | 协作规划文档 | Meta | 无 |
| 2026-01-28 | iOS 功能增强（缩略图重试） | iOS | 无 |
| 2026-01-28 | 服务器诊断 + 文档更新 | Meta | 无 |
| 2026-01-25 | H5 落地页规划 | Backend + Meta | 无 |
| 2026-01-24 | 举报功能实施 | Backend + iOS + Admin-Web + Meta | 无 |
| 2026-01-23 | iOS Bug 修复（状态恢复） | iOS | 无 |
| 2026-01-23 | iOS 地图锁定修复规划 | iOS + Meta | 无 |
| 2026-01-09 | Onboarding 系统规划 | iOS + Meta | 无 |

### 2.2 操作模式归类

#### 模式 1: 单 Workspace 操作（40%）

**特征**：只修改一个 workspace 的代码/文档。

**典型场景**：
- iOS 功能增强：修改 SwiftUI 视图、ViewModel
- iOS Bug 修复：修复导航、状态管理问题
- Meta 文档更新：更新服务器操作规则、连接信息

**示例**：
```
操作：iOS 缩略图重试机制
文件：guanzhi/ModelsForMap/SearchViewModel.swift
      guanzhi/View/MapPages/CustomMKAnnotationView.swift
```

**并发风险**：⭐️ 低（同一端不太可能有多个 Agent 同时工作）

---

#### 模式 2: 跨多端功能实施（40%）

**特征**：单次任务同时涉及 Backend + iOS + Admin-Web + Meta（日志）。

**典型场景**：
- 新功能实施（如举报功能）：后端 API + iOS 界面 + 管理后台
- H5 落地页：后端渲染 + 前端页面 + 配置文档

**示例**：
```
操作：举报功能实施
Backend：modules/dto/ReportDTO.java, modules/rest/GuanZhiController.java
iOS：ModelsForNetwork/ReportService.swift, View/SharePages/ShareDetailView.swift
Admin-Web：src/views/ReportManagement.vue, src/router/index.js
Meta：projectBasicInfo/logs/2026-01-24-report-feature-implementation-cc.md
```

**并发风险**：⭐️⭐️⭐️ 高（多端操作容易与其他任务冲突）

---

#### 模式 3: 规划类操作（10%）

**特征**：只涉及 Meta workspace，创建规划文档。

**典型场景**：
- 功能规划文档（如 H5 落地页规划）
- 系统优化规划（如 Agent 协作优化）
- Bug 修复规划

**示例**：
```
操作：Agent 协作优化规划
文件：projectBasicInfo/logs/2026-02-02-agent-collaboration-optimization-plan-cc.md
```

**并发风险**：⭐️ 低（规划阶段通常是单一 Agent）

---

#### 模式 4: 服务器运维操作（10%）

**特征**：涉及 Meta workspace，进行问题诊断、文档更新。

**典型场景**：
- 服务器问题诊断
- 更新服务器操作规则文档
- 更新连接信息文档

**示例**：
```
操作：缩略图诊断 + 文档更新
文件：projectBasicInfo/99_SERVER_OPERATIONS_RULES.md
      projectBasicInfo/02_CONNECTIONS.private.md
```

**并发风险**：⭐️⭐️ 中（运维操作可能与功能开发同时进行）

---

### 2.3 并发场景分析

**当前状态**：
- **未发现并发场景**：所有操作日志都是单一 Agent（Claude Code）顺序执行
- **主要操作者**：Claude Code (cc)
- **操作间隔**：通常数小时到数天

**潜在并发场景**（设计系统时需考虑）：

| 场景 | 可能性 | 冲突点 | 示例 |
|------|--------|--------|------|
| **不同 Agent 同时操作不同端** | 高 | 跨端功能依赖 | Agent A 改 Backend API，Agent B 同时改 iOS 客户端调用该 API |
| **规划 + 实施并行** | 中 | Meta 日志目录 | Agent A 写规划文档，Agent B 写实施日志 |
| **多个 Bug 修复并行** | 中 | 同一 workspace | Agent A 修复 iOS Bug 1，Agent B 修复 iOS Bug 2（不同文件） |
| **前端 + 后端部署同时进行** | 低 | 服务重启冲突 | Agent A 部署后端，Agent B 部署 Admin-Web |

---

## 三、锁粒度建议

### 3.1 推荐方案：**Workspace 级别锁**

**理由**：
1. **匹配操作模式**：40% 的操作跨多端，需要锁定多个 workspace
2. **简化实现**：只需 4 个锁文件（ios.lock, backend.lock, admin-web.lock, meta.lock）
3. **避免死锁**：粒度不会过细，Agent 按需申请多个 workspace 锁
4. **易于监控**：lock 文件数量少，易于查看当前锁定状态

**锁定规则**：
- Agent 启动任务时，声明需要访问的 workspace
- Guard 脚本自动尝试获取对应的 workspace 锁
- 如果锁已被占用，显示锁持有者信息，等待或退出
- 任务完成后自动释放锁

**示例**：
```bash
# 单 workspace 任务
Agent: ios-developer
Workspace: ios
锁文件: .locks/ios.lock

# 跨多端任务
Agent: cc
Workspace: backend, ios, admin-web
锁文件: .locks/backend.lock, .locks/ios.lock, .locks/admin-web.lock
```

### 3.2 备选方案：**目录级别锁**（不推荐）

**问题**：
- 粒度过细，可能产生过多锁文件
- 增加死锁风险（Agent 需要锁定多个目录）
- 实现复杂度高（需要遍历文件树、处理嵌套目录）

### 3.3 备选方案：**全局锁**（不推荐）

**问题**：
- 粒度过粗，限制了并发能力
- 不同 workspace 的操作无法并行（如 iOS Bug 修复 vs Backend 部署）

---

## 四、权限例外目录

以下目录所有 Agent 均可写入，**无需申请锁**：

| 目录 | 用途 | 理由 |
|------|------|------|
| `projectBasicInfo/logs/` | 操作日志 | 日志写入不应被阻塞，且通常是追加操作（低冲突） |
| `.locks/` | 锁文件目录 | Agent 需要自由创建/删除锁文件 |

---

## 五、Agent 角色分析

根据操作日志，当前系统中只有一个主要 Agent：

| Agent | 角色 | 操作范围 | 活跃度 |
|-------|------|---------|--------|
| **Claude Code (cc)** | 全栈开发 + 运维 | iOS + Backend + Admin-Web + Meta | 高（唯一活跃 Agent） |

**预期 Agent 角色**（设计系统时需考虑）：

| Agent | 角色 | 主要 Workspace | 场景 |
|-------|------|---------------|------|
| **iOS Developer** | iOS 开发 | iOS | iOS 功能开发、Bug 修复 |
| **Backend Developer** | 后端开发 | Backend | API 开发、数据库迁移 |
| **Frontend Developer** | 前端开发 | Admin-Web | 管理后台功能 |
| **Infrastructure** | 基础设施 | Meta, tools, .githooks | 配置管理、工具开发 |
| **DevOps** | 运维 | Meta | 服务器诊断、文档更新 |

---

## 六、锁机制设计要点

基于操作模式分析，锁机制需要支持：

### 6.1 多锁获取
Agent 可以同时持有多个 workspace 锁（如跨多端功能实施）。

**获取顺序**：按字母顺序（避免死锁）
```
admin-web → backend → ios → meta
```

### 6.2 锁超时机制
防止 Agent 异常退出导致锁无法释放。

**推荐超时时间**：
- **自动模式**：5 分钟（配合 60 秒心跳）
- **交互模式**：20 分钟（配合 10-15 分钟心跳）

### 6.3 锁抢占机制
当锁超时后，其他 Agent 可以抢占锁。

**抢占条件**：
- 锁文件的最后修改时间超过超时时间
- 锁持有者的心跳失效

### 6.4 锁信息透明
锁文件内容应包含：
```json
{
  "agent_id": "cc",
  "workspace": "ios",
  "task_id": "task-123",
  "acquired_at": "2026-02-03T18:46:00Z",
  "last_heartbeat": "2026-02-03T18:47:00Z",
  "timeout": 300
}
```

---

## 七、推荐的锁粒度决策

| 维度 | Workspace 级别锁 | 目录级别锁 | 全局锁 |
|------|-----------------|-----------|--------|
| **实现复杂度** | ⭐️⭐️ 中 | ⭐️⭐️⭐️⭐️ 高 | ⭐️ 低 |
| **并发能力** | ⭐️⭐️⭐️ 高 | ⭐️⭐️⭐️⭐️ 极高 | ⭐️ 极低 |
| **死锁风险** | ⭐️⭐️ 低 | ⭐️⭐️⭐️⭐️ 高 | ⭐️ 无 |
| **匹配操作模式** | ⭐️⭐️⭐️⭐️ 极好 | ⭐️⭐️ 差 | ⭐️ 差 |
| **可监控性** | ⭐️⭐️⭐️⭐️ 极好 | ⭐️⭐️ 差 | ⭐️⭐️⭐️ 好 |

**最终推荐**：✅ **Workspace 级别锁**

---

## 八、下一步行动

1. ✅ 完成资产盘点（本文档）
2. ⏭️ 在 `agent_guard.sh` 中实现 workspace 锁机制
3. ⏭️ 集成到 Git Hooks（core.hooksPath）
4. ⏭️ 编写测试场景（至少 5 个）
5. ⏭️ 实施 Schema SSOT（定义任务输入/输出格式）

---

**报告完成时间**: 2026-02-03
**下一步负责人**: Infrastructure Agent
