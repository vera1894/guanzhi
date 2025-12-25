# 分享详情页网络错误处理优化

**日期**: 2025-12-25
**执行者**: Claude Code
**相关文件**:
- `guanzhi/View/SharePages/CommentSectionView.swift`
- `guanzhi/ModelsForNetwork/UserProfileManager.swift`
- `guanzhi/View/SharePages/ShareDetailView.swift`
- `guanzhi/View/Features/StickerKit/Views/StickerSummaryBar.swift`
- `guanzhi/View/SharePages/ShareInteractionViewModel.swift`

## 需求背景

分享详情页在网络异常时存在以下问题：
1. 没有提示网络有问题或获取数据失败
2. 顶部用户名变成硬编码的"我"
3. 贴纸看板和贴纸队列变成清零状态，无错误提示
4. 评论区直接显示"暂无评论"，无错误提示

## 修改内容

### 1. CommentSectionView - 评论区错误状态

**位置**: `CommentSectionView.swift:42-67`

**变更**: 添加 `viewModel.error` 检查，显示"获取评论失败"和重试按钮

```swift
// 修改后
if viewModel.error != nil && viewModel.comments.isEmpty && !viewModel.isLoading {
    // 加载失败状态
    VStack(spacing: 12) {
        Image(systemName: "wifi.exclamationmark")
        Text("获取评论失败")
        Button("点击重试") {
            viewModel.error = nil
            await viewModel.loadComments(reset: true)
        }
    }
} else if viewModel.comments.isEmpty && !viewModel.isLoading {
    // 空状态
    Text("暂无评论")
}
```

---

### 2. UserProfileManager - 用户名缓存降级

**位置**: `UserProfileManager.swift:164-177`

**变更**: 新增 `getCachedNickname()` 方法，优先从内存读取，降级从 SwiftData 读取

```swift
func getCachedNickname() -> String? {
    // 优先使用内存中的 localUserProfile
    if let nickname = localUserProfile?.nickname, !nickname.isEmpty {
        return nickname
    }
    // 降级：从 SwiftData 缓存中读取
    let userId = OTOLoginStatusManager.shared.getUserID()
    if let cachedUser = findLocalUserInSwiftData(userId: userId) {
        return cachedUser.nickname.isEmpty ? nil : cachedUser.nickname
    }
    return nil
}
```

**位置**: `ShareDetailView.swift:1398-1400`

**变更**: 使用缓存昵称作为降级

```swift
// 修改前
capsuleContentSimple(nickname: "我", iconName: nil, onTap: {})

// 修改后
let cachedName = userProfileManager.getCachedNickname() ?? "我"
capsuleContentSimple(nickname: cachedName, iconName: nil, onTap: {})
```

---

### 3. StickerSummaryBar - 贴纸看板错误状态

**位置**: `StickerSummaryBar.swift:22-29, 45-71, 76-105`

**变更**: 添加 `loadingState` 和 `onRetry` 参数，增加加载中和错误状态视图

```swift
struct StickerSummaryBar: View {
    var loadingState: StickerLoadingState = .loaded
    var onRetry: () -> Void = {}

    var body: some View {
        switch loadingState {
        case .loading, .idle:
            loadingStateView      // "加载贴纸中..."
        case .failed:
            errorStateView        // "获取贴纸失败 点击重试"
        case .loaded:
            if items.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
    }
}
```

**位置**: `ShareDetailView.swift:517-527`

**变更**: 传入加载状态和重试回调

```swift
StickerSummaryBar(
    items: interactionViewModel.stickerSummaries,
    maxVisibleItems: 4,
    loadingState: interactionViewModel.stickerLoadingState,
    onTap: { ... },
    onRetry: { retryStickerLoad() }
)
```

---

### 4. ShareInteractionViewModel - 贴纸加载失败处理

**位置**: `ShareInteractionViewModel.swift:377-385`

**变更**: 达到最大重试次数后保持 `.failed` 状态，不再自动降级为 `.loaded`

```swift
// 修改前
self.fallbackToLocalAvailability()
self.stickerLoadingState = .loaded

// 修改后
// 保持 .failed 状态，让 UI 显示错误提示和重试按钮
self.stickerLoadingState = .failed(retryCount: newRetryCount)
```

---

## 效果总结

| 组件 | 网络正常 | 网络异常 |
|------|---------|---------|
| 评论区 | 显示评论列表 | "获取评论失败 点击重试" |
| 用户名 | 显示真实昵称 | 显示缓存昵称（最后才用"我"） |
| 贴纸看板 | 显示贴纸统计 | "获取贴纸失败 点击重试" |
| 贴纸队列 | 显示可用贴纸 | "贴纸加载失败 点击重试" |

---

## 构建验证

```
** BUILD SUCCEEDED **
```
