//
//  StickerTextureCache.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/10.
//
//  贴纸纹理缓存 - 避免重复渲染 SwiftUI → UIImage → SKTexture
//
//  ⚠️ 重要：所有纹理创建必须在主线程执行！
//  UIGraphicsImageRenderer 和 String.draw 涉及 Core Text，
//  在后台线程执行容易导致并发崩溃 (EXC_BAD_ACCESS)。
//

import SpriteKit
import UIKit

// MARK: - StickerTextureCache

/// 贴纸纹理缓存
/// 使用 NSCache 缓存已生成的纹理，避免每帧重复渲染
///
/// ⚠️ 线程安全说明：
/// - 所有涉及 UIGraphicsImageRenderer、String.draw 的操作必须在主线程执行
/// - preload 方法已移除后台线程逻辑，改为同步执行
final class StickerTextureCache {

    // MARK: - 单例

    static let shared = StickerTextureCache()

    // MARK: - 属性

    private var cache = NSCache<NSString, SKTexture>()

    // MARK: - 初始化

    private init() {
        cache.countLimit = 50  // 最多缓存 50 个纹理
        cache.totalCostLimit = 50 * 1024 * 1024  // 约 50MB
    }

    // MARK: - 公开方法

    /// 获取或创建纹理（同步，必须在主线程调用）
    /// - Parameters:
    ///   - definition: 贴纸定义
    ///   - size: 纹理尺寸
    /// - Returns: SKTexture
    ///
    /// ⚠️ 此方法必须在主线程调用，涉及 UIGraphicsImageRenderer
    func texture(for definition: StickerDefinition, size: CGSize) -> SKTexture {
        // ✅ 断言主线程（DEBUG 模式下检查）
        #if DEBUG
        assert(Thread.isMainThread, "⚠️ [StickerTextureCache] texture(for:size:) 必须在主线程调用！")
        #endif

        let key = cacheKey(for: definition, size: size)

        if let cached = cache.object(forKey: key) {
            return cached
        }

        let texture = createTexture(for: definition, size: size)
        cache.setObject(texture, forKey: key)
        return texture
    }

    /// 预加载所有贴纸纹理（同步，主线程执行）
    /// - Parameters:
    ///   - definitions: 贴纸定义数组
    ///   - size: 纹理尺寸
    ///
    /// ⚠️ 此方法必须在主线程调用
    /// 由于贴纸数量少（通常 < 10 个）且尺寸小（72x72），
    /// 同步执行对性能影响微乎其微，但能保证线程安全。
    func preload(definitions: [StickerDefinition], size: CGSize) {
        #if DEBUG
        assert(Thread.isMainThread, "⚠️ [StickerTextureCache] preload 必须在主线程调用！")
        print("✅ [StickerTextureCache] preload \(definitions.count) 个贴纸纹理")
        #endif

        for definition in definitions {
            _ = texture(for: definition, size: size)
        }
    }

    /// 清除所有缓存
    func clearCache() {
        cache.removeAllObjects()
    }

    /// 移除指定贴纸的缓存
    func removeCache(for definition: StickerDefinition, size: CGSize) {
        let key = cacheKey(for: definition, size: size)
        cache.removeObject(forKey: key)
    }

    // MARK: - 私有方法

    /// 生成缓存 Key
    private func cacheKey(for definition: StickerDefinition, size: CGSize) -> NSString {
        "\(definition.stickerID.rawValue)_\(Int(size.width))x\(Int(size.height))" as NSString
    }

    /// 创建纹理
    private func createTexture(for definition: StickerDefinition, size: CGSize) -> SKTexture {
        let dynamicName = definition.dynamicDisplayName  // 使用动态名称
        switch definition.assetKind {
        case .image(let name):
            if let image = UIImage(named: name) {
                return SKTexture(image: renderWithFrame(image: image, size: size))
            }
            return createPlaceholderTexture(size: size, label: dynamicName)

        case .systemSymbol(let name):
            let config = UIImage.SymbolConfiguration(pointSize: size.width * 0.45, weight: .semibold)
            if let symbolImage = UIImage(systemName: name, withConfiguration: config)?
                .withTintColor(.systemOrange, renderingMode: .alwaysOriginal) {
                return SKTexture(image: renderWithFrame(symbolImage: symbolImage, size: size))
            }
            return createPlaceholderTexture(size: size, label: dynamicName)

        case .svg(let name):
            // TODO: 对接 SVG 渲染管线
            if let image = UIImage(named: name) {
                return SKTexture(image: renderWithFrame(image: image, size: size))
            }
            return createPlaceholderTexture(size: size, label: "SVG")

        case .textFallback(let characters):
            // 文字回退：渲染为带圆形背景的文字贴纸
            return createTextFallbackTexture(characters: characters, size: size)

        case .threeD(let configID):
            // TODO: 对接 3D 渲染（SK3DNode 或预渲染 snapshot）
            print("[StickerTextureCache] 3D sticker not implemented: \(configID)")
            return createPlaceholderTexture(size: size, label: "3D")
        }
    }

    /// 将普通图像渲染为带圆形边框的贴纸
    private func renderWithFrame(image: UIImage, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let insetRect = rect.insetBy(dx: 3, dy: 3)

            // 白色圆形背景 + 阴影
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.2).cgColor)
            UIColor.white.setFill()
            UIBezierPath(ovalIn: insetRect).fill()

            // 重置阴影
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            // 边框
            UIColor.systemGray4.setStroke()
            let borderPath = UIBezierPath(ovalIn: insetRect)
            borderPath.lineWidth = 2
            borderPath.stroke()

            // 裁剪为圆形并绘制图像
            UIBezierPath(ovalIn: insetRect).addClip()
            let imageRect = insetRect.insetBy(dx: size.width * 0.12, dy: size.height * 0.12)
            image.draw(in: imageRect)
        }
    }

    /// 将 SF Symbol 渲染为带圆形边框的贴纸
    private func renderWithFrame(symbolImage: UIImage, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let insetRect = rect.insetBy(dx: 3, dy: 3)

            // 白色圆形背景 + 阴影
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.2).cgColor)
            UIColor.white.setFill()
            UIBezierPath(ovalIn: insetRect).fill()

            // 重置阴影
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            // 渐变边框效果
            let gradientColors = [
                UIColor.systemOrange.withAlphaComponent(0.8).cgColor,
                UIColor.systemYellow.withAlphaComponent(0.6).cgColor
            ]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: gradientColors as CFArray,
                                          locations: [0, 1]) {
                context.cgContext.saveGState()
                context.cgContext.addPath(UIBezierPath(ovalIn: insetRect.insetBy(dx: -1, dy: -1)).cgPath)
                context.cgContext.addPath(UIBezierPath(ovalIn: insetRect.insetBy(dx: 1, dy: 1)).cgPath)
                context.cgContext.clip(using: .evenOdd)
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
                context.cgContext.restoreGState()
            }

            // 居中绘制 Symbol
            let symbolSize = symbolImage.size
            let symbolRect = CGRect(
                x: (size.width - symbolSize.width) / 2,
                y: (size.height - symbolSize.height) / 2,
                width: symbolSize.width,
                height: symbolSize.height
            )
            symbolImage.draw(in: symbolRect)
        }
    }

    /// 创建文字回退纹理（用于没有图标的标签类贴纸）
    private func createTextFallbackTexture(characters: String, size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let insetRect = rect.insetBy(dx: 3, dy: 3)

            // 渐变背景色（柔和的蓝紫色调）
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.15).cgColor)

            // 圆形背景
            let gradientColors = [
                UIColor.systemIndigo.withAlphaComponent(0.85).cgColor,
                UIColor.systemPurple.withAlphaComponent(0.7).cgColor
            ]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: gradientColors as CFArray,
                                          locations: [0, 1]) {
                context.cgContext.saveGState()
                context.cgContext.addPath(UIBezierPath(ovalIn: insetRect).cgPath)
                context.cgContext.clip()
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
                context.cgContext.restoreGState()
            }

            // 重置阴影
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            // 白色边框
            UIColor.white.withAlphaComponent(0.6).setStroke()
            let borderPath = UIBezierPath(ovalIn: insetRect.insetBy(dx: 1, dy: 1))
            borderPath.lineWidth = 1.5
            borderPath.stroke()

            // 文字（白色，居中）
            let displayText = String(characters.prefix(2))  // 安全截取前两个字符
            let fontSize = size.width * 0.32
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = displayText.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            displayText.draw(in: textRect, withAttributes: attributes)
        }
        return SKTexture(image: image)
    }

    /// 创建占位纹理
    private func createPlaceholderTexture(size: CGSize, label: String) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let insetRect = rect.insetBy(dx: 3, dy: 3)

            // 灰色背景
            UIColor.systemGray5.setFill()
            UIBezierPath(ovalIn: insetRect).fill()

            // 边框
            UIColor.systemGray3.setStroke()
            let borderPath = UIBezierPath(ovalIn: insetRect)
            borderPath.lineWidth = 2
            borderPath.stroke()

            // 文字标签
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.width * 0.2, weight: .medium),
                .foregroundColor: UIColor.systemGray
            ]
            let textSize = label.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            label.draw(in: textRect, withAttributes: attributes)
        }
        return SKTexture(image: image)
    }
}
