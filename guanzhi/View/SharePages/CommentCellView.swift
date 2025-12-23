//
//  CommentCellView.swift
//  guanzhi
//
//  Created by Claude Code on 2024/12/23.
//  单条评论 Cell
//

import SwiftUI

struct CommentCellView: View {
    let comment: CommentViewData
    @ObservedObject var viewModel: CommentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 判断状态
            if comment.displayStatus != .normal {
                // 删除/违规占位
                deletedPlaceholder
            } else {
                // 正常评论
                normalContent
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 正常评论内容
    @ViewBuilder
    private var normalContent: some View {
        HStack(alignment: .top, spacing: 12) {
            // 头像
            AsyncImage(url: URL(string: comment.userAvatar ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure, .empty:
                    Image("例子")
                        .resizable()
                        .scaledToFill()
                @unknown default:
                    Image("例子")
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 6) {
                // 用户名 + 作者标识
                HStack(spacing: 6) {
                    Text(comment.userNickname ?? "匿名用户")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color("color-black"))

                    if comment.isAuthor == true {
                        Text("作者")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color("color-primary"))
                            .cornerRadius(4)
                    }
                }

                // 评论内容
                Text(comment.content ?? "")
                    .font(.system(size: 15))
                    .foregroundColor(Color("color-black"))
                    .lineSpacing(4)

                // 操作栏
                HStack(spacing: 16) {
                    Text(formatCommentTime(comment.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Spacer()

                    // 点赞按钮
                    Button(action: {
                        Task { await viewModel.toggleLike(on: comment.id) }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: comment.liked ? "heart.fill" : "heart")
                                .font(.system(size: 14))
                                .foregroundColor(comment.liked ? .red : .secondary)
                            if comment.likeCount > 0 {
                                Text("\(comment.likeCount)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // 回复按钮
                    Button(action: {
                        viewModel.enterReplyMode(to: comment)
                    }) {
                        Text("回复")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    // 删除按钮（仅自己的评论）
                    if comment.canDelete {
                        Menu {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteComment(id: comment.id) }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 回复预览
                if comment.replyCount > 0 {
                    replyPreviewSection
                }
            }
        }
    }

    // MARK: - 删除/违规占位
    @ViewBuilder
    private var deletedPlaceholder: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)

            Text(comment.statusText ?? "该评论不可用")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .italic()

            Spacer()
        }
    }

    // MARK: - 回复预览区
    @ViewBuilder
    private var replyPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 预览回复（最多2条）
            if let previews = comment.repliesPreview {
                ForEach(previews.prefix(2)) { reply in
                    ReplyPreviewView(reply: reply, viewModel: viewModel, parentId: comment.id)
                }
            }

            // 已展开的回复
            if comment.isExpanded {
                ForEach(comment.loadedReplies.dropFirst(comment.repliesPreview?.count ?? 0)) { reply in
                    ReplyPreviewView(reply: reply, viewModel: viewModel, parentId: comment.id)
                        .background(
                            viewModel.highlightCommentId == reply.id
                            ? Color.yellow.opacity(0.2)
                            : Color.clear
                        )
                }
            }

            // 展开更多按钮
            let previewCount = comment.repliesPreview?.count ?? 0
            let remainingCount = comment.replyCount - previewCount

            if remainingCount > 0 && !comment.isExpanded {
                Button {
                    Task { await viewModel.loadMoreReplies(for: comment) }
                } label: {
                    HStack(spacing: 4) {
                        Text("展开 \(remainingCount) 条回复")
                        if comment.isLoadingReplies {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Color("color-primary"))
                }
            } else if comment.isExpanded && comment.loadedReplies.count < comment.replyCount {
                Button {
                    Task { await viewModel.loadMoreReplies(for: comment) }
                } label: {
                    HStack(spacing: 4) {
                        Text("加载更多回复")
                        if comment.isLoadingReplies {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Color("color-primary"))
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - 回复预览视图
struct ReplyPreviewView: View {
    let reply: ReplyViewData
    @ObservedObject var viewModel: CommentViewModel
    let parentId: Int64

    var body: some View {
        if reply.displayStatus != .normal {
            // 删除/违规的回复
            Text(reply.statusText ?? "该回复不可用")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .italic()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                // 回复内容
                HStack(alignment: .top, spacing: 0) {
                    Text(reply.userNickname ?? "匿名用户")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color("color-black"))

                    if let replyToName = reply.replyToUserNickname {
                        Text(" 回复 ")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("@\(replyToName)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color("color-primary"))
                    }

                    Text("：")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text(reply.content ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(Color("color-black"))
                }
                .lineLimit(2)

                // 操作栏
                HStack(spacing: 12) {
                    Text(formatCommentTime(reply.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Spacer()

                    // 点赞按钮
                    Button(action: {
                        Task {
                            await viewModel.toggleLike(
                                on: reply.id,
                                isReply: true,
                                parentId: parentId
                            )
                        }
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: reply.liked ? "heart.fill" : "heart")
                                .font(.system(size: 12))
                                .foregroundColor(reply.liked ? .red : .secondary)
                            if reply.likeCount > 0 {
                                Text("\(reply.likeCount)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // 回复按钮
                    Button(action: {
                        // 找到父评论
                        if let parentComment = viewModel.comments.first(where: { $0.id == parentId }) {
                            viewModel.enterReplyMode(
                                to: parentComment,
                                replyToUser: CommentUserSummary(
                                    id: reply.userId,
                                    nickname: reply.userNickname,
                                    avatar: reply.userAvatar
                                )
                            )
                        }
                    }) {
                        Text("回复")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    // 删除按钮
                    if reply.canDelete {
                        Menu {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteComment(id: reply.id) }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
