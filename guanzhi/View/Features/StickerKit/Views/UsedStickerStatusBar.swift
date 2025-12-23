//
//  UsedStickerStatusBar.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/21.
//
//  已使用贴纸状态条
//  当用户对某条分享使用过贴纸后，替代贴纸队列显示
//

import SwiftUI

/// 已使用贴纸状态条
/// 显示"已使用了「xx」贴纸" + 贴纸图标
struct UsedStickerStatusBar: View {
    /// 已使用的贴纸信息
    let usedSticker: UsedStickerInfo

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：贴纸图标
            stickerIcon

            // 右侧：已使用文案
            Text("已使用了「\(usedSticker.name)」贴纸")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.4))
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
        )
        .clipShape(Capsule())
    }

    // MARK: - 贴纸图标

    @ViewBuilder
    private var stickerIcon: some View {
        // 尝试使用服务器图标 URL，否则使用本地图标
        if let iconURL = usedSticker.iconURL {
            AsyncImage(url: iconURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                case .failure, .empty:
                    localStickerIcon
                @unknown default:
                    localStickerIcon
                }
            }
        } else {
            localStickerIcon
        }
    }

    /// 本地贴纸图标（从 StickerDefinition 获取）
    @ViewBuilder
    private var localStickerIcon: some View {
        let definition = StickerDefinition.definition(for: usedSticker.kind)

        switch definition.assetKind {
        case .image(let name):
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)

        case .systemSymbol(let name):
            Image(systemName: name)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)

        case .textFallback(let characters):
            Text(characters)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                )

        case .svg, .threeD:
            // 预留类型，暂用占位符
            Circle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 28, height: 28)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("UsedStickerStatusBar") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            UsedStickerStatusBar(
                usedSticker: UsedStickerInfo(kind: .like, name: "赞同")
            )

            UsedStickerStatusBar(
                usedSticker: UsedStickerInfo(kind: .neutral, name: "无感")
            )

            UsedStickerStatusBar(
                usedSticker: UsedStickerInfo(kind: .zhenxiu, name: "珍馐")
            )

            UsedStickerStatusBar(
                usedSticker: UsedStickerInfo(kind: .mijing, name: "秘境")
            )
        }
    }
}
#endif
