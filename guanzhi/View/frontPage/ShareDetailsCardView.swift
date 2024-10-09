//
//  ShareDetailsCardView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/9/26.
//

import SwiftUI

struct ShareDetailsCardView: View {
    var isFullScreen: Bool // 传入当前卡片状态
    @Binding var isAtTop: Bool
    

    var body: some View {
        VStack {
            // 拖拽指示器
//            RoundedRectangle(cornerRadius: 3)
//                .frame(width: 40, height: 6)
//                .foregroundColor(isFullScreen ? Color.clear : Color("color-primary"))
//                .padding(.top, 8)
////                .padding(.bottom, 0)
            //

            // 卡片内容
            CustomScrollView(isAtTop: $isAtTop, isScrollEnabled: isFullScreen) {
                VStack(alignment: .leading, spacing: Constants.spacingSpacingXs) {
                    Text("快来这里看看！快来这里看看！快来这里看看！快来这里看看！")
                        .font(Font.custom("PingFang SC", size: 16))
                        .kerning(0.22)
                        .foregroundColor(Color("color-black"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 次级信息
                    Text("#FB80765·2023.02.12 12:22")
                        .font(Font.custom("PingFang SC", size: 14))
                        .kerning(0.22)
                        .foregroundColor(Color("text-gray"))
                }
                .padding(.horizontal, Constants.spacingSpacingM)
                .padding(.vertical, Constants.spacingSpacingXs)

                // 用户信息
                HStack(alignment: .top, spacing: Constants.spacingSpacingXs) {
                    HStack(alignment: .center, spacing: Constants.spacingSpacing0) {
                        Image("icon-avatar")
                            .frame(width: Constants.iconSizeXl, height: Constants.iconSizeXl)
                        
                        VStack(alignment: .leading) {
                            // 用户名
                            Text("一只鸡腿儿")
                                .font(
                                    Font.custom("PingFang SC", size: 18)
                                        .weight(.semibold)
                                )
                                .kerning(0.22)
                                .foregroundColor(.black)
                            
                            // 次级信息
                            HStack {
                                Text("☠️")
                                    .font(Font.custom("PingFang SC", size: 14))
                                    .kerning(0.22)
                                    .foregroundColor(Color(red: 0.61, green: 0.61, blue: 0.61))
                                
                                Text("Onettoooo")
                                    .font(Font.custom("PingFang SC", size: 14))
                                    .kerning(0.22)
                                    .foregroundColor(Constants.textColorTxGery)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, Constants.spacingSpacingM)
                
                Spacer()
            }
//            .background(.brown)
        }
        .background(
//            // 毛玻璃效果背景
//            BlurView(style: .systemMaterialLight)
//                .opacity(isFullScreen ? 1 : 0.7) // 根据状态调整透明度
//                .cornerRadius(isFullScreen ? 0 : 15) // 部分状态下有圆角，全屏无圆角
            
            Color.white.opacity(isFullScreen ? 1 : 0.5 )
        )
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height) // 固定卡片尺寸为屏幕大小
    }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

struct CustomScrollView<Content: View>: UIViewRepresentable {
    var content: Content
    @Binding var isAtTop: Bool
    var isScrollEnabled: Bool // 新增：控制 ScrollView 是否可滚动

    init(isAtTop: Binding<Bool>, isScrollEnabled: Bool, @ViewBuilder content: () -> Content) {
        self._isAtTop = isAtTop
        self.isScrollEnabled = isScrollEnabled
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear // 设置 ScrollView 背景为透明
        scrollView.isScrollEnabled = isScrollEnabled // 根据参数设置是否可滚动

        // 创建一个 UIHostingController 来承载 SwiftUI 内容
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear // 设置 HostingController 背景为透明

        // 将 hostingController 的视图添加到 scrollView
        scrollView.addSubview(hostingController.view)

        // 设置约束
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        uiView.isScrollEnabled = isScrollEnabled // 动态更新 ScrollView 的滚动状态
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: CustomScrollView

        init(_ parent: CustomScrollView) {
            self.parent = parent
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // 检查 scrollView 是否在顶部
            if scrollView.contentOffset.y <= 0 {
                parent.isAtTop = true
            } else {
                parent.isAtTop = false
            }
        }

        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            if parent.isAtTop && scrollView.contentOffset.y <= 0 && velocity.y < 0 {
                // 当在顶部并继续下拉时，禁用弹性
                scrollView.setContentOffset(.zero, animated: false)
                scrollView.bounces = false
            } else {
                scrollView.bounces = true
            }
        }
    }
}

#Preview {
    ShareDetailsCardView(isFullScreen: false, isAtTop: .constant(true))
}


