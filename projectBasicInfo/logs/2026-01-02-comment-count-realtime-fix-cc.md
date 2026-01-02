# 评论计数实时更新修复

**日期**: 2026-01-02
**操作者**: Claude Code (cc)
**类型**: Bug修复

---

## 问题描述

在分享页面发布新评论后，评论按钮的计数不会更新。即使退出分享页面再进入也不会更新，只有杀掉 app 重新进入才会更新。

## 根因分析

| 组件 | 问题 |
|-----|------|
| `CommentViewModel.postComment()` | 发布评论成功后，没有更新 `Share.commentCount` |
| `CommentViewModel.deleteComment()` | 删除评论成功后，没有更新 `Share.commentCount` |
| 数据同步 | `CommentViewModel` 和 `Share` 模型之间没有数据同步机制 |

**对比**：贴纸计数正常工作，因为它使用 `@Published var stickerSummaries`，每次操作后自动触发 UI 更新。

## 解决方案

### 1. 添加回调机制

在 `CommentViewModel` 中添加评论计数变化回调：

```swift
// CommentViewModel.swift
var onCommentCountChanged: ((Int) -> Void)?
```

### 2. 触发回调

在 `postComment()` 和 `deleteComment()` 成功后触发回调：

```swift
// postComment() 成功后
onCommentCountChanged?(1)

// deleteComment() 成功后（一级评论和二级回复）
onCommentCountChanged?(-1)
```

### 3. 设置回调更新计数

在 `ShareDetailsCardView` 的两个位置设置回调：

```swift
// handleOnAppear() 和 .onChange(of: selectedShare?.id) 中
commentViewModel.onCommentCountChanged = { [weak searchViewModel] delta in
    if let share = searchViewModel?.selectedShare {
        share.commentCount = max(0, share.commentCount + delta)
    }
}
```

## 修改文件清单

| 文件 | 修改内容 |
|-----|---------|
| `guanzhi/ModelsForNetwork/CommentViewModel.swift` | 添加 `onCommentCountChanged` 回调，在 `postComment()` 和 `deleteComment()` 中触发 |
| `guanzhi/View/SharePages/ShareDetailsCardView.swift` | 在 `handleOnAppear()` 和 `.onChange()` 中设置回调 |

## 关键代码位置

- **回调定义**: `CommentViewModel.swift` 第 43-45 行
- **发布触发**: `CommentViewModel.swift` 第 212-213 行
- **删除触发**: `CommentViewModel.swift` 第 237-238 行（一级）、247-248 行（二级）
- **回调设置**: `ShareDetailsCardView.swift` 第 297-303 行、319-325 行

## 验证结果

| 操作 | 修复前 | 修复后 |
|-----|-------|-------|
| 发布评论 | 计数不变 | 计数 +1 |
| 删除一级评论 | 计数不变 | 计数 -1 |
| 删除二级回复 | 计数不变 | 计数 -1 |

## 相关说明

- **贴纸计数**：无需修复，使用 `@Published` 属性自动更新
- **SwiftData 自动保存**：修改 `share.commentCount` 后，SwiftData 会自动持久化
