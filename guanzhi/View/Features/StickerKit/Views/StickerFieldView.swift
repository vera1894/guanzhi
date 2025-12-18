//
//  StickerFieldView.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/10.
//
//  贴纸交互区域视图 - SwiftUI 容器
//
//  重要架构说明：
//  - StickerScene 始终存在，不会被设为 nil
//  - 贴纸变化时通过 scene.resetStickers() 更新内容
//  - 所有尺寸相关操作都有 size > 0 的防护
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

    /// 贴纸加载状态（用于显示 loading/error UI）
    var stickerLoadingState: StickerLoadingState = .loaded

    /// 重试加载的回调（用户点击重试按钮时调用）
    var onRetryLoad: (() -> Void)? = nil

    /// 是否显示背景渐变（默认 true）
    var showBackground: Bool = true

    /// 是否显示使用区域提示框（默认 true）
    var showUseZoneHint: Bool = true

    /// 使用区域在场景中的位置（可外部传入，默认自动计算）
    /// 当嵌入到其他视图中时，可以通过此属性指定使用区域
    var customUseZoneFrame: CGRect? = nil

    /// 贴纸队列距离底部的距离（SpriteKit 坐标系）
    /// 默认 100pt，在有底部 sheet 的页面中可以设置更大的值
    var queueBottomY: CGFloat = 100

    /// 触摸响应区域高度（从底部算起，SwiftUI 坐标系）
    /// 只有在这个区域内的触摸才会被贴纸场景处理，其他区域会穿透到下层视图
    /// 设置为 nil 表示全屏响应（适用于独立的 StickerPage）
    var touchAreaHeight: CGFloat? = nil

    /// 是否启用自动轮播（基于陀螺仪的贴纸滚动）
    /// 在嵌入到其他页面时可以关闭以节省性能
    var enableAutoScroll: Bool = true

    // MARK: - 状态

    @StateObject private var motionManager = StickerMotionManager()

    /// ✅ 场景始终存在，永不为 nil
    @StateObject private var sceneHolder = SceneHolder()

    /// 是否正在加载纹理
    @State private var isLoading = true

    /// ✅ 强引用 Coordinator，防止被释放
    @State private var coordinator: Coordinator?

    /// 缓存的上次有效尺寸（防止零尺寸更新）
    @State private var lastValidSize: CGSize = .zero

    /// 是否已完成初始设置
    @State private var isSetupDone = false

    /// 调试模式（仅 DEBUG 生效）
    private let debugMode = false

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack(alignment: .top) {
                // 背景渐变（可选）
                if showBackground {
                    backgroundGradient
                }

                // 根据加载状态显示不同内容
                #if DEBUG
                let _ = print("🎨 [StickerFieldView] 渲染状态: loadingState=\(stickerLoadingState), stickers.count=\(stickers.count), stickers.isEmpty=\(stickers.isEmpty)")
                #endif

                switch stickerLoadingState {
                case .idle, .loading:
                    // 加载中状态：显示加载动画
                    #if DEBUG
                    let _ = print("🎨 [StickerFieldView] 显示: stickerLoadingView (状态=\(stickerLoadingState))")
                    #endif
                    stickerLoadingView

                case .failed(let retryCount):
                    // 加载失败状态
                    if retryCount >= StickerLoadingConfig.maxRetryCount {
                        // 达到最大重试次数：显示重试按钮
                        #if DEBUG
                        let _ = print("🎨 [StickerFieldView] 显示: stickerFailedView (retryCount=\(retryCount))")
                        #endif
                        stickerFailedView
                    } else {
                        // 自动重试中：显示加载动画
                        #if DEBUG
                        let _ = print("🎨 [StickerFieldView] 显示: stickerLoadingView (自动重试中, retryCount=\(retryCount))")
                        #endif
                        stickerLoadingView
                    }

                case .loaded:
                    // 加载成功：显示贴纸场景
                    #if DEBUG
                    let _ = print("🎨 [StickerFieldView] 显示: spriteKitView (stickers.count=\(stickers.count), opacity=\(stickers.isEmpty ? 0 : 1))")
                    #endif
                    // ✅ 只有尺寸有效时才渲染 SpriteKit 场景
                    if size.width > 0 && size.height > 0 {
                        spriteKitView(size: size)
                            .opacity(stickers.isEmpty ? 0 : 1)
                    }

                    // 纹理加载中显示加载视图
                    if isLoading && !stickers.isEmpty {
                        loadingView
                    }
                }

                // 使用区域 overlay（仅在加载成功且有贴纸时显示）
                if showUseZoneHint && stickerLoadingState == .loaded && !stickers.isEmpty {
                    useZoneOverlay
                        .frame(height: 110)
                        .padding(.top, 100)
                        .padding(.horizontal, 40)
                        .background(useZoneGeometryReader(rootProxy: proxy))
                }

                // 调试信息
                #if DEBUG
                if debugMode {
                    debugOverlay
                }
                #endif
            }
            .coordinateSpace(name: "stickerField")
            .onAppear {
                #if DEBUG
                print("✅ [StickerFieldView] onAppear, size=\(size), stickers=\(stickers.count)")
                #endif
                setupSceneIfNeeded()
                applySizeIfNeeded(size)
            }
            .onChange(of: size) { _, newSize in
                applySizeIfNeeded(newSize)
            }
        }
        .onAppear {
            if enableAutoScroll {
                motionManager.start()
            }
        }
        .onDisappear {
            motionManager.stop()
        }
        // ✅ 简化的 onChange：每次 stickers 变化都直接 reset
        .onChange(of: stickers) { _, newValue in
            #if DEBUG
            print("🔄 [StickerFieldView] stickers changed, count=\(newValue.count)")
            #endif
            applyStickerChange(to: newValue)
        }
    }

    // MARK: - 场景设置

    /// 初始化场景配置（只执行一次）
    private func setupSceneIfNeeded() {
        guard !isSetupDone else { return }
        isSetupDone = true

        #if DEBUG
        print("✅ [StickerFieldView] setupSceneIfNeeded")
        #endif

        // 创建 Coordinator 并设置代理
        let newCoordinator = Coordinator(onUseSticker: onUseSticker)
        sceneHolder.scene.stickerDelegate = newCoordinator
        sceneHolder.scene.motionManager = enableAutoScroll ? motionManager : nil
        sceneHolder.scene.queueBottomY = queueBottomY
        sceneHolder.scene.enableAutoScroll = enableAutoScroll

        coordinator = newCoordinator

        // 应用初始贴纸（如果有）
        applyStickerChange(to: stickers)
    }

    /// 应用尺寸变化（带防护）
    private func applySizeIfNeeded(_ size: CGSize) {
        // 保护：0 尺寸直接跳过
        guard size.width > 0, size.height > 0 else {
            #if DEBUG
            print("⚠️ [StickerFieldView] 跳过 applySizeIfNeeded，size 为 0：\(size)")
            #endif
            return
        }

        // 如果尺寸没变，跳过
        guard size != lastValidSize else { return }

        #if DEBUG
        print("✅ [StickerFieldView] applySizeIfNeeded, size=\(size)")
        #endif

        lastValidSize = size
        configureScene(size: size)
    }

    /// 处理贴纸列表变化（简化版：不做 diff，直接 reset）
    private func applyStickerChange(to newStickers: [StickerDefinition]) {
        #if DEBUG
        print("✅ [StickerFieldView] applyStickerChange, count=\(newStickers.count)")
        #endif

        if newStickers.isEmpty {
            sceneHolder.scene.clearAllStickers()
            isLoading = false
            return
        }

        isLoading = true
        // ✅ 主线程同步预加载，确保线程安全
        preloadTexturesSync(for: newStickers)
        sceneHolder.scene.resetStickers(with: newStickers)
        isLoading = false
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

    /// 加载视图（纹理加载）
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

    /// 贴纸可用性加载中视图（从服务器加载）
    /// 位置：固定在屏幕底部，与贴纸队列位置一致
    private var stickerLoadingView: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                // 加载动画
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            Color.white.opacity(0.8),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(stickerLoadingRotation))
                        .onAppear {
                            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                                stickerLoadingRotation = 360
                            }
                        }
                }

                Text("正在加载贴纸...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.3))
            )
            .padding(.bottom, queueBottomY - 40)  // 与贴纸队列位置对齐
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 贴纸加载失败视图（显示重试按钮）
    /// 位置：固定在屏幕底部，与贴纸队列位置一致
    private var stickerFailedView: some View {
        VStack {
            Spacer()

            VStack(spacing: 12) {
                Text("贴纸加载失败")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                // 重试按钮
                Button(action: {
                    onRetryLoad?()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                        Text("点击重试")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, queueBottomY - 40)  // 与贴纸队列位置对齐
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 加载动画旋转角度
    @State private var stickerLoadingRotation: Double = 0

    /// SpriteKit 视图
    @ViewBuilder
    private func spriteKitView(size: CGSize) -> some View {
        // 在渲染前配置场景（尺寸已在 applySizeIfNeeded 中验证）
        let _ = configureScene(size: size)

        if let height = touchAreaHeight {
            let touchRegion = CGRect(
                x: 0,
                y: size.height - height,
                width: size.width,
                height: height
            )
            PassthroughSpriteView(scene: sceneHolder.scene, touchActiveRegion: touchRegion)
                .frame(width: size.width, height: size.height)
        } else {
            SpriteView(scene: sceneHolder.scene, options: [.allowsTransparency])
                .frame(width: size.width, height: size.height)
        }
    }

    /// 配置场景参数
    private func configureScene(size: CGSize) {
        // 保护：0 尺寸直接跳过
        guard size.width > 0, size.height > 0 else {
            #if DEBUG
            print("⚠️ [StickerFieldView] 跳过 configureScene，size 为 0：\(size)")
            #endif
            return
        }

        let scene = sceneHolder.scene

        if scene.size != size {
            #if DEBUG
            print("✅ [StickerFieldView] configureScene, size=\(size)")
            #endif
            scene.size = size
        }

        scene.queueBottomY = queueBottomY
        scene.enableAutoScroll = enableAutoScroll

        if let customFrame = customUseZoneFrame {
            scene.useZoneFrameInScene = convertToSpriteKitCoordinates(customFrame, in: size)
        }
    }

    /// 使用区域 overlay
    private var useZoneOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.primary.opacity(0.03))

            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [12, 8])
                )
                .foregroundStyle(Color.secondary.opacity(0.4))

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

    /// ✅ 主线程同步预加载（确保线程安全）
    private func preloadTexturesSync(for definitions: [StickerDefinition]) {
        let size = CGSize(width: 72, height: 72)
        for definition in definitions {
            _ = StickerTextureCache.shared.texture(for: definition, size: size)
        }
    }

    /// 将 SwiftUI 坐标系的 frame 转换为 SpriteKit 坐标系
    private func convertToSpriteKitCoordinates(_ frame: CGRect, in sceneSize: CGSize) -> CGRect {
        guard sceneSize.width > 0, sceneSize.height > 0 else { return .zero }
        let convertedY = sceneSize.height - frame.origin.y - frame.height
        return CGRect(
            x: frame.origin.x,
            y: convertedY,
            width: frame.width,
            height: frame.height
        )
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
        }
    }

    private func updateUseZoneFrame(zoneProxy: GeometryProxy, rootProxy: GeometryProxy) {
        let scene = sceneHolder.scene

        if let customFrame = customUseZoneFrame {
            scene.useZoneFrameInScene = customFrame
            return
        }

        guard scene.size.width > 0 && scene.size.height > 0 else { return }
        guard rootProxy.size.width > 0 && rootProxy.size.height > 0 else { return }

        let zoneFrameInRoot = zoneProxy.frame(in: .named("stickerField"))
        let rootSize = rootProxy.size
        let sceneSize = scene.size

        let scaleX = sceneSize.width / rootSize.width
        let scaleY = sceneSize.height / rootSize.height

        guard scaleX.isFinite, scaleY.isFinite else { return }

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
            let scene = sceneHolder.scene
            Text("Scene: \(Int(scene.size.width))×\(Int(scene.size.height))")
            Text("Zone: (\(Int(scene.useZoneFrameInScene.minX)), \(Int(scene.useZoneFrameInScene.minY)))")
            Text("Gravity X: \(String(format: "%.2f", motionManager.gravityX))")
            Text("Loading: \(isLoading ? "是" : "否")")
            Text("Stickers: \(stickers.count)")
            Text("LastSize: \(Int(lastValidSize.width))×\(Int(lastValidSize.height))")
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

// MARK: - SceneHolder

private class SceneHolder: ObservableObject {
    let scene: StickerScene

    init() {
        // 使用一个合理的初始尺寸（非零）
        self.scene = StickerScene(size: CGSize(width: 375, height: 400))
        #if DEBUG
        print("✅ [SceneHolder] init, scene created")
        #endif
    }
}

// MARK: - Preview

#Preview {
    StickerFieldView(stickers: StickerDefinition.mockAll) { sticker in
        print("使用贴纸: \(sticker.displayName)")
    }
}
