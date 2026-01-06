# 术语统一：「分享」→「观之」实施计划

**日期**: 2026-01-06
**作者**: Claude Code
**状态**: 阶段一完成（v4 - 文档/规则/术语字典已更新）

---

## 目标与边界

### 目标
用户可见的「分享/Share」（名词）全部在 UI 层统一展示为「观之」。

### 边界（严格遵守）

**禁止改动**：
- Swift 类型/文件/变量名（`Share`、`ShareService`、`ShareDetailView`...）
- API 路径、JSON key、数据库表/字段
- 后端 Java 实体名、接口名
- 任何符号级别命名（`shareId`、`share_url` 等）

**允许改动**：
1. iOS 前端 UI 文案（按钮、标题、空态、错误、Toast、弹窗）
2. iOS 前端代码注释/日志（仅中文文本，不动变量名）
3. 项目文档 / projectBasicInfo / rules / agents 准则
4. 本地化文件（如有）

### 动词 vs 名词区分

| 类型 | 示例 | 处理方式 |
|------|------|----------|
| **名词**（用户发的内容） | "发一条分享"、"暂无分享"、"删除这条分享" | 改为「观之」 |
| **动词**（系统分享动作） | "分享到微信"、"分享到朋友圈" | 保留「分享」或改为「转发」 |

---

## 第一步：建立术语字典（SSOT）

新建文件：`projectBasicInfo/04_TERMINOLOGY.md`

内容定义：
- **对外展示术语**：观之
- **内部技术术语**：Share（仅代码内部使用）
- **约定写法**：
  - UI 文案：只写「观之」
  - 注释：用「观之」或「观之（Share）」
  - 文档：首次出现写「观之（内部模型 Share）」，后续全用「观之」

---

## 第二步：扫描范围与结果

### 扫描范围（三类）

| 类别 | 完整相对路径 | 说明 |
|------|--------------|------|
| Swift 硬编码文案 | `guanzhi/**/*.swift` | UI 字符串、print/日志 |
| 本地化资源 | `guanzhi/**/*.strings`、`guanzhi/**/*.stringsdict` | 如有 |
| 项目文档/规则 | `projectBasicInfo/00_AGENT_RULES.md`<br>`projectBasicInfo/01_PROJECT_OVERVIEW.md`<br>`.rules/agent_rules.md`<br>`CLAUDE.md`（根目录） | 不含历史日志 |

### A. 用户可见字符串（必须改）

| 文件 | 行号 | 当前文案 | 改为 | 待确认 |
|------|------|----------|------|--------|
| `MainToolbar.swift` | 22 | `"分享一下想法吧"` | `"发一条观之吧"` | 文案语感 |
| `ButtonStyles.swift` | 190 | `"📷 分享地点"` | `"📷 发布观之"` | |
| `SheetView.swift` | 72 | `"📷 分享地点"` | `"📷 发布观之"` | |
| `ShareListView.swift` | 60 | `"暂无分享"` | `"暂无观之"` | |
| `StickerSummaryOverlay.swift` | 58 | `"拖动下方贴纸来为这条分享添加互动"` | `"...这条观之..."` | |
| `ShareDetailView.swift` | 1274 | `"确定要删除这条分享吗？..."` | `"...这条观之..."` | |
| `CommentViewModel.swift` | 152 | `"无效的分享ID"` | `"无效的观之ID"` | |
| `MainToolbar.swift` | 594 | `"发布分享成功"` (print) | `"发布观之成功"` | |

### B. 动词白名单（允许保留「分享」）

| 文件 | 行号 | 文案 | 原因 |
|------|------|------|------|
| `ShareDetailView.swift` | 1231 | `title: "分享"` | 系统分享动作（分享到微信等） |

**决定**：保留「分享」或改为「转发」，由用户最终拍板。

### C. 调试日志（建议改）

以下文件包含大量调试日志中的「分享」：

| 文件 | 出现次数 | 说明 |
|------|----------|------|
| `SearchViewModel.swift` | ~30 | 各种 print 语句 |
| `guanzhiApp.swift` | 2 | 导航日志 |
| `MessagesView.swift` | 1 | 跳转日志 |
| `ShareDetailView.swift` | 3 | 加载/删除日志 |
| `ShareListView.swift` | 1 | 错误日志 |

**建议**：日志中统一改为「观之」，但变量名（如 `shareId`）保持不变。

### D. 测试数据/Mock 数据

| 文件 | 行号 | 说明 |
|------|------|------|
| `SearchViewModel.swift` | 1145 | `"这是一个测试分享..."` |
| `SearchViewModel.swift` | 1153 | `title: "测试分享"` |
| `ShareDetailView.swift` | 1924 | `title: "测试分享"` |
| `InteractionOverlayView.swift` | 189 | `data: "测试分享"` |
| `ShareSingleView.swift` | 197 | `"这是 mock 的分享内容"` |
| `MessageRowView.swift` | 362 | `"给你的分享贴了..."` |

---

## 第三步：项目文档更新

### 必须更新的文档（完整相对路径）

| 文件路径 | 说明 |
|----------|------|
| `projectBasicInfo/04_TERMINOLOGY.md` | **新建** 术语字典（SSOT） |
| `projectBasicInfo/01_PROJECT_OVERVIEW.md` | 42 处「分享」需要改为「观之」 |
| `projectBasicInfo/00_AGENT_RULES.md` | 添加术语规范条款 |
| `.rules/agent_rules.md` | 添加术语规范条款 |
| `CLAUDE.md` | 更新项目描述（根目录） |

### 历史日志文件

日志文件（`projectBasicInfo/logs/*.md`）记录的是历史事实，**不建议全量修改**。但在未来的日志中应使用「观之」。

---

## 第四步：规则文件更新

### 需要添加的术语规范条款

```markdown
## 术语规范

### 对外展示术语
- 用户可见层（UI/文案/文档）统一使用「观之」
- 代码内部模型仍叫 `Share`
- API/数据库契约保持 `share` 命名不迁移

### 术语对照表
| 场景 | 使用术语 |
|------|----------|
| UI 按钮/标题 | 观之 |
| 空态提示 | 暂无观之 |
| 错误提示 | 无效的观之ID |
| 代码类型名 | Share（不改） |
| API 路径 | /shares/（不改） |
| 数据库表 | share（不改） |

### 特殊情况
- 「分享到微信」等系统分享功能，保留「分享」（动词）
- 或改为「转发」以区分
```

---

## 实施顺序（分两阶段）

### 阶段一：文档/规则/术语字典（不碰代码）

1. **创建术语字典** - `projectBasicInfo/04_TERMINOLOGY.md`
2. **更新规则文件** - `00_AGENT_RULES.md`、`.rules/agent_rules.md`、`CLAUDE.md`
3. **更新项目概述** - `01_PROJECT_OVERVIEW.md`
4. **验证阶段一** - 确认文档一致性

**好处**：回滚最干净，可先合并文档变更

### 阶段二：iOS UI 文案（改代码）

5. **用户确认文案表** - 最终拍板每条替换文案
6. **修改 iOS UI 文案** - 按确认后的表逐一修改
7. **修改注释/日志** - 可选，仅改中文文本
8. **验证阶段二** - UI 名词零残留 + 动词白名单确认

---

## 验证命令

### A. 全量列出「分享/Share」（核心验证，不做过滤）

```bash
# 1. Swift 文件中所有「分享」（中文）
rg "分享" guanzhi/ --type swift

# 2. Swift 文件中所有「Share」（英文，全量不过滤）
rg "Share" guanzhi/ --type swift

# 3. 本地化文件（如有）
rg "分享|Share" guanzhi/ --glob '*.strings' --glob '*.stringsdict'

# 4. 全仓库扫描（排除 xcassets/pbxproj）
rg "分享|Share" guanzhi/ --glob '!**/*.xcassets/**' --glob '!**/*.pbxproj'
```

**验证方式**：全量列出 → 按白名单人工确认，A 部分始终全量，过滤动作交给 B

### B. 白名单确认（人工分类）

将 A 的结果按以下分类：

| 分类 | 示例 | 预期处理 |
|------|------|----------|
| ✅ 已改为「观之」 | `Text("暂无观之")` | 确认 |
| ✅ 动词白名单 | `title: "分享"` (系统分享) | 允许保留 |
| ✅ 类型名/变量名 | `ShareService`、`shareId` | 不改 |
| ✅ 历史日志 | `logs/*.md` 中的「分享」 | 发现但不改，记录"未来新日志要用观之" |
| ❌ 漏网之鱼 | `"发一条分享"` | 需要改 |

### C. 类型名未被改动（关键验证）

```bash
# 确认 Share 相关类型名完整存在（数量应与改动前一致）
rg "class Share|struct Share|ShareService|ShareDetailView" guanzhi/ --type swift

# 确认 shareId 等变量名未被改动
rg "shareId|share_url|ShareResponse" guanzhi/ --type swift

# 生成改动前后对比
git diff --stat
```

### D. 文档一致性

```bash
# 检查规则文件是否包含术语条款
rg "术语规范|观之" projectBasicInfo/00_AGENT_RULES.md
rg "术语规范|观之" .rules/agent_rules.md
```

---

## 交付物清单

### 阶段一交付
- [x] `projectBasicInfo/04_TERMINOLOGY.md` 已创建（术语字典 SSOT）
- [x] `projectBasicInfo/00_AGENT_RULES.md` 已添加术语条款
- [x] `.rules/agent_rules.md` 已添加术语条款
- [x] `CLAUDE.md`（根目录）已更新
- [x] `projectBasicInfo/01_PROJECT_OVERVIEW.md` 已更新

### 阶段二交付
- [ ] 用户确认的文案替换表
- [ ] iOS UI 名词零残留（验证命令 A 结果）
- [ ] 动词白名单列表（验证命令 B 人工确认）
- [ ] 类型名/API/DB 未改动证据（验证命令 C 结果 + git diff）

---

## 预估工作量

| 类别 | 文件数 | 预估改动 |
|------|--------|----------|
| UI 文案 | ~8 | ~15 处 |
| 注释/日志 | ~10 | ~50 处 |
| 项目文档 | ~5 | ~60 处 |
| 规则文件 | ~3 | 新增条款 |
| 术语字典 | 1 | 新建 |
