# Agent 协作流程优化规划

**文档类型**: 规划文档
**创建日期**: 2026-02-02
**创建者**: Claude Code
**版本**: v2.0（统一路径基准规范、明确权限要求）
**状态**: 待执行
**修订日期**: 2026-02-02（v2.0 - Schema 路径统一为仓库根相对路径、权限要求明确化）

---

## v2.0 修订说明

**核心问题**: v1.9 的路径基准与示例路径混用，导致 schema 的 path 字段在不同工作目录下不一致，影响可审计性。同时执行权限表述可能被误解为"写非 Meta workspace 不需要权限"。

**v2.0 修订目标**: 统一 schema/evidence 路径为仓库根相对路径，明确"工作目录 vs 路径记录"的区别，完善执行权限表述，确保规则清晰可审计。

**主要修订**（按严重度）:
1. **中：统一 Schema 路径规范**（Evidence 示例路径从 `guanzhi/guanzhi/View/...` 改为 `guanzhi/View/...`，明确 schema 一律使用仓库根相对路径，执行时可能需要加前缀但记录仍用仓库根相对路径）
2. **中：工作目录使用说明更新**（增加"Schema 路径规范"条款，明确记录路径与执行路径的区别，推荐切换到仓库根执行）
3. **低：执行权限表述明确化**（增加"写入非 Meta workspace 不等于'不需要权限'"说明，明确仍需遵守 workspace 权限规则）

**关键原则**:
- **Schema 路径一律使用仓库根相对路径**（如 `guanzhi/View/...`），不随工作目录变化
- **执行命令时可能需要加前缀**（如工作目录在上层），但记录路径仍为仓库根相对路径
- **推荐做法**：先切换到仓库根（`cd guanzhi`），避免路径转换

**质量保证**:
- Schema path 字段在不同工作目录下保持一致（可审计性保证）
- 执行权限表述无歧义（明确非 Meta workspace 仍需权限）
- 路径使用规范清晰（记录 vs 执行区分明确）

---

## v1.9 修订说明

**核心问题**: v1.8 的 evidence 示例路径（`guanzhi/View/SearchView.swift`）在实际使用中无法正确定位文件，因为实际工作目录是 `.../Seee/`（而非仓库根 `.../Seee/guanzhi/`），导致 guard/evidence 规则定位出错。执行权限总则表述过于绝对，未考虑阶段 5 可能需要在其他位置创建测试脚本。

**v1.9 修订目标**: 基于实际工作目录修正 evidence 路径，增加工作目录使用说明，完善执行权限表述的灵活性。

**主要修订**（按严重度）:
1. **中：Evidence 示例路径修正**（`guanzhi/View/SearchView.swift` → `guanzhi/guanzhi/View/FrontPages/SearchView.swift`，从实际工作目录可达，并增加路径说明）
2. **中：增加工作目录使用说明**（在路径基准定义后增加"实际使用注意"，说明工作目录与路径基准不一致时的处理方法）
3. **低：执行权限表述灵活化**（"所有阶段交付物位于 Meta" → "大部分阶段...，阶段 5 可能需要在其他 workspace 输出，需显式声明并申请权限"）

**关键变更**:
- **Evidence 路径使用实际工作目录**：从 `.../Seee/` 开始，包含仓库目录前缀（第一个 `guanzhi`）
- **增加路径使用注意事项**：明确工作目录与路径基准不一致时的处理方法，推荐切换到仓库根或使用完整路径
- **Guard 示例路径增加双版本**：从仓库根开始的路径 + 从上层目录开始的路径

**质量保证**:
- Evidence 路径在实际工作目录下可正确定位文件
- 路径使用说明清晰，避免"工作目录 vs 路径基准"困惑
- 执行权限表述灵活，覆盖特殊情况（如阶段 5 测试脚本）

---

## v1.8 修订说明

**核心问题**: v1.7 虽然解决了日志目录权限矛盾，但只在 Phase 1 声明执行权限要求，阶段 0/1/2/4 的交付物同样位于 Meta workspace，存在执行冲突。Infrastructure Agent 示例任务"创建日志"已不准确（日志已是权限特例），锁粒度描述未覆盖新增的 Meta workspace 目录。

**v1.8 修订目标**: 在执行阶段规划总则中明确通用权限要求，修正示例任务，完善锁粒度描述，确保各阶段执行规则统一。

**主要修订**（按严重度）:
1. **中高：各阶段通用权限要求明确**（在"二、执行阶段规划"开头增加通用说明，明确所有阶段交付物位于 Meta workspace，需 Infrastructure Agent 或临时特权，避免阶段 0/1/2/4 执行时权限冲突）
2. **低：Infrastructure Agent 示例任务修正**（"创建日志" → "创建 guard 脚本、配置 Git hooks"，日志已是权限特例无需特权）
3. **低：锁粒度描述完善**（"基础设施锁（projectBasicInfo/、.claude/）" → "Meta workspace 锁（projectBasicInfo/、.claude/、重要项目信息/、tools/、.githooks/）"，覆盖所有 Meta 目录）

**质量保证**:
- 各阶段执行权限要求统一（所有写 Meta workspace 的阶段都需特权）
- 示例任务准确（Infrastructure Agent 示例符合权限规则）
- 锁粒度描述完整（覆盖所有 Meta workspace 目录）

---

## v1.7 修订说明

**核心问题**: v1.6 存在 Meta workspace 权限矛盾（要求所有 Agent 写日志，但 Meta workspace 仅特权可写），Phase 1 创建目录权限不明确，Shell 命令注释语法错误。

**v1.7 修订目标**: 解决权限矛盾，明确 Phase 1 执行者要求，修正语法错误，确保规则自洽且可执行。

**主要修订**（按严重度）:
1. **高：日志目录权限特例**（将 `projectBasicInfo/logs/` 从 Meta workspace 分离，作为权限特例目录，所有 Agent 可写，解决"必须写日志"与"Meta 仅特权可写"的矛盾）
2. **中：Phase 1 执行者要求明确**（在"立即行动"清单前增加说明：涉及 Meta workspace 操作必须由 Infrastructure Agent 执行或授予临时特权）
3. **低：Shell 命令注释语法修正**（将行尾注释 `\  # 注释` 移到上一行，避免 shell 断行失败）

**关键变更**:
- **Workspace 定义调整**:
  - Meta workspace: `projectBasicInfo/`（除 `logs/`）、`.claude/`、`重要项目信息/`、`tools/`、`.githooks/`
  - 新增"权限特例"类别: `projectBasicInfo/logs/`、`.locks/`（所有 Agent 可写）
- **写权限矩阵增加"权限特例目录"列**（所有 Agent 包括普通 Agent 都可写）
- **Phase 1 立即行动增加执行者要求**（需 Infrastructure Agent 或临时特权）

**质量保证**:
- 所有 Agent 可正常写日志（权限特例）
- Phase 1 不会因权限不足而失败（明确执行者要求）
- Shell 命令可正常执行（注释语法正确）

---

## v1.6 修订说明

**核心问题**: v1.5 虽然统一了路径基准描述，但交付物路径仍有 `guanzhi/` 前缀，且 iOS workspace 范围过窄（漏掉根目录工程文件），tools/、.githooks/ 等目录未归入 workspace 定义。

**v1.6 修订目标**: 修正所有路径基准不一致问题，扩展 iOS workspace 覆盖范围，完善 Meta workspace 定义，确保 guard 不会误拦截合法操作。

**主要修订**（按严重度）:
1. **高：交付物路径基准统一**（8 处 `guanzhi/projectBasicInfo/...` → `projectBasicInfo/...`，全文统一为仓库根基准）
2. **高：iOS workspace 范围扩展**（新增 `Podfile*`、`*.xcodeproj`、`*.xcworkspace`、`Pods/`、`Assets.xcassets`，避免 guard 误拦截 iOS 工程文件修改）
3. **中：Meta workspace 定义完善**（新增 `tools/`、`.githooks/` 目录，避免 Phase 1 创建目录时被视为越权）
4. **中：agent-schema/ 目录位置统一**（"立即行动" 从 `agent-schema/` 改为 `projectBasicInfo/agent-schema/`，归入 Meta workspace）

**质量保证**:
- 所有路径基准统一为仓库根（无 `guanzhi/` 前缀）
- iOS workspace 覆盖所有工程文件（Podfile、Xcode 项目、CocoaPods 依赖）
- Meta workspace 包含所有协作工具目录
- guard 脚本不会误拦截合法操作

---

## v1.5 修订说明

**核心问题**: v1.4 虽然修正了高优先级工程问题，但仍存在路径基准不一致、锁初始化命令错误、Git Hooks 强制力表述偏强等问题，影响实际执行时的准确性。

**v1.5 修订目标**: 修正所有路径基准、命令、表述不一致问题，确保文档自洽且可精确执行。

**主要修订**（按严重度）:
1. **高：Workspace 路径基准统一**（`guanzhi/guanzhi/` → `guanzhi/`，`guanzhi/Server/onettoo/` → `Server/onettoo/`，全文统一为"仓库根目录基准"）
2. **高：锁目录初始化命令修正**（3 处 `mkdir -p .claude/locks` → `mkdir -p .locks`）
3. **中：Guard 示例路径统一**（`guanzhi/guanzhi/View/...` → `guanzhi/View/...`）
4. **低：锁清理日志命名规范化**（`.log` → `YYYY-MM-DD-lock-cleanup-cc.md`）
5. **低：Git Hooks 强制力表述现实化**（"100%" → "可被 --no-verify 绕过"，明确只有 CI 是唯一 100% 保证）
6. **低：概率指标口径统一**（在备注中明确区分"覆盖率指标"（允许 ≥90%）和"确定性指标"（必须 100%））

**质量保证**: 路径基准、命令、表述全文一致，文档自洽无矛盾

---

## v1.4 修订说明

**核心问题**: v1.3 经 Codex 深度检查后发现 6 个严重问题，包括**锁文件权限冲突**（导致锁机制完全不可用）、**原子性方案缺陷**（iCloud 同步目录可能失效）、**Guard 强制力虚假声称**等。

**v1.4 修订目标**: 修正所有高优先级问题，确保方案在实际环境中可用。

**主要修订**（按严重度）:
1. **高：锁目录移出 Meta workspace**（`.claude/locks/` → `.locks/`），避免普通 Agent 无法加锁，全文替换 21 处
2. **高：锁原子性修正**（临时文件从 `/tmp/` 改为 `.locks/.tmp.`，确保同一文件系统避免 iCloud 复制）
3. **中高：区分强制卡口和建议卡口**（明确只有 CI + Git Hooks 可 100% 强制，IDE/终端仅为建议）
4. **中：明确路径基准**（所有路径以"仓库根目录"（含 `.git/` 的层级）为基准，消除歧义）
5. **中：修正执行依赖说明**（阶段 3 对阶段 1 的依赖是"可选增强"而非"阻塞依赖"）
6. **低：澄清概率指标使用范围**（仅覆盖率指标允许 ≥90%，工程规则保持确定性）

**质量保证**: 锁机制在实际环境（iCloud 同步、普通 Agent 权限）下可用

---

## 一、背景与目标

### 问题背景

当前项目存在多 Agent 协作的场景（Codex、Claude Code、手动操作、自动化脚本等），但缺乏统一的协作规范，导致：

1. **入口混乱**：多个 Agent 可以从不同路径进入项目，缺乏统一约束
2. **数据格式不一致**：任务输出、状态记录格式各异，难以跨 Agent 追踪
3. **越权风险**：Agent 可能误写跨 workspace 文件
4. **并发冲突**：多 Agent 同时写入可能导致文件冲突
5. **子任务回传混乱**：子 Agent 回传信息格式不统一

### 优化目标

建立统一的 Agent 协作流程规范，实现：

1. **入口可控**：明确所有入口及其工具能力
2. **数据统一**：Schema SSOT 保证跨 Agent 数据一致性
3. **权限清晰**：Workspace 边界明确，防止越权
4. **并发安全**：锁机制避免写冲突
5. **回传标准**：子 Agent 输出格式统一

---

## 二、执行阶段规划

**执行权限要求（所有阶段通用）**:

大部分阶段的交付物位于 Meta workspace（`projectBasicInfo/`、`tools/`、`.githooks/` 等），根据权限规则，默认需由 **Infrastructure Agent** 执行，或在任务启动时授予临时特权（任务类型：`infra-config` 或 `agent-setup`）。

**例外情况**：
- 阶段 5（全流程验收）可能需要创建测试脚本、验证工具等，若输出目标在其他 workspace（如 iOS workspace 的测试目录），需在任务开始时显式声明并申请对应 workspace 的写权限（如 iOS Agent 权限或临时特权）
- **重要**：写入非 Meta workspace 不等于"不需要权限"，仍需遵守 workspace 权限规则

**权限特例目录**：
- `projectBasicInfo/logs/` - 所有 Agent 可写（操作日志）
- `.locks/` - 所有 Agent 可写（并发锁）

---

### 阶段 0：资产盘点（Agent 入口与工具清单）

#### 目标

明确"入口/工具"清单，为后续工具层约束提供卡口。

#### 行动清单

1. **列出所有 Agent 入口**
   - Codex（AI 助手）
   - Claude Code（本 Agent）
   - 终端脚本（手动执行）
   - IDE 插件（Xcode、VS Code）
   - 自动化触发器（Git hooks、CI/CD）
   - 其他潜在入口

2. **列出写操作工具清单**
   - 文件写入工具（Write、Edit、NotebookEdit）
   - 命令执行工具（Bash）
   - 配置修改工具
   - 数据库操作工具

3. **列出读操作工具清单**
   - 文件读取工具（Read、Glob、Grep）
   - 命令查询工具
   - 数据库查询工具

#### 交付物

**文档路径**: `projectBasicInfo/06_AGENT_ASSET_MAP.md`

**文档结构**:
```markdown
# Agent 资产地图

## 1. Agent 入口矩阵
| 入口名称 | 类型 | 访问路径 | 认证方式 | 风险等级 |
|---------|------|---------|---------|---------|
| Codex | AI Agent | ... | ... | ... |
| Claude Code | CLI Tool | ... | ... | ... |
| ... | ... | ... | ... | ... |

## 2. 工具能力矩阵
| 工具名称 | 读权限 | 写权限 | 执行权限 | 覆盖范围 |
|---------|-------|-------|----------|---------|
| Write | ✅ | ✅ | ❌ | 所有文件 |
| ... | ... | ... | ... | ... |

## 3. 风险评估
| 风险项 | 描述 | 影响范围 | 缓解措施 |
|-------|------|---------|---------|
| 跨 workspace 写入 | ... | ... | ... |
| ... | ... | ... | ... |
```

#### 完成定义（DoD）

- [ ] 至少包含"入口矩阵 + 工具能力矩阵 + 风险备注"三段
- [ ] 入口数与实际使用一致
- [ ] 工具清单覆盖现有可写入口（≥90%）

#### 验收标准

- 入口矩阵至少包含 5 个入口
- **工具能力矩阵按入口分别列出**（不同入口工具差异大，需分开统计）
- 每个入口至少列出 3 种主要工具
- 每个风险项都有对应的缓解措施

#### 风险与应对

**风险**: 入口遗漏导致后续约束无法真正落地
**应对**: 查看项目配置文件（.claude/、.git/hooks/）、历史日志、开发文档

---

### 阶段 1：Agent I/O Schema SSOT（统一任务输入输出格式）

#### 目标

统一任务/状态/结果/审计字段，避免跨端漂移。

#### 行动清单

1. **定义 JSON Schema**
   - 任务输入格式（task_id、task_type、workspace、params...）
   - 任务输出格式（status、result、evidence、next_steps...）
   - 审计字段（run_id、actor、timestamp、schema_version...）

2. **定义 TypeScript 类型**（双版本保证前后端一致）
   - 导出 `.ts` 类型定义
   - 与 JSON Schema 保持同步

3. **版本策略**
   - 加入 `schema_version` 字段
   - 新增字段允许（向后兼容）
   - 删除字段需标记 `deprecated`（逐步废弃）

4. **覆盖常用任务类型**（至少 Top 10）
   - bug root-cause 分析
   - patch plan 规划
   - refactor plan 重构规划
   - regression check 回归检查
   - release checklist 发布清单
   - deployment 部署任务
   - code review 代码审查
   - test execution 测试执行
   - documentation update 文档更新
   - security audit 安全审计

#### 交付物

1. **Schema 文档**: `projectBasicInfo/07_AGENT_SCHEMA_SSOT.md`
2. **JSON Schema**: `projectBasicInfo/agent-schema/agent_schema.json`
3. **TypeScript 类型**: `projectBasicInfo/agent-schema/agent_schema.ts`

**Schema 示例结构**:
```json
{
  "task_id": "string",
  "run_id": "string",
  "workspace": "ios|backend|admin-web|meta",
  "actor": "cc|codex|human",
  "task_type": "bug-rootcause|patch-plan|...",
  "schema_version": "1.0.0",
  "timestamp": "ISO8601",
  "input": {
    "description": "string",
    "context": {}
  },
  "output": {
    "status": "pending|in_progress|completed|failed",
    "result": {},
    "evidence": [
      {
        "kind": "file|log|command_output|commit",
        "path": "relative/path/to/file",
        "range": {
          "start_line": 10,
          "end_line": 25,
          "commit_hash": "abc123..."
        },
        "snippet": "代码片段或日志内容"
      }
    ],
    "next_steps": [],
    "error": {}
  }
}
```

**证据字段可定位标准（Critical）**:

为确保证据可追踪和审计，`evidence` 数组中的每个条目必须符合**条件必填规则**：

| 字段 | 类型 | 必填规则 | 说明 |
|------|------|---------|------|
| `kind` | string | **必填** | 证据类型：`file`（文件）/ `log`（日志）/ `command_output`（命令输出）/ `commit`（提交记录）|
| `path` | string | **必填** | 相对路径（从 repo 根目录开始）|
| `range` | object | **条件必填** | 定位范围（根据 `kind` 不同而定）|
| `range.start_line` | number | **当 `kind=file` 时必填** | 起始行号 |
| `range.end_line` | number | **当 `kind=file` 时必填** | 结束行号 |
| `range.commit_hash` | string | **当 `kind=commit` 时必填** | 提交哈希（短哈希或完整哈希均可）|
| `snippet` | string | 推荐（lint 时缺失会 warning）| 简短摘录（≤500 字符）|

**条件必填规则汇总**:
- **所有证据**: `kind` + `path` 必填
- **文件类证据** (`kind=file`): `range.start_line` + `range.end_line` 必填
- **提交类证据** (`kind=commit`): `range.commit_hash` 必填
- **日志/命令输出** (`kind=log` 或 `command_output`): `range` 可选，建议提供 `snippet`

**反例（不可接受）**:
```json
{
  "evidence": ["在某个文件里找到了问题"]  // ❌ 无法定位
}
```

**正例（可接受）**:
```json
{
  "evidence": [
    {
      "kind": "file",
      "path": "guanzhi/View/FrontPages/SearchView.swift",
      "range": {
        "start_line": 142,
        "end_line": 156
      },
      "snippet": "func restoreClusterListIfNeeded() {...}"
    }
  ]
}
```

**路径规范（重要）**:
- Schema 中的 `path` 字段**一律使用仓库根相对路径**（如 `guanzhi/View/...`），确保不同工作目录下路径一致，保证可审计性
- 如实际工作目录在上层（如 `.../Seee/`），执行 guard/evidence 验证时需在路径前加仓库目录前缀（如 `guanzhi/guanzhi/View/...`），但记录到 schema 的路径仍应为仓库根相对路径

#### 完成定义（DoD）

- [ ] 至少覆盖 Top 10 常用任务类型
- [ ] Schema 包含 schema_version 字段
- [ ] 提供版本兼容策略说明
- [ ] JSON Schema 和 TS 类型双版本齐全
- [ ] **证据字段符合条件必填规则**（kind/path 必填，range 根据 kind 条件必填）

#### 验收标准

- 任务输出与 schema 对齐率 ≥90%
- schema 版本字段在示例中必须出现
- 至少提供 3 个完整的任务示例

#### 风险与应对

**风险**: 没有版本策略会导致 2 周内再次碎裂
**应对**: 强制要求所有任务输出必须包含 schema_version，并在文档中明确版本演进规则

---

### 阶段 2：Workspace 权限边界（读写权限分级）

#### 目标

降低 monorepo 误改风险，并隔离敏感读权限。

#### 行动清单

1. **定义 Workspace 目录边界**

   **路径基准**: 所有路径以**仓库根目录**为基准（即包含 `.git/` 的那一层目录）

   **实际使用注意**:
   - **Schema 路径规范**：所有记录到 schema、evidence、日志的路径**一律使用仓库根相对路径**（如 `guanzhi/View/...`），确保不同工作目录下路径一致，保证可审计性
   - **执行命令时**：如当前工作目录在上层（如 `.../Seee/` 而非仓库根 `.../Seee/guanzhi/`），执行 guard/evidence 验证时需在路径前加仓库目录前缀（如 `guanzhi/guanzhi/View/...`）
   - **推荐做法**：在执行 guard/evidence 验证前先切换到仓库根目录（`cd guanzhi`），避免路径转换困惑

   | Workspace | 目录路径（基准：仓库根） | 说明 |
   |-----------|----------------------|------|
   | **iOS** | `guanzhi/`、`Podfile*`、`*.xcodeproj`、`*.xcworkspace`、`Pods/`、`Assets.xcassets` | iOS 客户端（含源代码及工程文件） |
   | **Backend** | `Server/onettoo/` | Java 后端代码 |
   | **Admin-Web** | `admin-web/` | 管理后台前端代码 |
   | **Meta** | `projectBasicInfo/`（除 `logs/`）、`.claude/`、`重要项目信息/`、`tools/`、`.githooks/` | 元数据/规则/协作工具（日志目录除外） |
   | **日志目录** | `projectBasicInfo/logs/` | 操作日志（所有 Agent 可写） |
   | **运行时** | `.locks/` | 锁文件目录（所有 Agent 可写） |

   **说明**:
   - iOS workspace 包含 `guanzhi/` 源代码目录及仓库根目录的工程文件（Podfile、Xcode 项目、CocoaPods 依赖等）
   - Meta workspace 包含项目规则、Agent 协作配置、guard 脚本、Git hooks 等，**但不含日志目录**
   - `projectBasicInfo/logs/` 和 `.locks/` 是**权限特例目录**，所有 Agent 均可写入（用于记录操作日志和并发锁）

2. **写权限规则**
   - **iOS Agent**: 只能写 iOS workspace
   - **Backend Agent**: 只能写 Backend workspace
   - **Admin-Web Agent**: 只能写 Admin-Web workspace
   - **Meta workspace**: 仅特权 Agent 可写（见下文特权定义）
   - **权限特例目录**（所有 Agent 可写）:
     - `projectBasicInfo/logs/` - 操作日志记录
     - `.locks/` - 并发锁文件
   - **跨 workspace 写入**: 所有入口默认禁止，由 guard 脚本拦截

3. **读权限分级**
   - **默认可读**: 所有源代码、公开文档
   - **受限可读**:
     - `.private.md` 文件（敏感信息）
     - 部署脚本（`*.sh`）
     - 生产配置（`.env.production`、`Secrets.xcconfig`）
     - 数据库凭证

4. **特权 Agent 定义与触发条件**

   特权 Agent 是唯一可以跨 workspace 写入的角色，必须满足以下条件才能获得特权：

   | 角色 | 可读写范围 | 触发条件（必须全部满足） | 示例任务 |
   |------|-----------|----------------------|---------|
   | **Deployment Agent** | 所有 workspace | 1. 任务类型为 `deployment` <br> 2. 用户明确授权部署操作 <br> 3. 通过部署前检查清单 | 后端 JAR 部署、前端构建部署 |
   | **Infrastructure Agent** | Meta + 所有只读 | 1. 任务类型为 `infra-config` 或 `agent-setup` <br> 2. 仅写入 Meta workspace <br> 3. 用户明确授权 | 更新 Agent 规则、创建 guard 脚本、配置 Git hooks |
   | **Multi-Workspace Refactor Agent** | 指定的多个 workspace | 1. 任务类型为 `multi-refactor` <br> 2. 用户明确列出允许的 workspace 列表 <br> 3. 重构影响范围评估完成 | 跨端 API 重构、术语统一 |

   **重要约束**:
   - 特权必须由用户在任务开始时**显式授权**，不得自动获取
   - 特权授权记录必须写入任务日志（含授权时间、范围、理由）
   - 特权操作结束后，Agent 立即降级为普通权限

#### 交付物

**文档路径**: `projectBasicInfo/08_WORKSPACE_BOUNDARY.md`

**文档结构**:
```markdown
# Workspace 权限边界

## 1. Workspace 定义
| Workspace | 目录路径（基准：仓库根） | 说明 |
|-----------|----------------------|------|
| iOS | guanzhi/、Podfile*、*.xcodeproj、*.xcworkspace、Pods/、Assets.xcassets | iOS 客户端（含源代码及工程文件） |
| Backend | Server/onettoo/ | Java 后端 |
| Admin-Web | admin-web/ | 管理后台前端 |
| Meta | projectBasicInfo/（除 logs/）、.claude/、重要项目信息/、tools/、.githooks/ | 元数据/规则/协作工具（日志目录除外） |
| **权限特例** | **projectBasicInfo/logs/**、**.locks/** | **所有 Agent 可写**（日志记录、并发锁） |

## 2. 写权限矩阵
| Agent 角色 | iOS | Backend | Admin-Web | Meta | 权限特例目录 |
|-----------|-----|---------|-----------|------|-------------|
| iOS Agent | ✅ | ❌ | ❌ | ❌ | ✅ |
| Backend Agent | ❌ | ✅ | ❌ | ❌ | ✅ |
| Admin-Web Agent | ❌ | ❌ | ✅ | ❌ | ✅ |
| Infrastructure Agent | ❌ | ❌ | ❌ | ✅ | ✅ |
| Deployment Agent（特权）| ✅ | ✅ | ✅ | ✅ | ✅ |

## 3. 读权限分级
| 资源类型 | 默认可读 | 受限可读 | 访问条件 |
|---------|---------|---------|---------|
| 源代码 | ✅ | - | - |
| .private.md | ❌ | ✅ | 部署任务 |
| ... | ... | ... | ... |

## 4. 拦截规则
- 跨 workspace 写入时触发警告
- 读取敏感文件时需验证权限
```

#### 完成定义（DoD）

- [ ] 每个 Agent 的读/写范围明确到目录级
- [ ] 受限读目录列出清单（明确禁止范围）
- [ ] 提供跨 workspace 写入拦截机制说明

#### 验收标准

- 跨 workspace 写入被拦截（100%）
- 受限读目录列出清单（至少 5 个路径模式）

#### 风险与应对

**风险**: 只写规则、不在工具层拦截会失效（特别是非 Claude 入口无法受 .claude/settings.json 约束）

**应对**: 采用**两层卡口**机制，确保跨入口强制力

**两层卡口设计**（区分强制卡口和建议卡口）:

##### 第 1 层：流程卡口（强制 vs 建议）

创建统一的 guard 验证脚本：

```bash
# 路径: tools/agent_guard.sh
# 功能: 越权写入检测 + 锁检测 + schema 检测

# 使用示例（路径从仓库根开始）
./tools/agent_guard.sh --check-write \
  --workspace=ios \
  --files="guanzhi/View/FrontPages/SearchView.swift" \
  --actor=cc

# 注意：如工作目录在上层，需加仓库目录前缀：
# --files="guanzhi/guanzhi/View/FrontPages/SearchView.swift"

# 返回值:
# 0 = 允许写入
# 1 = 越权拒绝
# 2 = 锁冲突
```

**集成位置（按强制程度分级）**:

| 入口 | 类型 | 强制程度 | 集成方式 |
|------|------|---------|---------|
| **CI/CD** | 强制卡口 | 100% 覆盖 | Pipeline 第一步运行 guard，失败阻塞 |
| **Git Hooks** | 准强制卡口 | 可被 --no-verify 绕过 | `core.hooksPath .githooks/pre-commit` |
| **Claude Code** | 建议卡口 | 依赖工具实现 | `.claude/hooks/pre-write.sh`（如可用）|
| **IDE（Xcode/VS Code）** | 建议卡口 | 无法强制 | 操作指南中建议手动运行 guard |
| **手动终端** | 建议卡口 | 无法强制 | 操作指南中建议手动运行 guard |

**关键原则**:
- **只有 CI 是唯一100%保证**，Git Hooks 可被 `--no-verify` 绕过，IDE/终端只能"建议"
- **最后防线**: 即使本地违规或绕过 hooks，CI 仍能捕获
- **不要绝对化**: 避免声称"所有入口必须走 guard"（技术上做不到）

**为什么不用 `.git/hooks/`？**
- `.git/hooks/` 目录默认不进版本管理
- 每个开发者 clone 后需要手动设置，容易遗漏
- CI 环境也需要单独配置，维护成本高
- 推荐用 `core.hooksPath` 或 CI 强制步骤代替

##### 第 2 层：工具卡口（特定入口可用）

`.claude/settings.json` 的 `allowed_tools` 配置仅作为**锦上添花**，非唯一防线。

**关键原则**: 规则要靠 repo 内的 guard 才能跨入口生效，否则就是"只管得住 CC，管不住世界"。

---

### 阶段 3：并发治理（写冲突锁机制）

#### 目标

消除并行写冲突。

#### 适用前提（Scope）

**重要声明**：本锁机制为**本地文件锁**，适用范围和局限性如下：

| 项目 | 说明 |
|------|------|
| **适用场景** | 同机同工作目录内的并发写入互斥 |
| **当前协作形态** | 同一台 Mac + 多入口/多 Agent（Claude Code、Codex、Xcode、终端、VS Code） |
| **不覆盖场景** | 多机协作、多 clone 并发、多人分布式开发 |
| **服务器部署** | 仅偶发部署操作，不存在服务器上多 Agent 并发改代码 |
| **未来扩展** | 若需分布式协作，升级为中心化锁（Redis/DB/HTTP lock service），列入 v2 |

**关键约束**：
- **锁目录**: `.locks/`（位于仓库根目录，所有路径基准为仓库根）
- **权限特例**: `.locks/` 是**运行时目录**，不受 workspace 权限限制，所有 Agent 均可读写
- **作用域**: 仅在同一工作目录副本内有效（不同机器、不同 clone 副本的锁文件相互独立，无法互斥）
- **未来扩展**: 如出现多机/多人协作需求，必须升级为中心化锁（Redis/DB/HTTP lock service）

#### 行动清单

1. **定义"写入任务"**
   - 任何修改 repo 文件的操作
   - 包含格式化、生成文件、patch、代码编辑
   - 不包含只读分析、查询操作

2. **锁粒度设计**
   - Workspace 级锁（iOS/Backend/Admin-Web 独立）
   - Meta workspace 锁（projectBasicInfo/、.claude/、重要项目信息/、tools/、.githooks/）

3. **锁获取策略与工程化设计**

   **锁文件位置**: `.locks/{workspace}.lock`（需加入 `.gitignore`，避免误提交）

   **锁内容结构**（最小可信字段）:
   ```json
   {
     "task_id": "string",
     "actor": "cc|codex|human",
     "lock_mode": "automated|interactive",
     "holder_pid": 12345,
     "host": "hostname or device_id",
     "started_at": "ISO8601",
     "heartbeat_at": "ISO8601",
     "workspace": "ios|backend|admin-web|meta"
   }
   ```

   **锁模式说明**:

   | 模式 | 适用场景 | Heartbeat 间隔 | 僵尸锁判定 | 抢占策略 |
   |------|---------|---------------|-----------|---------|
   | **automated** | 自动化脚本、Agent 批处理 | 60 秒 | 5 分钟未更新 | 允许抢占（需记录 reason）|
   | **interactive** | 人类 IDE 编辑、长时间开发 | 10-15 分钟 | 20 分钟未更新 | **禁止自动抢占**，需显式 `steal_reason` 且输出终端提示 |

   **Interactive 模式特殊规则**:
   - 人类在 IDE 中编辑代码时，可能长时间（10-30 分钟）不运行 heartbeat 进程
   - 为避免误判为僵尸锁，`lock_mode=interactive` 时：
     - Heartbeat 间隔放宽到 10-15 分钟
     - 僵尸锁判定放宽到 20 分钟
     - **抢占前必须输出警告到终端**，提示"锁持有者可能仍在工作，确认抢占？"
     - 或者更保守：人类锁只能"拒绝执行/降级只读"，不允许自动抢占，直到人工释放

   **原子性保证**（避免 iCloud 同步导致的非原子复制）:
   - 使用文件系统的原子操作（`mv` 替代 `echo >`）避免并发创建冲突
   - **关键**: 临时文件必须与目标文件在**同一文件系统**（避免 `mv` 跨文件系统变成复制）
   - 实现伪代码:
     ```bash
     # 生成临时锁文件（在 .locks/ 目录内，确保同一文件系统）
     echo $lock_content > .locks/.tmp.lock.$$
     # 原子移动（失败则说明已被抢占）
     mv -n .locks/.tmp.lock.$$ .locks/ios.lock || exit 1
     ```
   - **为什么不用 `/tmp`**: 在 iCloud 同步目录中，`/tmp`（本地文件系统）到 `.locks/`（iCloud 文件系统）的 `mv` 会变成非原子复制，失去原子性保证

   **Heartbeat 机制**（按 lock_mode 分支，防止参数打架）:
   - **automated 模式**：持锁进程每 60 秒更新 `heartbeat_at`，5 分钟未更新视为僵尸锁，允许抢占
   - **interactive 模式**：持锁进程每 10-15 分钟更新 `heartbeat_at`，20 分钟未更新视为僵尸锁，需显式确认才能抢占

   **锁目录初始化**:
   - 所有入口启动前自动创建 `.locks/` 目录（`mkdir -p .locks`）
   - 避免"第一天就因为目录不存在而锁不可用"

4. **抢锁失败策略**
   - **策略 1: 排队等待**（默认，适用于自动化任务）
   - **策略 2: 拒绝执行**（适用于交互式任务）
   - **策略 3: 降级只读分析**（适用于分析类任务）

5. **锁释放与抢占机制**

   **正常释放**:
   - 任务完成后删除锁文件
   - 验证 `holder_pid` 和 `host` 匹配，避免误删他人的锁

   **超时与僵尸锁处理**（按 lock_mode 分支，禁止 interactive 自动释放）:

   **automated 模式**:
   - **Heartbeat 超时**: 如果 `heartbeat_at` 超过 5 分钟未更新 → 允许抢占
   - **任务超时**: 如果 `started_at` 超过 30 分钟 → 允许抢占（但需先检查 heartbeat）

   **interactive 模式**:
   - **Heartbeat 超时**: 如果 `heartbeat_at` 超过 20 分钟未更新 → 仅输出 warning，禁止自动抢占
   - **不得固定超时自动释放**（避免人类长时间编辑被误判）
   - **释放方式**: 必须由持有者显式释放（或同 host/pid 的确认流程）
   - **其他写入任务**: 拒绝执行或降级只读

   **抢占时必须记录**:
   ```json
   {
     "steal_reason": "heartbeat timeout (automated 5min / interactive confirmed)",
     "stolen_from": {
       "task_id": "...",
       "actor": "...",
       "started_at": "..."
     },
     "stolen_at": "ISO8601",
     "stolen_by": "cc"
   }
   ```

   **残留清理**:
   - 启动时检查所有锁文件，清理僵尸锁
   - 清理前记录日志到 `projectBasicInfo/logs/YYYY-MM-DD-lock-cleanup-cc.md`

#### 交付物

**文档路径**: `projectBasicInfo/09_CONCURRENCY_RULES.md`

**文档结构**:
```markdown
# 并发治理规则

## 1. 写入任务定义
| 操作类型 | 是否为写入任务 | 示例 |
|---------|--------------|------|
| Edit 文件 | ✅ | 修改代码 |
| Write 文件 | ✅ | 创建新文件 |
| Read 文件 | ❌ | 读取文档 |
| ... | ... | ... |

## 2. 锁粒度与文件结构
| Workspace | 锁文件路径 | 说明 |
|-----------|-----------|------|
| iOS | .locks/ios.lock | iOS 客户端锁 |
| Backend | .locks/backend.lock | 后端锁 |
| Admin-Web | .locks/admin-web.lock | 管理后台锁 |
| Meta | .locks/meta.lock | 元数据/规则锁 |

**锁文件内容示例**:

Automated 模式（Agent/脚本）:
```json
{
  "task_id": "2026-02-02-T14:30:00-ios-refactor",
  "actor": "cc",
  "lock_mode": "automated",
  "holder_pid": 12345,
  "host": "MacBook-Pro.local",
  "started_at": "2026-02-02T14:30:00+08:00",
  "heartbeat_at": "2026-02-02T14:32:00+08:00",
  "workspace": "ios"
}
```

Interactive 模式（人类 IDE 编辑）:
```json
{
  "task_id": "2026-02-02-T14:00:00-ios-manual-edit",
  "actor": "human",
  "lock_mode": "interactive",
  "holder_pid": 56789,
  "host": "MacBook-Pro.local",
  "started_at": "2026-02-02T14:00:00+08:00",
  "heartbeat_at": "2026-02-02T14:12:00+08:00",
  "workspace": "ios"
}
```

**目录管理**:
- `.locks/` 目录加入 `.gitignore`
- 所有入口启动时自动创建该目录（`mkdir -p .locks`）

## 3. 抢锁失败策略
| 策略 | 适用场景 | 行为 |
|------|---------|------|
| 排队等待 | 自动化任务 | 阻塞直到获取锁 |
| 拒绝执行 | 交互式任务 | 立即返回错误 |
| 降级只读 | 分析任务 | 转为只读分析 |

## 4. 超时与抢占规则（按 lock_mode 分支）
- **automated**: heartbeat 超时（5 分钟）允许抢占
- **interactive**: heartbeat 超时（20 分钟）仅 warning，禁止自动抢占
- **抢占必须记录**: steal_reason + stolen_from 信息
```

#### 完成定义（DoD）

- [ ] 写入任务定义清晰（含边界案例）
- [ ] 锁策略完整（获取、释放、超时、heartbeat、抢占）
- [ ] **Automated / Interactive 双模式实现**（heartbeat 间隔、抢占策略差异化）
- [ ] **适用前提文档化**（同机单 clone，多机/分布式需 v2）
- [ ] 失败处理策略明确（至少 3 种：排队/拒绝/降级）
- [ ] **锁原子性实现方案明确**（使用 `mv -n` 避免双重获取）
- [ ] **僵尸锁清理机制完整**（含抢占记录、启动时清理）
- [ ] `.gitignore` 更新（排除 `.locks/`）
- [ ] 锁目录自动创建（所有入口启动时 `mkdir -p .locks`）

#### 验收标准（确定性指标）

- [ ] **提供可重复的并发测试脚本**（模拟多入口并发写入）
- [ ] **并发测试 10/10 次，0 次出现双写**（100% 互斥，非概率保证）
- [ ] **抢锁/拒绝/降级行为可观测**:
  - Exit code 明确：0=成功获取锁，1=越权拒绝，2=锁冲突
  - 日志输出清晰：包含锁持有者信息、拒绝原因
  - 终端提示友好：交互式抢占时输出警告
- [ ] 锁文件格式 100% 符合规范（包含所有必填字段）
- [ ] Automated 模式：heartbeat 超时（5 分钟）可被抢占
- [ ] Interactive 模式：heartbeat 超时（20 分钟）需显式确认才能抢占
- [ ] 僵尸锁清理正常（启动时自动清理，记录日志）

#### 风险与应对

**风险**: "读/写界限模糊"导致规则难执行
**应对**: 在 Schema SSOT 中明确标记每个操作的读写属性

---

### 阶段 4：Sub-agent SOP（子任务回传标准）

#### 目标

标准化子任务回传，主会话快速决策。

#### 行动清单

1. **定义子 Agent 类型**
   - Explore Agent（代码探索）
   - Plan Agent（规划设计）
   - Test Runner（测试执行）
   - Build Validator（构建验证）
   - Bash Agent（命令执行）

2. **统一回传格式**
   ```json
   {
     "task_id": "string",
     "sub_agent_type": "explore|plan|test|build|bash",
     "status": "completed|failed|partial",
     "conclusion": "简短结论（1-2 句话）",
     "evidence": [
       {
         "kind": "file|log|command_output|commit",
         "path": "relative/path/to/file",
         "range": {
           "start_line": 10,
           "end_line": 25,
           "commit_hash": "abc123..."
         },
         "snippet": "代码片段或日志内容（≤500 字符）"
       }
     ],
     "risk": [
       {
         "level": "low|medium|high",
         "description": "string"
       }
     ],
     "next_steps": [
       {
         "action": "string",
         "priority": "p0|p1|p2"
       }
     ]
   }
   ```

   **注**: `evidence` 字段必须符合阶段 1 定义的可定位标准（kind/path/range），确保证据可追踪和审计。

3. **回传内容要求**
   - **结论**: 直接回答任务问题（避免模糊表述）
   - **证据**: 提供文件路径/日志片段支撑结论
   - **风险**: 标记潜在问题和影响范围
   - **下一步建议**: 按优先级排序（P0/P1/P2）

#### 交付物

**文档路径**: `projectBasicInfo/10_SUBAGENT_SOP.md`

**文档结构**:
```markdown
# Sub-agent 标准操作流程

## 1. 子 Agent 类型定义
| 类型 | 职责 | 典型任务 |
|------|------|---------|
| Explore | 代码探索 | 查找文件、理解架构 |
| Plan | 规划设计 | 设计方案、评估方案 |
| ... | ... | ... |

## 2. 回传格式模板
（JSON Schema）

## 3. 回传内容要求
### 3.1 结论（Conclusion）
- 必须直接回答任务问题
- 避免"可能"、"大概"等模糊词
- 长度: 1-3 句话

### 3.2 证据（Evidence）

**条件必填规则**（与阶段 1 保持一致）:
- **必填**: `kind` + `path`（所有证据）
- **条件必填**:
  - `kind=file` 时: `range.start_line` + `range.end_line` 必填
  - `kind=commit` 时: `range.commit_hash` 必填
- **推荐**: `snippet`（≤500 字符，lint 时缺失会 warning）

**验证清单**:
- [ ] 至少提供 1 条证据
- [ ] 所有证据都包含 `kind` 和 `path`
- [ ] 文件类证据包含行号范围
- [ ] 证据可定位、可复核（能够通过路径+范围精确定位）

### 3.3 风险（Risk）
- 标记潜在问题
- 分级: low/medium/high
- 包含影响范围

### 3.4 下一步建议（Next Steps）
- 按优先级排序（P0/P1/P2）
- P0: 阻塞任务，必须立即处理
- P1: 重要但不阻塞
- P2: 优化建议

## 4. 示例
（提供 3-5 个完整示例）
```

#### 完成定义（DoD）

- [ ] 回传模板 + 示例齐全
- [ ] 至少提供 5 个完整示例
- [ ] 覆盖所有子 Agent 类型

#### 验收标准

- 子任务回传格式合规率 ≥90%
- 所有示例都包含完整的 4 个字段（结论/证据/风险/下一步）

#### 风险与应对

**风险**: 回传散乱导致主会话难以汇总
**应对**: 在 Schema SSOT（阶段 1）中嵌入子 Agent 回传格式约束

---

### 阶段 5：可选项（暂不实施）

以下项目暂不启动，仅在"多入口、多角色、多设备协作"成为刚需后再考虑：

1. **Gateway 统一控制平面**
   - 所有 Agent 请求通过统一 Gateway 进入
   - Gateway 负责权限验证、日志记录、限流

2. **Sandbox 深化**
   - 为每个 Agent 提供独立的沙箱环境
   - 限制文件系统访问范围

3. **工具白名单**
   - 动态配置每个 Agent 可用的工具列表
   - 基于任务类型自动授权工具权限

---

## 三、统一验收指标

每个阶段完成后，需通过以下指标验证：

| 指标 | 目标值 | 验证方法 | 备注 |
|------|-------|---------|------|
| **Schema 覆盖率** | Top 10 常用任务 ≥90% | 抽样检查最近 20 个任务日志 | **覆盖率指标**（允许概率表述） |
| **越权写入拦截率** | 跨 workspace 写入 100% 拦截 | 使用 guard 脚本模拟测试（至少 5 种场景）| **确定性指标**（工程规则必须 100%） |
| **写冲突率** | **并发测试 10/10 次，0 次双写** | **提供可重复的并发测试脚本** | **确定性指标**（Exit code + 日志可观测） |
| **子 Agent 回传合规率** | ≥90% | 抽样检查最近 10 个子任务输出 | **覆盖率指标**（evidence 可定位性） |
| **证据可定位率** | 100% | 验证所有 evidence 符合条件必填规则 | **确定性指标**（kind/path 必填，range 条件必填） |

---

## 四、阶段依赖关系

**阶段编号 vs 执行顺序**: 阶段编号用于文档组织，执行顺序按 MVP 优先级（见"七、下一步行动"）

**依赖关系**（分为"阻塞依赖"和"可选增强"）:

```
阶段 0 (资产盘点)
    ↓ 阻塞依赖
阶段 2 (权限边界) → 提供 workspace 定义，阶段 3 需要
    ↓ 阻塞依赖
阶段 3 (并发治理) → 基础锁机制可独立实现
    ║
    ║ 可选增强（非阻塞）
    ╚══ 阶段 1 (Schema SSOT) → 在 Schema 中标记操作读写属性，增强锁判断准确性

阶段 4 (Sub-agent SOP)
    ↑ 阻塞依赖
阶段 1 (Schema SSOT) → 提供统一的 evidence 格式

阶段 5 (可选项) ← 暂不启动
```

**说明**:
- **阻塞依赖**: 必须先完成前置阶段（如阶段 2 → 阶段 3）
- **可选增强**: 不阻塞，但建议后续补充（如阶段 1 可增强阶段 3 的准确性）
- **MVP 执行顺序**: Phase 1（Guard + 越权）→ Phase 2（边界）→ Phase 3（锁）→ Phase 4（Schema）

---

## 五、日志记录规范

每个阶段完成后，必须在 `projectBasicInfo/logs/` 创建日志文件：

**命名格式**:
```
YYYY-MM-DD-阶段描述-cc.md
```

**示例**:
- `2026-02-03-agent-asset-map-complete-cc.md`
- `2026-02-05-agent-schema-ssot-complete-cc.md`

**日志内容**:
- 完成了什么
- 遇到了什么问题
- 如何解决的
- 验收结果
- 下一步行动

---

## 六、风险汇总与应对

| 阶段 | 主要风险 | 应对措施 | 责任人 |
|------|---------|---------|--------|
| 阶段 0 | 入口遗漏 | 查看配置文件、历史日志、IDE 配置 | CC |
| 阶段 1 | Schema 碎裂 | 强制 schema_version + 证据可定位标准 | CC |
| 阶段 2 | **跨入口强制力缺失** | **两层卡口：repo guard（必须）+ .claude/settings.json（辅助）** | CC |
| 阶段 3 | **锁的原子性/死锁** | **heartbeat + 抢占机制 + 原子文件操作** | CC |
| 阶段 4 | 回传散乱 | 嵌入 Schema 约束 + 强制证据可定位 | CC |
| 全局 | 验收指标无法衡量 | 提供可重复的测试脚本 | CC |

---

## 七、下一步行动（按 MVP 优先级）

### 最小可落地 MVP 顺序

按照"先止血、再建制、后标准化"的原则，调整实施顺序如下：

**Phase 1: Guard 骨架 + 越权拦截**（最优先，立即止血）
- 创建 `tools/agent_guard.sh` 脚本骨架
- 定义 exit code 约定（0=通过，1=越权，2=锁冲突）
- 实现最基础的跨 workspace 写入检测
- **收益**: 立即拦截最痛的"跨 workspace 误写"问题
- **预计**: 1 天

**Phase 2: Workspace 边界 + 写入拦截**（建立隔离）
- 完成阶段 0（资产盘点）+ 阶段 2（权限边界）
- 将 guard 脚本集成到各入口（core.hooksPath / CI）
- 测试越权写入拦截（至少 5 种场景）
- **收益**: 建立基础隔离机制
- **预计**: 1-2 天

**Phase 3: 锁机制（分步实施）**（避免并发冲突）

3.1 **基础锁**（先做获取/释放/超时）
- 实现锁获取/释放/超时逻辑
- 创建 `.locks/` 目录，加入 `.gitignore`
- **不做**: heartbeat、抢占、清理（下一步再加）
- **预计**: 1 天

3.2 **Heartbeat + 抢占**（补强健壮性）
- 实现 automated / interactive 双模式
- 实现 heartbeat 机制
- 实现僵尸锁抢占 + 清理
- **预计**: 1 天

**Phase 4: Schema SSOT + 回传标准**（标准化，收益大但不紧急）
- 完成阶段 1（Schema SSOT）
- 完成阶段 4（Sub-agent SOP）
- 建立证据可定位标准
- **收益**: 提升主会话可复核性，长期收益
- **预计**: 2 天

**Phase 5: 全流程验收**（验证闭环）
- 执行所有验收测试
- 补充测试脚本（并发、越权、证据可定位）
- 记录完成日志
- **预计**: 1 天

---

### 具体时间安排

**本周完成**（优先止血）:
- Day 1: Phase 1 - Guard 骨架 + 越权拦截
- Day 2-3: Phase 2 - Workspace 边界 + 集成测试
- Day 4: Phase 3.1 - 基础锁

**下周完成**（补强 + 标准化）:
- Day 5: Phase 3.2 - Heartbeat + 抢占
- Day 6-7: Phase 4 - Schema SSOT + 回传标准
- Day 8: Phase 5 - 全流程验收

---

### 立即行动（今日完成）

**执行者要求**: 以下操作涉及 Meta workspace 写入，必须由 **Infrastructure Agent** 执行，或在任务启动时授予临时特权（任务类型：`infra-config`）。

- [ ] 创建 `tools/` 目录（Meta workspace，需特权）
- [ ] 创建 `projectBasicInfo/agent-schema/` 目录（Meta workspace，需特权）
- [ ] 创建 `.locks/` 目录（运行时目录，无需特权）
- [ ] 创建 `.githooks/` 目录（Meta workspace，需特权）
- [ ] 在 `.gitignore` 中添加 `.locks/`（仓库根文件，需特权）
- [ ] 阅读最近 5 条操作日志，了解当前 Agent 使用情况（只读操作）
- [ ] 开始编写 `tools/agent_guard.sh` 骨架（Meta workspace，需特权）

---

## 八、参考文档

- `projectBasicInfo/00_AGENT_RULES.md` - Agent 使用规则
- `projectBasicInfo/01_PROJECT_OVERVIEW.md` - 项目概述
- `projectBasicInfo/04_TERMINOLOGY.md` - 术语规范
- `.claude/settings.json` - Claude 本地规则配置

---

## 九、修订历史

| 版本 | 日期 | 修订内容 | 审阅者 |
|------|------|---------|--------|
| v1.0 | 2026-02-02 | 初始版本，完成 5 个阶段规划 | - |
| v1.1 | 2026-02-02 | 补充跨入口强制力、锁工程化、Meta workspace、证据可定位标准 | GPT/Codex |
| v1.2 | 2026-02-02 | 修正 5 个工程问题：evidence 条件必填、interactive 锁模式、锁适用前提、Git hooks 分发、确定性指标、MVP 优先级 | GPT |
| v1.3 | 2026-02-02 | 文档去重手术：删除所有旧版本段落，统一 lock_mode 参数描述，删除"30 分钟超时自动释放"，evidence/Git hooks/验收指标全文统一 | GPT |
| v1.4 | 2026-02-02 | 修正高优先级工程问题：锁目录移出 Meta workspace（`.claude/locks/` → `.locks/`，21 处替换）、锁原子性修正（临时文件同一文件系统）、区分强制/建议卡口、明确路径基准、修正执行依赖、澄清概率指标范围 | Codex |
| v1.5 | 2026-02-02 | 修正路径基准与一致性问题：Workspace 路径统一为仓库根基准（`guanzhi/guanzhi/` → `guanzhi/`）、锁初始化命令修正（3 处）、Guard 示例路径统一、日志命名规范化、Git Hooks 强制力现实化（承认可被 --no-verify 绕过）、指标口径统一 | Codex |
| v1.6 | 2026-02-02 | 修正交付路径与 workspace 定义：交付物路径统一（8 处 `guanzhi/projectBasicInfo/` → `projectBasicInfo/`）、iOS workspace 扩展（新增根目录工程文件：Podfile*、*.xcodeproj、*.xcworkspace、Pods/、Assets.xcassets）、Meta workspace 完善（新增 tools/、.githooks/）、agent-schema/ 位置统一 | Codex |
| v1.7 | 2026-02-02 | 修正权限矛盾与执行者要求：日志目录作为权限特例（`projectBasicInfo/logs/` 所有 Agent 可写，解决 Meta workspace 权限矛盾）、Phase 1 执行者要求明确（需 Infrastructure Agent 或临时特权）、Shell 命令注释语法修正 | Codex |
| v1.8 | 2026-02-02 | 完善各阶段执行权限要求：在执行阶段规划总则中明确通用权限要求（所有阶段交付物位于 Meta workspace，需 Infrastructure Agent 或临时特权）、Infrastructure Agent 示例任务修正（"创建日志" → "创建 guard 脚本、配置 Git hooks"）、锁粒度描述完善（覆盖 tools/、.githooks/） | Codex |
| v1.9 | 2026-02-02 | 修正路径实际定位问题：Evidence 示例路径从实际工作目录可达（`guanzhi/guanzhi/View/FrontPages/SearchView.swift`）、增加工作目录使用说明（推荐切换到仓库根或使用完整路径）、执行权限表述灵活化（阶段 5 可在其他位置输出，需显式声明）| Codex |
| **v2.0** | 2026-02-02 | **统一路径基准规范**：Schema 路径统一为仓库根相对路径（Evidence 示例改为 `guanzhi/View/...`）、明确"记录路径 vs 执行路径"区别（记录一律仓库根相对路径，执行时可能需加前缀）、执行权限表述明确化（写非 Meta workspace 仍需对应 workspace 权限）| **Codex** |

---

**文档状态**: ✅ 规划完成（**v2.0 路径规范统一版，可审计性保证**），待执行

**下一步**: 按 MVP 优先级执行（**所有阶段需 Infrastructure Agent 或临时特权**）
1. **Phase 1**: Guard 骨架 + 越权拦截（立即止血）
2. **Phase 2**: Workspace 边界 + 集成测试
3. **Phase 3**: 锁机制（分步实施）
4. **Phase 4**: Schema SSOT + 回传标准
5. **Phase 5**: 全流程验收

**v2.0 关键改进**（路径规范统一与权限表述明确）:
- ✅ **Schema 路径统一为仓库根相对路径**：Evidence 示例路径从 `guanzhi/guanzhi/View/...` 改为 `guanzhi/View/...`，确保 schema 的 path 字段在不同工作目录下保持一致，保证可审计性
- ✅ **明确"记录路径 vs 执行路径"区别**：Schema/evidence/日志中的路径一律使用仓库根相对路径，执行命令时可能需要加前缀（工作目录在上层时），但记录路径不变
- ✅ **工作目录使用说明更新**：增加"Schema 路径规范"条款，明确路径记录标准，推荐切换到仓库根执行（`cd guanzhi`）避免路径转换
- ✅ **执行权限表述明确化**：增加"写入非 Meta workspace 不等于'不需要权限'"说明，明确仍需遵守对应 workspace 权限规则

**质量保证**:
- Schema path 字段在不同工作目录下保持一致（可审计性保证）
- 路径记录标准统一（仓库根相对路径）
- 执行权限表述无歧义（非 Meta workspace 仍需对应权限）
- 路径使用规范清晰（记录标准 vs 执行方法区分明确）

**工程化质量**: 从"路径实际可用"→"路径规范统一、可审计性保证"
