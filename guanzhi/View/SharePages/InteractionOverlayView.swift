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

    // MARK: - Initializer

    /// 使用外部传入的 ViewModel（推荐，用于状态共享）
    init(share: Share, viewModel: ShareInteractionViewModel) {
        self.share = share
        self.viewModel = viewModel
    }

    /// 兼容旧接口：自动创建内部 ViewModel（用于独立使用场景）
    init(share: Share) {
        self.share = share
        self.viewModel = ShareInteractionViewModel()
    }

    // MARK: - Body

    var body: some View {
        HStack {
            Spacer()

            VStack(spacing: 16) {
                Spacer()

                // ✅ 当前版本：只显示点赞按钮
                likeButton

                // ⚠️ 未来版本：无感按钮（暂不显示）
                // if shouldShowNeutralButton {
                //     neutralButton
                // }

                // TODO: 打卡按钮
                // TODO: 评论按钮
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

    private var likeButton: some View {
        VStack(spacing: 4) {
            Button {
                // 震动反馈（iOS 10+）
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()

                viewModel.toggleLike()
            } label: {
                Image(systemName: viewModel.isLiked ? "heart.circle.fill" : "heart.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(viewModel.isLiked ? Color("color-primary") : Color(.white)))
                    // ✅ 弹簧动画
                    .scaleEffect(viewModel.isAnimating ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isAnimating)
            }
            .buttonStyle(ButtonStyle_LikeControl())

            // 点赞数
            Text(formatCount(viewModel.agreeCount))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2)
                // ✅ 数字变化动画
                .animation(.easeInOut(duration: 0.2), value: viewModel.agreeCount)
        }
    }

    // ⚠️ 未来版本：无感按钮（预留）
    // private var neutralButton: some View {
    //     VStack(spacing: 4) {
    //         Button {
    //             let generator = UIImpactFeedbackGenerator(style: .medium)
    //             generator.impactOccurred()
    //             viewModel.toggleNeutral()
    //         } label: {
    //             Image(systemName: viewModel.isNeutral ? "hand.thumbsdown.fill" : "hand.thumbsdown")
    //                 .font(.system(size: 36))
    //                 .foregroundStyle(viewModel.isNeutral ? .orange : .white)
    //         }
    //         Text(formatCount(viewModel.neutralCount))
    //             .font(.system(size: 14, weight: .medium))
    //             .foregroundColor(.white)
    //     }
    // }

    // MARK: - Private Methods

    private func initializeViewModel() {
        viewModel.initialize(share: share)
    }

    /// 格式化计数（超过 9999 显示 9999+）
    private func formatCount(_ count: Int) -> String {
        if count > 9999 {
            return "9999+"
        }
        return "\(count)"
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
