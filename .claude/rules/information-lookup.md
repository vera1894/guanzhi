# 信息查找策略

> **本规则优先级高于默认探索行为。** 接到任务后，按以下步骤查找信息，禁止跳过前面的步骤直接启动 Explore。

## 步骤 1：检查已加载的上下文

MEMORY.md 已自动注入（含数据库连接、部署经验、iOS 踩坑记录），rules/ 已自动加载。
**先检查这些内容是否已包含所需信息**，能直接用就直接用。

## 步骤 2：查 CLAUDE.md 任务索引定位文档

根据任务类型（后端/iOS/部署/服务器）查阅 CLAUDE.md 中的任务索引表，只阅读对应的 1-2 个文档。

## 步骤 3：用 Grep/Glob 做针对性搜索

**用搜索工具代替 Explore。** 常用搜索模式：

- iOS 代码定位：`Grep pattern="关键词" type="swift"`
- 后端代码定位：`Grep pattern="关键词" path="Server/onettoo/src" type="java"`
- 查找 View 文件：`Glob pattern="guanzhi/View/**/*.swift"`
- 查找 Model 文件：`Glob pattern="guanzhi/Models*/**/*.swift"`
- 查找网络模型：`Glob pattern="guanzhi/ModelsForNetwork/**/*.swift"`

## 步骤 4：阅读搜索命中的文件

根据 Grep/Glob 结果，用 Read 阅读相关文件。

## 步骤 5：Explore（最后手段）

**仅当以上 4 步都无法定位信息时**，才启动 Explore 子代理。需要启动 Explore 时，限定搜索范围（如只搜 `guanzhi/View/` 而不是整个项目）。

---

## 示例

| 任务 | 正确做法 | 错误做法 |
|------|---------|---------|
| "分享功能消失了" | `Grep pattern="share\|分享" type="swift"` → 读命中文件 | Explore 整个项目 |
| "重置数据库字段" | 查 MEMORY.md 数据库连接 → 查 02_CONNECTIONS → 执行 SQL | Explore 整个项目 |
| "修改详情页 UI" | `Grep pattern="Detail" type="swift"` → 读命中的 View 文件 | 阅读全部 projectBasicInfo |
| "后端部署" | 查任务索引 → 读 05_DEPLOYMENT_SSOT.md → 执行 | 遍历 Server/ |
