# 评论删除行为优化

**日期**: 2025-12-25
**执行者**: Claude Code
**相关文件**:
- `Server/onettoo/src/main/java/com/cloud/onettoo/modules/service/impl/ShareCommentServiceImpl.java`

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

## Git 提交

**后端** (`Server/onettoo` - Zaptain 分支):
```
7ad9b1d fix: 优化评论删除状态处理
```

**主仓库** (`guanzhi` - dev-x 分支):
```
dd079df chore: 更新后端子模块引用
```
