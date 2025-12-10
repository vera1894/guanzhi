//
//  StickerFieldView.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/10.
//
//  贴纸交互区域视图 - SwiftUI 容器
//

import SwiftUI
import SpriteKit

// MARK: - StickerFieldView

/// 贴纸交互区域视图
/// 包含 SpriteKit 场景和使用区域 overlay
struct StickerFieldView: View {

    // MARK: - 属性

    /// 可用的贴纸列表
    let stickers: [StickerDefinition]

    /// 使用贴纸的回调
    var onUseSticker: (StickerDefinition) -> Void

    // MARK: - 状态

    @StateObject private var motionManager = StickerMotionManager()
    @State private var scene: StickerScene?
    @State private var isLoading = true
    @State private var sceneCreated = false

    /// 调试模式（仅 DEBUG 生效）
    private let debugMode = false

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                // 背景渐变
                backgroundGradient

                // 加载中
                if isLoading {
                    loadingView
                } else {
                    // SpriteKit 场景
                    spriteKitView(size: proxy.size)
                }

                // 使用区域 overlay
                useZoneOverlay
                    .frame(height: 110)
                    .padding(.top, 100)
                    .padding(.horizontal, 40)
                    .background(useZoneGeometryReader(rootProxy: proxy))

                // 调试信息
                #if DEBUG
                if debugMode {
                    debugOverlay
                }
                #endif
            }
            .coordinateSpace(name: "stickerField")
        }
        .onAppear {
            preloadTextures()
            motionManager.start()
        }
        .onDisappear {
            motionManager.stop()
        }
    }

    // MARK: - 子视图

    /// 背景渐变
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(UIColor.systemBackground),
                Color(UIColor.systemBackground).opacity(0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    /// 加载视图
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载贴纸...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// SpriteKit 视图
    private func spriteKitView(size: CGSize) -> some View {
        SpriteView(
            scene: getOrCreateScene(size: size),
            options: [.allowsTransparency]
        )
        .ignoresSafeArea()
    }

    /// 使用区域 overlay
    private var useZoneOverlay: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.primary.opacity(0.03))

            // 虚线边框
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [12, 8])
                )
                .foregroundStyle(Color.secondary.opacity(0.4))

            // 提示内容
            VStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary.opacity(0.6))

                Text("拖动贴纸到这里使用")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 预加载

    private func preloadTextures() {
        let size = CGSize(width: 72, height: 72)
        StickerTextureCache.shared.preload(definitions: stickers, size: size) {
            withAnimation(.easeIn(duration: 0.3)) {
                isLoading = false
            }
        }
    }

    // MARK: - 场景管理

    private func getOrCreateScene(size: CGSize) -> SKScene {
        if let existingScene = scene {
            // 更新尺寸
            if existingScene.size != size {
                existingScene.size = size
            }
            return existingScene
        }

        // 创建新场景
        let newScene = StickerScene(size: size, stickers: stickers)
        newScene.stickerDelegate = Coordinator(onUseSticker: onUseSticker)
        newScene.motionManager = motionManager

        // 延迟设置状态，避免在视图更新中修改状态
        DispatchQueue.main.async {
            self.scene = newScene
            self.sceneCreated = true
        }

        return newScene
    }

    // MARK: - 坐标转换

    private func useZoneGeometryReader(rootProxy: GeometryProxy) -> some View {
        GeometryReader { zoneProxy in
            Color.clear
                .onAppear {
                    updateUseZoneFrame(zoneProxy: zoneProxy, rootProxy: rootProxy)
                }
                .onChange(of: rootProxy.size) { _, _ in
                    updateUseZoneFrame(zoneProxy: zoneProxy, rootProxy: rootProxy)
                }
                .onChange(of: sceneCreated) { _, _ in
                    updateUseZoneFrame(zoneProxy: zoneProxy, rootProxy: rootProxy)
                }
        }
    }

    private func updateUseZoneFrame(zoneProxy: GeometryProxy, rootProxy: GeometryProxy) {
        guard let scene = scene else { return }

        // 获取使用区域在坐标空间中的位置
        let zoneFrameInRoot = zoneProxy.frame(in: .named("stickerField"))
        let rootSize = rootProxy.size
        let sceneSize = scene.size

        // 计算缩放比例
        let scaleX = sceneSize.width / rootSize.width
        let scaleY = sceneSize.height / rootSize.height

        // SwiftUI: Y 轴向下，原点左上角
        // SpriteKit: Y 轴向上，原点左下角
        // 转换公式: sceneY = sceneHeight - swiftUIY * scaleY

        let convertedMinY = sceneSize.height - (zoneFrameInRoot.maxY * scaleY)

        let convertedRect = CGRect(
            x: zoneFrameInRoot.minX * scaleX,
            y: convertedMinY,
            width: zoneFrameInRoot.width * scaleX,
            height: zoneFrameInRoot.height * scaleY
        )

        scene.useZoneFrameInScene = convertedRect
    }

    // MARK: - 调试 Overlay

    #if DEBUG
    private var debugOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let scene = scene {
                Text("Scene: \(Int(scene.size.width))×\(Int(scene.size.height))")
                Text("Zone: (\(Int(scene.useZoneFrameInScene.minX)), \(Int(scene.useZoneFrameInScene.minY))) \(Int(scene.useZoneFrameInScene.width))×\(Int(scene.useZoneFrameInScene.height))")
            }
            Text("Gravity X: \(String(format: "%.2f", motionManager.gravityX))")
            Text("Motion: \(motionManager.isAvailable ? "可用" : "不可用")")
        }
        .font(.caption2.monospaced())
        .padding(8)
        .background(Color.black.opacity(0.75))
        .foregroundColor(.green)
        .cornerRadius(8)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    #endif

    // MARK: - Coordinator

    /// 场景代理适配器
    private class Coordinator: StickerSceneDelegate {
        let onUseSticker: (StickerDefinition) -> Void

        init(onUseSticker: @escaping (StickerDefinition) -> Void) {
            self.onUseSticker = onUseSticker
        }

        func stickerScene(_ scene: StickerScene, didUse sticker: StickerDefinition) {
            onUseSticker(sticker)
        }
    }
}

// MARK: - Preview

#Preview {
    StickerFieldView(stickers: StickerDefinition.mockAll) { sticker in
        print("使用贴纸: \(sticker.displayName)")
    }
}
