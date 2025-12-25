# 评论删除行为优化

**日期**: 2025-12-25
**执行者**: Claude Code
**相关文件**:
- `Server/onettoo/src/main/java/com/cloud/onettoo/modules/service/impl/ShareCommentServiceImpl.java`
- `guanzhi/ModelsForNetwork/CommentModels.swift`
- `guanzhi/ModelsForNetwork/CommentViewModel.swift`
- `guanzhi/View/SharePages/CommentCellView.swift`

## 需求背景

优化评论删除后的显示逻辑，统一由后端控制过滤，前端仅负责渲染。

## 修改内容

### 1. `getCommentList` - 评论列表接口

**变更**: 只返回 `status = NORMAL` 的一级评论

```java
// 修改前：返回所有状态的一级评论
LambdaQueryWrapper<ShareCommentDO> wrapper = new LambdaQueryWrapper<>();
wrapper.eq(ShareCommentDO::getShareId, shareId)
       .and(w -> w.isNull(ShareCommentDO::getParentId).or().eq(ShareCommentDO::getParentId, 0L));

// 修改后：只返回正常状态的一级评论
LambdaQueryWrapper<ShareCommentDO> wrapper = new LambdaQueryWrapper<>();
wrapper.eq(ShareCommentDO::getShareId, shareId)
       .eq(ShareCommentDO::getStatus, ShareCommentDO.STATUS_NORMAL)
       .and(w -> w.isNull(ShareCommentDO::getParentId).or().eq(ShareCommentDO::getParentId, 0L));
```

**效果**:
- 一级评论被删除 → 完全隐藏，其下所有回复也一并消失
- 二级评论（回复）被删除 → 仅该条回复隐藏，同级其他回复仍显示

### 2. `getCommentContext` - 评论上下文接口

**变更**: 增加删除状态处理，支持软着陆

```java
// 1. 检查分享是否存在/已删除
GuanzhiDO share = guanzhiMapper.selectById(comment.getShareId());
if (share == null || (share.getDeleted() != null && share.getDeleted() == 1)) {
    throw new BadRequestException("该分享已删除");
}

// 2. 评论已删除/屏蔽时：返回 shareId + null comment
if (comment.getStatus() != ShareCommentDO.STATUS_NORMAL) {
    vo.setShareId(comment.getShareId());
    vo.setComment(null);
    vo.setParentComment(null);
    vo.setPosition(null);
    return vo;
}

// 3. 回复的父评论已删除时：该回复也不可见
if (comment.getParentId() != null && comment.getParentId() != 0L) {
    ShareCommentDO parent = shareCommentMapper.selectById(comment.getParentId());
    if (parent == null || parent.getStatus() != ShareCommentDO.STATUS_NORMAL) {
        vo.setShareId(comment.getShareId());
        vo.setComment(null);
        vo.setParentComment(null);
        vo.setPosition(null);
        return vo;
    }
}
```

**响应示例**:

正常评论：
```json
{
  "respCode": 0,
  "datas": {
    "shareId": 88,
    "comment": { ... },
    "parentComment": null,
    "position": { "pageIndex": 0, "indexInPage": 2 }
  }
}
```

已删除评论（软着陆）：
```json
{
  "respCode": 0,
  "datas": {
    "shareId": 88,
    "comment": null,
    "parentComment": null,
    "position": null
  }
}
```

分享已删除：
```json
{
  "respCode": 400,
  "message": "该分享已删除"
}
```

---

## 前端适配指南

### iOS 端处理逻辑

当从通知/消息跳转到评论时：

```swift
// 调用 GET /api/comments/{commentId}/context
let response = await commentService.getCommentContext(commentId)

if response.comment == nil {
    if let shareId = response.shareId {
        // 评论已删除，但分享存在 → 跳转到分享详情页
        navigateToShareDetail(shareId: shareId)
        showToast("该评论已被删除")
    }
} else {
    // 正常跳转到评论位置
    navigateToComment(response)
}
```

### 管理后台

不受影响，管理后台使用独立的 Inspector API 查询所有状态的评论。

---

## 设计原则

| 场景 | 行为 |
|-----|------|
| 一级评论删除 | 完全隐藏，所有回复一并消失 |
| 二级评论删除 | 仅该条隐藏，其他回复正常显示 |
| 从通知跳转到已删除评论 | 返回 shareId，前端可跳转到分享页 |
| 从通知跳转到已删除分享 | 抛出异常，前端显示错误提示 |

---

## iOS 前端实现

### 1. `CommentModels.swift` - 数据模型更新

**变更**: `CommentContextResponse` 的 `comment` 和 `position` 改为可选类型

```swift
// 修改前
struct CommentContextResponse: Codable {
    let comment: CommentViewData
    let parentComment: CommentViewData?
    let shareId: Int64
    let position: CommentPositionInfo
}

// 修改后
struct CommentContextResponse: Codable {
    let comment: CommentViewData?        // 可选：评论已删除时为 null
    let parentComment: CommentViewData?
    let shareId: Int64
    let position: CommentPositionInfo?   // 可选：评论已删除时为 null
}
```

### 2. `CommentViewModel.swift` - 跳转逻辑更新

**变更**: `navigateToComment` 方法增加删除评论处理，返回 `Bool` 表示是否需要显示提示

```swift
/// 从通知跳转：精准定位到指定评论
/// 返回值表示是否需要显示"评论已删除"提示
@discardableResult
func navigateToComment(commentId: Int64) async -> Bool {
    do {
        let context = try await CommentService.shared.getCommentContext(commentId: commentId)
        self.shareId = context.shareId

        // 评论已删除：comment 和 position 为 null
        guard let position = context.position, context.comment != nil else {
            await loadComments(reset: true)
            return true  // 需要显示提示
        }

        // ... 正常跳转逻辑 ...
        return false
    } catch {
        // 降级策略
        await loadComments(reset: true)
        return false
    }
}
```

### 3. `CommentCellView.swift` - 移除删除占位符

**变更**: 移除一级评论和二级回复的删除占位符显示逻辑

```swift
// 修改前：一级评论
var body: some View {
    VStack(alignment: .leading, spacing: 8) {
        if comment.displayStatus != .normal {
            deletedPlaceholder  // 删除/违规占位
        } else {
            normalContent
        }
    }
}

// 修改后：直接显示正常内容
var body: some View {
    VStack(alignment: .leading, spacing: 8) {
        // 后端已过滤删除的评论，直接显示正常内容
        normalContent
    }
}
```

```swift
// 修改前：二级回复 (ReplyPreviewView)
var body: some View {
    if reply.displayStatus != .normal {
        // 删除/违规的回复占位符
        HStack(spacing: 8) { ... }
    } else {
        HStack(alignment: .top, spacing: 8) { ... }
    }
}

// 修改后：直接显示正常内容
var body: some View {
    // 后端已过滤删除的回复，直接显示正常内容
    HStack(alignment: .top, spacing: 8) { ... }
}
```

---

## Git 提交

**后端** (`Server/onettoo` - Zaptain 分支):
```
7ad9b1d fix: 优化评论删除状态处理
```

**主仓库** (`guanzhi` - dev-x 分支):
```
dd079df chore: 更新后端子模块引用
```

**iOS 前端** (待提交):
- 修改 `CommentModels.swift`: `CommentContextResponse` 字段改为可选
- 修改 `CommentViewModel.swift`: `navigateToComment` 返回删除提示标志
- 修改 `CommentCellView.swift`: 移除删除占位符显示逻辑
