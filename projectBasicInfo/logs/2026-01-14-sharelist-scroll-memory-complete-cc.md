# ShareListView 滚动位置记忆功能 - 完成报告

**日期**: 2026-01-14
**作者**: Claude Code
**状态**: 已完成

---

## 一、问题描述

个人主页中的观之列表（ShareListView）点击进入详情页后返回，列表回到顶部，无法恢复到之前的滚动位置。

---

## 二、问题根因分析

### 2.1 初始实现问题

初始实现参考 MessagesView 的 `ScrollView + LazyVStack + ScrollViewReader` 结构，但发现 `scrollTo` 执行后仍然无效。

### 2.2 深入分析对比

通过对比三种列表实现，发现关键差异：

| 特性 | 聚合列表 (ClusterList) | 消息列表 (MessagesView) | 观之列表 (ShareListView) |
|------|------------------------|------------------------|------------------------|
| **组件** | `HostingTableView` (UIKit) | `ScrollView + LazyVStack` | `ScrollView + LazyVStack` |
| **恢复机制** | 内置 `restoreToID` | 手动 `restoreScrollIfPossible` | 手动 `restoreScrollIfPossible` |
| **数据加载** | 不刷新，保持原数据 | **`loadIfNeeded()` 首次加载** | **`.task` 每次都加载** ❌ |
| **防重复加载** | 保持 `savedClusterAnnotations` | **`didInitialLoad` 标记** | **无** ❌ |

### 2.3 根本原因

**MessagesView 有关键保护机制**：

```swift
// MessagesViewModel
var didInitialLoad = false

func loadIfNeeded() async {
    guard !didInitialLoad else {
        print("📬 [Messages] loadIfNeeded: 已加载过，跳过")
        return
    }
    didInitialLoad = true
    // 首次加载...
}
```

**ShareListView 缺少这个保护**：

```swift
// ShareListView - 原实现
.task {
    try await timelineVM.fetchUserShareList(...)  // ❌ 每次都执行！
}
```

**问题流程**：
1. 用户点击观之 → 保存 `targetId=87` → 进入详情页
2. 用户返回 → `.task` **再次执行** `fetchUserShareList`
3. 数据重新加载 → **ScrollView 重置到顶部**
4. `scrollTo(87)` 执行但被数据刷新覆盖

---

## 三、解决方案

### 3.1 UserTimelineViewModel 添加防重复加载机制

**文件**: `guanzhi/ModelsForNetwork/UserTimelineViewModel.swift`

```swift
/// 是否已完成首次加载（避免返回时重复刷新，覆盖滚动恢复）
var didInitialLoad = false

/// 仅在首次时加载数据，返回时跳过（避免覆盖滚动恢复）
func loadIfNeeded(
    userId: Int,
    lat: Double,
    lon: Double,
    radius: Double = 10
) async throws {
    guard !didInitialLoad else {
        print("📋 [UserTimelineViewModel] loadIfNeeded: 已加载过，跳过（保持滚动位置）")
        return
    }
    didInitialLoad = true
    print("📋 [UserTimelineViewModel] loadIfNeeded: 首次加载")
    try await fetchUserShareList(userId: userId, lat: lat, lon: lon, radius: radius)
}

/// 强制刷新（用户主动下拉刷新时使用）
func forceRefresh(
    userId: Int,
    lat: Double,
    lon: Double,
    radius: Double = 10
) async throws {
    print("📋 [UserTimelineViewModel] forceRefresh: 强制刷新")
    try await fetchUserShareList(userId: userId, lat: lat, lon: lon, radius: radius)
}
```

### 3.2 ShareListView 使用 loadIfNeeded()

**文件**: `guanzhi/View/MyPages/ShareListView.swift`

```swift
.task {
    // 只在首次加载数据，返回时跳过（避免覆盖滚动恢复）
    do {
        try await timelineVM.loadIfNeeded(
            userId: userId,
            lat: lat,
            lon: lon,
            radius: radius
        )
    } catch {
        print("加载用户分享列表出错：\(error)")
    }
}
```

### 3.3 事件驱动的滚动恢复

将 `.onReceive(shareDetailDidDisappear)` 移到最外层 VStack，确保即使 ScrollView 重建也能收到通知：

```swift
// 最外层 VStack
.onReceive(NotificationCenter.default.publisher(for: .shareDetailDidDisappear)) { _ in
    // 设置标记，触发 ScrollView 内部的恢复
    needsScrollRestore = true
}

// ScrollView 内部
.onChange(of: needsScrollRestore) { _, newValue in
    if newValue {
        needsScrollRestore = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            tryRestoreIfPending(proxy)
        }
    }
}
```

---

## 四、修复后的流程

```
用户点击观之 → 保存 targetId=87 → 进入详情页
         ↓
用户返回 → .task 调用 loadIfNeeded()
         ↓
didInitialLoad = true → 跳过加载（数据保持不变）
         ↓
shareDetailDidDisappear 通知 → needsScrollRestore = true
         ↓
ScrollView.onChange(needsScrollRestore) → scrollTo(87)
         ↓
✅ 滚动位置恢复成功
```

---

## 五、修改的文件清单

| 文件 | 修改内容 |
|------|----------|
| `AppStateModel.swift` | 添加 `ShareListTab`、`ShareListScrollKey`、`ShareListScrollState`、`pendingRestore` 字段、相关辅助方法 |
| `UserTimelineViewModel.swift` | 添加 `didInitialLoad` 标记、`loadIfNeeded()` 方法、`forceRefresh()` 方法 |
| `ShareListView.swift` | List 改为 ScrollView + LazyVStack + ScrollViewReader、添加事件驱动恢复逻辑、使用 `loadIfNeeded()` |

---

## 六、关键学习点

### 6.1 SwiftUI 列表滚动恢复的核心要点

1. **数据稳定性**：返回时不能重新加载数据，否则 ScrollView 会重置
2. **事件时机**：使用 `shareDetailDidDisappear` 通知确保详情页完全消失后再恢复
3. **状态分离**：`pendingRestore` 和 `didRestore` 分开管理，避免"执行了但没生效却已标记完成"

### 6.2 与 UIKit TableView 的差异

- **UIKit TableView**：内置 `restoreToID`，数据更新不影响滚动位置
- **SwiftUI ScrollView**：需要手动管理，数据更新会重置滚动位置

---

## 七、测试清单

- [ ] tabA（全部观之）中间点进详情 → 返回恢复到原位置
- [ ] tabB（已褪色）中间点进详情 → 返回恢复到原位置
- [ ] tabA 点进 → 返回 → 切 tabB → 返回 → 切回 tabA（不串、不乱跳）
- [ ] 进入别人主页（userId 变化）不复用自己主页滚动位置
- [ ] 下拉刷新后不会被拉回旧位置

---

## 八、相关文件

- `AppStateModel.swift` - NavigationCoordinator 和滚动状态定义
- `UserTimelineViewModel.swift` - 数据加载控制
- `ShareListView.swift` - 观之列表视图
- `MessagesView.swift` - 参考实现
- `SearchView.swift` - 聚合列表参考（ClusterList）
