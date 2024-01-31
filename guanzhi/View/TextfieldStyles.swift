//
//  TextfieldStyles.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/1/31.
//

import SwiftUI

struct TextfieldStyles: View {
    
    @State private var text: String = ""
    
    var body: some View {
        TextField("🔍想瞧瞧哪里？", text: $text)
                    .textFieldStyle(TextFieldStyle_capsuleFill())
        
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        
        Button(action: {
                    // 查看路线
                }) {
                    Text("🧭 查看路线")
                }
                .buttonStyle(TextfieldFill(isEnabled: true))
    }
}


struct TextFieldStyle_capsuleFill: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(10) // 设置内边距
            .background(Color(.systemGray6)) // 设置背景颜色
            .cornerRadius(8) // 设置圆角
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1)) // 设置边框
    }
}


struct TextfieldFill: ButtonStyle {

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
                    .fill(Color("color-white"))
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

#Preview {
    TextfieldStyles()
}
