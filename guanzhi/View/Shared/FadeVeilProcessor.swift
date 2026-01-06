//
//  FadeVeilProcessor.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/6.
//
//  褪色白化效果处理器（单一实现，SwiftUI/UIKit 共用）
//  - 当 fadeScore >= 90 时应用白化效果
//  - 使用 Core Image 实现：降低饱和度 + 白色蒙版 Screen 混合
//  - 参数集中管理，调一处全局生效
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// 褪色白化效果处理器
///
/// 为褪色度 >= 90 的观之缩略图添加"发白"效果，表示即将褪色。
/// 效果：去饱和（desaturate）+ 白色蒙版（white veil）
///
/// 使用方式：
/// ```swift
/// let processed = FadeVeilProcessor.shared.process(image, fadeScore: 95)
/// ```
final class FadeVeilProcessor {

    // MARK: - Singleton

    static let shared = FadeVeilProcessor()
    private init() {}

    // MARK: - 参数集中管理

    /// 触发阈值：fadeScore >= 此值时才应用白化效果
    static let threshold: Int = 90

    /// 饱和度：0 = 完全灰，1 = 原色
    static let saturation: CGFloat = 0.15

    /// 白色蒙版透明度
    static let veilOpacity: CGFloat = 0.24

    /// 缓存版本号：修改参数后必须 bump，否则旧缓存会导致"改了参数但看起来没变"
    static let version: String = "fv_v1"

    // MARK: - Private

    /// CIContext 复用（创建成本高）
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Public API

    /// 处理图片：当 fadeScore >= threshold 时应用白化效果
    /// - Parameters:
    ///   - image: 原图
    ///   - fadeScore: 褪色度 (0-100)
    /// - Returns: 处理后的图片（fadeScore < threshold 时返回原图）
    func process(_ image: UIImage, fadeScore: Int) -> UIImage {
        // 低于阈值直接返回原图
        guard fadeScore >= Self.threshold else { return image }

        // 1. 转换为 CIImage（处理 EXIF 方向）
        guard let ciImage = CIImage(image: image)?.oriented(forExifOrientation: Int32(image.imageOrientation.exifOrientation)) else {
            return image
        }

        // 2. 降低饱和度（CIColorControls）
        guard let colorControls = CIFilter(name: "CIColorControls") else { return image }
        colorControls.setValue(ciImage, forKey: kCIInputImageKey)
        colorControls.setValue(Float(Self.saturation), forKey: kCIInputSaturationKey)

        guard let desaturated = colorControls.outputImage else { return image }

        // 3. 生成白色蒙版（CIConstantColorGenerator）
        guard let whiteGenerator = CIFilter(name: "CIConstantColorGenerator") else { return image }
        whiteGenerator.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: Self.veilOpacity), forKey: kCIInputColorKey)

        guard let whiteImage = whiteGenerator.outputImage?.cropped(to: desaturated.extent) else {
            return image
        }

        // 4. Screen 混合（类似 SwiftUI .blendMode(.screen)，提亮效果）
        guard let screenBlend = CIFilter(name: "CIScreenBlendMode") else { return image }
        screenBlend.setValue(whiteImage, forKey: kCIInputImageKey)
        screenBlend.setValue(desaturated, forKey: kCIInputBackgroundImageKey)

        guard let output = screenBlend.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }

        // 关键：CIImage 已经校正过方向，返回时用 .up 避免二次旋转
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }
}

// MARK: - UIImageOrientation -> EXIF Orientation

private extension UIImage.Orientation {
    /// 转换为 EXIF 方向值（用于 CIImage.oriented）
    var exifOrientation: Int {
        switch self {
        case .up: return 1
        case .down: return 3
        case .left: return 8
        case .right: return 6
        case .upMirrored: return 2
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .rightMirrored: return 7
        @unknown default: return 1
        }
    }
}
