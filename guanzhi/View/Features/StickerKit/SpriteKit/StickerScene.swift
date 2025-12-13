//
//  StickerScene.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/10.
//
//  贴纸交互场景 - SpriteKit 实现
//

import SpriteKit

// MARK: - ⚙️ 可调参数（方便调试）

/// 自动轮播速度（点/秒），值越大轮播越快
private let kAutoScrollSpeed: CGFloat = 50

/// 橡皮筋阻力系数（0-1），值越小拉动越费力
private let kRubberBandResistance: CGFloat = 0.55

/// 橡皮筋回弹动画时长（秒）
private let kRubberBandBounceDuration: TimeInterval = 0.4

/// 惯性滚动减速系数（0-1），值越大滑得越远
private let kDecelerationRate: CGFloat = 0.95

/// 惯性滚动最小速度阈值（点/秒），低于此值停止滚动
private let kMinVelocityThreshold: CGFloat = 8

// MARK: - StickerSceneDelegate

/// 贴纸场景代理协议
protocol StickerSceneDelegate: AnyObject {
    /// 当用户成功使用一个贴纸时调用
    func stickerScene(_ scene: StickerScene, didUse sticker: StickerDefinition)
}

// MARK: - StickerScene

/// 贴纸交互场景
final class StickerScene: SKScene {

    // MARK: - 代理

    weak var stickerDelegate: StickerSceneDelegate?

    // MARK: - 数据（私有，通过方法访问）

    /// 当前贴纸定义列表（可通过 resetStickers 更新）
    private var stickerDefinitions: [StickerDefinition]
    private var stickerNodes: [SKSpriteNode] = []

    // MARK: - 配置

    private let stickerSize = CGSize(width: 72, height: 72)
    private let spacing: CGFloat = 16
    private let edgePadding: CGFloat = 24  // 屏幕边缘留白（确保贴纸完全显示）

    /// 贴纸队列距离底部的距离（可配置）
    var queueBottomY: CGFloat = 100

    /// 是否启用自动轮播
    var enableAutoScroll: Bool = true

    /// 贴纸队列的 Y 坐标
    private var queueY: CGFloat {
        return queueBottomY
    }

    // MARK: - 横向位置管理（slot 系统）

    /// 每个贴纸的基准 X（slot 中心位置），不包含滚动偏移
    /// 使用数组索引作为 key，与 stickerNodes 对应
    private var baseXPositions: [CGFloat] = []

    /// 当前队列的横向滚动偏移（所有贴纸共享）
    private var scrollOffsetX: CGFloat = 0

    // MARK: - 滚动状态

    private var contentWidth: CGFloat = 0
    private var canAutoScroll = false
    private var isUserInteracting = false

    // MARK: - 边界限制（基于 scrollOffsetX）

    private var minScrollOffsetX: CGFloat = 0
    private var maxScrollOffsetX: CGFloat = 0

    // MARK: - 拖拽状态

    private var draggingNode: SKSpriteNode?
    private var draggingOriginalPosition: CGPoint?
    private var draggingOriginalIndex: Int?

    // MARK: - 队列滚动状态

    private var isPanningQueue = false
    private var lastPanLocation: CGPoint?

    // MARK: - 惯性滚动状态

    /// 当前滚动速度（点/秒）
    private var scrollVelocity: CGFloat = 0
    /// 是否正在惯性滚动
    private var isDecelerating = false
    /// 上次触摸时间（用于计算速度）
    private var lastTouchTime: TimeInterval = 0
    /// 速度采样（用于平滑速度计算）
    private var velocitySamples: [CGFloat] = []
    private let maxVelocitySamples = 5

    // MARK: - 橡皮筋状态

    /// 是否正在橡皮筋回弹
    private var isBouncingBack = false
    /// 当前超出边界的距离（正值表示超出右边界，负值表示超出左边界）
    private var overscrollAmount: CGFloat = 0

    // MARK: - 方向判断状态

    /// 触摸起始位置
    private var touchStartLocation: CGPoint?
    /// 触摸起始时命中的贴纸节点（待判断方向）
    private var pendingStickerNode: SKSpriteNode?
    /// 是否已确定交互模式（拖贴纸 or 滚动列表）
    private var interactionModeDecided = false
    /// 向上拖动的最小角度阈值（度数，相对于水平线）
    private let upwardAngleThreshold: CGFloat = 45

    // MARK: - 贴纸交互状态

    /// 正在执行回弹动画的贴纸节点
    private weak var returningNode: SKSpriteNode?

    /// 是否有贴纸正在被拖拽或回弹中
    /// 当此状态为 true 时，队列禁止滑动
    private var isQueueLocked: Bool {
        return draggingNode != nil || returningNode != nil
    }

    // MARK: - 使用区域（由 SwiftUI 层传入）

    var useZoneFrameInScene: CGRect = .zero

    // MARK: - 粒子效果

    /// 使用区域圆环提示粒子发射器
    private var useZoneHintEmitter: SKEmitterNode?
    /// 使用区域位置（圆环粒子的中心点）
    private var useZoneCenter: CGPoint {
        CGPoint(x: useZoneFrameInScene.midX, y: useZoneFrameInScene.midY)
    }

    // MARK: - 运动管理器（外部注入）

    weak var motionManager: StickerMotionManager?

    // MARK: - 初始化

    /// 默认初始化器（空贴纸列表）
    /// 用于 StickerFieldView 中场景始终存在的模式
    override init(size: CGSize) {
        self.stickerDefinitions = []
        super.init(size: size)
        scaleMode = .resizeFill
    }

    /// 带贴纸列表的初始化器
    init(size: CGSize, stickers: [StickerDefinition]) {
        self.stickerDefinitions = stickers
        super.init(size: size)
        // 使用 resizeFill 让场景坐标系精确匹配视图尺寸
        // 这样 size.width 就是实际屏幕宽度
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 公开方法：重置/清空贴纸

    /// 重置贴纸列表（用于贴纸数据变化时）
    /// 会清除所有现有节点，然后根据新的定义重新布局
    func resetStickers(with newStickers: [StickerDefinition]) {
        #if DEBUG
        print("✅ [StickerScene] resetStickers, count=\(newStickers.count), size=\(size)")
        #endif

        // ✅ 保护：场景尺寸必须有效
        guard size.width > 0, size.height > 0 else {
            #if DEBUG
            print("⚠️ [StickerScene] resetStickers 跳过，size 无效：\(size)")
            #endif
            // 先保存定义，等尺寸有效时再布局
            stickerDefinitions = newStickers
            return
        }

        // 停止所有进行中的动画和状态
        stopAllInteractions()

        // 更新定义
        stickerDefinitions = newStickers

        // 重新布局
        layoutStickers()
        calculateScrollBounds()

        // 恢复场景运行（如果之前暂停了）
        if isPaused {
            isPaused = false
        }
    }

    /// 清空所有贴纸节点（保持场景存在）
    func clearAllStickers() {
        #if DEBUG
        print("🧹 [StickerScene] clearAllStickers")
        #endif

        // 停止所有进行中的动画和状态
        stopAllInteractions()

        // 清除节点
        stickerNodes.forEach { $0.removeFromParent() }
        stickerNodes.removeAll()
        baseXPositions.removeAll()
        stickerDefinitions = []

        // 重置滚动状态
        scrollOffsetX = 0
        contentWidth = 0
        canAutoScroll = false
        minScrollOffsetX = 0
        maxScrollOffsetX = 0
    }

    /// 停止所有进行中的交互和动画
    private func stopAllInteractions() {
        // 停止惯性滚动
        isDecelerating = false
        scrollVelocity = 0
        velocitySamples.removeAll()

        // 停止橡皮筋回弹
        isBouncingBack = false
        removeAllActions()

        // 清除拖拽状态
        draggingNode = nil
        draggingOriginalPosition = nil
        draggingOriginalIndex = nil
        returningNode = nil

        // 清除滚动状态
        isPanningQueue = false
        lastPanLocation = nil
        touchStartLocation = nil
        pendingStickerNode = nil
        interactionModeDecided = false

        // 恢复用户交互标志
        isUserInteracting = false

        // 隐藏粒子效果
        hideUseZoneHint()

        // 停止所有节点的动画
        stickerNodes.forEach { $0.removeAllActions() }
    }

    // MARK: - 公开方法：查找贴纸定义

    /// 通过 StickerID 查找定义
    func definition(for id: StickerID) -> StickerDefinition? {
        stickerDefinitions.first { $0.stickerID == id }
    }

    /// 通过原始 ID 字符串查找定义
    func definition(forRawValue rawValue: String) -> StickerDefinition? {
        stickerDefinitions.first { $0.stickerID.rawValue == rawValue }
    }

    // MARK: - 生命周期

    override func didMove(to view: SKView) {
        #if DEBUG
        print("✅ [StickerScene] didMove(to:), size=\(size), stickers=\(stickerDefinitions.count)")
        #endif

        backgroundColor = .clear
        setupPhysicsWorld()

        // ✅ 只有尺寸有效时才布局
        if size.width > 0, size.height > 0 {
            layoutStickers()
            calculateScrollBounds()
        } else {
            #if DEBUG
            print("⚠️ [StickerScene] didMove(to:) 跳过布局，size 无效：\(size)")
            #endif
        }

        // 如果禁用自动轮播，初始时暂停场景以节省性能
        if !enableAutoScroll {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.pauseIfIdle()
            }
        }
    }

    override func willMove(from view: SKView) {
        // 清理工作（如果需要）
    }

    // MARK: - 布局

    private func layoutStickers() {
        // ✅ 保护：场景尺寸必须有效
        guard size.width > 0, size.height > 0 else {
            #if DEBUG
            print("⚠️ [StickerScene] layoutStickers 跳过，size 无效：\(size)")
            #endif
            return
        }

        // 清理现有节点和基准位置
        stickerNodes.forEach { $0.removeFromParent() }
        stickerNodes.removeAll()
        baseXPositions.removeAll()

        // 重置滚动偏移
        scrollOffsetX = 0

        // 第一个贴纸的基准 x = 边缘留白 + 贴纸半宽
        var baseX: CGFloat = edgePadding + stickerSize.width / 2
        let y: CGFloat = queueY

        for def in stickerDefinitions {
            let node = StickerSpriteFactory.makeNode(for: def, size: stickerSize)
            node.position = CGPoint(x: baseX, y: y)  // 初始位置 = 基准位置（偏移为0）
            node.zPosition = 1
            addChild(node)
            stickerNodes.append(node)
            baseXPositions.append(baseX)  // 记录这个 slot 的基准 X

            baseX += stickerSize.width + spacing
        }

        // 内容总宽度 = 最后一个贴纸右边缘 + 边缘留白
        contentWidth = baseX - spacing + edgePadding
        canAutoScroll = contentWidth > size.width
    }

    private func setupPhysicsWorld() {
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
    }

    /// 计算滚动边界（基于 scrollOffsetX）
    private func calculateScrollBounds() {
        // ✅ 保护：场景尺寸必须有效
        guard size.width > 0, size.height > 0 else {
            #if DEBUG
            print("⚠️ [StickerScene] calculateScrollBounds 跳过，size 无效：\(size)")
            #endif
            minScrollOffsetX = 0
            maxScrollOffsetX = 0
            canAutoScroll = false
            return
        }

        guard !baseXPositions.isEmpty else {
            minScrollOffsetX = 0
            maxScrollOffsetX = 0
            canAutoScroll = false
            return
        }

        let stickerCount = CGFloat(stickerNodes.count)
        let actualContentWidth = edgePadding * 2 + stickerCount * stickerSize.width + max(0, stickerCount - 1) * spacing

        // 如果内容不足屏幕宽度，居中显示，不允许滚动
        if actualContentWidth <= size.width {
            canAutoScroll = false
            // 计算居中需要的偏移量
            let totalStickerWidth = stickerCount * stickerSize.width + max(0, stickerCount - 1) * spacing
            let centeredFirstX = (size.width - totalStickerWidth) / 2 + stickerSize.width / 2
            let currentFirstBaseX = baseXPositions[0]
            let centerOffset = centeredFirstX - currentFirstBaseX

            // ✅ 安全检查：确保计算结果有限
            guard centerOffset.isFinite else {
                #if DEBUG
                print("⚠️ [StickerScene] calculateScrollBounds 跳过，centerOffset 无效：\(centerOffset)")
                #endif
                minScrollOffsetX = 0
                maxScrollOffsetX = 0
                return
            }

            minScrollOffsetX = centerOffset
            maxScrollOffsetX = centerOffset
            // 应用居中偏移
            scrollOffsetX = centerOffset
            repositionAllStickers()
        } else {
            canAutoScroll = true
            let firstBaseX = baseXPositions[0]
            let lastBaseX = baseXPositions[baseXPositions.count - 1]

            // maxScrollOffsetX: 第一个贴纸完全显示在屏幕左侧
            // 第一个贴纸中心 x = edgePadding + stickerSize/2
            // firstBaseX + maxScrollOffsetX = edgePadding + stickerSize/2
            let calculatedMax = (edgePadding + stickerSize.width / 2) - firstBaseX

            // minScrollOffsetX: 最后一个贴纸完全显示在屏幕右侧
            // 最后一个贴纸中心 x = size.width - edgePadding - stickerSize/2
            // lastBaseX + minScrollOffsetX = size.width - edgePadding - stickerSize/2
            let calculatedMin = (size.width - edgePadding - stickerSize.width / 2) - lastBaseX

            // ✅ 安全检查：确保计算结果有限
            guard calculatedMax.isFinite, calculatedMin.isFinite else {
                #if DEBUG
                print("⚠️ [StickerScene] calculateScrollBounds 跳过，计算值无效：max=\(calculatedMax), min=\(calculatedMin)")
                #endif
                minScrollOffsetX = 0
                maxScrollOffsetX = 0
                canAutoScroll = false
                return
            }

            maxScrollOffsetX = calculatedMax
            minScrollOffsetX = calculatedMin
        }
    }

    /// 统一管理所有贴纸的 X 位置
    /// X = baseX + scrollOffsetX
    private func repositionAllStickers() {
        for (index, node) in stickerNodes.enumerated() {
            guard index < baseXPositions.count else { continue }
            // 如果这个贴纸正在被拖拽，不要改它的位置
            if node === draggingNode { continue }
            node.position.x = baseXPositions[index] + scrollOffsetX
        }
    }

    // MARK: - 尺寸变化

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)

        // ✅ 保护：新尺寸必须有效
        guard size.width > 0, size.height > 0 else {
            #if DEBUG
            print("⚠️ [StickerScene] didChangeSize 跳过，新 size 无效：\(size)")
            #endif
            return
        }

        // 尺寸变化时重新计算边界
        if oldSize != size && !stickerNodes.isEmpty {
            #if DEBUG
            print("✅ [StickerScene] didChangeSize: \(oldSize) → \(size)")
            #endif
            calculateScrollBounds()
        }
    }

    // MARK: - 更新循环

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)

        // 处理惯性滚动（无论是否启用自动轮播都需要处理）
        if isDecelerating {
            updateDeceleration()
            return  // 惯性滚动期间不执行自动轮播
        }

        // 如果禁用自动轮播，直接返回（节省性能）
        guard enableAutoScroll else { return }

        // 用户正在交互或正在回弹时不执行自动轮播
        guard canAutoScroll, !isUserInteracting, !isBouncingBack else { return }

        // 从运动管理器获取重力
        let gravityX = motionManager?.gravityX ?? 0

        // 根据重力方向调整轮播方向和速度
        let direction: CGFloat = gravityX >= 0 ? -1 : 1
        let magnitude = min(max(abs(gravityX), 0.1), 0.8)
        let delta = kAutoScrollSpeed * magnitude * direction * (1.0 / 60.0)

        // 移动所有贴纸（自动轮播不允许超出边界）
        moveAllStickersForAutoScroll(by: delta)

        // 应用倾斜效果
        applyTiltEffect(gravityX: gravityX)
    }

    /// 处理惯性减速滚动
    private func updateDeceleration() {
        // 如果已经超出边界，触发回弹
        if scrollOffsetX > maxScrollOffsetX || scrollOffsetX < minScrollOffsetX {
            startBounceBack()
            return
        }

        // 应用减速
        scrollVelocity *= kDecelerationRate

        // 计算本帧移动距离（速度是点/秒，需要转换为点/帧）
        let delta = scrollVelocity / 60.0
        let newOffsetX = scrollOffsetX + delta

        // 如果移动后会超出边界，允许超出一点然后回弹
        if newOffsetX > maxScrollOffsetX {
            // 超出右边界，应用橡皮筋阻力
            let overscroll = newOffsetX - maxScrollOffsetX
            let resistedDelta = delta - overscroll * (1 - kRubberBandResistance)
            scrollOffsetX += resistedDelta
            repositionAllStickers()
            // 快速减速
            scrollVelocity *= 0.5
        } else if newOffsetX < minScrollOffsetX {
            // 超出左边界，应用橡皮筋阻力
            let overscroll = minScrollOffsetX - newOffsetX
            let resistedDelta = delta + overscroll * (1 - kRubberBandResistance)
            scrollOffsetX += resistedDelta
            repositionAllStickers()
            // 快速减速
            scrollVelocity *= 0.5
        } else {
            // 正常移动
            scrollOffsetX += delta
            repositionAllStickers()
        }

        // 如果速度过小，检查是否需要回弹
        if abs(scrollVelocity) < kMinVelocityThreshold {
            if scrollOffsetX > maxScrollOffsetX || scrollOffsetX < minScrollOffsetX {
                startBounceBack()
            } else {
                stopDeceleration()
            }
        }
    }

    /// 开始橡皮筋回弹动画
    private func startBounceBack() {
        isDecelerating = false
        isBouncingBack = true
        scrollVelocity = 0

        let targetOffsetX: CGFloat
        if scrollOffsetX > maxScrollOffsetX {
            targetOffsetX = maxScrollOffsetX
        } else if scrollOffsetX < minScrollOffsetX {
            targetOffsetX = minScrollOffsetX
        } else {
            isBouncingBack = false
            stopDeceleration()
            return
        }

        let startOffsetX = scrollOffsetX

        // 使用 SKAction 动画 scrollOffsetX
        let bounceAction = SKAction.customAction(withDuration: kRubberBandBounceDuration) { [weak self] _, elapsedTime in
            guard let self = self else { return }
            let progress = elapsedTime / CGFloat(kRubberBandBounceDuration)
            // easeOut 曲线
            let easedProgress = 1 - pow(1 - progress, 3)
            self.scrollOffsetX = startOffsetX + (targetOffsetX - startOffsetX) * easedProgress
            self.repositionAllStickers()
        }

        // 在场景上运行动画（不是在节点上）
        run(bounceAction) { [weak self] in
            self?.scrollOffsetX = targetOffsetX
            self?.repositionAllStickers()
            self?.isBouncingBack = false
            self?.isUserInteracting = false
            self?.pauseIfIdle()
        }
    }

    /// 停止惯性滚动，恢复自动轮播
    private func stopDeceleration() {
        isDecelerating = false
        scrollVelocity = 0

        // 延迟恢复自动轮播
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isUserInteracting = false
            // 如果禁用自动轮播且处于空闲状态，暂停场景
            self?.pauseIfIdle()
        }
    }

    /// 如果场景处于空闲状态且不需要自动轮播，暂停场景以节省性能
    private func pauseIfIdle() {
        // 只有在禁用自动轮播时才考虑暂停
        guard !enableAutoScroll else { return }
        // 确保没有用户交互、没有惯性滚动、没有回弹动画
        guard !isUserInteracting, !isDecelerating, !isBouncingBack else { return }
        // 确保没有正在拖拽的贴纸
        guard draggingNode == nil else { return }
        // 确保没有正在回弹的贴纸
        guard returningNode == nil else { return }
        // 确保没有任何贴纸正在执行动画
        let anyNodeHasActions = stickerNodes.contains { $0.hasActions() }
        guard !anyNodeHasActions else { return }

        isPaused = true
    }

    /// 移动所有贴纸（用于自动轮播，有边界限制）
    private func moveAllStickersForAutoScroll(by delta: CGFloat) {
        let newOffsetX = scrollOffsetX + delta

        // 边界检查（自动轮播不允许超出边界）
        if delta > 0 && newOffsetX > maxScrollOffsetX {
            return
        }
        if delta < 0 && newOffsetX < minScrollOffsetX {
            return
        }

        scrollOffsetX = newOffsetX
        repositionAllStickers()
    }

    /// 移动所有贴纸（用于手动滑动，带橡皮筋效果）
    private func moveAllStickers(by delta: CGFloat) {
        var actualDelta = delta

        // 橡皮筋效果：超出边界时增加阻力
        if scrollOffsetX > maxScrollOffsetX {
            // 已超出右边界
            if delta > 0 {
                // 继续向右拉，增加阻力
                actualDelta = delta * kRubberBandResistance
            }
            // 向左拉正常响应
        } else if scrollOffsetX < minScrollOffsetX {
            // 已超出左边界
            if delta < 0 {
                // 继续向左拉，增加阻力
                actualDelta = delta * kRubberBandResistance
            }
            // 向右拉正常响应
        } else {
            // 在边界内，检查是否会超出
            let newOffsetX = scrollOffsetX + delta
            if newOffsetX > maxScrollOffsetX {
                // 将要超出右边界，部分应用阻力
                let normalPart = maxScrollOffsetX - scrollOffsetX
                let overPart = delta - normalPart
                actualDelta = normalPart + overPart * kRubberBandResistance
            } else if newOffsetX < minScrollOffsetX {
                // 将要超出左边界，部分应用阻力
                let normalPart = minScrollOffsetX - scrollOffsetX
                let overPart = delta - normalPart
                actualDelta = normalPart + overPart * kRubberBandResistance
            }
        }

        scrollOffsetX += actualDelta
        repositionAllStickers()
    }

    /// 应用倾斜效果
    private func applyTiltEffect(gravityX: CGFloat) {
        let maxTilt: CGFloat = 0.12  // 最大倾斜角度（弧度）
        let targetRotation = gravityX * maxTilt

        for node in stickerNodes where node != draggingNode {
            // 平滑过渡到目标角度
            let currentRotation = node.zRotation
            let newRotation = currentRotation + (targetRotation - currentRotation) * 0.08
            node.zRotation = newRotation
        }
    }

    // MARK: - 触摸处理

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // 恢复场景运行（如果之前暂停了）
        if isPaused {
            isPaused = false
        }

        // 停止任何正在进行的惯性滚动
        isDecelerating = false
        scrollVelocity = 0
        velocitySamples.removeAll()

        // 如果队列正在橡皮筋回弹，停止回弹动画
        if isBouncingBack {
            isBouncingBack = false
            removeAllActions()  // 停止场景上的回弹动画
        }

        // 停止所有贴纸的动画，并强制归位
        for node in stickerNodes {
            node.removeAllActions()
            // 重置 Y 到队列位置
            node.position.y = queueY
            // 重置缩放和层级
            node.setScale(1.0)
            node.zPosition = 1
        }

        // 重置 X 位置到正确的 slot
        repositionAllStickers()

        // 清除回弹状态
        returningNode = nil

        isUserInteracting = true
        touchStartLocation = location
        interactionModeDecided = false
        pendingStickerNode = nil
        lastPanLocation = location
        lastTouchTime = touch.timestamp

        // 检查是否点中贴纸（从上层开始检查）
        let sortedNodes = stickerNodes.sorted { $0.zPosition > $1.zPosition }
        if let node = sortedNodes.first(where: { $0.contains(location) }) {
            // 记录命中的贴纸，但先不开始拖拽，等待方向判断
            pendingStickerNode = node
        }
        // 无论是否点中贴纸，都先以滚动模式待命
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // 如果交互模式尚未确定，根据移动方向判断
        if !interactionModeDecided, let startLocation = touchStartLocation {
            let deltaX = location.x - startLocation.x
            let deltaY = location.y - startLocation.y
            let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

            // 移动超过一定距离后才判断方向（避免抖动误判）
            let decisionThreshold: CGFloat = 10
            if distance > decisionThreshold {
                interactionModeDecided = true

                // 计算角度：atan2 返回弧度，转为度数
                // SpriteKit Y轴向上，所以 deltaY > 0 表示向上
                let angleRadians = atan2(deltaY, abs(deltaX))
                let angleDegrees = angleRadians * 180 / .pi

                // 如果点中了贴纸，且向上角度超过阈值，则拖拽贴纸
                if let node = pendingStickerNode,
                   angleDegrees > upwardAngleThreshold,
                   let index = stickerNodes.firstIndex(of: node) {
                    // 开始拖拽贴纸（touchesBegan 已经清理过所有动画和状态）
                    draggingNode = node
                    draggingOriginalPosition = node.position
                    draggingOriginalIndex = index
                    node.zPosition = 100  // 置顶
                    node.zRotation = 0    // 重置旋转

                    // 放大动画
                    let scaleUp = SKAction.scale(to: 1.15, duration: 0.12)
                    scaleUp.timingMode = .easeOut
                    node.run(scaleUp, withKey: "scale")

                    // 显示使用区域圆环提示粒子
                    showUseZoneHint()

                    isPanningQueue = false
                } else {
                    // 横向滑动或未点中贴纸 -> 滚动队列
                    isPanningQueue = true
                    draggingNode = nil
                }
                pendingStickerNode = nil
            }
        }

        // 执行已确定的交互模式
        if let node = draggingNode {
            // 拖拽贴纸
            node.position = location

            // 进入使用区域的视觉反馈
            if useZoneFrameInScene.contains(location) {
                node.alpha = 0.75
                if node.action(forKey: "scaleHover") == nil {
                    let scaleHover = SKAction.scale(to: 1.25, duration: 0.1)
                    node.run(scaleHover, withKey: "scaleHover")
                }
            } else {
                node.alpha = 1.0
                if node.action(forKey: "scaleNormal") == nil {
                    node.removeAction(forKey: "scaleHover")
                    let scaleNormal = SKAction.scale(to: 1.15, duration: 0.1)
                    node.run(scaleNormal, withKey: "scaleNormal")
                }
            }
        } else if isPanningQueue || !interactionModeDecided, let last = lastPanLocation {
            // 滚动队列（包括未确定模式时的滚动）
            let deltaX = location.x - last.x
            moveAllStickers(by: deltaX)

            // 计算速度（用于惯性滚动）
            let currentTime = touch.timestamp
            let timeDelta = currentTime - lastTouchTime
            if timeDelta > 0 {
                let instantVelocity = deltaX / CGFloat(timeDelta)
                velocitySamples.append(instantVelocity)
                // 保持采样数量在限制内
                if velocitySamples.count > maxVelocitySamples {
                    velocitySamples.removeFirst()
                }
            }

            lastPanLocation = location
            lastTouchTime = currentTime
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endInteraction()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endInteraction()
    }

    // MARK: - 结束交互

    private func endInteraction() {
        // 记录是否是贴纸拖拽模式
        let wasDraggingSticker = draggingNode != nil

        // 处理贴纸拖拽结束
        if let node = draggingNode {
            // 隐藏使用区域圆环提示粒子
            hideUseZoneHint()

            let inZone = useZoneFrameInScene.contains(node.position)

            if inZone,
               let stickerIDRaw = node.name,
               let definition = definition(forRawValue: stickerIDRaw) {
                // 成功使用贴纸
                useStickerSuccessfully(node: node, definition: definition)
            } else {
                // 未进入使用区域，回到原位
                returnStickerToOriginalPosition(node: node)
            }

            draggingNode = nil
            draggingOriginalPosition = nil
            draggingOriginalIndex = nil
        }

        // 如果是贴纸拖拽模式，不触发队列的惯性滚动或回弹
        // 直接清理状态并返回（队列保持锁定直到贴纸回弹完成）
        if wasDraggingSticker {
            isPanningQueue = false
            lastPanLocation = nil
            velocitySamples.removeAll()
            touchStartLocation = nil
            pendingStickerNode = nil
            interactionModeDecided = false
            // 注意：不设置 isUserInteracting = false
            // 由贴纸回弹动画完成后或使用成功后来恢复
            return
        }

        // 处理队列滚动结束 - 触发惯性滚动或橡皮筋回弹
        let wasPanning = isPanningQueue || !interactionModeDecided
        if wasPanning {
            // 检查是否超出边界，需要回弹
            if scrollOffsetX > maxScrollOffsetX || scrollOffsetX < minScrollOffsetX {
                // 超出边界，触发回弹（忽略速度）
                startBounceBack()
                isPanningQueue = false
                lastPanLocation = nil
                velocitySamples.removeAll()
                touchStartLocation = nil
                pendingStickerNode = nil
                interactionModeDecided = false
                return
            }

            // 没有超出边界，检查是否需要惯性滚动
            if !velocitySamples.isEmpty {
                // 计算平均速度
                let averageVelocity = velocitySamples.reduce(0, +) / CGFloat(velocitySamples.count)

                // 如果速度足够大，启动惯性滚动
                if abs(averageVelocity) > kMinVelocityThreshold {
                    scrollVelocity = averageVelocity
                    isDecelerating = true
                    // 惯性滚动期间保持 isUserInteracting = true，由 stopDeceleration 来恢复
                } else {
                    // 速度太小，直接恢复自动轮播
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.isUserInteracting = false
                        self?.pauseIfIdle()
                    }
                }
            } else {
                // 没有速度采样，直接恢复
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.isUserInteracting = false
                    self?.pauseIfIdle()
                }
            }
        } else {
            // 没有滑动，直接恢复
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.isUserInteracting = false
                self?.pauseIfIdle()
            }
        }

        isPanningQueue = false
        lastPanLocation = nil
        velocitySamples.removeAll()

        // 清理方向判断状态
        touchStartLocation = nil
        pendingStickerNode = nil
        interactionModeDecided = false
    }

    /// 成功使用贴纸
    private func useStickerSuccessfully(node: SKSpriteNode, definition: StickerDefinition) {
        // 回调代理
        stickerDelegate?.stickerScene(self, didUse: definition)

        // 播放绽放粒子效果
        playUseZoneBurst(at: node.position)

        // 获取被移除贴纸的索引
        let removedIndex = stickerNodes.firstIndex(of: node)

        // 从数组中移除（同时移除对应的 baseX）
        if let index = removedIndex {
            stickerNodes.remove(at: index)
            if index < baseXPositions.count {
                baseXPositions.remove(at: index)
            }
        }

        // 消失动画
        let fadeOut = SKAction.fadeOut(withDuration: 0.25)
        let scaleUp = SKAction.scale(to: 1.6, duration: 0.25)
        let group = SKAction.group([fadeOut, scaleUp])
        group.timingMode = .easeOut

        node.run(group) { [weak self] in
            node.removeFromParent()
            // 动画完成后恢复交互状态
            self?.isUserInteracting = false
            self?.pauseIfIdle()
        }

        // 让后面的贴纸补位
        rearrangeStickers(fromIndex: removedIndex ?? 0)

        // 重新计算边界
        calculateScrollBounds()
    }

    /// 重新排列贴纸队列（贴纸被移除后重建 baseXPositions）
    private func rearrangeStickers(fromIndex: Int) {
        guard !stickerNodes.isEmpty else {
            baseXPositions.removeAll()
            return
        }

        // 重建 baseXPositions（因为有贴纸被移除了）
        baseXPositions.removeAll()
        var baseX: CGFloat = edgePadding + stickerSize.width / 2
        for _ in stickerNodes {
            baseXPositions.append(baseX)
            baseX += stickerSize.width + spacing
        }

        // 动画时长
        let animationDuration: TimeInterval = 0.25

        // 使用动画将所有贴纸移动到新的位置
        for (index, node) in stickerNodes.enumerated() {
            guard index < baseXPositions.count else { continue }
            let targetX = baseXPositions[index] + scrollOffsetX

            if node.position.x != targetX {
                let moveAction = SKAction.moveTo(x: targetX, duration: animationDuration)
                moveAction.timingMode = .easeOut
                node.run(moveAction)
            }
        }
    }

    /// 贴纸回到原位（带弹性效果）
    /// X 和 Y 同时动画回去，动画期间队列锁定
    private func returnStickerToOriginalPosition(node: SKSpriteNode) {
        node.removeAllActions()
        node.alpha = 1.0
        node.zPosition = 1

        // 确保场景没有被暂停，否则动画不会执行
        if isPaused {
            isPaused = false
        }

        // 记录正在回弹的贴纸（锁定队列）
        returningNode = node

        // 计算目标位置
        let startX = node.position.x
        let startY = node.position.y
        let targetY = queueY

        // 计算目标 X（slot 位置）
        var targetX = startX  // 默认保持当前位置
        if let index = stickerNodes.firstIndex(of: node), index < baseXPositions.count {
            targetX = baseXPositions[index] + scrollOffsetX
        }

        let startScale = node.xScale
        let targetScale: CGFloat = 1.0
        let duration: TimeInterval = 0.4

        // 使用 customAction 实现弹性动画（X 和 Y 同时动画）
        let springAction = SKAction.customAction(withDuration: duration) { [weak node, targetX, targetY] _, elapsedTime in
            guard let node = node else { return }

            let progress = elapsedTime / CGFloat(duration)

            // Spring 公式：damped oscillation
            let damping: CGFloat = 6.0
            let frequency: CGFloat = 12.0
            let springProgress = 1 - exp(-damping * progress) * cos(frequency * progress)

            // 同时插值 X 和 Y
            let newX = startX + (targetX - startX) * springProgress
            let newY = startY + (targetY - startY) * springProgress
            node.position = CGPoint(x: newX, y: newY)

            // 插值缩放
            let newScale = startScale + (targetScale - startScale) * springProgress
            node.setScale(newScale)
        }

        node.run(springAction) { [weak self, weak node, targetX, targetY] in
            // 确保最终位置和缩放精确
            node?.position = CGPoint(x: targetX, y: targetY)
            node?.setScale(targetScale)
            // 清除回弹状态，解锁队列
            self?.returningNode = nil
            // 恢复交互状态
            self?.isUserInteracting = false
            // 动画完成后，延迟尝试暂停场景
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.pauseIfIdle()
            }
        }
    }

    // MARK: - 粒子效果

    /// 显示使用区域圆环提示粒子
    private func showUseZoneHint() {
        // 如果已经在显示，直接返回
        guard useZoneHintEmitter == nil else { return }

        #if DEBUG
        print("🔥 [StickerScene] showUseZoneHint - useZoneCenter: \(useZoneCenter), useZoneFrame: \(useZoneFrameInScene)")
        #endif

        // 创建圆环粒子发射器
        let emitter = UseZoneParticleFactory.makeSimpleRingEmitter()
        emitter.position = useZoneCenter
        emitter.zPosition = 50  // 在贴纸下方，但在背景上方

        // 初始透明，渐入显示
        emitter.alpha = 0
        addChild(emitter)
        useZoneHintEmitter = emitter

        // 渐入动画
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.2)
        fadeIn.timingMode = .easeOut
        emitter.run(fadeIn)
    }

    /// 隐藏使用区域圆环提示粒子
    private func hideUseZoneHint() {
        guard let emitter = useZoneHintEmitter else { return }

        // 渐出动画后移除
        let fadeOut = SKAction.fadeOut(withDuration: 0.15)
        fadeOut.timingMode = .easeIn

        emitter.run(fadeOut) { [weak emitter] in
            emitter?.removeFromParent()
        }
        useZoneHintEmitter = nil
    }

    /// 播放使用成功的绽放粒子效果
    private func playUseZoneBurst(at position: CGPoint) {
        #if DEBUG
        print("🎆 [StickerScene] playUseZoneBurst at \(position)")
        #endif

        // 创建绽放粒子发射器
        let emitter = UseZoneParticleFactory.makeSimpleBurstEmitter()
        emitter.position = position
        emitter.zPosition = 150  // 在最上层

        addChild(emitter)

        // 粒子发射完毕后自动移除（numParticlesToEmit = 50，birthRate = 400）
        // 发射时间约 50/400 = 0.125 秒，加上粒子生命周期 0.6 秒，共约 0.8 秒
        let waitDuration = 1.0  // 稍微多等一会儿确保所有粒子消失
        let wait = SKAction.wait(forDuration: waitDuration)
        let remove = SKAction.removeFromParent()
        emitter.run(SKAction.sequence([wait, remove]))
    }
}
