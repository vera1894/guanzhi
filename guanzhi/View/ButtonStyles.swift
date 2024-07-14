//
//  ButtonStyles.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/1/25.
//

import SwiftUI

struct ButtonStyles: View {
    
    @State private var isLocated: Bool = false //已经定位？
    @State private var isCaptureEnabled: Bool = true  //拍摄按钮可用？
    
    @State private var isFlashOn: Bool = false //camera闪光灯开启？
    @State private var isDateShow: Bool = false //camera日期显示？
    @State private var isBackCamera: Bool = false //camera使用后摄像头？
    
    @State private var isTieTieEnabled: Bool = true //贴贴可用？
    @State private var isNextEnabled: Bool = true //下一步可用？
    
    
    
    
    
    var body: some View {
        
        HStack {
            Button{
                //定位图标
            }label: { }
        .buttonStyle(IconStylePosition(isAnimating: $isLocated))
            
            Button{
                //Seee位置，需要添加是否已经定位的状态 isLocated
            }label: { }
        .buttonStyle(SeeePositionStyle(isEnabled: true))
            
            Button{
                //播放按钮
            }label: {
                Image("icon-play")
            }
            .buttonStyle(ButtonStyle_play())
            
            Button{
                //闪光灯按钮
            }label: {
                Image("iconCamera-capture")
            }
            .buttonStyle(ButtonStyle_CameraCapture(isEnabled: isCaptureEnabled))
            
        }
        
        HStack(alignment: .top) {
            Button(action: {
                // 头像-s
            }) { }
            .buttonStyle(AvatarStyle_s(isEnabled: true, profileImage: Image("例子"), borderThickness: 4))
            
            Button(action: {
                // 头像-m
            }) { }
            .buttonStyle(AvatarStyle_m(isEnabled: true, profileImage: Image("例子"), borderThickness: 4))
            
            Button(action: {
                // 头像-l
            }) { }
            .buttonStyle(AvatarStyle_l(isEnabled: true, profileImage: Image("例子"), borderThickness: 4))
        }
        
        HStack(alignment: .top) {
            
            Button{
                //返回按钮-圆形
            }label: {
                Image("icon-back")
            }
            .buttonStyle(ButtonStyle_m())
            
            Button{
                //关闭按钮-圆形
            }label: {
                Image("icon-close")
            }
            .buttonStyle(ButtonStyle_m())
            
            Button{
                //定位按钮-圆形
            }label: {
                Image("icon-location")
            }
            .buttonStyle(ButtonStyle_m())
            
            Button{
                //更多按钮-圆形
            }label: {
                Image("icon-more")
            }
            .buttonStyle(ButtonStyle_m())
            
            Button{
                //设置按钮-圆形
            }label: {
                Image("icon-setting")
            }
            .buttonStyle(ButtonStyle_m())
            
            Button{
                //提醒按钮-圆形
            }label: {
                Image("icon-notification")
            }
            .buttonStyle(ButtonStyle_m())
            
        }
        
        HStack {  //摄像控件
            
            Button{
                //闪光灯按钮
                isFlashOn.toggle()
            }label: {
                Image(isFlashOn ? "iconCamera-flashOn" : "iconCamera-flashOff")
            }
        .buttonStyle(ButtonStyle_CameraControl())
            
            Button{
                //时间显示按钮
                isDateShow.toggle()
            }label: {
                Image(isDateShow ? "iconCamera-dateShow" : "iconCamera-dateHide")
            }
            .buttonStyle(ButtonStyle_CameraControl())
            
            Button{
                //切换摄像头按钮
                isBackCamera.toggle()
            }label: {
                Image("iconCamera-switchCamera")
            }
            .buttonStyle(ButtonStyle_CameraControl())
            
        }
        
        
        VStack(spacing: 10) {
            Button(action: {
                        // 查看路线-胶囊按钮s
                    }) {
                        Text("🧭 查看路线")
                    }
                    .buttonStyle(ButtonStyle_capsuleHugPrimary_s(isEnabled: true))
            
            Button(action: {
                        // 分享地点-胶囊按钮hug
                    }) {
                        Text("📷 分享地点")
                    }
                    .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: true))
            
            HStack {
                Button(action: {
                            // 贴贴--胶囊按钮hug
                        }) {
                            Text("🫂 贴贴")
                        }
                    .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: isTieTieEnabled))
                
                Button(action: {
                            // 贴贴（禁用）-胶囊按钮hug
                        }) {
                            Text("🫂 贴贴")
                        }
                        .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: false))
            }
            
            HStack {
                Button(action: {
                            // 下一步-胶囊按钮hug
                        }) {
                            Text("🔜 下一步")
                        }
                    .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: isNextEnabled))
                
                Button(action: {
                            // 下一步（禁用）-胶囊按钮hug
                        }) {
                            Text("🔜 下一步")
                        }
                        .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: false))
            }
            
            VStack {
                
                Button(action: {
                            // 发布-胶囊按钮fill
                        }) {
                            Text("✅ 发布")
                        }
                    .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: true))
                
                Button(action: {
                            // 求助（紫色）-胶囊按钮fill
                        }) {
                            Text("🥺 求一下这里最新的照片或视频")
                        }
                    .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
                
                Button(action: {
                            // 查看求助（紫色）-胶囊按钮fill
                        }) {
                            Text("🥺 查看求助信息")
                        }
                    .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
                
                Button(action: {
                            // 帮他（紫色）-胶囊按钮fill
                        }) {
                            Text("📷 帮助ta了解这里的情况")
                        }
                    .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
                
                Button(action: {
                            // 去查看求助（紫色）-胶囊按钮fill
                        }) {
                            Text("🥺 去查看")
                        }
                    .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
                
                Button(action: {
                            // 查看路线（紫色）-胶囊按钮fill
                        }) {
                            Text("🧭 查看路线")
                        }
                    .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
                
            }
            
            VStack {  //注册登录页面
                
                HStack {
                    Button(action: {
                                // 返回（白色）-胶囊按钮hug
                            }) {
                                Text("🔙️ 返回")
                            }
                        .buttonStyle(ButtonStyle_capsuleHugLeft(isEnabled: true))
                    
                    Button(action: {
                                // 下一步-胶囊按钮fill
                            }) {
                                Text("🔜 下一步")
                            }
                        .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: isNextEnabled))
                }
                
                HStack {
                    Button(action: {
                                // 返回（白色）-胶囊按钮hug
                            }) {
                                Text("🔙️ 返回")
                            }
                        .buttonStyle(ButtonStyle_capsuleHugLeft(isEnabled: true))
                    
                    Button(action: {
                                // 下一步（禁用）-胶囊按钮fill
                            }) {
                                Text("🔜 下一步")
                            }
                        .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: false))
                }
                
                HStack {
                    Button(action: {
                                // 返回（白色）-胶囊按钮hug
                            }) {
                                Text("🔙️ 返回")
                            }
                        .buttonStyle(ButtonStyle_capsuleHugLeft(isEnabled: true))
                    
                    Button(action: {
                                // 完成-胶囊按钮fill
                            }) {
                                Text("✅ 完成")
                            }
                        .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: true))
                }
            }  //注册登录页面
            
        }
        
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
            .frame(height: 40, alignment: .center)
            .background(
                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft])
                    .fill(Color("color-primary"))
            )
            .overlay(
                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft])
                    .stroke(Color.black, lineWidth: 4)
            )
            .compositingGroup()
            .shadow(color: configuration.isPressed || !isEnabled ? Color.clear : Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
            .brightness(isEnabled && configuration.isPressed ? -0.2 : 0)
            .grayscale(isEnabled ? 0 : 1)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ButtonStyle_capsuleHugPrimary_s: ButtonStyle {
    
    var isEnabled: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(Color("text-black"))
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .frame(height: 24, alignment: .center)
            .background(
                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                    .fill(Color("color-primary"))
            )
            .overlay(
                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                    .stroke(Color.black, lineWidth: 2)
            )
            .compositingGroup()
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
                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomRight])
                    .fill(Color("color-white"))
            )
            .overlay(
                RoundedCorner(radius: 20, corners: [.topLeft, .topRight, .bottomRight])
                    .stroke(Color.black, lineWidth: 4)
            )
            .compositingGroup()
            .shadow(color: configuration.isPressed || !isEnabled ? Color.clear : Color("color-gray").opacity(1), radius: 0, x: 2, y: 4)
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
            .compositingGroup()
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
            .compositingGroup()
            .shadow(color: configuration.isPressed || !isEnabled ? Color.clear : Color("color-secondary").opacity(1), radius: 0, x: 2, y: 4)
            .brightness(isEnabled && configuration.isPressed ? -0.2 : 0)
            .grayscale(isEnabled ? 0 : 1)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ButtonStyle_play: ButtonStyle {

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: 40, height: 40)
            .shadow(color: configuration.isPressed ? Color.clear : Color("color-primary"), radius: 0, x: 2, y:4)
            .brightness(configuration.isPressed ? -0.2 : 0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
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
                .scaledToFill()
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
    let animationDuration: Double = 0.8 // 定义动画周期为1秒

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

struct ButtonStyle_CameraControl: ButtonStyle {

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: 32, height: 32)
//            .shadow(color: configuration.isPressed ? Color.clear : Color("color-primary"), radius: 0, x: 2, y:4)
            .brightness(configuration.isPressed ? -0.2 : 0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ButtonStyle_CameraCapture: ButtonStyle {

    var isEnabled: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
        .frame(width: 80, height: 80)
        .brightness(isEnabled && configuration.isPressed ? -0.2 : 0)
        .grayscale(isEnabled ? 0 : 1)
        .scaleEffect(isEnabled && configuration.isPressed ? 0.95 : 1.0)
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


struct CombinedBackgroundAndBorder_white: View {  //解决白色背景按钮的内部投影问题 未使用
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
