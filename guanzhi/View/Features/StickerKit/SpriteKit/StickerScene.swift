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
private let kAutoScrollSpeed: CGFloat = 25

/// 橡皮筋阻力系数（0-1），值越小拉动越费力
private let kRubberBandResistance: CGFloat = 0.4

/// 橡皮筋回弹动画时长（秒）
private let kRubberBandBounceDuration: TimeInterval = 0.35

/// 惯性滚动减速系数（0-1），值越大滑得越远
private let kDecelerationRate: CGFloat = 0.92

/// 惯性滚动最小速度阈值（点/秒），低于此值停止滚动
private let kMinVelocityThreshold: CGFloat = 5

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

    private let stickerDefinitions: [StickerDefinition]
    private var stickerNodes: [SKSpriteNode] = []

    // MARK: - 配置

    private let stickerSize = CGSize(width: 72, height: 72)
    private let spacing: CGFloat = 16
    private let edgePadding: CGFloat = 24  // 屏幕边缘留白（确保贴纸完全显示）
    private let queueY: CGFloat = 100  // 贴纸队列距底部高度

    // MARK: - 滚动状态

    private var contentWidth: CGFloat = 0
    private var canAutoScroll = false
    private var isUserInteracting = false

    // MARK: - 边界限制

    private var minScrollX: CGFloat = 0
    private var maxScrollX: CGFloat = 0

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

    // MARK: - 使用区域（由 SwiftUI 层传入）

    var useZoneFrameInScene: CGRect = .zero

    // MARK: - 运动管理器（外部注入）

    weak var motionManager: StickerMotionManager?

    // MARK: - 初始化

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
        backgroundColor = .clear
        setupPhysicsWorld()
        layoutStickers()
        calculateScrollBounds()
    }

    override func willMove(from view: SKView) {
        // 清理工作（如果需要）
    }

    // MARK: - 布局

    private func layoutStickers() {
        // 清理现有节点
        stickerNodes.forEach { $0.removeFromParent() }
        stickerNodes.removeAll()

        // 第一个贴纸的中心 x = 边缘留白 + 贴纸半宽
        var x: CGFloat = edgePadding + stickerSize.width / 2
        let y: CGFloat = queueY

        for def in stickerDefinitions {
            let node = StickerSpriteFactory.makeNode(for: def, size: stickerSize)
            node.position = CGPoint(x: x, y: y)
            node.zPosition = 1
            addChild(node)
            stickerNodes.append(node)

            x += stickerSize.width + spacing
        }

        // 内容总宽度 = 最后一个贴纸右边缘 + 边缘留白
        contentWidth = x - spacing + edgePadding
        canAutoScroll = contentWidth > size.width
    }

    private func setupPhysicsWorld() {
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
    }

    /// 计算滚动边界
    private func calculateScrollBounds() {
        // 重新计算当前内容宽度（基于实际贴纸数量）
        // 内容宽度 = 边缘留白 + n个贴纸 + (n-1)个间距 + 边缘留白
        let stickerCount = CGFloat(stickerNodes.count)
        let actualContentWidth = edgePadding * 2 + stickerCount * stickerSize.width + max(0, stickerCount - 1) * spacing

        // 如果内容不足屏幕宽度，居中显示，不允许滚动
        if actualContentWidth <= size.width {
            canAutoScroll = false
            // 居中位置：第一个贴纸的中心 x
            let totalStickerWidth = stickerCount * stickerSize.width + max(0, stickerCount - 1) * spacing
            let centeredFirstX = (size.width - totalStickerWidth) / 2 + stickerSize.width / 2
            minScrollX = centeredFirstX
            maxScrollX = centeredFirstX
            // 将贴纸移到居中位置
            centerStickers()
        } else {
            canAutoScroll = true
            // 最右位置：第一个贴纸完全显示在屏幕左侧
            // 第一个贴纸左边缘 = edgePadding，所以中心 x = edgePadding + stickerSize/2
            maxScrollX = edgePadding + stickerSize.width / 2

            // 最左位置：最后一个贴纸完全显示在屏幕右侧
            // 最后一个贴纸右边缘 = size.width - edgePadding
            // 最后一个贴纸中心 x = size.width - edgePadding - stickerSize/2
            let step = stickerSize.width + spacing
            let lastStickerCenterX = size.width - edgePadding - stickerSize.width / 2
            minScrollX = lastStickerCenterX - CGFloat(stickerNodes.count - 1) * step
        }
    }

    /// 将贴纸队列居中显示
    private func centerStickers() {
        guard !stickerNodes.isEmpty else { return }

        let stickerCount = CGFloat(stickerNodes.count)
        // 所有贴纸占用的总宽度（不含边缘留白）
        let totalStickerWidth = stickerCount * stickerSize.width + max(0, stickerCount - 1) * spacing
        // 第一个贴纸的中心 x（居中）
        let startX = (size.width - totalStickerWidth) / 2 + stickerSize.width / 2

        let animationDuration: TimeInterval = 0.3

        for (index, node) in stickerNodes.enumerated() {
            let targetX = startX + CGFloat(index) * (stickerSize.width + spacing)
            if node.position.x != targetX {
                let moveAction = SKAction.moveTo(x: targetX, duration: animationDuration)
                moveAction.timingMode = .easeOut
                node.run(moveAction)
            }
        }
    }

    // MARK: - 尺寸变化

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if oldSize != size && !stickerNodes.isEmpty {
            calculateScrollBounds()
        }
    }

    // MARK: - 更新循环

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)

        // 处理惯性滚动
        if isDecelerating {
            updateDeceleration()
            return  // 惯性滚动期间不执行自动轮播
        }

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
        // 检查是否超出边界
        guard let firstNode = stickerNodes.first else {
            stopDeceleration()
            return
        }

        let currentFirstX = firstNode.position.x

        // 如果已经超出边界，触发回弹
        if currentFirstX > maxScrollX || currentFirstX < minScrollX {
            startBounceBack()
            return
        }

        // 应用减速
        scrollVelocity *= kDecelerationRate

        // 计算本帧移动距离（速度是点/秒，需要转换为点/帧）
        let delta = scrollVelocity / 60.0
        let newFirstX = currentFirstX + delta

        // 如果移动后会超出边界，允许超出一点然后回弹
        if newFirstX > maxScrollX {
            // 超出右边界，应用橡皮筋阻力
            let overscroll = newFirstX - maxScrollX
            let resistedDelta = delta - overscroll * (1 - kRubberBandResistance)
            moveAllStickersDirectly(by: resistedDelta)
            // 快速减速
            scrollVelocity *= 0.5
        } else if newFirstX < minScrollX {
            // 超出左边界，应用橡皮筋阻力
            let overscroll = minScrollX - newFirstX
            let resistedDelta = delta + overscroll * (1 - kRubberBandResistance)
            moveAllStickersDirectly(by: resistedDelta)
            // 快速减速
            scrollVelocity *= 0.5
        } else {
            // 正常移动
            moveAllStickersDirectly(by: delta)
        }

        // 如果速度过小，检查是否需要回弹
        if abs(scrollVelocity) < kMinVelocityThreshold {
            let finalFirstX = stickerNodes.first?.position.x ?? 0
            if finalFirstX > maxScrollX || finalFirstX < minScrollX {
                startBounceBack()
            } else {
                stopDeceleration()
            }
        }
    }

    /// 开始橡皮筋回弹动画
    private func startBounceBack() {
        guard let firstNode = stickerNodes.first else {
            stopDeceleration()
            return
        }

        isDecelerating = false
        isBouncingBack = true
        scrollVelocity = 0

        let currentFirstX = firstNode.position.x
        let targetFirstX: CGFloat

        if currentFirstX > maxScrollX {
            targetFirstX = maxScrollX
        } else if currentFirstX < minScrollX {
            targetFirstX = minScrollX
        } else {
            isBouncingBack = false
            stopDeceleration()
            return
        }

        let deltaX = targetFirstX - currentFirstX

        // 为所有贴纸添加回弹动画
        for node in stickerNodes {
            let targetX = node.position.x + deltaX
            let moveAction = SKAction.moveTo(x: targetX, duration: kRubberBandBounceDuration)
            moveAction.timingMode = .easeOut
            node.run(moveAction)
        }

        // 动画结束后恢复状态
        DispatchQueue.main.asyncAfter(deadline: .now() + kRubberBandBounceDuration) { [weak self] in
            self?.isBouncingBack = false
            self?.isUserInteracting = false
        }
    }

    /// 停止惯性滚动，恢复自动轮播
    private func stopDeceleration() {
        isDecelerating = false
        scrollVelocity = 0

        // 延迟恢复自动轮播
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isUserInteracting = false
        }
    }

    /// 直接移动所有贴纸（无边界限制，用于惯性滚动）
    private func moveAllStickersDirectly(by delta: CGFloat) {
        for node in stickerNodes {
            node.position.x += delta
        }
    }

    /// 移动所有贴纸（用于自动轮播，有边界限制）
    private func moveAllStickersForAutoScroll(by delta: CGFloat) {
        guard let firstNode = stickerNodes.first else { return }

        let newFirstX = firstNode.position.x + delta

        // 边界检查（自动轮播不允许超出边界）
        if delta > 0 && newFirstX > maxScrollX {
            return
        }
        if delta < 0 && newFirstX < minScrollX {
            return
        }

        for node in stickerNodes {
            node.position.x += delta
        }
    }

    /// 移动所有贴纸（用于手动滑动，带橡皮筋效果）
    private func moveAllStickers(by delta: CGFloat) {
        guard let firstNode = stickerNodes.first else { return }

        let currentFirstX = firstNode.position.x
        var actualDelta = delta

        // 橡皮筋效果：超出边界时增加阻力
        if currentFirstX > maxScrollX {
            // 已超出右边界
            if delta > 0 {
                // 继续向右拉，增加阻力
                actualDelta = delta * kRubberBandResistance
            }
            // 向左拉正常响应
        } else if currentFirstX < minScrollX {
            // 已超出左边界
            if delta < 0 {
                // 继续向左拉，增加阻力
                actualDelta = delta * kRubberBandResistance
            }
            // 向右拉正常响应
        } else {
            // 在边界内，检查是否会超出
            let newFirstX = currentFirstX + delta
            if newFirstX > maxScrollX {
                // 将要超出右边界，部分应用阻力
                let normalPart = maxScrollX - currentFirstX
                let overPart = delta - normalPart
                actualDelta = normalPart + overPart * kRubberBandResistance
            } else if newFirstX < minScrollX {
                // 将要超出左边界，部分应用阻力
                let normalPart = minScrollX - currentFirstX
                let overPart = delta - normalPart
                actualDelta = normalPart + overPart * kRubberBandResistance
            }
        }

        for node in stickerNodes {
            node.position.x += actualDelta
        }
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

        // 停止任何正在进行的惯性滚动或回弹动画
        isDecelerating = false
        scrollVelocity = 0
        velocitySamples.removeAll()

        // 如果正在回弹，停止回弹动画
        if isBouncingBack {
            isBouncingBack = false
            for node in stickerNodes {
                node.removeAllActions()
            }
        }

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
                    // 开始拖拽贴纸
                    draggingNode = node
                    draggingOriginalPosition = node.position
                    draggingOriginalIndex = index
                    node.zPosition = 100  // 置顶
                    node.zRotation = 0    // 重置旋转

                    // 放大动画
                    let scaleUp = SKAction.scale(to: 1.15, duration: 0.12)
                    scaleUp.timingMode = .easeOut
                    node.run(scaleUp, withKey: "scale")

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
        // 处理贴纸拖拽结束
        if let node = draggingNode {
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

            // 拖拽贴纸结束，不触发惯性滚动
            velocitySamples.removeAll()
        }

        // 处理队列滚动结束 - 触发惯性滚动或橡皮筋回弹
        let wasPanning = isPanningQueue || !interactionModeDecided
        if wasPanning {
            // 检查是否超出边界，需要回弹
            if let firstNode = stickerNodes.first {
                let currentFirstX = firstNode.position.x
                if currentFirstX > maxScrollX || currentFirstX < minScrollX {
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
                    }
                }
            } else {
                // 没有速度采样，直接恢复
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.isUserInteracting = false
                }
            }
        } else if draggingNode == nil {
            // 没有滑动也没有拖贴纸，直接恢复
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.isUserInteracting = false
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

        // 获取被移除贴纸的索引
        let removedIndex = stickerNodes.firstIndex(of: node)

        // 从数组中移除
        if let index = removedIndex {
            stickerNodes.remove(at: index)
        }

        // 消失动画
        let fadeOut = SKAction.fadeOut(withDuration: 0.25)
        let scaleUp = SKAction.scale(to: 1.6, duration: 0.25)
        let group = SKAction.group([fadeOut, scaleUp])
        group.timingMode = .easeOut

        node.run(group) {
            node.removeFromParent()
        }

        // 让后面的贴纸补位
        rearrangeStickers(fromIndex: removedIndex ?? 0)

        // 重新计算边界
        calculateScrollBounds()
    }

    /// 重新排列贴纸队列（从指定索引开始，让后面的贴纸补位）
    private func rearrangeStickers(fromIndex: Int) {
        guard !stickerNodes.isEmpty else { return }

        // 先重新计算边界（基于新的贴纸数量）
        let stickerCount = CGFloat(stickerNodes.count)
        let totalStickerWidth = stickerCount * stickerSize.width + max(0, stickerCount - 1) * spacing
        let actualContentWidth = edgePadding * 2 + totalStickerWidth

        // 计算第一个贴纸当前的 X 位置
        var targetFirstX = stickerNodes.first?.position.x ?? (edgePadding + stickerSize.width / 2)

        // 检查是否需要调整位置（队列可能超出新边界）
        if actualContentWidth <= size.width {
            // 内容不足屏幕宽度，需要居中
            targetFirstX = (size.width - totalStickerWidth) / 2 + stickerSize.width / 2
        } else {
            // 检查最后一个贴纸是否超出右边界
            let step = stickerSize.width + spacing
            let lastStickerTargetX = targetFirstX + CGFloat(stickerNodes.count - 1) * step
            let maxLastX = size.width - edgePadding - stickerSize.width / 2

            if lastStickerTargetX < maxLastX {
                // 最后一个贴纸超出了右边界（左移过多），需要向右修正
                let correction = maxLastX - lastStickerTargetX
                targetFirstX += correction
            }

            // 确保第一个贴纸不超出左边界
            let maxFirstX = edgePadding + stickerSize.width / 2
            if targetFirstX > maxFirstX {
                targetFirstX = maxFirstX
            }
        }

        // 动画时长
        let animationDuration: TimeInterval = 0.25

        // 更新所有贴纸的位置
        for (index, node) in stickerNodes.enumerated() {
            let targetX = targetFirstX + CGFloat(index) * (stickerSize.width + spacing)

            if node.position.x != targetX {
                let moveAction = SKAction.moveTo(x: targetX, duration: animationDuration)
                moveAction.timingMode = .easeOut
                node.run(moveAction)
            }
        }
    }

    /// 贴纸回到原位（带弹性效果）
    private func returnStickerToOriginalPosition(node: SKSpriteNode) {
        node.removeAllActions()
        node.alpha = 1.0

        guard let originalPos = draggingOriginalPosition else {
            node.zPosition = 1
            return
        }

        let startPos = node.position
        let startScale = node.xScale
        let targetScale: CGFloat = 1.0
        let duration: TimeInterval = 0.5

        // 使用 customAction 实现弹性动画
        let springAction = SKAction.customAction(withDuration: duration) { [weak node] _, elapsedTime in
            guard let node = node else { return }

            let progress = elapsedTime / CGFloat(duration)

            // Spring 公式：damped oscillation
            // f(t) = 1 - e^(-damping * t) * cos(frequency * t)
            let damping: CGFloat = 6.0
            let frequency: CGFloat = 12.0
            let springProgress = 1 - exp(-damping * progress) * cos(frequency * progress)

            // 插值位置
            let newX = startPos.x + (originalPos.x - startPos.x) * springProgress
            let newY = startPos.y + (originalPos.y - startPos.y) * springProgress
            node.position = CGPoint(x: newX, y: newY)

            // 插值缩放
            let newScale = startScale + (targetScale - startScale) * springProgress
            node.setScale(newScale)
        }

        node.run(springAction) { [weak node] in
            // 确保最终位置和缩放精确
            node?.position = originalPos
            node?.setScale(targetScale)
            node?.zPosition = 1
        }
    }
}
