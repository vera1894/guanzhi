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

                // ✅ 贴纸切换按钮（原点赞按钮已弃用）
                stickerToggleButton

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

    /// 贴纸切换按钮
    /// - 空心图标 = 未使用贴纸状态
    /// - 填充图标 = 已使用贴纸状态
    private var stickerToggleButton: some View {
        Button {
            // 震动反馈
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            viewModel.toggleStickerPanel()
        } label: {
            Image(systemName: viewModel.currentUserSticker != nil
                ? "sparkles.rectangle.stack.fill"  // 已使用贴纸，填充图标
                : "sparkles.rectangle.stack")      // 未使用贴纸，空心图标
                .font(.system(size: 32))
                .foregroundStyle(.white)
                // 面板显示时的视觉反馈
                .opacity(viewModel.isStickerPanelVisible ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: viewModel.isStickerPanelVisible)
        }
        .buttonStyle(ButtonStyle_LikeControl())
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
