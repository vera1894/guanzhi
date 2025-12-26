//
//  InteractionOverlayView.swift
//  guanzhi
//
//  Created by Zaptain Zi on 2025/11/27.
//

import SwiftUI

struct InteractionOverlayView: View {
    // MARK: - Properties

    let share: Share

    /// 外部传入的 ViewModel（用于与其他组件共享状态）
    @ObservedObject var viewModel: ShareInteractionViewModel

    /// 点击评论按钮的回调
    var onCommentTap: (() -> Void)?

    // MARK: - Computed Properties

    /// 贴纸总数（所有类型贴纸数量之和）
    private var totalStickerCount: Int {
        viewModel.stickerSummaries.reduce(0) { $0 + $1.count }
    }

    // MARK: - Initializer

    /// 使用外部传入的 ViewModel（推荐，用于状态共享）
    init(share: Share, viewModel: ShareInteractionViewModel, onCommentTap: (() -> Void)? = nil) {
        self.share = share
        self.viewModel = viewModel
        self.onCommentTap = onCommentTap
    }

    /// 兼容旧接口：自动创建内部 ViewModel（用于独立使用场景）
    init(share: Share) {
        self.share = share
        self.viewModel = ShareInteractionViewModel()
        self.onCommentTap = nil
    }

    // MARK: - Body

    var body: some View {
        HStack {
            Spacer()

            VStack(spacing: 20) {
                Spacer()

                // ✅ 贴纸切换按钮
                stickerToggleButton

                // ✅ 评论按钮
                commentButton
            }
            .padding(.trailing, 16)
            .padding(.bottom, 140)  // 避开底部 sheet
        }
        .onAppear {
            initializeViewModel()
        }
        // ✅ 关键修复：监听 share.id 变化，重新初始化
        .onChange(of: share.id) { oldId, newId in
            #if DEBUG
            print("🔄 [InteractionOverlay] Share 切换: \(oldId) -> \(newId)")
            #endif
            initializeViewModel()
        }
        // 错误提示
        .overlay(alignment: .top) {
            if let errorMessage = viewModel.errorMessage {
                ErrorToast(message: errorMessage)
                    .padding(.top, 50)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Subviews

    /// 贴纸切换按钮
    /// - 空心图标 = 未使用贴纸状态
    /// - 填充图标 = 已使用贴纸状态
    /// - 显示贴纸总数
    private var stickerToggleButton: some View {
        Button {
            // 震动反馈
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            viewModel.toggleStickerPanel()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: viewModel.currentUserSticker != nil
                    ? "sparkles.rectangle.stack.fill"  // 已使用贴纸，填充图标
                    : "sparkles.rectangle.stack")      // 未使用贴纸，空心图标
                    .font(.system(size: 28))
                    .foregroundStyle(.white)

                // 贴纸总数
                if totalStickerCount > 0 {
                    Text(formatCount(totalStickerCount))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            // 面板显示时的视觉反馈
            .opacity(viewModel.isStickerPanelVisible ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: viewModel.isStickerPanelVisible)
        }
        .buttonStyle(ButtonStyle_LikeControl())
    }

    /// 评论按钮
    /// - 显示评论总数
    private var commentButton: some View {
        Button {
            // 震动反馈
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            onCommentTap?()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)

                // 评论总数
                if share.commentCount > 0 {
                    Text(formatCount(share.commentCount))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(ButtonStyle_LikeControl())
    }

    // MARK: - Helper Methods

    /// 格式化数量显示（超过999显示999+，超过9999显示1w+）
    private func formatCount(_ count: Int) -> String {
        if count >= 10000 {
            return "\(count / 10000)w+"
        } else if count >= 1000 {
            return "999+"
        } else {
            return "\(count)"
        }
    }

    // MARK: - Private Methods

    private func initializeViewModel() {
        viewModel.initialize(share: share)
    }
}

// MARK: - Error Toast

struct ErrorToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.red.opacity(0.9))
            )
            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    let testShare = Share(
        id: 12345,
        createDate: Date(),
        userId: 1,
        data: "测试分享",
        longitude: 121.5,
        latitude: 31.2,
        provinceCode: "31",
        cityCode: "3101",
        districtCode: "310115",
        address: "上海市 浦东新区",
        imagePaths: [],
        title: "测试",
        deleted: false
    )

    ZStack {
        Color.black.ignoresSafeArea()

        InteractionOverlayView(share: testShare)
    }
}
