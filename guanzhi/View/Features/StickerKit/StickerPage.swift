//
//  StickerPage.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/10.
//
//  贴纸互动页面入口
//

import SwiftUI

// MARK: - StickerPage

/// 贴纸互动页面
/// 作为独立页面展示贴纸交互功能
struct StickerPage: View {

    // MARK: - 属性

    /// 可用的贴纸列表
    let stickers: [StickerDefinition]

    /// 使用贴纸的外部回调
    var onUseSticker: ((StickerDefinition) -> Void)?

    // MARK: - 状态

    @State private var usedSticker: StickerDefinition?
    @State private var showUsedFeedback = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - 初始化

    init(
        stickers: [StickerDefinition] = StickerDefinition.mockAll,
        onUseSticker: ((StickerDefinition) -> Void)? = nil
    ) {
        self.stickers = stickers
        self.onUseSticker = onUseSticker
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 贴纸交互区域
            StickerFieldView(stickers: stickers) { sticker in
                handleStickerUsed(sticker)
            }

            // 使用成功反馈
            if showUsedFeedback, let sticker = usedSticker {
                usedFeedbackView(sticker: sticker)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .navigationTitle("贴纸")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    dismiss()
                }
            }
        }
    }

    // MARK: - 子视图

    /// 使用成功反馈视图
    private func usedFeedbackView(sticker: StickerDefinition) -> some View {
        VStack(spacing: 12) {
            // 图标
            Group {
                switch sticker.assetKind {
                case .systemSymbol(let name):
                    Image(systemName: name)
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                case .image(let name):
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                default:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                }
            }

            Text("已使用「\(sticker.displayName)」")
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }

    // MARK: - 处理逻辑

    private func handleStickerUsed(_ sticker: StickerDefinition) {
        // 设置当前使用的贴纸
        usedSticker = sticker

        // 显示反馈
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showUsedFeedback = true
        }

        // 回调外部
        onUseSticker?(sticker)

        // 打印日志
        print("[StickerPage] Used: \(sticker.stickerID.rawValue) - \(sticker.displayName)")

        // 延迟隐藏反馈
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showUsedFeedback = false
            }
        }
    }
}

// MARK: - Preview

#Preview("Default") {
    NavigationStack {
        StickerPage()
    }
}

#Preview("With Callback") {
    NavigationStack {
        StickerPage(stickers: StickerDefinition.mockAll) { sticker in
            print("外部回调: \(sticker.displayName)")
        }
    }
}
