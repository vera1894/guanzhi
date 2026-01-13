//
//  OnboardingHighlightModifier.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/9.
//

import SwiftUI

/// 引导高亮效果 ViewModifier
///
/// 关键设计：
/// - 使用设计 token（Color("color-primary")）
/// - 尊重 Reduce Motion 设置
/// - allowsHitTesting(false) 不挡点击
/// - 增强视觉效果：更粗的边框、更大的阴影、缩放动画
struct OnboardingHighlightModifier: ViewModifier {
    let isHighlighted: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var animationPhase: CGFloat = 0
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHighlighted && !reduceMotion ? scale : 1.0)
            .overlay {
                if isHighlighted {
                    // 外层光晕
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("color-primary").opacity(0.3), lineWidth: 8)
                        .blur(radius: 4)
                        .allowsHitTesting(false)

                    // 主边框
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color("color-primary"), lineWidth: 4)
                        .opacity(reduceMotion ? 1 : (0.6 + 0.4 * Darwin.sin(animationPhase)))
                        .shadow(color: Color("color-primary").opacity(0.8), radius: reduceMotion ? 4 : 12)
                        .shadow(color: Color("color-primary").opacity(0.4), radius: reduceMotion ? 2 : 20)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard isHighlighted && !reduceMotion else { return }
                // 脉冲动画
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    animationPhase = .pi
                }
                // 缩放动画
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    scale = 1.08
                }
            }
            .onChange(of: isHighlighted) { _, newValue in
                if !newValue {
                    // 使用非 repeatForever 动画来停止并重置
                    withAnimation(.easeOut(duration: 0.2)) {
                        scale = 1.0
                        animationPhase = 0
                    }
                } else if !reduceMotion {
                    // 重新开始动画（当从非高亮变为高亮时）
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        animationPhase = .pi
                    }
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        scale = 1.08
                    }
                }
            }
    }
}

extension View {
    /// 添加引导高亮效果
    /// - Parameter isHighlighted: 是否高亮
    func onboardingHighlight(_ isHighlighted: Bool) -> some View {
        modifier(OnboardingHighlightModifier(isHighlighted: isHighlighted))
    }
}
