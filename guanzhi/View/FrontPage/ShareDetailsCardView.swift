//
//  ShareDetailsCardView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/9/26.
//

import SwiftUI
import CoreLocation

struct ShareDetailsCardView: View {
    @EnvironmentObject var searchViewModel: SearchViewModel
    @Binding var isFullScreen: Bool
    @Binding var isAtTop: Bool
    @Binding var dragOffset: CGFloat
    @State private var scrollPosition: CGPoint = .zero
    @Binding var cardDragIsActive: Bool

    var body: some View {
        if let share = searchViewModel.selectedShare {
            ZStack {
                VStack {
    //                Text("Scroll offset: \(scrollPosition.y)  \(isFullScreen)  \(isAtTop)") //调试用
                    
                    Rectangle()
                        .foregroundStyle(Color("color-gray"))
                        .frame(width: 36, height: 5)
                        .cornerRadius(2.5, corners: .allCorners)
                        .padding(.top, 6)
                    
                    ScrollView {
                        VStack {
                            VStack(alignment: .leading, spacing: Constants.spacingSpacingXs) {
//                                Text("快来这里看看！快来这里看看！快来这里看看！快来这里看看！")
                                Text(share.data)
                                    .font(Font.custom("PingFang SC", size: 16))
                                    .kerning(0.22)
                                    .foregroundColor(Color("color-black"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // 次级信息
                                HStack {
    //                                Text("#FB80765·2023.02.12 12:22")
                                    Text("#\(share.id) · \(searchViewModel.formattedDate(from: share.createDate))")
                                        .font(Font.custom("PingFang SC", size: 14))
                                        .kerning(0.22)
                                        .foregroundColor(Color("text-deepgray"))
                                    Spacer()
//                                    Text("👀 XXX") //浏览量 暂时去除
//                                        .font(Font.custom("PingFang SC", size: 14))
//                                        .kerning(0.22)
//                                        .foregroundColor(Color("color-black"))
                                }
                                
                                // 位置信息
                                HStack{
                                    Text("📌 \(share.address)") //需要调整
                                        .font(Font.custom("PingFang SC", size: 14))
                                        .kerning(0.22)
                                        .foregroundColor(Color("color-black"))
                                        .lineLimit(1) // 限制显示一行
                                        .truncationMode(.tail) // 设置省略模式为尾部省略
                                    Spacer()
                                    Button(action: {
                                        // 查看路线-胶囊按钮s
                                        openNavigationApp(destination: CLLocationCoordinate2D(latitude: share.latitude, longitude: share.longitude))
                                    }) {
                                        Text("🧭 查看路线")
                                    }
                                    .buttonStyle(ButtonStyle_capsuleHugPrimary_s(isEnabled: true))
                                }
                            }
                            .padding(.horizontal, Constants.spacingSpacingM)
                            .padding(.bottom, Constants.spacingSpacingXs)
                            
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
                            ForEach(0..<20, id: \.self) { i in
                                Text("评论内容 \(i)")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(i)
                            }
                            .padding()
                            
                            Spacer()
                        }
                        .background(GeometryReader { geometry in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).origin)
                        })
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            self.scrollPosition = value
                        }
                        .padding(.top, isFullScreen ? UIScreen.main.bounds.height * 0.05 : 0)
                    }
                    .coordinateSpace(name: "scroll")
                    .onAppear(perform: {
                        isAtTop = true
                    })
                    .onChange(of: scrollPosition) { _ , _ in
                        if scrollPosition.y >= (UIScreen.main.bounds.height * 0.05 - 5) {
                            isAtTop = true
                        } else {
                            isAtTop = false
                        }
                    }
                    
                }
                .background(
                    BlurView(style: .systemMaterial) // 毛玻璃效果背景
                        .opacity(isFullScreen ? 1 : 0.7) //根据状态调整透明度
                        .cornerRadius(isFullScreen ? 0 : Constants.cornerRCornerRM) //卡片状态下有圆角，全屏无圆角
    //                Color.white.opacity(isFullScreen ? 1 : 0.5 )
                )
                .frame(maxWidth: .infinity)
                .scrollDisabled(!isFullScreen || !cardDragIsActive)
                
                HStack {
                    Color.clear
                        .frame(width: 25)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let dragDistance = value.translation.width
                                    if dragDistance > 0 {
                                        dragOffset = dragDistance
                                    }
                                }
                                .onEnded { value in
                                    let dragDistance = value.translation.width
                                    let threshold: CGFloat = 120
                                    if dragDistance > threshold {
                                        withAnimation(.spring) {
                                            isFullScreen = false
                                        }
                                    }
                                    withAnimation(.spring) {
                                        dragOffset = 0
                                    }
                                    
                                }
                        )
                    Spacer()
                } // 左边缘滑动退出区域
                .ignoresSafeArea(.all)
            }
    //        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height) // 固定卡片尺寸为屏幕大小
        }
        
    }
    
    func openNavigationApp(destination: CLLocationCoordinate2D) {
        let alert = UIAlertController(title: "选择导航应用", message: nil, preferredStyle: .actionSheet)

        // 高德地图选项
        if UIApplication.shared.canOpenURL(URL(string: "iosamap://")!) {
            alert.addAction(UIAlertAction(title: "高德地图", style: .default) { _ in
                let urlString = "iosamap://path?sourceApplication=YourAppName&dlat=\(destination.latitude)&dlon=\(destination.longitude)&dev=0&t=0"
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
            })
        }

        // 百度地图选项
        if UIApplication.shared.canOpenURL(URL(string: "baidumap://")!) {
            alert.addAction(UIAlertAction(title: "百度地图", style: .default) { _ in
                let urlString = "baidumap://map/direction?destination=latlng:\(destination.latitude),\(destination.longitude)|name:目标位置&mode=driving&src=YourAppName"
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
            })
        }

        // Google Maps 选项
        if UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!) {
            alert.addAction(UIAlertAction(title: "Google Maps", style: .default) { _ in
                let urlString = "comgooglemaps://?daddr=\(destination.latitude),\(destination.longitude)&directionsmode=driving"
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
            })
        }

        // Apple Maps 选项（默认）
        alert.addAction(UIAlertAction(title: "Apple 地图", style: .default) { _ in
            let urlString = "http://maps.apple.com/?daddr=\(destination.latitude),\(destination.longitude)"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        })

        // 取消按钮
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))

        // 在 iPad 上设置弹窗呈现样式为底部弹出
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = UIApplication.shared.windows.first?.rootViewController?.view
            popoverController.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }

        // 展示弹窗
        UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
    }
    
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) { }
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

#Preview {
    ShareDetailsCardView(isFullScreen: .constant(false), isAtTop: .constant(true), dragOffset: .constant(0), cardDragIsActive: .constant(true))
        .environmentObject(SearchViewModel())
}


struct CommentContentView: View {
    @State private var commentContent: String = ""
    @State private var placeholder: String = "发表一个贴贴"
    @Binding var isTieTieEnabled: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 8) {
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(.shadow(.inner(color: Color("color-primary").opacity(1), radius: 0, x: 4, y: 6)))
                    .stroke(.black, lineWidth: 4)
                    .foregroundStyle(Color("color-white").opacity(1))
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        TextField(placeholder, text: $commentContent)
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .padding(.horizontal, 16)
                            .frame(height: 32)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0))
                            .cornerRadius(20)
                            .multilineTextAlignment(.leading)
                            .autocorrectionDisabled()
                            .onTapGesture {
                                
                            }
                            .onSubmit {
                                
                            }
                    }
                
                Button(action: {
                    // 贴贴--胶囊按钮hug
                }) {
                    Text("🫂 贴贴")
                }
                .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: isTieTieEnabled))
                
                
            }
            .padding(.top, 16)
            .padding(.horizontal)
            .padding(.bottom, 48)
            .background(BlurView(style: .systemMaterialLight)/*Color.white.opacity(0.9)*/)
        }
    }
}
