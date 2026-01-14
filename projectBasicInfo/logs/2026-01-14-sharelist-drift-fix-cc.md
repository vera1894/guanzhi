# ShareListView 底部向上漂移修复

**日期**: 2026-01-14
**作者**: Claude Code
**状态**: 已完成

---

## 问题描述

个人页面的观之列表（ShareListView）在底部向上多拉几次时，会出现"向上漂移"现象。

这与之前聚合列表（ClusterList）出现过的问题相同。

---

## 根本原因

ShareListView 使用 SwiftUI 的 `ScrollView + LazyVStack`，而 SwiftUI 的 ScrollView 无法完全禁用边界回弹（bounces）。

即使使用 `.scrollBounceBehavior(.basedOnSize)` 也只能缓解，无法根治。

---

## 解决方案

将 `ScrollView + LazyVStack` 替换为 `HostingTableView`（UIKit UITableView 包装器），并设置 `bouncesEnabled: false`。

这与 ClusterList 在 Overlay 模式下使用的方案一致。

---

## 代码修改

**文件**: `guanzhi/View/MyPages/ShareListView.swift`

### 修改前

```swift
// 使用 ScrollView + LazyVStack + ScrollViewReader（与 MessagesView 一致）
ScrollViewReader { proxy in
    ScrollView {
        LazyVStack(spacing: 0) {
            ForEach(currentShares, id: \.id) { shareItem in
                ShareSingleView(share: shareItem) { ... }
                    .id(shareItem.id)
                Divider()
            }
        }
    }
    .onAppear { tryRestoreIfPending(proxy) }
    .onChange(of: currentShares.count) { ... }
    .onChange(of: navigationCoordinator.path.count) { ... }
    .onChange(of: needsScrollRestore) { ... }
}
```

### 修改后

```swift
// 使用 HostingTableView（UIKit）解决底部回弹漂移问题
HostingTableView(
    items: currentShares,
    id: \.id,
    row: { shareItem in
        VStack(spacing: 0) {
            ShareSingleView(share: shareItem) {
                // 点击时保存滚动位置
                navigationCoordinator.saveShareListScrollPosition(
                    userId: userId,
                    tab: selectedTab,
                    shareId: shareItem.id
                )
            }
            .environment(\.appState, appState)
            .environmentObject(searchViewModel)
            .environmentObject(navigationCoordinator)

            Divider()
                .padding(.leading, 16)
        }
    }
)
.bouncesEnabled(false)  // 关键：禁用回弹，解决向上漂移问题
.showsSeparators(false)
.restoreToID(restoreTargetId)  // 滚动恢复目标
```

### 滚动恢复逻辑适配

```swift
// 状态变量
@State private var restoreTargetId: Int? = nil

// 监听通知：从详情页返回时恢复滚动位置
.onReceive(NotificationCenter.default.publisher(for: .shareDetailDidDisappear)) { _ in
    guard let state = navigationCoordinator.getShareListScrollState(...),
          state.pendingRestore,
          !state.didRestore,
          let targetId = state.lastShareId else {
        return
    }

    // 设置恢复目标 ID，HostingTableView 会自动滚动
    restoreTargetId = targetId

    // 标记恢复完成
    navigationCoordinator.markShareListRestoreComplete(userId: userId, tab: selectedTab)
}
```

### 删除的代码

- `needsScrollRestore` 状态变量
- `tryRestoreIfPending(_ proxy:)` 方法
- `restoreScrollIfPossible(_ proxy:)` 方法
- `formattedDate(_ timeInterval:)` 方法（未使用）

---

## 技术对比

| 组件 | 列表实现 | 回弹控制 | 漂移问题 |
|------|----------|----------|----------|
| ClusterList (Overlay) | `HostingTableView` | `bouncesEnabled: false` | 无 |
| ShareListView (修复前) | `ScrollView + LazyVStack` | 无法禁用 | 有 |
| ShareListView (修复后) | `HostingTableView` | `bouncesEnabled: false` | 无 |

---

## 相关文件

- `View/MyPages/ShareListView.swift` - 本次修改
- `View/Shared/UIKitListKit/HostingTableView.swift` - UIKit 列表组件
- `View/Shared/UIKitListKit/HostingTableViewController.swift` - UITableViewController 实现

---

## 相关日志

- [2026-01-05 聚合列表 Overlay 优化](2026-01-05-cluster-list-overlay-optimization-cc.md) - ClusterList 的漂移修复
- [2026-01-05 HostingTableView 组件计划](2026-01-05-hosting-tableview-component-plan.md) - UIKit 列表组件设计
- [2026-01-14 ShareListView 滚动记忆完成](2026-01-14-sharelist-scroll-memory-complete-cc.md) - 滚动记忆功能
