//
//  ButtonStyles.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/1/25.
//

import SwiftUI

struct ButtonStyles: View {
    
    @State private var isLocated: Bool = false //是否已经定位
    
    var body: some View {
        
        HStack {
            Button{
                //定位
            }label: { }
        .buttonStyle(IconStylePosition(isAnimating: $isLocated))
            
            Button{
                //Seee位置
            }label: { }
        .buttonStyle(SeeePositionStyle(isEnabled: true))
        }
        
        HStack(alignment: .top) {
            Button(action: {
                // 头像-s
            }) { }
            .buttonStyle(AvatarStyle_s(isEnabled: true, profileImage: Image("例子"), borderThickness: 4))
            
            Button(action: {
                // 头像-s
            }) { }
            .buttonStyle(AvatarStyle_m(isEnabled: true, profileImage: Image("例子"), borderThickness: 4))
            
            Button(action: {
                // 头像-s
            }) { }
            .buttonStyle(AvatarStyle_l(isEnabled: true, profileImage: Image("例子"), borderThickness: 4))
        }
        
        HStack(alignment: .top) {
            
            Button{
                //返回按钮
            }label: {
                Image("icon-back")
            }
            .buttonStyle(ButtonStyle_m())
            
            Button{
                //关闭按钮
            }label: {
                Image("icon-close")
            }
            .buttonStyle(ButtonStyle_m())
            
            Button{
                //定位按钮
            }label: {
                Image("icon-location")
            }
            .buttonStyle(ButtonStyle_m())
            
            Button{
                //更多按钮
            }label: {
                Image("icon-more")
            }
            .buttonStyle(ButtonStyle_m())
            
            Button{
                //设置按钮
            }label: {
                Image("icon-setting")
            }
            .buttonStyle(ButtonStyle_m())
            
            Button{
                //提醒按钮
            }label: {
                Image("icon-notification")
            }
            .buttonStyle(ButtonStyle_m())
            
        }
        
        
        
        VStack(spacing: 10) {
            Button(action: {
                        // 查看路线
                    }) {
                        Text("🧭 查看路线")
                    }
                    .buttonStyle(ButtonStyle_capsuleHugPrimary_s(isEnabled: true))
            
            Button(action: {
                        // 分享地点
                    }) {
                        Text("📷 分享地点")
                    }
                    .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: true))
            
            HStack {
                Button(action: {
                            // 贴贴
                        }) {
                            Text("🫂 贴贴")
                        }
                    .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: true))
                
                Button(action: {
                            // 贴贴（禁用）
                        }) {
                            Text("🫂 贴贴")
                        }
                        .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: false))
            }
            
            HStack {
                Button(action: {
                            // 下一步
                        }) {
                            Text("🔜 下一步")
                        }
                    .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: true))
                
                Button(action: {
                            // 下一步（禁用）
                        }) {
                            Text("🔜 下一步")
                        }
                        .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: false))
            }
            
            VStack {
                
                Button(action: {
                            // 发布
                        }) {
                            Text("✅ 发布")
                        }
                    .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: true))
                
                Button(action: {
                            // 发布
                        }) {
                            Text("🥺 求一下这里最新的照片或视频")
                        }
                    .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
                
                Button(action: {
                            // 发布
                        }) {
                            Text("🥺 查看求助信息")
                        }
                    .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
                
                Button(action: {
                            // 发布
                        }) {
                            Text("📷 帮助ta了解这里的情况")
                        }
                    .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
                
                Button(action: {
                            // 发布
                        }) {
                            Text("🥺 去查看")
                        }
                    .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
                
                Button(action: {
                            // 发布
                        }) {
                            Text("🧭 查看路线")
                        }
                    .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
                
            }
            
            VStack {  //注册登录页面
                
                HStack {
                    Button(action: {
                                // 返回
                            }) {
                                Text("🔙️ 返回")
                            }
                        .buttonStyle(ButtonStyle_capsuleHugLeft(isEnabled: true))
                    
                    Button(action: {
                                // 下一步
                            }) {
                                Text("🔜 下一步")
                            }
                        .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: true))
                }  //注册-返回&下一步
                
                HStack {
                    Button(action: {
                                // 下一步
                            }) {
                                Text("🔙️ 返回")
                            }
                        .buttonStyle(ButtonStyle_capsuleHugLeft(isEnabled: true))
                    
                    Button(action: {
                                // 下一步
                            }) {
                                Text("🔜 下一步")
                            }
                        .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: false))
                }  //注册-返回&下一步（禁用）
                
                HStack {
                    Button(action: {
                                // 返回
                            }) {
                                Text("🔙️ 返回")
                            }
                        .buttonStyle(ButtonStyle_capsuleHugLeft(isEnabled: true))
                    
                    Button(action: {
                                // 下一步
                            }) {
                                Text("✅ 完成")
                            }
                        .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: true))
                }  //注册-返回&完成
                
            }  //注册登录页面
            
        }
        
    }
}

struct ButtonStyle_s: ButtonStyle {

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: 32, height: 32)
            .shadow(color: configuration.isPressed ? Color.clear : Color("color-primary"), radius: 0, x: 2, y:4)
            .brightness(configuration.isPressed ? -0.2 : 0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ButtonStyle_m: ButtonStyle {

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: 32, height: 32)
            .shadow(color: configuration.isPressed ? Color.clear : Color("color-primary"), radius: 0, x: 2, y:4)
            .brightness(configuration.isPressed ? -0.2 : 0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ButtonStyle_capsuleHugPrimary: ButtonStyle {
//    var foregroundColor: Color
//    var backgroundColor: Color
//    var borderColor: Color
//    var borderWidth: CGFloat
    var isEnabled: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(Color("text-black"))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(height: 32, alignment: .center)
            .background(
                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft])
                    .fill(Color("color-primary"))
            )
            .overlay(
                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft])
                    .stroke(Color.black, lineWidth: 4)
            )
            .shadow(color: configuration.isPressed || !isEnabled ? Color.clear : Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
            .brightness(isEnabled && configuration.isPressed ? -0.2 : 0)
            .grayscale(isEnabled ? 0 : 1)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ButtonStyle_capsuleHugPrimary_s: ButtonStyle {
//    var foregroundColor: Color
//    var backgroundColor: Color
//    var borderColor: Color
//    var borderWidth: CGFloat
    var isEnabled: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(Color("text-black"))
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .frame(height: 24, alignment: .center)
            .background(
                RoundedCorner(radius: 12, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                    .fill(Color("color-primary"))
            )
            .overlay(
                RoundedCorner(radius: 12, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                    .stroke(Color.black, lineWidth: 4)
            )
            .shadow(color: configuration.isPressed || !isEnabled ? Color.clear : Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
            .brightness(isEnabled && configuration.isPressed ? -0.2 : 0)
            .grayscale(isEnabled ? 0 : 1)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ButtonStyle_capsuleHugLeft: ButtonStyle {

    var isEnabled: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(Color("text-black"))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(height: 32, alignment: .center)
            .background(
                CombinedBackgroundAndBorder(radius: 20, corners: [.topLeft, .topRight, .bottomLeft], isEnabled: isEnabled, isPressed: configuration.isPressed)
            )
            .brightness(isEnabled && configuration.isPressed ? -0.2 : 0)
            .grayscale(isEnabled ? 0 : 1)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ButtonStyle_capsuleFillPrimary: ButtonStyle {

    var isEnabled: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(Color("text-black"))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(height: 32, alignment: .center)
            .frame(maxWidth: .infinity)
            .background(
                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft])
                    .fill(Color("color-primary"))
            )
            .overlay(
                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft])
                    .stroke(Color.black, lineWidth: 4)
            )
            .shadow(color: configuration.isPressed || !isEnabled ? Color.clear : Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
            .brightness(isEnabled && configuration.isPressed ? -0.2 : 0)
            .grayscale(isEnabled ? 0 : 1)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ButtonStyle_capsuleFillSecondary: ButtonStyle {

    var isEnabled: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(Color("text-white"))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(height: 32, alignment: .center)
            .frame(maxWidth: .infinity)
            .background(
                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft])
                    .fill(Color("color-secondary"))
            )
            .overlay(
                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft])
                    .stroke(Color.black, lineWidth: 4)
            )
            .shadow(color: configuration.isPressed || !isEnabled ? Color.clear : Color("color-secondary").opacity(1), radius: 0, x: 2, y: 4)
            .brightness(isEnabled && configuration.isPressed ? -0.2 : 0)
            .grayscale(isEnabled ? 0 : 1)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.95 : 1.0)
    }
}

struct AvatarStyle_s: ButtonStyle {

    var isEnabled: Bool
    var profileImage: Image
    var borderThickness: CGFloat

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
        ZStack(alignment: .center) {
            Image("icon-avatar")  // 边框层，稍微放大以显示边框
                .resizable()
                .scaledToFit()
                .frame(width: 32 - 2, height: 32 - 2)
                .foregroundColor(.black)
                .shadow(color: configuration.isPressed || !isEnabled ? Color.clear : Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
            profileImage  // 头像图像层
                .resizable()
                .scaledToFit()
                .frame(width: 32 - borderThickness - 2, height: 32 - borderThickness - 2 )
                .mask(
                    Image("icon-avatar")
                        .resizable()
                        .scaledToFit()
                )
        }
            .brightness(isEnabled && configuration.isPressed ? -0.2 : 0)
            .grayscale(isEnabled ? 0 : 1)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.95 : 1.0)
    }
}

struct AvatarStyle_m: ButtonStyle {

    var isEnabled: Bool
    var profileImage: Image
    var borderThickness: CGFloat

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
        ZStack(alignment: .center) {
            Image("icon-avatar")  // 边框层，稍微放大以显示边框
                .resizable()
                .scaledToFit()
                .frame(width: 40 - 2, height: 40 - 2)
                .foregroundColor(.black)
//                .shadow(color: configuration.isPressed || !isEnabled ? Color.clear : Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
            profileImage  // 头像图像层
                .resizable()
                .scaledToFit()
                .frame(width: 40 - borderThickness - 2, height: 40 - borderThickness - 2 )
                .mask(
                    Image("icon-avatar")
                        .resizable()
                        .scaledToFit()
                )
        }
            .brightness(isEnabled && configuration.isPressed ? -0.2 : 0)
            .grayscale(isEnabled ? 0 : 1)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.95 : 1.0)
    }
}

struct AvatarStyle_l: ButtonStyle {

    var isEnabled: Bool
    var profileImage: Image
    var borderThickness: CGFloat

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
        ZStack(alignment: .center) {
            Image("icon-avatar")  // 边框层，稍微放大以显示边框
                .resizable()
                .scaledToFit()
                .frame(width: 54 - 2, height: 54 - 2)
                .foregroundColor(.black)
//                .shadow(color: configuration.isPressed || !isEnabled ? Color.clear : Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
            profileImage  // 头像图像层
                .resizable()
                .scaledToFit()
                .frame(width: 54 - borderThickness - 2, height: 54 - borderThickness - 2 )
                .mask(
                    Image("icon-avatar")
                        .resizable()
                        .scaledToFit()
                )
        }
            .brightness(isEnabled && configuration.isPressed ? -0.2 : 0)
            .grayscale(isEnabled ? 0 : 1)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SeeePositionStyle: ButtonStyle {

    var isEnabled: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
        ZStack(alignment: .center) {
            Image("icon-position")
                .frame(width: 24, height: 33)
//                .offset(CGSize(width: 0, height: 32.0))
                .offset(y: 32)
            Image("例子")
                .resizable()
                .scaledToFit()
                .clipShape(Circle())
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(Color.black, lineWidth: 4))
        }
        .frame(height: 82)
        .compositingGroup() // 将所有视图作为一个整体进行组合
        .offset(y: -7)
        .shadow(color: configuration.isPressed || !isEnabled ? Color.clear : Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
//        .border(Color.black)
        .brightness(isEnabled && configuration.isPressed ? -0.2 : 0)
        .grayscale(isEnabled ? 0 : 1)
        .scaleEffect(isEnabled && configuration.isPressed ? 0.95 : 1.0)
    }
}

struct IconStylePosition: ButtonStyle {

    @Binding var isAnimating: Bool
    let animationDuration: Double = 1 // 定义动画周期为1秒

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
        Image("icon-position")
            .frame(width: 24, height: 33)
            .shadow(color: Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
            .grayscale(isAnimating ? 0 : 1)
            .onAppear {
                withAnimation(Animation.linear(duration: animationDuration).repeatForever(autoreverses: true)) {
                    isAnimating = true // 开始动画
                }
            }
            .onDisappear {
                isAnimating = false // 停止动画
            }
    }
}




extension View {  //定义一个 View 扩展来实现单个角的圆角
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}
struct RoundedCorner: Shape {  //定义一个 View 扩展来实现单个角的圆角
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}


struct CombinedBackgroundAndBorder: View {  //解决白色背景按钮的内部投影问题
    var radius: CGFloat
    var corners: UIRectCorner
    var isEnabled: Bool
    var isPressed: Bool

    var body: some View {
        ZStack {
            // 先绘制背景形状并应用阴影
            RoundedCorner(radius: radius, corners: corners)
                .fill(Color("color-white"))
                .shadow(color: isPressed || !isEnabled ? Color.clear : Color("color-gray").opacity(1), radius: 0, x: 4, y: 6)

            // 在其上叠加一个仅有边框的形状
            RoundedCorner(radius: radius, corners: corners)
                .stroke(Color.black, lineWidth: 4)
        }
    }
}


#Preview {
    ButtonStyles()
}
