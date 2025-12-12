//
//  UseZoneParticleFactory.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/11.
//
//  使用区域粒子效果工厂
//

import SpriteKit

/// 使用区域粒子效果工厂
/// 创建拖动提示圆环和使用成功绽放效果
enum UseZoneParticleFactory {

    // MARK: - 圆环提示粒子

    /// 创建使用区域的圆环提示粒子
    /// 拖动贴纸时显示，引导用户拖到此处
    static func makeRingEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()

        // 粒子纹理（使用圆形）
        emitter.particleTexture = SKTexture(imageNamed: "spark")  // 如果没有，会用默认

        // 发射配置 - 环形发射
        emitter.particleBirthRate = 30
        emitter.numParticlesToEmit = 0  // 无限发射
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2  // 360度发射

        // 粒子生命周期
        emitter.particleLifetime = 1.5
        emitter.particleLifetimeRange = 0.5

        // 粒子位置范围（环形）
        emitter.particlePositionRange = CGVector(dx: 120, dy: 120)

        // 粒子速度（向外扩散）
        emitter.particleSpeed = 15
        emitter.particleSpeedRange = 10

        // 粒子大小
        emitter.particleScale = 0.15
        emitter.particleScaleRange = 0.05
        emitter.particleScaleSpeed = -0.05  // 逐渐缩小

        // 粒子颜色（蓝白渐变）
        emitter.particleColor = UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleColorBlendFactorRange = 0.2

        // 透明度变化
        emitter.particleAlpha = 0.8
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -0.4  // 逐渐消失

        // 粒子旋转
        emitter.particleRotation = 0
        emitter.particleRotationRange = .pi * 2
        emitter.particleRotationSpeed = 1.0

        // 混合模式
        emitter.particleBlendMode = .add

        return emitter
    }

    // MARK: - 绽放粒子

    /// 创建使用成功时的绽放粒子
    /// 一次性爆发效果
    static func makeBurstEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()

        // 粒子纹理
        emitter.particleTexture = SKTexture(imageNamed: "spark")

        // 发射配置 - 一次性爆发
        emitter.particleBirthRate = 500  // 短时间内大量发射
        emitter.numParticlesToEmit = 60  // 限制总数
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2  // 360度发射

        // 粒子生命周期
        emitter.particleLifetime = 0.8
        emitter.particleLifetimeRange = 0.3

        // 粒子位置范围（从中心爆发）
        emitter.particlePositionRange = CGVector(dx: 10, dy: 10)

        // 粒子速度（快速向外）
        emitter.particleSpeed = 200
        emitter.particleSpeedRange = 80

        // 粒子大小
        emitter.particleScale = 0.25
        emitter.particleScaleRange = 0.1
        emitter.particleScaleSpeed = -0.15  // 逐渐缩小

        // 粒子颜色（多彩）
        emitter.particleColor = UIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleColorBlendFactorRange = 0.5

        // 颜色序列（从亮黄到橙红）
        let colorSequence = SKKeyframeSequence(keyframeValues: [
            UIColor(red: 1.0, green: 1.0, blue: 0.6, alpha: 1.0),
            UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0),
            UIColor(red: 1.0, green: 0.3, blue: 0.1, alpha: 0.5)
        ], times: [0, 0.5, 1.0])
        emitter.particleColorSequence = colorSequence

        // 透明度变化
        emitter.particleAlpha = 1.0
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -0.8  // 快速消失

        // 粒子旋转
        emitter.particleRotation = 0
        emitter.particleRotationRange = .pi * 2
        emitter.particleRotationSpeed = 3.0

        // 混合模式
        emitter.particleBlendMode = .add

        // 重力效果（轻微下落）
        emitter.yAcceleration = -100

        return emitter
    }

    // MARK: - 简化版本（无纹理依赖）

    /// 创建简化版圆环提示粒子（使用内置圆形）
    static func makeSimpleRingEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()

        // 使用程序生成的圆形纹理
        let size: CGFloat = 8
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fillEllipse(in: rect)
        }
        emitter.particleTexture = SKTexture(image: image)

        // 发射配置
        emitter.particleBirthRate = 25
        emitter.numParticlesToEmit = 0
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2

        // 粒子生命周期
        emitter.particleLifetime = 2.0
        emitter.particleLifetimeRange = 0.5

        // 粒子位置范围（环形）
        emitter.particlePositionRange = CGVector(dx: 100, dy: 100)

        // 粒子速度
        emitter.particleSpeed = 8
        emitter.particleSpeedRange = 5

        // 粒子大小
        emitter.particleScale = 1.0
        emitter.particleScaleRange = 0.3
        emitter.particleScaleSpeed = -0.2

        // 粒子颜色（淡蓝色）
        emitter.particleColor = UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0

        // 透明度变化
        emitter.particleAlpha = 0.6
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -0.25

        // 混合模式
        emitter.particleBlendMode = .add

        return emitter
    }

    /// 创建简化版绽放粒子（使用内置圆形）
    static func makeSimpleBurstEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()

        // 使用程序生成的圆形纹理
        let size: CGFloat = 12
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fillEllipse(in: rect)
        }
        emitter.particleTexture = SKTexture(image: image)

        // 发射配置 - 一次性爆发
        emitter.particleBirthRate = 400
        emitter.numParticlesToEmit = 50
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2

        // 粒子生命周期
        emitter.particleLifetime = 0.6
        emitter.particleLifetimeRange = 0.2

        // 粒子位置范围
        emitter.particlePositionRange = CGVector(dx: 5, dy: 5)

        // 粒子速度
        emitter.particleSpeed = 180
        emitter.particleSpeedRange = 60

        // 粒子大小
        emitter.particleScale = 1.2
        emitter.particleScaleRange = 0.4
        emitter.particleScaleSpeed = -0.8

        // 粒子颜色（金黄色）
        emitter.particleColor = UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleColorBlendFactorRange = 0.3

        // 透明度变化
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -1.2

        // 混合模式
        emitter.particleBlendMode = .add

        // 重力效果
        emitter.yAcceleration = -80

        return emitter
    }
}
