# fadeScore=100 分享隐藏功能 - 实现计划

**日期**: 2026-01-06
**作者**: Claude Code
**状态**: 已完成

---

## 产品规则（明确）

### fadeScore = 100 的分享

| 场景 | 是否可见 | 说明 |
|------|----------|------|
| 详情页 | **可访问** | 包括 Deep Link / 推送 / 搜索结果 / 历史记录 |
| 个人主页列表 | **可见** | "已褪色" Tab 显示 |
| 首页地图单标注 | **不可见** | 过滤不生成 annotation |
| 首页地图聚合标注 | **不可见** | 成员被过滤后自动消失 |
| 首页地图聚合列表 | **不可见** | 数据源来自 annotations |

### 关键边界

- **"隐藏"只发生在 Home Map 的 annotation pipeline**，不是数据层删除
- 不要把过滤写进通用的 Share 查询、数据库存储或全局列表层
- fadeScore=100 的分享仍然存在于本地数据库和缓存中

---

## 技术方案（SSOT）

### 核心原则

**单一事实源（Single Source of Truth）**：
- 在 `getAnnotations()` 中做一次过滤
- 使用 `cachedResponsedShares` 优先的 fadeScore
- 地图标注、聚合标注、聚合列表自动一致

### 数据流（过滤后）

```
getAnnotations()
    ↓ 过滤：effectiveFadeScore >= 100 的不创建 annotation
CustomAnnotation 列表（已排除 fadeScore=100）
    ↓ 聚合
MKClusterAnnotation（成员都是 fadeScore<100）
    ↓ 点击聚合后
SearchView.convertAnnotationsToShares()（天然不含 fadeScore=100）
    ↓
聚合列表（自动一致）
```

### fadeScore 取值策略

```swift
// 取 max(cached, local)，确保不会"低估"褪色度
let cachedFadeScore = cachedResponsedShares[shareId]?.fadeScore ?? 0
let effectiveFadeScore = max(cachedFadeScore, share.fadeScore)
```

**原因**：
- fadeScore 是单调递增的（褪色度只会越来越大）
- 取 max 更保守，确保 >=100 的隐藏更可靠
- 避免 cached 滞后于 local 时错误显示已褪色分享

**注意**：如果未来支持"褪色度回退"，需引入时间戳比较

---

## 修改点

### 唯一修改点：SearchViewModel.getAnnotations()

**文件**: `ModelsForMap/SearchViewModel.swift` 约第 934 行

```swift
for share in sharesInRegion {
    // 🆕 SSOT：取 max(cached, local) 确保不低估褪色度
    let cachedFadeScore = cachedResponsedShares[Int(share.id)]?.fadeScore ?? 0
    let effectiveFadeScore = max(cachedFadeScore, share.fadeScore)

    // 跳过已完全褪色的分享（Home Map 不可见）
    guard effectiveFadeScore < 100 else { continue }

    let wgsCoordinate = CLLocationCoordinate2D(...)
    // ... 创建 CustomAnnotation
}
```

### 兜底策略：不做

**决策**：只保留 SSOT 唯一过滤点，不在 `SearchView.convertAnnotationsToShares()` 添加兜底。

**原因**：
- 聚合列表数据源来自 annotations（已过滤），兜底基本不会触发
- 保持"唯一过滤点"更干净，减少维护成本
- 如未来需要兜底，应抽成公共 helper 避免逻辑重复

---

## 不需要修改的地方

| 组件 | 原因 |
|------|------|
| `ClusterShareListView.swift` | 主页聚合列表不用这个文件 |
| `CustomMKAnnotationView` | 只负责渲染，数据已在上游过滤 |
| `ClusterAnnotationView` | 成员自动减少，无需额外处理 |
| `ShareSingleView` | 数据已在上游过滤 |
| `ShareListView`（个人主页）| 需要显示已褪色分享，不过滤 |
| `ShareDetailView` | 详情页可访问，不过滤 |

---

## 本阶段不做的事项

1. **不做"已褪色"提示**
   - 不需要"仅在个人页可见"的拦截提示
   - 如后续要做，应该是弱提示（如详情页顶部小 banner），而不是拦截

2. **不修改后端 API**
   - 服务器仍返回所有分享（含 fadeScore=100）
   - 保持本地数据完整性，个人主页需要这些数据

3. **不修改数据库模型**
   - fadeScore=100 的分享仍存储在本地数据库
   - 只在 UI 层面（annotation pipeline）过滤

---

## 边界情况处理

| 场景 | 处理方式 | 状态 |
|------|----------|------|
| 聚合内所有成员都 fadeScore=100 | 聚合自动消失（无有效成员） | 自动 |
| 刷新后分享变为 100 | 下次 getAnnotations 时消失 | 自动 |
| 个人主页点进详情 | 允许查看 | 无需改 |
| Deep Link 访问 fadeScore=100 详情 | 允许查看（详情可访问，仅 Home Map 不显示） | 无需改 |

---

## 预估改动量

| 文件 | 改动行数 |
|------|----------|
| `SearchViewModel.swift` | +5 行 |

---

## 验证清单

- [ ] fadeScore=100 的分享在地图上不显示单标注
- [ ] fadeScore=100 的分享不出现在聚合列表中
- [ ] 聚合标注角标数量正确（不含 fadeScore=100）
- [ ] 个人主页"已褪色" Tab 仍能显示 fadeScore=100 的分享
- [ ] Deep Link 仍能打开 fadeScore=100 的分享详情
- [ ] 编译通过
