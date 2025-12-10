//
//  StickerSpriteFactory.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/10.
//
//  贴纸精灵工厂 - 将 StickerDefinition 转换为 SpriteKit 节点
//

import SpriteKit

// MARK: - StickerSpriteFactory

/// 贴纸精灵工厂
/// 负责将 StickerDefinition 转换为可在 SpriteKit 中使用的 SKSpriteNode
enum StickerSpriteFactory {

    // MARK: - 公开方法

    /// 创建贴纸节点
    /// - Parameters:
    ///   - definition: 贴纸定义
    ///   - size: 节点尺寸
    /// - Returns: 配置好的 SKSpriteNode
    static func makeNode(for definition: StickerDefinition, size: CGSize) -> SKSpriteNode {
        // 从缓存获取纹理
        let texture = StickerTextureCache.shared.texture(for: definition, size: size)

        let node = SKSpriteNode(texture: texture)
        node.size = size
        node.name = definition.stickerID.rawValue

        // 配置圆形物理体
        configurePhysicsBody(for: node, size: size)

        return node
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
