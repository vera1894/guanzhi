//
//  ConfettiParticleFactory.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/17.
//
//  彩屑粒子效果工厂 - 模拟 tsParticles 的 Confetti 效果
//  特点：多彩颜色、矩形纸屑、摆动飘落、旋转翻滚
//

import SpriteKit

/// 彩屑粒子效果工厂
/// 参考 tsParticles confetti 效果实现
enum ConfettiParticleFactory {

    // MARK: - 颜色配置

    /// 彩屑颜色调色板（多彩缤纷）
    private static let confettiColors: [UIColor] = [
        UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0),   // 金黄
        UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0),    // 珊瑚红
        UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0),    // 天蓝
        UIColor(red: 0.6, green: 1.0, blue: 0.6, alpha: 1.0),    // 薄荷绿
        UIColor(red: 1.0, green: 0.6, blue: 0.8, alpha: 1.0),    // 粉红
        UIColor(red: 0.8, green: 0.6, blue: 1.0, alpha: 1.0),    // 淡紫
        UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0),    // 橙黄
        UIColor(red: 0.5, green: 1.0, blue: 0.9, alpha: 1.0),    // 青绿
    ]

    // MARK: - 主要效果：彩屑爆发

    /// 创建彩屑爆发效果（使用成功时的主效果）
    /// - Parameters:
    ///   - particleCount: 粒子数量（默认 80）
    ///   - spread: 扩散角度范围（默认 360 度全向）
    /// - Returns: 配置好的 SKEmitterNode 数组（多个发射器模拟多彩效果）
    static func makeConfettiBurst(particleCount: Int = 80, spread: CGFloat = .pi * 2) -> [SKEmitterNode] {
        // 创建多个发射器，每个发射不同颜色的粒子
        // 这样可以实现真正的多彩效果（SKEmitterNode 单个只支持一种颜色序列）
        var emitters: [SKEmitterNode] = []

        // 每种颜色分配的粒子数
        let particlesPerColor = max(1, particleCount / confettiColors.count)

        for color in confettiColors {
            let emitter = makeSingleColorConfettiEmitter(
                color: color,
                particleCount: particlesPerColor,
                spread: spread
            )
            emitters.append(emitter)
        }

        return emitters
    }

    /// 创建单色彩屑发射器
    private static func makeSingleColorConfettiEmitter(
        color: UIColor,
        particleCount: Int,
        spread: CGFloat
    ) -> SKEmitterNode {
        let emitter = SKEmitterNode()

        // 使用矩形纹理（模拟纸屑）
        emitter.particleTexture = makeConfettiTexture()

        // MARK: 发射配置

        // 一次性爆发
        emitter.particleBirthRate = 1000  // 短时间大量发射
        emitter.numParticlesToEmit = particleCount

        // 发射角度：主要向上（模拟炮筒喷射）
        emitter.emissionAngle = .pi / 2  // 向上
        emitter.emissionAngleRange = spread * 0.6  // 扩散范围

        // MARK: 生命周期

        // 较长的生命周期，让彩屑飘落得更久
        emitter.particleLifetime = 2.5
        emitter.particleLifetimeRange = 1.0

        // MARK: 速度配置

        // 初始速度（向上喷射）
        emitter.particleSpeed = 280
        emitter.particleSpeedRange = 120

        // MARK: 尺寸配置

        // 彩屑大小变化
        emitter.particleScale = 0.8
        emitter.particleScaleRange = 0.4
        emitter.particleScaleSpeed = -0.1  // 缓慢缩小

        // MARK: 颜色配置

        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1.0
        emitter.particleColorBlendFactorRange = 0.15  // 轻微颜色变化

        // 颜色序列：保持颜色，只改变透明度
        let colorSequence = SKKeyframeSequence(keyframeValues: [
            color.withAlphaComponent(1.0),
            color.withAlphaComponent(0.9),
            color.withAlphaComponent(0.7),
            color.withAlphaComponent(0.0)
        ], times: [0, 0.3, 0.7, 1.0])
        emitter.particleColorSequence = colorSequence

        // MARK: 透明度

        emitter.particleAlpha = 1.0
        emitter.particleAlphaRange = 0.1
        emitter.particleAlphaSpeed = 0  // 由颜色序列控制

        // MARK: 旋转（模拟翻滚效果）

        emitter.particleRotation = 0
        emitter.particleRotationRange = .pi * 2  // 初始随机角度
        emitter.particleRotationSpeed = CGFloat.random(in: 2.0...8.0)  // 快速旋转

        // MARK: 物理效果

        // 重力：向下，但比真实重力弱（模拟空气阻力）
        emitter.yAcceleration = -180

        // 水平加速度：轻微随机漂移（模拟摆动）
        emitter.xAcceleration = CGFloat.random(in: -30...30)

        // MARK: 位置范围

        // 从中心点小范围扩散
        emitter.particlePositionRange = CGVector(dx: 15, dy: 15)

        // MARK: 混合模式

        // 使用 alpha 混合，让颜色更真实
        emitter.particleBlendMode = .alpha

        return emitter
    }

    // MARK: - 纹理生成

    /// 创建矩形彩屑纹理
    private static func makeConfettiTexture() -> SKTexture {
        let width: CGFloat = 12
        let height: CGFloat = 8

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: width, height: height)

            // 绘制带圆角的矩形
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 1.5)
            UIColor.white.setFill()
            path.fill()
        }

        return SKTexture(image: image)
    }

    /// 创建方形彩屑纹理（备选）
    private static func makeSquareConfettiTexture() -> SKTexture {
        let size: CGFloat = 10

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)

            // 绘制带圆角的方形
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 2)
            UIColor.white.setFill()
            path.fill()
        }

        return SKTexture(image: image)
    }

    /// 创建圆形彩屑纹理（备选）
    private static func makeCircleConfettiTexture() -> SKTexture {
        let size: CGFloat = 8

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: rect)
        }

        return SKTexture(image: image)
    }

    // MARK: - 便捷方法

    /// 在指定位置播放彩屑爆发效果
    /// - Parameters:
    ///   - scene: 目标场景
    ///   - position: 爆发位置
    ///   - particleCount: 粒子总数
    ///   - duration: 效果持续时间（粒子发射后多久移除发射器）
    ///   - completion: 完成回调
    static func playConfettiBurst(
        in scene: SKScene,
        at position: CGPoint,
        particleCount: Int = 80,
        duration: TimeInterval = 3.5,
        completion: (() -> Void)? = nil
    ) {
        let emitters = makeConfettiBurst(particleCount: particleCount)

        // 添加所有发射器到场景
        for emitter in emitters {
            emitter.position = position
            emitter.zPosition = 150  // 最上层
            scene.addChild(emitter)
        }

        // 延迟移除发射器
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            for emitter in emitters {
                emitter.removeFromParent()
            }
            completion?()
        }
    }

    // MARK: - 简化版本（单发射器，性能更好）

    /// 创建简化版彩屑爆发（单发射器，使用颜色序列模拟多彩）
    /// 性能更好，适合低端设备
    static func makeSimpleConfettiBurst() -> SKEmitterNode {
        let emitter = SKEmitterNode()

        // 矩形纹理
        emitter.particleTexture = makeConfettiTexture()

        // 发射配置
        emitter.particleBirthRate = 600
        emitter.numParticlesToEmit = 60
        emitter.emissionAngle = .pi / 2  // 向上
        emitter.emissionAngleRange = .pi * 1.2  // 较大扩散

        // 生命周期
        emitter.particleLifetime = 2.0
        emitter.particleLifetimeRange = 0.8

        // 速度
        emitter.particleSpeed = 250
        emitter.particleSpeedRange = 100

        // 尺寸
        emitter.particleScale = 0.7
        emitter.particleScaleRange = 0.3
        emitter.particleScaleSpeed = -0.15

        // 颜色：使用颜色序列模拟多彩（从暖色到冷色）
        emitter.particleColor = .white
        emitter.particleColorBlendFactor = 1.0

        let colorSequence = SKKeyframeSequence(keyframeValues: [
            UIColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 1.0),  // 金黄
            UIColor(red: 1.0, green: 0.5, blue: 0.4, alpha: 1.0),  // 珊瑚
            UIColor(red: 0.8, green: 0.5, blue: 1.0, alpha: 1.0),  // 紫色
            UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 0.6),  // 天蓝（渐隐）
            UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 0.0),  // 消失
        ], times: [0, 0.2, 0.5, 0.8, 1.0])
        emitter.particleColorSequence = colorSequence

        // 旋转
        emitter.particleRotation = 0
        emitter.particleRotationRange = .pi * 2
        emitter.particleRotationSpeed = 5.0

        // 物理
        emitter.yAcceleration = -150
        emitter.xAcceleration = CGFloat.random(in: -20...20)

        // 位置范围
        emitter.particlePositionRange = CGVector(dx: 10, dy: 10)

        // 混合模式
        emitter.particleBlendMode = .alpha

        return emitter
    }
}
