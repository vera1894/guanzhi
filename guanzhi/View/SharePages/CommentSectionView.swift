//
//  CommentSectionView.swift
//  guanzhi
//
//  Created by Claude Code on 2024/12/23.
//  评论区主视图
//

import SwiftUI

struct CommentSectionView: View {
    @ObservedObject var viewModel: CommentViewModel
    @State private var showSortPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // 排序切换
            HStack {
                Text("评论")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("color-black"))

                Spacer()

                Button(action: { showSortPicker = true }) {
                    HStack(spacing: 4) {
                        Text(viewModel.sortOrder.displayName)
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 16)

            // 评论列表
            if viewModel.comments.isEmpty && !viewModel.isLoading {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("暂无评论")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("快来发表第一条评论吧")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.comments) { comment in
                        CommentCellView(
                            comment: comment,
                            viewModel: viewModel
                        )
                        .background(
                            viewModel.highlightCommentId == comment.id
                            ? Color.yellow.opacity(0.2)
                            : Color.clear
                        )

                        Divider()
                            .padding(.leading, 60)
                    }

                    // 加载更多
                    if viewModel.hasMoreComments {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("加载中...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .onAppear {
                            Task { await viewModel.loadComments() }
                        }
                    }
                }
            }

            // 加载状态
            if viewModel.isLoading && viewModel.comments.isEmpty {
                HStack {
                    ProgressView()
                    Text("加载评论中...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
        }
        .confirmationDialog("选择排序方式", isPresented: $showSortPicker) {
            ForEach(CommentSortOrder.allCases, id: \.self) { order in
                Button(order.displayName) {
                    Task { await viewModel.changeSortOrder(to: order) }
                }
            }
        }
        .onAppear {
            // 高亮后清除
            if viewModel.highlightCommentId != nil {
                viewModel.clearHighlight()
            }
        }
    }
}
