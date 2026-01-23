//
//  OnboardingBannerView.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/9.
//

import SwiftUI

/// 引导 Banner 视图
///
/// 关键设计：
/// - 统一挂载在 App 根视图，避免多处重复
/// - 使用固定高度 frame，参考 AutoNotificationBanner 样式
/// - 自动关闭的提示带有倒计时圆环和关闭按钮
/// - 内嵌跳过确认按钮（非系统 Alert）
struct OnboardingBannerView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // ✅ 监听登录状态，未登录时不显示引导
    @ObservedObject var loginManager = OTOLoginStatusManager.shared

    /// 普通 Banner 高度（与现有提示栏一致）
    private let normalBannerHeight: CGFloat = 110
    /// 带按钮的 Banner 高度
    private let buttonBannerHeight: CGFloat = 160
    /// 长文案 Banner 高度（如提示 E，需要更多空间：安全区域 59 + 文字区域 140）
    private let tallBannerHeight: CGFloat = 200

    var body: some View {
        // ✅ 未登录时不显示引导 Banner
        if loginManager.isLoggedIn {
            ZStack(alignment: .top) {
                // 透明背景占满全屏，用于点击穿透
                Color.clear

                // Banner 内容
                Group {
                    switch coordinator.bannerState {
                    case .hidden:
                        EmptyView()
                            .id("hidden")

                    case .showing(let step):
                        if step.isPersistent {
                            // 常驻类型：有关闭按钮，无倒计时
                            persistentBannerContent(
                                message: step.message,
                                backgroundColor: Color("color-primary")
                            )
                            .id("persistent-\(step.rawValue)")
                        } else {
                            // 自动关闭类型：有倒计时圆环和关闭按钮
                            autoCloseBannerContent(
                                message: step.message,
                                backgroundColor: Color("color-primary"),
                                duration: step.autoCloseTiming ?? 3.0,
                                allowUnlimitedLines: step.allowsUnlimitedLines
                            )
                            .id("autoclose-\(step.rawValue)")
                        }

                    case .showingSuccess:
                        successBannerContent()
                            .id("success")

                    case .showingSkipConfirm:
                        skipConfirmContent()
                            .id("skipConfirm")
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: coordinator.bannerState)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - 常驻 Banner（有关闭按钮，无倒计时）

    @ViewBuilder
    private func persistentBannerContent(
        message: String,
        backgroundColor: Color
    ) -> some View {
        ZStack {
            // 背景容器 + 文字内容
            VStack {
                Spacer()

                HStack(alignment: .center) {
                    Text(message)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color("text-black"))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 16)
                        .padding(.trailing, 56)  // 右侧留出关闭按钮空间
                        .padding(.vertical, 10)
                }
                .padding(.bottom, 4)
            }
            .frame(height: normalBannerHeight, alignment: .center)
            .frame(maxWidth: .infinity)
            .background(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 0, bottomLeading: 20, bottomTrailing: 20, topTrailing: 0),
                    style: .continuous
                )
                .foregroundColor(backgroundColor)
            )
            .overlay(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 0, bottomLeading: 20, bottomTrailing: 20, topTrailing: 0),
                    style: .continuous
                )
                .stroke(Color.black, lineWidth: 4)
            )
            .compositingGroup()
            .shadow(color: backgroundColor.opacity(1), radius: 0, x: 2, y: 4)

            // 关闭按钮（右侧与文字垂直居中）- 使用统一的圆形按钮样式
            HStack {
                Spacer()

                VStack {
                    // 圆形按钮带静态圆环（与自动关闭按钮视觉一致）
                    Circle()
                        .foregroundColor(.clear)
                        .overlay {
                            Button {
                                coordinator.showSkipConfirm()
                            } label: {
                                Image("icon-X")
                                    .frame(width: 14, height: 14)
                            }
                        }
                        .overlay {
                            // 静态圆环（不带倒计时动画）
                            Circle()
                                .stroke(Color.black, style: StrokeStyle(lineWidth: 4.0, lineCap: .square, lineJoin: .round))
                        }
                        .frame(width: 32, height: 32)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
            .frame(height: normalBannerHeight, alignment: .bottomTrailing)
            .frame(maxWidth: .infinity)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }

    // MARK: - 自动关闭 Banner（有倒计时圆环和关闭按钮）

    @ViewBuilder
    private func autoCloseBannerContent(
        message: String,
        backgroundColor: Color,
        duration: TimeInterval,
        allowUnlimitedLines: Bool
    ) -> some View {
        AutoCloseTimerBanner(
            message: message,
            backgroundColor: backgroundColor,
            duration: duration,
            allowUnlimitedLines: allowUnlimitedLines,
            height: allowUnlimitedLines ? tallBannerHeight : normalBannerHeight,
            onClose: {
                coordinator.dismissCurrentBanner()
            }
        )
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }

    // MARK: - 成功 Banner（短暂显示）

    @ViewBuilder
    private func successBannerContent() -> some View {
        ZStack {
            VStack {
                Spacer()

                Text("💯✅")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.bottom, 4)
            }
            .frame(height: normalBannerHeight, alignment: .center)
            .frame(maxWidth: .infinity)
            .background(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 0, bottomLeading: 20, bottomTrailing: 20, topTrailing: 0),
                    style: .continuous
                )
                .foregroundColor(Color.green)
            )
            .overlay(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 0, bottomLeading: 20, bottomTrailing: 20, topTrailing: 0),
                    style: .continuous
                )
                .stroke(Color.black, lineWidth: 4)
            )
            .compositingGroup()
            .shadow(color: Color.green.opacity(1), radius: 0, x: 2, y: 4)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }

    // MARK: - 跳过确认 Content

    @ViewBuilder
    private func skipConfirmContent() -> some View {
        ZStack {
            VStack {
                Spacer()

                VStack(spacing: 8) {
                    Text("要跳过操作提示吗？")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color("text-black"))

                    Text("可以在系统设置中再次查看")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color("text-gray"))
                }
                .padding(.bottom, 64)
            }
            .frame(height: buttonBannerHeight, alignment: .center)
            .frame(maxWidth: .infinity)
            .background(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 0, bottomLeading: 20, bottomTrailing: 20, topTrailing: 0),
                    style: .continuous
                )
                .foregroundColor(Color("color-primary"))
            )
            .overlay(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 0, bottomLeading: 20, bottomTrailing: 20, topTrailing: 0),
                    style: .continuous
                )
                .stroke(Color.black, lineWidth: 4)
            )
            .compositingGroup()
            .shadow(color: Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)

            // 底部按钮
            VStack {
                Spacer()

                HStack(spacing: 12) {
                    Button("继续提示") {
                        coordinator.handleEvent(.continueRequested)
                    }
                    .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))

                    Button("跳过全部提示") {
                        coordinator.handleEvent(.skipAllRequested)
                    }
                    .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: true))
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
            }
            .frame(height: buttonBannerHeight, alignment: .bottom)
            .frame(maxWidth: .infinity)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }
}

// MARK: - 自动关闭计时器 Banner 组件

/// 带倒计时圆环的自动关闭 Banner
private struct AutoCloseTimerBanner: View {
    let message: String
    let backgroundColor: Color
    let duration: TimeInterval
    let allowUnlimitedLines: Bool
    let height: CGFloat
    let onClose: () -> Void

    @State private var elapsedTime: Double = 0.0
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    @State private var startTime: Date = Date()
    @State private var hasClosed: Bool = false  // 防止 timer 重复触发 onClose

    var body: some View {
        ZStack {
            // 背景容器 + 文字内容
            VStack {
                Spacer()

                HStack(alignment: .center) {
                    Text(message)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color("text-black"))
                        .lineLimit(allowUnlimitedLines ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 16)
                        .padding(.trailing, 56)  // 右侧留出关闭按钮空间
                        .padding(.vertical, 10)
                }
                .padding(.bottom, allowUnlimitedLines ? 20 : 4)
            }
            .frame(height: height, alignment: .center)
            .frame(maxWidth: .infinity)
            .background(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 0, bottomLeading: 20, bottomTrailing: 20, topTrailing: 0),
                    style: .continuous
                )
                .foregroundColor(backgroundColor)
            )
            .overlay(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 0, bottomLeading: 20, bottomTrailing: 20, topTrailing: 0),
                    style: .continuous
                )
                .stroke(Color.black, lineWidth: 4)
            )
            .compositingGroup()
            .shadow(color: backgroundColor.opacity(1), radius: 0, x: 2, y: 4)

            // 倒计时圆环和关闭按钮（右下角）
            HStack {
                Spacer()

                VStack {
                    Circle()
                        .foregroundColor(.clear)
                        .overlay {
                            Button(action: onClose) {
                                Image("icon-X")
                                    .frame(width: 14, height: 14)
                            }
                        }
                        .overlay {
                            Circle()
                                .trim(from: CGFloat(elapsedTime / duration), to: 1)
                                .stroke(Color.black, style: StrokeStyle(lineWidth: 4.0, lineCap: .square, lineJoin: .round))
                                .rotationEffect(Angle(degrees: 270))
                                .animation(.linear(duration: 0.2), value: elapsedTime)
                        }
                        .frame(width: 32, height: 32)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
            .frame(height: height, alignment: .bottomTrailing)
            .frame(maxWidth: .infinity)
        }
        .onReceive(timer) { _ in
            // 防止重复触发
            guard !hasClosed else { return }

            let elapsed = Date().timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate
            if elapsed < duration {
                elapsedTime = elapsed
            } else {
                elapsedTime = duration
                hasClosed = true  // 标记已关闭，防止重复调用
                // 时间到，自动关闭
                onClose()
            }
        }
        .onAppear {
            startTime = Date()
            elapsedTime = 0
            hasClosed = false
        }
    }
}

#Preview {
    OnboardingBannerView()
        .environmentObject(OnboardingCoordinator())
}
