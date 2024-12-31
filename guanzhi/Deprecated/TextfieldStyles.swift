//
//  TextfieldStyles.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/1/31.
//

import SwiftUI
import UIKit


struct TextfieldStyles: View {
    
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    @State private var variableValue: Double = 0.0
    @State private var phoneNumber: String = ""
    
    var body: some View {
        
        
        ZStack { //用于在最底层增加点击收起键盘
            
            Color.clear // 最底层放置的收起键盘透明背景
                .contentShape(Rectangle())
                .onTapGesture {
                    // 点击背景时收起键盘
                    UIApplication.shared.endEditing()
                }
                .edgesIgnoringSafeArea(.all)
            
            
            
            VStack {
                
                TextField("🔍想瞧瞧哪里？", text: $text) //弹性文字输入框
                            .textFieldStyle(TextFieldStyle_capsuleFill())
                            .focused($isFocused)
                
                PhoneNumberField(text: $phoneNumber) //手机号输入框
                    .frame(height: 54)
                
                
            RoundedRectangle(cornerRadius: 20)
                .fill(.shadow(.inner(color: Color("color-primary").opacity(1), radius: 0, x: 4, y: 6)))
                .stroke(.black, lineWidth: 4)
                .foregroundStyle(.white.opacity(1))
                .frame(width: 54, height: 54)
                .overlay {
                    TextField("", text: $text)
                        .keyboardType(.numberPad)
                        .frame(width: 54, height: 54)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(20)
                }
                
            Image(systemName: "timelapse", variableValue: variableValue)
                .resizable()
                .scaledToFill()
                .background(Color("color-primary"))
                .clipShape(Circle())
                .symbolEffect(.variableColor.iterative.dimInactiveLayers.reversing)
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(Color.black, lineWidth: 4))
                .onAppear {
                    withAnimation(
                        Animation.linear(duration: 5.0)
                            .repeatForever(autoreverses: true)
                    ) {
                        self.variableValue = 1.0
                    }
                }
//                .symbolEffect(.variableColor.iterative.dimInactiveLayers.reversing, options: .repeat(.continuous))
                
                    
            }
            .onAppear { // 用于确保应用启动时文本字段获得焦点（可选）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            
        }
    }
}



struct TextFieldStyle_capsuleFill: TextFieldStyle { //弹性文字输入框样式
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
    }
}

struct PhoneNumberField: UIViewRepresentable { //手机号输入框
    @Binding var text: String
    var onCommit: () -> Void = {}
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = .numberPad
        textField.delegate = context.coordinator
        textField.placeholder = "输入手机号"// 设置placeholder
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        
        // 应用样式
        textField.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        textField.layer.cornerRadius = 20
        textField.backgroundColor = UIColor.white
        textField.layer.borderWidth = 4
        textField.layer.borderColor = UIColor.black.cgColor
        textField.layer.shadowColor = UIColor(named: "color-primary")?.cgColor
        textField.layer.shadowOpacity = 1
        textField.layer.shadowRadius = 0
        textField.layer.shadowOffset = CGSize(width: 2, height: 4)
        textField.textAlignment = .center
        textField.contentVerticalAlignment = .center
        textField.text = text // 初始化文本
        
        // 设置内边距
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: textField.frame.height))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        textField.rightView = paddingView
        textField.rightViewMode = .always
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PhoneNumberField
        
        init(_ numericTextField:                 PhoneNumberField) {
            self.parent = numericTextField
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            parent.onCommit()
            return true
        }
        
        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let isNumber = string.isEmpty || (string.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil)
            let newLength = (textField.text?.count ?? 0) + string.count - range.length
            return isNumber && newLength <= 11
        }
    }
}


#Preview {
    TextfieldStyles()
}
