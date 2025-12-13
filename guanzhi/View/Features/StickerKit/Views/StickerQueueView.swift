//
//  StickerQueueView.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/11.
//
//  贴纸队列视图 - 仅显示底部贴纸横条（无使用区域）
//

import SwiftUI
import SpriteKit

// MARK: - StickerQueueView

/// 贴纸队列视图（简化版）
/// 仅显示底部的贴纸横条，用于嵌入到其他视图中
struct StickerQueueView: View {

    // MARK: - 属性

    /// 可用的贴纸列表
    let stickers: [StickerDefinition]

    /// 队列高度
    let height: CGFloat

    /// 使用贴纸的回调（贴纸被拖到屏幕上方时触发）
    var onUseSticker: ((StickerDefinition) -> Void)?

    /// 使用区域的 frame（在父视图坐标系中）
    var useZoneFrame: CGRect = .zero

    // MARK: - 状态

    @StateObject private var motionManager = StickerMotionManager()
    @State private var scene: StickerScene?
    @State private var isLoading = true

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // 背景（可选）
                Color.clear

                // 加载中
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                } else {
                    // SpriteKit 场景
                    spriteKitView(size: proxy.size)
                }
            }
        }
        .frame(height: height)
        .onAppear {
            preloadTextures()
            motionManager.start()
        }
        .onDisappear {
            motionManager.stop()
        }
        .onChange(of: useZoneFrame) { _, newFrame in
            updateUseZoneFrame(newFrame)
        }
    }

    // MARK: - SpriteKit 视图

    private func spriteKitView(size: CGSize) -> some View {
        SpriteView(
            scene: getOrCreateScene(size: size),
            options: [.allowsTransparency]
        )
        .frame(width: size.width, height: size.height)
    }

    // MARK: - 预加载

    private func preloadTextures() {
        let size = CGSize(width: 72, height: 72)
        // ✅ 同步预加载（主线程），确保线程安全
        StickerTextureCache.shared.preload(definitions: stickers, size: size)
        withAnimation(.easeIn(duration: 0.3)) {
            isLoading = false
        }
    }

    // MARK: - 场景管理

    private func getOrCreateScene(size: CGSize) -> SKScene {
        if let existingScene = scene {
            if existingScene.size != size {
                existingScene.size = size
            }
            return existingScene
        }

        let newScene = StickerScene(size: size, stickers: stickers)
        newScene.stickerDelegate = Coordinator(onUseSticker: onUseSticker)
        newScene.motionManager = motionManager

        DispatchQueue.main.async {
            self.scene = newScene
        }

        return newScene
    }

    private func updateUseZoneFrame(_ frame: CGRect) {
        guard let scene = scene else { return }
        // 将 SwiftUI 坐标转换为 SpriteKit 坐标（Y轴翻转）
        let sceneHeight = scene.size.height
        let convertedFrame = CGRect(
            x: frame.origin.x,
            y: sceneHeight - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )
        scene.useZoneFrameInScene = convertedFrame
    }

    // MARK: - Coordinator

    private class Coordinator: StickerSceneDelegate {
        let onUseSticker: ((StickerDefinition) -> Void)?

        init(onUseSticker: ((StickerDefinition) -> Void)?) {
            self.onUseSticker = onUseSticker
        }

        func stickerScene(_ scene: StickerScene, didUse sticker: StickerDefinition) {
            onUseSticker?(sticker)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("StickerQueueView") {
    VStack {
        Spacer()

        StickerQueueView(
            stickers: StickerDefinition.mockAll,
            height: 150
        ) { sticker in
            print("Used sticker: \(sticker.displayName)")
        }
        .background(Color.black.opacity(0.3))
    }
}
#endif
