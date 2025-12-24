# iOS 客户端投票系统代码清理

**日期**: 2025-12-24
**作者**: Claude Code
**类型**: 代码清理 / 重构

---

## 背景

在 2025-12-22 完成后端投票系统废弃后（见 `2025-12-22-vote-system-removal-cc.md`），iOS 客户端仍保留了部分过时的投票系统代码。本次清理旨在移除这些不再使用的代码，使代码库更加简洁。

**关键信息**：
- 原投票系统（like/neutral 互斥投票）已完全废弃
- 所有贴纸（包括赞同/无感）现在都使用统一的标签系统
- 贴纸之间的互斥逻辑由服务器统一控制

---

## 清理内容

### 1. StickerKind.swift

**删除的属性和方法**：
```swift
// 已删除
var isVoteType: Bool { ... }
var isTagType: Bool { ... }
var asVoteState: VoteState? { ... }
static func from(voteState: VoteState) -> StickerKind? { ... }
static var voteTypes: [StickerKind] { ... }
static var tagTypes: [StickerKind] { ... }
```

**修改**：
- `tagCode` 属性改为非可选类型，所有贴纸都有 tagCode
- `like` 的 tagCode: `"LIKE"`
- `neutral` 的 tagCode: `"NEUTRAL"`

### 2. ShareInteractionViewModel.swift

**删除的内容**：
```swift
// 已删除
enum VoteState: Int {
    case none = 0
    case liked = 1
    case neutral = 2
}

@Published var voteState: VoteState = .none
private var _agreeCount: Int = 0
private var _neutralCount: Int = 0
```

**修改**：
- `initialize(share:onStateChanged:)` 简化为 `initialize(share:)`
- 移除了 `onStateChanged` 回调参数

### 3. OTORequests.swift

**删除的 case**：
```swift
// 已删除
case voteShare(shareId: Int64, voteType: Int)
```

**删除的请求定义**：
```swift
// 已删除
case .voteShare(let shareId, let voteType):
    return .init(
        path: "/api/guan/share/vote",
        method: .post,
        param: [
            "shareId": shareId,
            "voteType": voteType
        ]
    )
```

### 4. ShareService.swift

**删除的方法**：
```swift
// 已删除
func voteShare(shareId: Int64, voteType: Int) async throws -> VoteShareResponse { ... }
```

### 5. InteractionOverlayView.swift

**修改的初始化器**：
```swift
// 之前
init(share: Share, viewModel: ShareInteractionViewModel, onVoteStateChanged: ...)

// 现在
init(share: Share, viewModel: ShareInteractionViewModel)
```

### 6. ShareDetailView.swift

**删除的方法**：
```swift
// 已删除
private func makeStateChangedCallback() -> ((VoteState, Int, Int) -> Void) { ... }
```

**修改的调用**：
```swift
// 之前
interactionViewModel.initialize(share: share, onStateChanged: makeStateChangedCallback())

// 现在
interactionViewModel.initialize(share: share)
```

### 7. StickerSummaryBar.swift

**修改**：
```swift
// 之前
private var textFallbackBackgroundColor: Color {
    definition.kind.isVoteType ? Color.orange.opacity(0.3) : Color.blue.opacity(0.3)
}

// 现在
private var textFallbackBackgroundColor: Color {
    switch definition.kind {
    case .like, .neutral:
        return Color.orange.opacity(0.3)
    default:
        return Color.blue.opacity(0.3)
    }
}
```

### 8. StickerDefinition.swift

**修改**：
```swift
// 之前
static var mockAll: [StickerDefinition] {
    StickerKind.voteTypes.map { ... }
}

// 现在
static var mockAll: [StickerDefinition] {
    StickerKind.allCases.map { ... }
}
```

---

## 保留内容

以下内容保留未动：

1. **服务器端 `voteShare` API** - 保持向后兼容，旧版本客户端可能仍在使用
2. **历史文档** - `项目信息记录/11.27 分享详情中交互实现.md` 作为历史参考
3. **服务器端 Java 控制器** - `GuanZhiController.java` 中的投票接口

---

## 更新的文档

- `projectBasicInfo/01_PROJECT_OVERVIEW.md` 更新至 v1.9
  - 更新了 `ShareInteractionViewModel` 的属性列表
  - 记录了已移除的过时代码
  - 更新了核心规则描述

---

## 验证

- [x] 编译通过
- [x] 基本功能测试通过
- [x] 贴纸系统正常工作

---

## 相关文件变更列表

| 文件 | 变更类型 |
|------|----------|
| `StickerKind.swift` | 修改 |
| `ShareInteractionViewModel.swift` | 修改 |
| `OTORequests.swift` | 修改 |
| `ShareService.swift` | 修改 |
| `InteractionOverlayView.swift` | 修改 |
| `ShareDetailView.swift` | 修改 |
| `StickerSummaryBar.swift` | 修改 |
| `StickerDefinition.swift` | 修改 |
| `01_PROJECT_OVERVIEW.md` | 修改 |
