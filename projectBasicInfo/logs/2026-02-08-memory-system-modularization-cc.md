# 记忆系统重构 & 架构模块化

**日期**：2026-02-08
**角色**：Claude Code
**类型**：架构改造

---

## 第一阶段：记忆系统重构（已完成）

### 问题
- MEMORY.md 只有 ~30 行，80+ 个会话的经验未沉淀
- jsonl 文件最大 130MB，充满噪音，不可用作有效记忆
- 经验回流完全依赖用户手动提醒

### 改造内容

**创建 memory/ 主题文件体系**：
```
memory/
├── MEMORY.md          # 62 行索引 + 关键经验（≤200行，自动注入）
├── ios-dev.md         # SwiftUI 导航、滚动、评论、贴纸、时区
├── backend-deploy.md  # Flyway、JDBC、systemd、S3、SSM
├── notification.md    # 频率限制、幂等性、事件体系
└── architecture.md    # 贴纸替投票、评论删除、时区、术语
```

**建立自动回流机制**：
- CLAUDE.md 末尾增加「记忆回流」章节
- settings.json 添加 Stop hook，每次回复结束提醒回流

### 修改的文件
- `~/.claude/projects/.../memory/MEMORY.md` — 重写
- `~/.claude/projects/.../memory/ios-dev.md` — 新建
- `~/.claude/projects/.../memory/backend-deploy.md` — 新建
- `~/.claude/projects/.../memory/notification.md` — 新建
- `~/.claude/projects/.../memory/architecture.md` — 新建
- `guanzhi/CLAUDE.md` — 追加回流指令
- `guanzhi/.claude/settings.json` — 添加 Stop hook

---

## 第二阶段：架构模块化（规划中）

### 目标
将写死在观之项目中的架构拆分为「全局框架层」和「项目实例层」，实现：
1. 新项目启动时自动询问是否启用「动态经验更新架构」
2. 如果启用，通过对话收集项目信息后自动创建配置
3. 跨电脑迁移只需同步 `~/.claude/CLAUDE.md` + `settings.json`

### 设计

```
全局层 ~/.claude/CLAUDE.md
  ├── 通用规则（语言、代码原则、工作模式）
  ├── 记忆回流行为指令
  └── 新项目自动引导逻辑
        → 检测到无 .claude/rules/ 时触发
        → 询问是否启用架构
        → 收集项目信息
        → 自动创建配置文件

项目层 {项目}/.claude/
  ├── settings.json          # hooks（参数化）
  ├── hooks/load-project-rules.sh  # 用 $CLAUDE_PROJECT_DIR
  └── rules/
      └── memory-reflux.md   # 回流规则（通用，自动加载）

项目入口 {项目}/CLAUDE.md    # 只含项目特有信息
```

### 实施步骤
1. 创建全局 `~/.claude/CLAUDE.md`（通用规则 + 引导逻辑）
2. 精简 `guanzhi/CLAUDE.md`（移除通用规则）
3. 参数化 hooks（`$CLAUDE_PROJECT_DIR` 替代硬编码）
4. 创建 `guanzhi/.claude/rules/memory-reflux.md`（自动加载）
