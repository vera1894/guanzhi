# 聚合列表状态恢复修复

**日期**: 2026-01-23
**作者**: Claude Code
**状态**: ✅ 已完成

---

## 问题描述

从聚合列表导航至详情页，再进入用户主页（OthersView），最后返回时：
- 底部 sheet 和 MapOverlayView 错误地与聚合列表同时显示
- 期望行为：返回时应只显示聚合列表，不显示搜索框 sheet

**关键发现**：直接从详情页返回聚合列表正常工作，只有进入用户主页后再返回才出现问题。

---

## 根因分析

问题有多个层次：

### 1. @State 变量在导航时丢失
`SearchView` 中的 `@State` 变量（`savedClusterAnnotations` 等）在导航过程中因视图重建而丢失。

### 2. 嵌套详情页触发恢复逻辑
当用户在 `OthersView` 的 `ShareListView` 中点击某个 Share 时，会创建嵌套的 `ShareDetailView`。当这个嵌套详情页返回时，它的 `onDisappear` 也会发送 `shareDetailDidDisappear` 通知，过早触发 `restoreClusterListIfNeeded()`，清空保存的状态。

### 3. 导航链路
```
聚合列表 → 详情页 A → 用户主页 → 详情页 B（用户的其他分享）→ 返回
                                      ↑
                            此处 onDisappear 触发恢复，
                            清空了原本保存的聚合列表状态
```

---

## 解决方案

实施三层保护机制：

### 1. 状态持久化到 SearchViewModel
将聚合列表恢复状态从 `@State` 移到 `SearchViewModel`（`@Published`），避免视图重建导致状态丢失。

### 2. 添加导航栈检查
在 `restoreClusterListIfNeeded()` 中添加 `path.isEmpty` 检查，只有当导航栈完全清空时才恢复聚合列表，防止嵌套详情页返回时过早触发。

### 3. ShareDetailView 条件检查
在 `ShareDetailView.onDisappear` 中检查 `shouldRestoreClusterList`，避免覆盖聚合列表恢复路径。

---

## 修改文件

### 1. SearchViewModel.swift（第 59-68 行）

新增聚合列表恢复状态属性：

```swift
// MARK: - 聚合列表恢复状态（从 @State 移到这里，避免视图重建导致状态丢失）
@Published var savedClusterAnnotations: [CustomAnnotation] = []
@Published var savedClusterListDetent: PresentationDetent = .medium
@Published var savedScrollToShareId: Int? = nil
```

### 2. SearchView.swift

**移除 @State 变量**（第 66-68 行）：
```swift
// ✅ savedClusterAnnotations/savedClusterListDetent/savedScrollToShareId 已移到 SearchViewModel 中
// 避免视图重建导致状态丢失（导航到用户主页再返回时的问题）
```

**更新引用**（第 147-149 行）：
```swift
searchViewModel.savedClusterAnnotations = clusterAnnotations
searchViewModel.savedClusterListDetent = clusterListDetent
searchViewModel.savedScrollToShareId = share.id
```

**添加关键检查**（`restoreClusterListIfNeeded()` 方法，第 183-229 行）：
```swift
private func restoreClusterListIfNeeded() {
    let pathCount = navigationCoordinator.path.count
    print("🔷 [ClusterList] restoreClusterListIfNeeded called, shouldRestore=\(appState.shouldRestoreClusterList), pathCount=\(pathCount), savedCount=\(searchViewModel.savedClusterAnnotations.count)")

    // ✅ 关键修复：只有当导航栈完全清空时才恢复聚合列表
    guard navigationCoordinator.path.isEmpty else {
        print("🔷 [ClusterList] 导航栈不为空（pathCount=\(pathCount)），跳过恢复")
        return
    }

    guard appState.shouldRestoreClusterList else { ... }
    guard !searchViewModel.savedClusterAnnotations.isEmpty else { ... }

    // 执行恢复逻辑...
}
```

### 3. ShareDetailView.swift（第 823-865 行）

添加 `shouldRestoreClusterList` 检查：
```swift
.onDisappear {
    appState.isInShareDetailView = false
    NotificationCenter.default.post(name: .shareDetailDidDisappear, object: nil)

    // ✅ 修复：检查是否需要恢复聚合列表
    if navigationCoordinator.path.isEmpty && !appState.shouldRestoreClusterList {
        print("🔷 [ShareDetail] 恢复搜索框 sheet（非聚合列表恢复路径）")
        withAnimation(.easeInOut) {
            // 恢复 sheet 状态...
        }
    } else if navigationCoordinator.path.isEmpty {
        print("🔷 [ShareDetail] 跳过搜索框恢复（聚合列表恢复路径）")
    }
}
```

### 4. OthersView.swift（第 179-186 行）

添加相同的条件检查：
```swift
.onDisappear {
    if navigationCoordinator.path.isEmpty && !appState.shouldRestoreClusterList {
        appState.isShowingSearchView = true
    }
}
```

---

## 调试日志

修复后的正确日志流程：
```
🔷 [ClusterList] 保存聚合列表状态，count=5
🔷 [ShareDetail] onDisappear - shouldRestoreClusterList=true
🔷 [ShareDetail] 跳过搜索框恢复（聚合列表恢复路径）
🔷 [ClusterList] restoreClusterListIfNeeded called, pathCount=0, savedCount=5
🔷 [ClusterList] 恢复成功
```

---

## 技术要点

1. **SwiftUI 视图生命周期**：@State 变量在视图重建时可能丢失，需要将重要状态存储在 ObservableObject 中
2. **NotificationCenter 同步通知**：所有订阅者会同步执行，需要注意执行顺序
3. **嵌套导航场景**：需要检查导航栈状态来区分不同的返回场景
4. **三层保护模式**：通过多重条件检查确保状态恢复的正确时机
