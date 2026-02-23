//
//  CommentViewModel.swift
//  guanzhi
//
//  Created by Claude Code on 2024/12/23.
//  评论系统 ViewModel
//

import Foundation
import SwiftUI

@MainActor
class CommentViewModel: ObservableObject {

    // MARK: - 状态
    @Published var comments: [CommentViewData] = []
    @Published var isLoading: Bool = false
    @Published var hasMoreComments: Bool = true
    @Published var sortOrder: CommentSortOrder = .default
    @Published var error: String?

    // MARK: - 回复模式状态
    @Published var isReplyMode: Bool = false
    @Published var replyTarget: CommentViewData?      // 回复的目标一级评论（用于本地列表更新）
    @Published var replyToUser: CommentUserSummary?   // 回复的具体用户（可能是二级回复作者）
    @Published var replyToCommentId: Int64?           // 被回复的评论ID（发送给服务端，用于判断是回复一级还是二级）

    // MARK: - 输入状态
    @Published var inputText: String = ""
    @Published var isSubmitting: Bool = false

    // MARK: - 高亮状态（用于精准定位）
    @Published var highlightCommentId: Int64? = nil

    // MARK: - 分页
    private var currentOffset: Int = 0
    private let pageSize: Int = 20

    // MARK: - 所属分享
    private(set) var shareId: Int64 = 0
    private(set) var shareAuthorId: Int64 = 0

    // MARK: - 评论计数变化回调
    /// 评论数变化回调：delta 为变化量（+1 表示新增，-1 表示删除）
    var onCommentCountChanged: ((Int) -> Void)?

    // MARK: - 方法

    /// 初始化（绑定到分享）
    func bind(to shareId: Int64, authorId: Int64 = 0) {
        print("🔗 [CommentViewModel] bind(to: \(shareId), authorId: \(authorId))")
        self.shareId = shareId
        self.shareAuthorId = authorId
        self.comments = []
        self.currentOffset = 0
        self.hasMoreComments = true
    }

    /// 加载评论列表
    /// - Parameter reset: 是否重置（切换排序、刷新时使用）
    func loadComments(reset: Bool = false) async {
        if reset {
            currentOffset = 0
            hasMoreComments = true
            // 重置时清除所有评论的展开状态和已加载回复
            // 避免切换排序后旧数据残留
            for i in comments.indices {
                comments[i].loadedReplies = []
                comments[i].isExpanded = false
            }
        }

        guard hasMoreComments, !isLoading else { return }

        isLoading = true
        error = nil

        do {
            var newComments = try await CommentService.shared.fetchComments(
                shareId: shareId,
                order: sortOrder,
                offset: currentOffset,
                limit: pageSize
            )

            // 确保新加载的评论本地状态正确初始化
            for i in newComments.indices {
                newComments[i].loadedReplies = []
                newComments[i].isExpanded = false
                newComments[i].isLoadingReplies = false
            }

            if reset {
                comments = newComments
            } else {
                comments.append(contentsOf: newComments)
            }

            currentOffset += newComments.count
            hasMoreComments = newComments.count >= pageSize

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// 加载更多回复
    func loadMoreReplies(for comment: CommentViewData) async {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }

        comments[index].isLoadingReplies = true

        do {
            let offset = comments[index].loadedReplies.count
            let replies = try await CommentService.shared.fetchReplies(
                commentId: comment.id,
                offset: offset,
                limit: 10
            )

            comments[index].loadedReplies.append(contentsOf: replies)
            comments[index].isExpanded = true

        } catch {
            self.error = error.localizedDescription
        }

        comments[index].isLoadingReplies = false
    }

    /// 发表评论/回复
    func postComment() async {
        print("📝 [CommentViewModel] postComment 开始")
        print("   - shareId: \(shareId)")
        print("   - inputText: \(inputText)")
        print("   - isLoggedIn: \(OTOLoginStatusManager.shared.isLoggedIn)")

        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ [CommentViewModel] 输入内容为空，取消发送")
            return
        }
        guard inputText.count <= 230 else {
            error = String(localized: "评论内容不能超过230字")
            print("❌ [CommentViewModel] 内容超过230字")
            return
        }

        // 检查 shareId 是否有效
        guard shareId > 0 else {
            error = String(localized: "无效的观之ID")
            print("❌ [CommentViewModel] shareId 无效: \(shareId)")
            return
        }

        // 登录检查
        guard OTOLoginStatusManager.shared.isLoggedIn else {
            // 触发登录流程
            print("❌ [CommentViewModel] 用户未登录，触发登录流程")
            NotificationCenter.default.post(name: .showLoginRequired, object: nil)
            return
        }

        print("✅ [CommentViewModel] 所有检查通过，开始提交...")
        isSubmitting = true

        do {
            let newComment = try await CommentService.shared.createComment(
                shareId: shareId,
                content: inputText,
                parentId: replyToCommentId,  // 使用被回复的评论ID（一级或二级）
                replyToUserId: replyToUser?.id
            )

            // 添加到列表
            if replyTarget == nil {
                // 一级评论：添加到列表顶部
                var mutableComment = newComment
                mutableComment.loadedReplies = []
                mutableComment.isExpanded = false
                mutableComment.isLoadingReplies = false
                comments.insert(mutableComment, at: 0)
            } else if let parentIndex = comments.firstIndex(where: { $0.id == replyTarget?.id }) {
                // 二级回复：添加到父评论的回复列表
                // ✅ 修正：直接使用服务端返回的 newComment 中的 replyToUserId
                // 服务端已经处理好了 converge 逻辑，如果 replyToUserId != nil，说明是回复了某人
                
                let reply = ReplyViewData(
                    id: newComment.id,
                    userId: newComment.userId,
                    userNickname: newComment.userNickname,
                    userAvatar: newComment.userAvatar,
                    replyToUserId: newComment.replyToUserId,
                    replyToUserNickname: newComment.replyToUserNickname,
                    content: newComment.content,
                    status: 0,
                    statusText: nil,
                    likeCount: 0,
                    liked: false,
                    createdAt: newComment.createdAt
                )
                comments[parentIndex].loadedReplies.append(reply)
                comments[parentIndex].replyCount += 1
            }

            // 重置输入状态
            inputText = ""
            exitReplyMode()
            print("✅ [CommentViewModel] 评论发送成功!")

            // 通知评论计数增加
            onCommentCountChanged?(1)

        } catch {
            self.error = error.localizedDescription
            print("❌ [CommentViewModel] 发送失败: \(error.localizedDescription)")
        }

        isSubmitting = false
        print("📝 [CommentViewModel] postComment 结束，isSubmitting=\(isSubmitting)")
    }

    /// 删除评论
    /// 返回值表示是否删除成功（用于显示提示）
    @discardableResult
    func deleteComment(id: Int64) async -> Bool {
        do {
            try await CommentService.shared.deleteComment(commentId: id)

            // 直接从列表中移除（带动画）
            if let index = comments.firstIndex(where: { $0.id == id }) {
                // 删除一级评论
                withAnimation(.easeOut(duration: 0.25)) {
                    _ = comments.remove(at: index)
                }
                // 通知评论计数减少
                onCommentCountChanged?(-1)
            } else {
                // 删除二级回复
                for i in comments.indices {
                    if let replyIndex = comments[i].loadedReplies.firstIndex(where: { $0.id == id }) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            comments[i].loadedReplies.remove(at: replyIndex)
                            comments[i].replyCount = max(0, comments[i].replyCount - 1)
                        }
                        // 通知评论计数减少
                        onCommentCountChanged?(-1)
                        break
                    }
                }
            }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// 点赞/取消点赞
    func toggleLike(on commentId: Int64, isReply: Bool = false, parentId: Int64? = nil) async {
        // 登录检查
        guard OTOLoginStatusManager.shared.isLoggedIn else {
            NotificationCenter.default.post(name: .showLoginRequired, object: nil)
            return
        }

        // 乐观更新
        var originalLiked = false
        var originalCount = 0

        if isReply, let parentId = parentId,
           let parentIndex = comments.firstIndex(where: { $0.id == parentId }),
           let replyIndex = comments[parentIndex].loadedReplies.firstIndex(where: { $0.id == commentId }) {

            originalLiked = comments[parentIndex].loadedReplies[replyIndex].liked
            originalCount = comments[parentIndex].loadedReplies[replyIndex].likeCount

            comments[parentIndex].loadedReplies[replyIndex].liked.toggle()
            comments[parentIndex].loadedReplies[replyIndex].likeCount += originalLiked ? -1 : 1

        } else if let index = comments.firstIndex(where: { $0.id == commentId }) {

            originalLiked = comments[index].liked
            originalCount = comments[index].likeCount

            comments[index].liked.toggle()
            comments[index].likeCount += originalLiked ? -1 : 1
        }

        // 调用 API
        do {
            if originalLiked {
                try await CommentService.shared.unlikeComment(commentId: commentId)
            } else {
                try await CommentService.shared.likeComment(commentId: commentId)
            }
        } catch {
            // 回滚
            if isReply, let parentId = parentId,
               let parentIndex = comments.firstIndex(where: { $0.id == parentId }),
               let replyIndex = comments[parentIndex].loadedReplies.firstIndex(where: { $0.id == commentId }) {

                comments[parentIndex].loadedReplies[replyIndex].liked = originalLiked
                comments[parentIndex].loadedReplies[replyIndex].likeCount = originalCount

            } else if let index = comments.firstIndex(where: { $0.id == commentId }) {
                comments[index].liked = originalLiked
                comments[index].likeCount = originalCount
            }

            self.error = error.localizedDescription
        }
    }

    /// 进入回复模式
    /// - Parameters:
    ///   - comment: 目标一级评论（用于本地列表更新）
    ///   - replyToUser: 被回复的用户信息
    ///   - replyToCommentId: 被回复的评论ID（一级或二级评论的ID，发送给服务端）
    func enterReplyMode(to comment: CommentViewData, replyToUser: CommentUserSummary? = nil, replyToCommentId: Int64? = nil) {
        isReplyMode = true
        replyTarget = comment
        self.replyToUser = replyToUser ?? CommentUserSummary(
            id: comment.userId,
            nickname: comment.userNickname,
            avatar: comment.userAvatar
        )
        // 如果没有指定 replyToCommentId，默认使用一级评论的 ID
        self.replyToCommentId = replyToCommentId ?? comment.id
    }

    /// 退出回复模式
    func exitReplyMode() {
        isReplyMode = false
        replyTarget = nil
        replyToUser = nil
        replyToCommentId = nil
    }

    /// 切换排序
    func changeSortOrder(to order: CommentSortOrder) async {
        guard order != sortOrder else { return }
        sortOrder = order
        await loadComments(reset: true)
    }

    // MARK: - 精准定位

    /// 从通知跳转：精准定位到指定评论
    /// 返回值表示是否需要显示"评论已删除"提示
    @discardableResult
    func navigateToComment(commentId: Int64) async -> Bool {
        do {
            let context = try await CommentService.shared.getCommentContext(commentId: commentId)

            // 更新 shareId
            self.shareId = context.shareId

            // 评论已删除：comment 和 position 为 null
            guard let position = context.position, context.comment != nil else {
                // 降级：加载评论第一页，提示用户评论已删除
                await loadComments(reset: true)
                return true  // 需要显示提示
            }

            if position.isFirstLevel {
                // 一级评论：计算页码并加载
                let page = position.index / pageSize

                // 重置并加载到正确的页
                comments = []
                currentOffset = 0

                // 加载到目标页
                for _ in 0...page {
                    await loadComments()
                }

                // 标记需要高亮的评论
                highlightCommentId = commentId

            } else if let parentId = position.parentId {
                // 二级回复：先定位父评论，再展开回复
                await loadComments(reset: true)

                if let parentIndex = comments.firstIndex(where: { $0.id == parentId }) {
                    await loadMoreReplies(for: comments[parentIndex])
                    highlightCommentId = commentId
                }
            }

            return false  // 正常跳转，无需提示

        } catch {
            // 降级策略：打开分享详情 → 加载第一页评论 → 滚动到评论区顶部
            print("⚠️ 精准定位失败，使用降级策略: \(error.localizedDescription)")
            await loadComments(reset: true)
            self.error = nil  // 不显示错误，静默降级
            return false
        }
    }

    /// 清除高亮（延迟调用）
    func clearHighlight() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                self.highlightCommentId = nil
            }
        }
    }
}
