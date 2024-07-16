//
//  RoundedRectangleTextField.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/3/7.
//

import SwiftUI

struct RoundedRectangleTextField: View {
    
    let placeholder = "填写求助信息"
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
                .frame(height: .infinity)
                .frame(width: .infinity)
                .overlay {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .font(.system(size: 18, weight: .regular, design: .default))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(minWidth: 100, maxWidth: .infinity, minHeight: 40, maxHeight: .infinity, alignment: .topLeading)
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
    RoundedRectangleTextField()
}
