# Agent Guard 骨架实现与立即行动清单完成

**日期**: 2026-02-03
**操作者**: Claude Code (Infrastructure Agent)
**任务类型**: infra-config
**关联文档**: `projectBasicInfo/logs/2026-02-02-agent-collaboration-optimization-plan-cc.md` (v2.0)

---

## 概述

完成 Agent 协作流程优化的"立即行动清单"，包括创建目录结构、配置 .gitignore、分析历史日志，并实现 `tools/agent_guard.sh` 权限检查脚本骨架（v0.1.0）。

---

## 完成的任务清单

### 1. 目录结构创建

创建以下目录：

```bash
mkdir -p tools                          # Meta workspace - Agent 协作工具
mkdir -p projectBasicInfo/agent-schema  # Meta workspace - Schema 定义目录
mkdir -p .locks                         # 运行时目录 - 并发锁（所有 Agent 可写）
mkdir -p .githooks                      # Meta workspace - Git Hooks
```

**验证**：
```bash
$ ls -la | grep -E "tools|\.locks|\.githooks"
drwxr-xr-x   2 zaptain  staff    64  2月  3 18:46 .githooks
drwxr-xr-x   2 zaptain  staff    64  2月  3 18:46 .locks
drwxr-xr-x   2 zaptain  staff    64  2月  3 18:46 tools
```

### 2. .gitignore 更新

在 `.gitignore` 末尾添加：

```gitignore
# Agent 协作运行时锁目录
.locks/
```

**原因**：`.locks/` 目录用于存储运行时并发锁文件，不应提交到版本控制。

### 3. Agent 使用模式分析

读取最近 5 个操作日志：
- `2026-02-02-agent-collaboration-optimization-plan-cc.md` - 协作优化规划（v2.0）
- `2026-01-28-annotation-thumbnail-retry-cc.md` - iOS 功能增强
- `2026-01-28-share-thumbnail-diagnosis-cc.md` - 问题诊断 + 文档更新
- `2026-01-25-share-landing-page-plan-cc.md` - 分享落地页规划
- `2026-01-24-report-feature-implementation-cc.md` - 举报功能实施

**分析结论**：

| 观察项 | 结论 |
|--------|------|
| **跨 workspace 操作** | 非常常见，单次任务经常同时涉及 iOS + Backend + Admin-Web + Meta |
| **主要操作者** | Claude Code (cc) |
| **并发场景** | 目前无，都是单一 Agent 顺序操作 |
| **典型操作** | 功能开发（涉及多端）、问题诊断、文档更新、部署记录 |

### 4. Agent Guard 脚本骨架实现

**文件**: `tools/agent_guard.sh`
**版本**: v0.1.0 (骨架版本)
**兼容性**: bash 3.2+ (macOS 默认版本)

#### 核心功能

1. **跨 workspace 写入检测**
   - 验证文件是否属于 Agent 声明的 workspace
   - 支持权限例外目录（`projectBasicInfo/logs/`, `.locks/`）

2. **Workspace 定义**（使用函数代替关联数组以兼容 bash 3.x）：
   - `ios`: `guanzhi/`, `Podfile`, `.xcodeproj`, `.xcworkspace`, `Pods/`, `Assets.xcassets`
   - `backend`: `Server/onettoo/`
   - `admin-web`: `admin-web/`
   - `meta`: `projectBasicInfo/`, `.claude/`, `重要项目信息/`, `tools/`, `.githooks/`

3. **退出码约定**：
   - `0` - 检查通过
   - `1` - 未授权操作（跨 workspace 写入）
   - `2` - 锁冲突（TODO: 尚未实现）
   - `3` - 参数错误或脚本内部错误

#### 使用示例

```bash
# 检查 iOS Agent 是否可以写入指定文件
./tools/agent_guard.sh --check-write --workspace=ios \
  --files="guanzhi/View/FrontPages/SearchView.swift" --actor=cc

# 检查多个文件
./tools/agent_guard.sh --check-write --workspace=ios \
  --files="guanzhi.xcodeproj/project.pbxproj,Podfile,guanzhi/View/MapPages/MapView.swift" \
  --actor=cc

# 检查跨 workspace 写入（会被拒绝）
./tools/agent_guard.sh --check-write --workspace=ios \
  --files="Server/onettoo/src/main/java/Main.java" --actor=cc
# 输出: ❌ 检测到跨 workspace 写入，操作被拒绝
# 退出码: 1

# 检查例外目录（会通过）
./tools/agent_guard.sh --check-write --workspace=backend \
  --files="projectBasicInfo/logs/2026-02-03-test-cc.md" --actor=cc
# 输出: ✓ projectBasicInfo/logs/... (例外目录，允许所有 Agent 写入)
```

#### 测试结果

所有基本测试通过：

| 测试场景 | 预期结果 | 实际结果 |
|---------|---------|---------|
| iOS workspace 内文件访问 | 通过 (退出码 0) | ✅ 通过 |
| 跨 workspace 写入检测 | 拒绝 (退出码 1) | ✅ 拒绝 |
| 例外目录访问 | 通过 (退出码 0) | ✅ 通过 |
| 多文件检查 | 正确逐个检查 | ✅ 正确 |
| 工程文件匹配（.xcodeproj） | 正确识别 | ✅ 正确 |

---

## 技术细节

### 问题 1：bash 关联数组兼容性

**现象**：
```bash
./tools/agent_guard.sh: line 27: ios: unbound variable
```

**原因**：
macOS 默认的 bash 版本是 3.2.57，不支持关联数组（`declare -A`，需要 bash 4.0+）。

**解决方案**：
使用函数 `get_workspace_patterns()` 代替关联数组，通过 `case` 语句返回对应的路径模式。

```bash
# 修改前（bash 4.0+ 语法）
declare -A WORKSPACES=(
    ["ios"]="guanzhi/|Podfile|..."
)

# 修改后（bash 3.2+ 兼容）
get_workspace_patterns() {
    local workspace="$1"
    case "$workspace" in
        ios)
            echo "guanzhi/|Podfile|..."
            ;;
        *)
            return 1
            ;;
    esac
}
```

### 问题 2：工程文件扩展名匹配

**需求**：
iOS workspace 包含 `.xcodeproj`, `.xcworkspace` 等扩展名文件，需要模糊匹配。

**解决方案**：
在 `file_belongs_to_workspace()` 函数中，对以 `.` 开头的模式使用包含匹配（`*$pattern*`），而非前缀匹配。

```bash
# 如果模式以 . 开头（如 .xcodeproj），匹配包含该扩展名的路径
if [[ "$pattern" == .* ]]; then
    if [[ "$file_path" == *"$pattern"* ]]; then
        return 0  # 属于
    fi
fi
```

---

## 下一步工作

根据 v2.0 规划文档，接下来进入 **Phase 1: Guard 骨架 + 跨 workspace 阻断**（优先级 1，预计 1 天）：

### Stage 0: 资产盘点（已完成 50%）

- [x] 读取最近 5 个操作日志
- [ ] 汇总常见 workspace 操作模式（需补充）
- [ ] 确定锁粒度（推荐：workspace 级别）

### Stage 2: Workspace 边界划定 + 写入阻断（进行中）

- [x] 定义 4 个 workspace 边界
- [x] 实现基础的跨 workspace 写入检测
- [ ] 集成到 Git Hooks（core.hooksPath）
- [ ] 集成到 CI（如果存在）
- [ ] 编写测试场景（至少 5 个）

**预计时间**：1-2 天

---

## 相关文件

- `tools/agent_guard.sh` - 新建（v0.1.0 骨架）
- `.gitignore` - 已更新（添加 .locks/）
- `projectBasicInfo/logs/2026-02-02-agent-collaboration-optimization-plan-cc.md` - v2.0 规划文档

---

## 总结

立即行动清单已全部完成，Agent Guard 脚本骨架实现并通过基本测试。脚本兼容 macOS 默认的 bash 3.2 版本，支持跨 workspace 写入检测和权限例外目录。

接下来将进入 Phase 1 的 Stage 2，完成 Git Hooks 集成和更完善的测试场景覆盖。
