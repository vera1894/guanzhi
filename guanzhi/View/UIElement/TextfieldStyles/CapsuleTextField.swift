//
//  CapsuleTextField.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/3/7.
//

import SwiftUI

struct CapsuleTextField: View {
    /// 占位符文本
    let placeholder: String
    /// 文本绑定，使外部可以控制和获取输入框内容
    @Binding var text: String
    /// 提交时的回调
    var onSubmit: () -> Void = {}
    /// 最大字符数
    var maxCharacters: Int = 24
    /// 是否显示右侧字符统计
    var showsCharacterCount: Bool = true
    /// 可选的绑定，用于传递当前输入字符数（外部可以直接读取）
    var characterCount: Binding<Int>? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // 用于点击空白处收起键盘
//            Color.clear
//                .contentShape(Rectangle())
//                .onTapGesture {
//                    isFocused = false
//                }
//                .edgesIgnoringSafeArea(.all)
            
            RoundedRectangle(cornerRadius: 20)
                .fill(.shadow(.inner(color: Color("color-primary").opacity(1), radius: 0, x: 4, y: 6)))
                .stroke(.black, lineWidth: 4)
                .foregroundStyle(Color("color-white").opacity(1))
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .overlay {
                    HStack {
                        TextField(placeholder, text: $text)
                            .font(.system(size: 18, weight: .regular))
                            .padding(.leading, 16)
                            .frame(height: 40)
                            .background(Color.clear)
                            .focused($isFocused)
                            .onChange(of: text) { newValue in
                                // 超出最大字符数时截断输入
                                if newValue.count > maxCharacters {
                                    text = String(newValue.prefix(maxCharacters))
                                    isFocused = false
                                }
                                // 更新外部绑定的字符计数（如果有传入的话）
                                characterCount?.wrappedValue = text.count
                            }
                            .onSubmit {
                                onSubmit()
                            }
                        
                        if showsCharacterCount {
                            Spacer()
                            Text("\(text.count)/\(maxCharacters)")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .padding(.trailing, 16)
                        }
                    }
                }
        }
    }
}

struct CapsuleTextField_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var text: String = ""
        @State private var currentCount: Int = 0
        
        var body: some View {
            VStack(spacing: 16) {
                CapsuleTextField(
                    placeholder: "🔍 想瞧瞧哪里？",
                    text: $text,
                    onSubmit: {
                        print("提交：\(text)")
                    },
                    maxCharacters: 24,
                    showsCharacterCount: true,
                    characterCount: $currentCount
                )
                Text("当前字符数：\(currentCount)")
            }
            .padding()
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}
