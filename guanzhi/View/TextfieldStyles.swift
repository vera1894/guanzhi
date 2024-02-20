//
//  TextfieldStyles.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/1/31.
//

import SwiftUI

struct TextfieldStyles: View {
    
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        
        
        TextField_capsuleFill(text: $text)
            .focused($isFocused)
        //                    .onTapGesture {  //用在页面中的其他地方，点击收起键盘
        //                        isFocused = false
        //                            }
        
        
        TextField("🔍想瞧瞧哪里？", text: $text)
                    .textFieldStyle(TextFieldStyle_capsuleFill())
                    .focused($isFocused)

                    
    }
}





struct TextField_capsuleFill: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("🔍想瞧瞧哪里？", text: $text)
            .focused($isFocused)
            .font(.system(size: 16, weight: .regular, design: .default))
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Color(.systemGray6)) // 设置背景颜色
            .cornerRadius(20) // 设置圆角
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 4)) // 设置边框
            .shadow(color: isFocused ? Color.clear : Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
            .frame(height: 40)
    }
}



struct TextFieldStyle_capsuleFill: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16, weight: .regular, design: .default))
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Color(.systemGray6)) // 设置背景颜色
            .cornerRadius(20) // 设置圆角
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 4)) // 设置边框
            .shadow(color: Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
            .frame(height: 40)
            .toolbar {  //键盘上方的小功能栏，收起键盘
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        UIApplication.shared.endEditing()
                    }
                }
            }
    }
}

extension UIApplication {  //收起键盘
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


#Preview {
    TextfieldStyles()
}
