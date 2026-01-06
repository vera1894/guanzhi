# 褪色度 UI 显示修复

**日期**: 2026-01-06
**作者**: Claude Code

---

## 背景

用户反馈聚合列表（ClusterList）中的褪色度显示为 0，而个人主页列表显示正确。

## 问题分析

### 数据流追踪

```
服务器返回 ResponsedShare (fadeScore: 32, 30, 12 等)
    ↓
SearchViewModel.refreshNearbyShares() 保存到 SwiftData
    ↓
Share 对象（SwiftData）
    ↓
CustomAnnotation.annotationData
    ↓
SearchView.convertAnnotationsToShares() ← 问题所在
    ↓
ShareSingleView 显示
```

### 根本原因

`SearchView.swift` 中的 `convertAnnotationsToShares()` 函数第 107 行硬编码了 `fadeScore: 0`：

```swift
// 修复前
return ResponsedShare(
    // ... 其他字段
    fadeScore: 0  // 硬编码为 0
)
```

**注意**：`ClusterShareListView.swift` 虽然存在且包含正确的修复代码，但实际聚合列表使用的是 `SearchView.swift` 内部的 `clusterListContent`，它调用 `convertAnnotationsToShares()` 函数。

## 修复方案

### 1. SearchView.swift - convertAnnotationsToShares()

优先从 `cachedResponsedShares` 获取原始数据：

```swift
private func convertAnnotationsToShares(_ annotations: [CustomAnnotation]) -> [ResponsedShare] {
    return annotations.compactMap { annotation -> ResponsedShare? in
        guard let share = annotation.annotationData else { return nil }
        let shareId = Int(share.id)

        // 优先从缓存获取原始的 ResponsedShare（包含正确的 fadeScore 等字段）
        if let cached = searchViewModel.cachedResponsedShares[shareId] {
            return cached
        }

        // 回退：从本地 Share 对象转换
        return ResponsedShare(
            // ... 其他字段
            fadeScore: share.fadeScore  // 使用本地数据
        )
    }
}
```

### 2. 之前已完成的修复（本次确认仍有效）

- `SearchViewModel.swift` - 添加 `cachedResponsedShares` 属性缓存服务器数据
- `ShareSingleView.swift` - 添加褪色度标签显示
- `ShareListView.swift` - Tab 切换（全部观之 / 已褪色）

## 修改的文件

| 文件 | 修改内容 |
|------|----------|
| `SearchView.swift` | `convertAnnotationsToShares()` 优先从缓存获取数据 |
| `01_PROJECT_OVERVIEW.md` | 添加褪色度 UI 显示说明 |

## UI 效果

### 个人主页分享列表
- Tab 1 "全部观之"：显示所有未删除的分享
- Tab 2 "已褪色"：显示 `fadeScore >= 100` 的分享

### 分享条目显示
- 标题限制 2 行，超出显示省略号
- ID 行上方显示 "褪色度：n%"
- `fadeScore >= 90` 时标签为红色

### 聚合列表
- 点击地图聚合标注显示列表
- 每条分享正确显示褪色度

## 验证步骤

1. 重新编译运行 App
2. 进入地图页面，等待分享数据加载
3. 点击聚合标注，查看列表中的褪色度是否正确显示
4. 进入个人主页，验证 "全部观之" 和 "已褪色" Tab 功能
