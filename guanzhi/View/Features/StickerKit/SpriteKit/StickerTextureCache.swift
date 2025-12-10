//
//  StickerTextureCache.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/10.
//
//  贴纸纹理缓存 - 避免重复渲染 SwiftUI → UIImage → SKTexture
//

import SpriteKit
import UIKit

// MARK: - StickerTextureCache

/// 贴纸纹理缓存
/// 使用 NSCache 缓存已生成的纹理，避免每帧重复渲染
final class StickerTextureCache {

    // MARK: - 单例

    static let shared = StickerTextureCache()

    // MARK: - 属性

    private var cache = NSCache<NSString, SKTexture>()
    private let queue = DispatchQueue(label: "com.guanzhi.stickerTextureCache", qos: .userInitiated)

    // MARK: - 初始化

    private init() {
        cache.countLimit = 50  // 最多缓存 50 个纹理
        cache.totalCostLimit = 50 * 1024 * 1024  // 约 50MB
    }

    // MARK: - 公开方法

    /// 获取或创建纹理（同步）
    /// - Parameters:
    ///   - definition: 贴纸定义
    ///   - size: 纹理尺寸
    /// - Returns: SKTexture
    func texture(for definition: StickerDefinition, size: CGSize) -> SKTexture {
        let key = cacheKey(for: definition, size: size)

        if let cached = cache.object(forKey: key) {
            return cached
        }

        let texture = createTexture(for: definition, size: size)
        cache.setObject(texture, forKey: key)
        return texture
    }

    /// 预加载所有贴纸纹理（异步）
    /// - Parameters:
    ///   - definitions: 贴纸定义数组
    ///   - size: 纹理尺寸
    ///   - completion: 完成回调（主线程）
    func preload(definitions: [StickerDefinition], size: CGSize, completion: @escaping () -> Void) {
        queue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion() }
                return
            }

            for definition in definitions {
                _ = self.texture(for: definition, size: size)
            }

            DispatchQueue.main.async {
                completion()
            }
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
        switch definition.assetKind {
        case .image(let name):
            if let image = UIImage(named: name) {
                return SKTexture(image: renderWithFrame(image: image, size: size))
            }
            return createPlaceholderTexture(size: size, label: definition.displayName)

        case .systemSymbol(let name):
            let config = UIImage.SymbolConfiguration(pointSize: size.width * 0.45, weight: .semibold)
            if let symbolImage = UIImage(systemName: name, withConfiguration: config)?
                .withTintColor(.systemOrange, renderingMode: .alwaysOriginal) {
                return SKTexture(image: renderWithFrame(symbolImage: symbolImage, size: size))
            }
            return createPlaceholderTexture(size: size, label: definition.displayName)

        case .svg(let name):
            // TODO: 对接 SVG 渲染管线
            if let image = UIImage(named: name) {
                return SKTexture(image: renderWithFrame(image: image, size: size))
            }
            return createPlaceholderTexture(size: size, label: "SVG")

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
