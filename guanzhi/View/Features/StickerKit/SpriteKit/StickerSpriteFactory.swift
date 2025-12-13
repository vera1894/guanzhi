//
//  StickerSpriteFactory.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/10.
//
//  贴纸精灵工厂 - 将 StickerDefinition 转换为 SpriteKit 节点
//

import SpriteKit
import UIKit

// MARK: - StickerSpriteFactory

/// 贴纸精灵工厂
/// 负责将 StickerDefinition 转换为可在 SpriteKit 中使用的 SKSpriteNode
enum StickerSpriteFactory {

    // MARK: - 公开方法

    /// 创建贴纸节点（包含图标和文字标签）
    /// - Parameters:
    ///   - definition: 贴纸定义
    ///   - size: 节点尺寸
    /// - Returns: 配置好的 SKSpriteNode（带有文字标签子节点）
    ///
    /// ⚠️ 此方法必须在主线程调用（涉及纹理创建）
    static func makeNode(for definition: StickerDefinition, size: CGSize) -> SKSpriteNode {
        #if DEBUG
        assert(Thread.isMainThread, "⚠️ [StickerSpriteFactory] makeNode 必须在主线程调用！")
        #endif

        // 从缓存获取纹理
        let texture = StickerTextureCache.shared.texture(for: definition, size: size)

        let node = SKSpriteNode(texture: texture)
        node.size = size
        node.name = definition.stickerID.rawValue

        // 添加文字标签（作为子节点，随贴纸移动）
        let label = createLabel(for: definition, stickerSize: size)
        node.addChild(label)

        // 配置圆形物理体
        configurePhysicsBody(for: node, size: size)

        return node
    }

    /// 创建贴纸文字标签
    /// - Parameters:
    ///   - definition: 贴纸定义
    ///   - stickerSize: 贴纸尺寸
    /// - Returns: 配置好的 SKLabelNode
    private static func createLabel(for definition: StickerDefinition, stickerSize: CGSize) -> SKLabelNode {
        let label = SKLabelNode(text: definition.displayName)

        // 字体设置
        label.fontName = "PingFangSC-Medium"
        label.fontSize = 12
        label.fontColor = .white

        // 位置：贴纸下方居中（相对于贴纸中心）
        // 贴纸中心在 (0, 0)，标签在下方
        label.position = CGPoint(x: 0, y: -stickerSize.height / 2 - 10)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .top

        // 确保标签在贴纸上方渲染（zPosition 相对于父节点）
        label.zPosition = 1

        // 添加阴影效果增强可读性
        // 通过创建一个背景标签实现简单的阴影
        let shadowLabel = SKLabelNode(text: definition.displayName)
        shadowLabel.fontName = "PingFangSC-Medium"
        shadowLabel.fontSize = 12
        shadowLabel.fontColor = UIColor.black.withAlphaComponent(0.5)
        shadowLabel.position = CGPoint(x: 1, y: -1)  // 阴影偏移
        shadowLabel.horizontalAlignmentMode = .center
        shadowLabel.verticalAlignmentMode = .top
        shadowLabel.zPosition = -1  // 在主标签下方
        label.addChild(shadowLabel)

        // 给标签命名，方便后续查找
        label.name = "stickerLabel"

        return label
    }

    /// 批量创建贴纸节点
    /// - Parameters:
    ///   - definitions: 贴纸定义数组
    ///   - size: 节点尺寸
    /// - Returns: 节点数组（与定义数组顺序一致）
    static func makeNodes(for definitions: [StickerDefinition], size: CGSize) -> [SKSpriteNode] {
        definitions.map { makeNode(for: $0, size: size) }
    }

    // MARK: - 私有方法

    /// 配置物理体
    private static func configurePhysicsBody(for node: SKSpriteNode, size: CGSize) {
        let physicsBody = SKPhysicsBody(circleOfRadius: size.width / 2)

        // 物理属性
        physicsBody.isDynamic = false          // 初始静止，拖拽时切换
        physicsBody.allowsRotation = true
        physicsBody.friction = 0.3
        physicsBody.restitution = 0.2          // 弹性
        physicsBody.linearDamping = 3.0        // 线性阻尼
        physicsBody.angularDamping = 3.0       // 角阻尼

        // 碰撞配置
        physicsBody.categoryBitMask = 0x1
        physicsBody.collisionBitMask = 0x1
        physicsBody.contactTestBitMask = 0

        node.physicsBody = physicsBody
    }
}
