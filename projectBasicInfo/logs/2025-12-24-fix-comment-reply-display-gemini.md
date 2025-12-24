# 修复评论系统"回复 @xxx"显示问题

**日期**: 2025-12-24
**执行者**: Gemini
**相关文件**:
- `guanzhi/guanzhi/ModelsForNetwork/CommentModels.swift`
- `guanzhi/guanzhi/ModelsForNetwork/CommentViewModel.swift`

## 问题描述

在评论系统中，当用户回复一个"二级评论"时，前端页面在发送成功后没有立即显示"回复 @xxx"的字样，直到刷新页面才正常显示。

原因分析：
1. **前端模型缺失**：`CommentViewData`（用于接收 `createComment` 接口返回的新评论）缺少 `replyToUserId` 和 `replyToUserNickname` 字段，导致无法接收后端返回的回复元数据。
2. **本地逻辑缺陷**：前端在接收到新评论后，尝试手动构造 `ReplyViewData` 来更新 UI，其判断是否为"回复一级评论"的逻辑是 `replyToUser.id == replyTarget.userId`。当二级评论的作者恰好是一级评论的作者时，这个判断会出错，导致前端错误地认为这是回复一级评论，从而隐藏了"回复 @xxx"。

## 修改内容

### 1. 修改 `CommentModels.swift`

在 `CommentViewData` 结构体中添加了缺失的字段，使其能够正确接收后端返回的回复信息：

```swift
struct CommentViewData: Identifiable, Codable {
    // ...
    let replyToUserId: Int64?          // 新增
    let replyToUserNickname: String?   // 新增
    // ...
}
```

同时更新了 `CodingKeys`、`init(from decoder:)`、`encode(to encoder:)` 和手动 `init` 方法。

### 2. 修改 `CommentViewModel.swift`

在 `postComment` 方法中，废弃了不可靠的本地判断逻辑，直接使用服务端返回的字段来构造 `ReplyViewData`：

```swift
// 旧逻辑（已删除）
// let isReplyToFirstLevel = replyToUser?.id == replyTarget?.userId

// 新逻辑
let reply = ReplyViewData(
    // ...
    replyToUserId: newComment.replyToUserId,       // 直接使用服务端返回的值
    replyToUserNickname: newComment.replyToUserNickname,
    // ...
)
```

## 结果

现在发送评论后，前端会利用后端返回的准确数据（Converge 逻辑处理后的结果）来更新 UI，无论回复的是一级还是二级评论，都能正确显示"回复 @xxx"状态。
