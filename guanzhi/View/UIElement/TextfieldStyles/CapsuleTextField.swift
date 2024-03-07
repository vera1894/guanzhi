//
//  CapsuleTextField.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/3/7.
//

import SwiftUI

struct CapsuleTextField: View {
    
    let placeholder = "🔍想瞧瞧哪里？" // "发表一个贴贴"
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        
        ZStack { //用于在最底层增加点击收起键盘
            Color.clear // 最底层放置的收起键盘透明背景
                .contentShape(Rectangle())
                .onTapGesture {
                    isFocused = false
                }
                .edgesIgnoringSafeArea(.all)
            
            RoundedRectangle(cornerRadius: 20)
                .fill(.shadow(.inner(color: Color("color-primary").opacity(1), radius: 0, x: 4, y: 6)))
                .stroke(.black, lineWidth: 4)
                .foregroundStyle(.white.opacity(1))
                .frame(height: 40)
                .frame(width: .infinity)
                .overlay {
                    TextField(placeholder, text: $text)
                        .font(.system(size: 18, weight: .regular, design: .default))
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .frame(width: .infinity)
                        .background(Color.gray.opacity(0))
                        .cornerRadius(20)
                        .multilineTextAlignment(.leading)
                        .focused($isFocused)
                        .onChange(of: text) { newValue in
                            // 确保输入不超过400位字符
                            if newValue.count >= 400 {
                                text = String(newValue.prefix(400))
                                isFocused = false
                            }
                        }
                        .onSubmit {
                            // 当用户按下键盘上的提交/完成按钮时执行的操作
                        }
                }
        }
    }
}

#Preview {
    CapsuleTextField()
}
