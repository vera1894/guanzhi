//
//  PhoneNumberTextField.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/3/7.
//

import SwiftUI

struct PhoneNumberTextField: View {
    @State private var phoneNumber: String = ""
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
                .frame(height: 54)
                .frame(width: .infinity)
                .overlay {
                    TextField("输入手机号", text: $phoneNumber)
                        .font(.system(size: 20).bold())
                        .keyboardType(.numberPad)
                        .frame(height: 54)
                        .frame(width: .infinity)
                        .background(Color.gray.opacity(0))
                        .cornerRadius(20)
                        .multilineTextAlignment(.center)
                        .focused($isFocused)
                        .onChange(of: phoneNumber) { newValue in
                            // 确保输入不超过11位数字
                            if newValue.count >= 11 {
                                phoneNumber = String(newValue.prefix(11))
                                isFocused = false
                            }
                        }
                        .onSubmit {
                            // 当用户按下键盘上的提交/完成按钮时执行的操作
                        }
                        .onAppear { // 用于确保应用启动时文本字段获得焦点
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isFocused = true
                            }
                        }
                }
        }
    }
}


#Preview {
    PhoneNumberTextField()
}
