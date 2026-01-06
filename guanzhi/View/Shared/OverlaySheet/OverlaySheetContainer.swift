//
//  OverlaySheetContainer.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/5.
//
//  通用的 Overlay Sheet 容器
//  采用 macOS 26 风格的缩放动画效果
//

import SwiftUI
import UIKit

// MARK: - 屏幕圆角获取

/// 获取设备屏幕圆角半径
/// 使用 iOS 私有 API _displayCornerRadius，如果获取失败则返回默认值
func getDeviceCornerRadius(defaultValue: CGFloat = 44) -> CGFloat {
    // 尝试通过私有 API 获取屏幕圆角
    let key = "_displayCornerRadius"
    if let screen = UIScreen.main.value(forKey: key) as? CGFloat, screen > 0 {
        return screen
    }
    // 获取失败，返回默认值（现代 iPhone 通常是 44-47）
    return defaultValue
}

// MARK: - 带动画的 Overlay 包装器

/// 处理进入/退出动画的包装视图
/// 支持条件性动画：进入详情时无动画，从详情返回时瞬间出现
struct AnimatedOverlaySheet<Content: View>: View {
    @Binding var isPresented: Bool
    let cornerRadius: CGFloat
    let heightFraction: CGFloat
    let edgeInset: CGFloat
    let onDismiss: (() -> Void)?
    let content: () -> Content

    /// 是否跳过动画（进入详情/从详情返回时使用）
    var skipAnimation: Bool = false

    /// 动画状态
    @State private var animationProgress: CGFloat = 0
    @State private var isVisible: Bool = false

    /// 动画参数
    private let startScale: CGFloat = 1.06
    private let endScale: CGFloat = 1.0

    /// 获取实际使用的圆角（考虑屏幕圆角）
    private var effectiveCornerRadius: CGFloat {
        // 如果传入 0 或负数，使用屏幕圆角
        if cornerRadius <= 0 {
            return getDeviceCornerRadius()
        }
        return cornerRadius
    }

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let screenWidth = geometry.size.width
            let sheetHeight = screenHeight * heightFraction
            let sheetWidth = screenWidth - edgeInset * 2

            ZStack(alignment: .bottom) {
                // 背景遮罩（几乎透明，但能接收点击）
                if isVisible {
                    Color.black.opacity(0.001)
                        .onTapGesture {
                            dismissWithAnimation()
                        }
                }

                // Sheet 容器
                if isVisible {
                    VStack(spacing: 0) {
                        content()
                    }
                    .frame(width: sheetWidth, height: sheetHeight)
                    // 毛玻璃背景
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -8)
                    .padding(.horizontal, edgeInset)
                    .padding(.bottom, edgeInset)
                    .scaleEffect(skipAnimation ? endScale : lerp(startScale, endScale, animationProgress))
                    .opacity(skipAnimation ? 1.0 : animationProgress)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onChange(of: isPresented) { oldValue, newValue in
            if newValue {
                // 显示
                if skipAnimation {
                    // 跳过动画，使用 transaction 禁用所有动画
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        isVisible = true
                        animationProgress = 1.0
                    }
                } else {
                    // 带动画显示
                    isVisible = true
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        animationProgress = 1.0
                    }
                }
            } else {
                // 隐藏
                if skipAnimation {
                    // 跳过动画，使用 transaction 禁用所有动画
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        animationProgress = 0
                        isVisible = false
                    }
                } else {
                    // 带动画隐藏
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        animationProgress = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        isVisible = false
                    }
                }
            }
        }
        .onAppear {
            if isPresented {
                if skipAnimation {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        isVisible = true
                        animationProgress = 1.0
                    }
                } else {
                    isVisible = true
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        animationProgress = 1.0
                    }
                }
            }
        }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        return a + (b - a) * t
    }

    private func dismissWithAnimation() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            animationProgress = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isVisible = false
            isPresented = false
            onDismiss?()
        }
    }
}

// MARK: - 便捷修饰器

extension View {
    /// 以 overlay sheet 方式呈现内容（macOS 26 风格动画）
    /// - Parameters:
    ///   - isPresented: 是否显示
    ///   - cornerRadius: 圆角半径（传 0 或负数使用屏幕圆角）
    ///   - heightFraction: 高度占屏幕比例
    ///   - edgeInset: 边距
    ///   - skipAnimation: 是否跳过动画
    ///   - onDismiss: 关闭回调
    ///   - content: 内容
    func overlaySheet<Content: View>(
        isPresented: Binding<Bool>,
        cornerRadius: CGFloat = 0,  // 默认使用屏幕圆角
        heightFraction: CGFloat = 0.75,
        edgeInset: CGFloat = 12,
        skipAnimation: Bool = false,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.overlay {
            AnimatedOverlaySheet(
                isPresented: isPresented,
                cornerRadius: cornerRadius,
                heightFraction: heightFraction,
                edgeInset: edgeInset,
                onDismiss: onDismiss,
                content: content,
                skipAnimation: skipAnimation
            )
        }
    }
}
