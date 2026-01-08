//
//  ImagePlaceholder.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/8.
//
//  统一的图片占位符组件
//  - 加载中：wand.and.rays.inverse（动态效果）
//  - 加载失败：photo.badge.exclamationmark
//

import SwiftUI
import UIKit

// MARK: - 常量定义

/// 图片占位符 SF Symbols 名称
enum ImagePlaceholderSymbol {
    /// 加载中图标（魔法棒 + 光线）
    static let loading = "wand.and.rays.inverse"
    /// 加载失败图标（照片 + 感叹号）
    static let failed = "photo.badge.exclamationmark"
}

// MARK: - SwiftUI 组件

/// 图片占位符状态
enum ImagePlaceholderState {
    case loading
    case failed
}

/// SwiftUI 图片占位符视图
struct ImagePlaceholderView: View {
    let state: ImagePlaceholderState
    let size: CGFloat
    var backgroundColor: Color = Color("color-primary")
    var iconColor: Color = .white

    @State private var variableValue: Double = 0.0

    var body: some View {
        Group {
            switch state {
            case .loading:
                Image(systemName: ImagePlaceholderSymbol.loading, variableValue: variableValue)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.5, height: size * 0.5)
                    .foregroundColor(iconColor)
                    .symbolEffect(.variableColor.iterative.dimInactiveLayers.reversing)
                    .onAppear {
                        withAnimation(Animation.linear(duration: 2.0).repeatForever(autoreverses: true)) {
                            variableValue = 1.0
                        }
                    }

            case .failed:
                Image(systemName: ImagePlaceholderSymbol.failed)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.5, height: size * 0.5)
                    .foregroundColor(iconColor)
            }
        }
        .frame(width: size, height: size)
        .background(backgroundColor)
    }
}

/// 圆形图片占位符视图（用于地图标注等圆形缩略图）
struct CircularImagePlaceholderView: View {
    let state: ImagePlaceholderState
    let size: CGFloat
    var backgroundColor: Color = Color("color-primary")
    var iconColor: Color = .white
    var borderColor: Color = .black
    var borderWidth: CGFloat = 4

    @State private var variableValue: Double = 0.0

    var body: some View {
        Group {
            switch state {
            case .loading:
                Image(systemName: ImagePlaceholderSymbol.loading, variableValue: variableValue)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.4, height: size * 0.4)
                    .foregroundColor(iconColor)
                    .symbolEffect(.variableColor.iterative.dimInactiveLayers.reversing)
                    .onAppear {
                        withAnimation(Animation.linear(duration: 2.0).repeatForever(autoreverses: true)) {
                            variableValue = 1.0
                        }
                    }

            case .failed:
                Image(systemName: ImagePlaceholderSymbol.failed)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.4, height: size * 0.4)
                    .foregroundColor(iconColor)
            }
        }
        .frame(width: size, height: size)
        .background(backgroundColor)
        .clipShape(Circle())
        .overlay(Circle().stroke(borderColor, lineWidth: borderWidth))
    }
}

// MARK: - UIKit 辅助方法

/// UIKit 图片占位符工具类
enum ImagePlaceholderUIKit {

    /// 创建加载中图标的 UIImage
    /// - Parameters:
    ///   - pointSize: 图标大小
    ///   - weight: 图标粗细
    /// - Returns: UIImage
    static func loadingImage(pointSize: CGFloat = 24, weight: UIImage.SymbolWeight = .medium) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return UIImage(systemName: ImagePlaceholderSymbol.loading, withConfiguration: config)
    }

    /// 创建加载失败图标的 UIImage
    /// - Parameters:
    ///   - pointSize: 图标大小
    ///   - weight: 图标粗细
    /// - Returns: UIImage
    static func failedImage(pointSize: CGFloat = 24, weight: UIImage.SymbolWeight = .medium) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return UIImage(systemName: ImagePlaceholderSymbol.failed, withConfiguration: config)
    }

    /// 配置 UIImageView 为加载中状态
    /// - Parameters:
    ///   - imageView: 目标 UIImageView
    ///   - pointSize: 图标大小
    static func configureForLoading(_ imageView: UIImageView, pointSize: CGFloat = 24) {
        imageView.image = loadingImage(pointSize: pointSize)
        imageView.tintColor = .white
        imageView.contentMode = .center

        // 添加旋转动画
        addRotationAnimation(to: imageView)
    }

    /// 配置 UIImageView 为加载失败状态
    /// - Parameters:
    ///   - imageView: 目标 UIImageView
    ///   - pointSize: 图标大小
    static func configureForFailed(_ imageView: UIImageView, pointSize: CGFloat = 24) {
        // 移除动画
        imageView.layer.removeAnimation(forKey: "rotationAnimation")

        imageView.image = failedImage(pointSize: pointSize)
        imageView.tintColor = .white
        imageView.contentMode = .center
    }

    /// 添加旋转动画
    private static func addRotationAnimation(to imageView: UIImageView) {
        // 使用脉冲缩放动画代替旋转（更适合魔法棒图标）
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.9
        animation.toValue = 1.1
        animation.duration = 1.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        imageView.layer.add(animation, forKey: "rotationAnimation")
    }

    /// 移除动画
    static func removeAnimation(from imageView: UIImageView) {
        imageView.layer.removeAnimation(forKey: "rotationAnimation")
    }
}

// MARK: - Preview

#Preview("加载中状态 - 方形") {
    ImagePlaceholderView(state: .loading, size: 120)
}

#Preview("加载失败状态 - 方形") {
    ImagePlaceholderView(state: .failed, size: 120)
}

#Preview("加载中状态 - 圆形") {
    CircularImagePlaceholderView(state: .loading, size: 64)
}

#Preview("加载失败状态 - 圆形") {
    CircularImagePlaceholderView(state: .failed, size: 64)
}
