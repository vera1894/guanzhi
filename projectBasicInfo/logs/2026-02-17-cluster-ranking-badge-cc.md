# 聚合列表排名排序 + 「最新」徽章系统

**日期**: 2026-02-17
**角色**: Claude Code
**类型**: 功能开发

---

## 背景

聚合标注的缩略图和列表之前没有排序逻辑，使用 MKMapKit 内部聚合的随机顺序。用户希望综合展示最有价值的内容，并给最新内容更强的曝光。

## 目标

1. 聚合列表按加权互动评分排序
2. 48h 内发布的观之置顶 + 显示「最新」徽章
3. 聚合缩略图优先展示最新内容

## 方案

### 排名公式

借鉴 X/Twitter 开源算法的加权互动评分思路：

```
interactionScore = 1.0×agreeCount + 3.0×checkinCount + 5.0×commentCount - 2.0×neutralCount
recencyMultiplier = pow(0.5, ageSeconds / (168 * 3600))  // 7 天半衰期
healthMultiplier = 1.0 - 0.3 × (fadeScore / 100)
finalScore = (1 + max(0, interactionScore)) × recencyMultiplier × healthMultiplier
```

权重设计依据：
| 信号 | X/Twitter 对应 | 本 app 权重 |
|------|---------------|-----------|
| 评论 commentCount | 回复 Reply | 5.0 |
| 签到 checkinCount | 保存/深度参与 | 3.0 |
| 正向贴纸 agreeCount | 点赞 Like | 1.0 |
| 负向贴纸 neutralCount | 负反馈 | -2.0 |

### 列表排序规则

- **置顶区**：48h 内发布，按 createDate 降序，最多 3 条
- **排名区**：其余观之，按 finalScore 降序
- 置顶区观之不出现在排名区

### 「最新」徽章

- 位置：ShareSingleView 缩略图左上角
- 样式：胶囊形，半透明黑底 + 白色文字 "最新"
- 通过 `showNewBadge: Bool = false` 参数控制，默认关闭，不影响个人主页等其他使用场景

## 修改的文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `ModelsForMap/ClusterShareRanker.swift` | **新建** | 排名工具类（score/rank/isNew） |
| `View/MyPages/ShareSingleView.swift` | 修改 | 添加 `showNewBadge` 参数和徽章 overlay |
| `View/FrontPages/SearchView.swift` | 修改 | `clusterListContent` 接入 `ClusterShareRanker.rank()` |
| `View/MapPages/ClusterShareListView.swift` | 修改 | 备用路径的 `convertToResponsedShares()` 同步排名 |
| `View/MapPages/ClusterAnnotationView.swift` | 修改 | `configure()` 优先选 48h 内最新成员缩略图 |

## 设计决策

1. **纯客户端排序**：所有数据已在 `cachedResponsedShares` 中，无需后端改动
2. **ClusterAnnotationView 简化策略**：UIKit 层无法访问 `cachedResponsedShares`，仅按 `createDate` 判断最新
3. **showNewBadge 默认 false**：确保个人主页等其他使用 ShareSingleView 的场景不受影响
4. **7 天半衰期**：比 X/Twitter 的 6h 长很多，因为本 app 用户量少、内容寿命长

## 编译验证

Xcode build 通过 (**BUILD SUCCEEDED**)，无编译错误。
