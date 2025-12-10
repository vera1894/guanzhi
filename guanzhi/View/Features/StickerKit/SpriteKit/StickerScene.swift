//
//  StickerScene.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/10.
//
//  贴纸交互场景 - SpriteKit 实现
//

import SpriteKit

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
    private let queueY: CGFloat = 100  // 贴纸队列距底部高度

    // MARK: - 滚动状态

    private var contentWidth: CGFloat = 0
    private var canAutoScroll = false
    private var isUserInteracting = false
    private let baseScrollSpeed: CGFloat = 25

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

    // MARK: - 使用区域（由 SwiftUI 层传入）

    var useZoneFrameInScene: CGRect = .zero

    // MARK: - 运动管理器（外部注入）

    weak var motionManager: StickerMotionManager?

    // MARK: - 初始化

    init(size: CGSize, stickers: [StickerDefinition]) {
        self.stickerDefinitions = stickers
        super.init(size: size)
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

        var x: CGFloat = stickerSize.width / 2 + spacing
        let y: CGFloat = queueY

        for def in stickerDefinitions {
            let node = StickerSpriteFactory.makeNode(for: def, size: stickerSize)
            node.position = CGPoint(x: x, y: y)
            node.zPosition = 1
            addChild(node)
            stickerNodes.append(node)

            x += stickerSize.width + spacing
        }

        contentWidth = x
        canAutoScroll = contentWidth > size.width
    }

    private func setupPhysicsWorld() {
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
    }

    /// 计算滚动边界
    private func calculateScrollBounds() {
        let padding: CGFloat = spacing

        // 最右位置：第一个贴纸的 x 不超过左边界
        maxScrollX = stickerSize.width / 2 + padding

        // 最左位置：最后一个贴纸的 x 不低于右边界
        minScrollX = size.width - contentWidth + stickerSize.width / 2 + padding

        // 如果内容不足屏幕宽度，不需要滚动
        if contentWidth <= size.width {
            minScrollX = maxScrollX
            canAutoScroll = false
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

        guard canAutoScroll, !isUserInteracting else { return }

        // 从运动管理器获取重力
        let gravityX = motionManager?.gravityX ?? 0

        // 根据重力方向调整轮播方向和速度
        let direction: CGFloat = gravityX >= 0 ? -1 : 1
        let magnitude = min(max(abs(gravityX), 0.1), 0.8)
        let delta = baseScrollSpeed * magnitude * direction * (1.0 / 60.0)

        // 移动所有贴纸
        moveAllStickers(by: delta)

        // 应用倾斜效果
        applyTiltEffect(gravityX: gravityX)
    }

    /// 移动所有贴纸（带边界检查）
    private func moveAllStickers(by delta: CGFloat) {
        guard let firstNode = stickerNodes.first else { return }

        let newFirstX = firstNode.position.x + delta

        // 边界检查
        if delta > 0 && newFirstX > maxScrollX {
            return  // 已到右边界
        }
        if delta < 0 && newFirstX < minScrollX {
            return  // 已到左边界
        }

        for node in stickerNodes {
            node.position.x += delta
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

        isUserInteracting = true

        // 检查是否点中贴纸（从上层开始检查）
        let sortedNodes = stickerNodes.sorted { $0.zPosition > $1.zPosition }
        if let node = sortedNodes.first(where: { $0.contains(location) }),
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
        } else {
            // 点中空白区域 -> 开始滚动队列
            isPanningQueue = true
            lastPanLocation = location
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

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
        } else if isPanningQueue, let last = lastPanLocation {
            // 滚动队列
            let deltaX = location.x - last.x
            moveAllStickers(by: deltaX)
            lastPanLocation = location
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
        }

        isPanningQueue = false
        lastPanLocation = nil

        // 延迟恢复自动轮播
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.isUserInteracting = false
        }
    }

    /// 成功使用贴纸
    private func useStickerSuccessfully(node: SKSpriteNode, definition: StickerDefinition) {
        // 回调代理
        stickerDelegate?.stickerScene(self, didUse: definition)

        // 从数组中移除
        if let index = stickerNodes.firstIndex(of: node) {
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

        // 重新计算边界
        calculateScrollBounds()
    }

    /// 贴纸回到原位
    private func returnStickerToOriginalPosition(node: SKSpriteNode) {
        node.removeAllActions()
        node.alpha = 1.0

        guard let originalPos = draggingOriginalPosition else {
            node.zPosition = 1
            return
        }

        // 回到原位动画
        let moveBack = SKAction.move(to: originalPos, duration: 0.3)
        moveBack.timingMode = .easeOut

        let scaleBack = SKAction.scale(to: 1.0, duration: 0.2)
        scaleBack.timingMode = .easeOut

        let group = SKAction.group([moveBack, scaleBack])

        node.run(group) { [weak node] in
            node?.zPosition = 1
        }
    }
}
