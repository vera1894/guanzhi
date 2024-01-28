//
//  ButtonStyles.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/1/25.
//

import SwiftUI

struct ButtonStyles: View {
    var body: some View {
        HStack {
            Button{
                //返回按钮
            }label: {
                Image("icon-back")
            }
            .buttonStyle(ButtonStyle_s())
            
            Button{
                //返回按钮
            }label: {
                Image("icon-close")
            }
            .buttonStyle(ButtonStyle_s())
            
            Button{
                //返回按钮
            }label: {
                Image("icon-location")
            }
            .buttonStyle(ButtonStyle_s())
            
            Button{
                //返回按钮
            }label: {
                Image("icon-more")
            }
            .buttonStyle(ButtonStyle_s())
            
            Button{
                //返回按钮
            }label: {
                Image("icon-setting")
            }
            .buttonStyle(ButtonStyle_s())
            
            Button{
                //返回按钮
            }label: {
                Image("icon-notification")
            }
            .buttonStyle(ButtonStyle_s())
            
        }
        
        
        VStack {
            Button(action: {
                        // 分享地点
                    }) {
                        Text("📷 分享地点")
                    }
                .buttonStyle(ButtonStyle_capsuleAutoPrimary())
            
            
        }
        
    }
}

struct ButtonStyle_s: ButtonStyle {

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: 32, height: 32)
            .shadow(color: configuration.isPressed ? Color.clear : Color("color-primary"), radius: 0, x: 2, y:4)
            .brightness(configuration.isPressed ? -0.2 : 0)
    }
}

struct ButtonStyle_capsuleAutoPrimary: ButtonStyle {
//    var foregroundColor: Color
//    var backgroundColor: Color
//    var borderColor: Color
//    var borderWidth: CGFloat

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
            .shadow(color: configuration.isPressed ? Color.clear : Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
            .brightness(configuration.isPressed ? -0.2 : 0)
//            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
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



#Preview {
    ButtonStyles()
}
