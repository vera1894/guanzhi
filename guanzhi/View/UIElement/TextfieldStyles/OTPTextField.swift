//
//  OTPTextField.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/3/6.
//

import SwiftUI

struct OTPTextField: View {
    
//    @State private var text: String = ""
    
    let numberOfFields: Int
    
    @State var enterValue: [String]
    @FocusState private var fieldFocus: Int?
    @State private var oldValue = ""
    @Binding var enterSMSCode: String
    @Binding var isComplete: Bool // 新增状态变量绑定
    
    init(numberOfFields: Int, enterSMSCode: Binding<String>, isComplete: Binding<Bool>) {
        self.numberOfFields = numberOfFields
        self._enterSMSCode = enterSMSCode
        self._isComplete = isComplete
        self.enterValue = Array(repeating: "", count: numberOfFields)
    }
    
    var body: some View {
        
//        ZStack { //用于在最底层增加点击收起键盘
//            Color.clear // 最底层放置的收起键盘透明背景
//                .contentShape(Rectangle())
//                .onTapGesture {
//                    fieldFocus = nil
//                }
//                .edgesIgnoringSafeArea(.all)
            
            HStack {
                ForEach(0..<numberOfFields, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.shadow(.inner(color: Color("color-primary").opacity(1), radius: 0, x: 4, y: 6)))
                        .stroke(.black, lineWidth: 4)
                        .foregroundStyle(.white.opacity(1))
                        .frame(width: 54, height: 54)
                        .overlay {
                            TextField("", text: $enterValue[index], onEditingChanged: {editing in
                                if editing {
                                    oldValue = enterValue[index]
                                }
                            })
                            .keyboardType(.numberPad)
                            .font(.system(size: 20).bold())
                            .frame(width: 54, height: 54)
                            .background(Color.gray.opacity(0))
                            .cornerRadius(20)
                            .multilineTextAlignment(.center)
                            .focused($fieldFocus, equals: index)
                            .tag(index)
                            .onChange(of: enterValue[index]) {
                                // Check if the new value is more than one character
                                if enterValue[index].count > 1 {
                                    let currentValue = Array(enterValue[index])
                                    
                                    // If more than one character is entered, distribute the characters across the text fields
                                    for i in 0..<min(currentValue.count, numberOfFields - index) {
                                        enterValue[index + i] = String(currentValue[i])
                                    }
                                    
                                    // Move focus to the next field
                                    if index + currentValue.count < numberOfFields {
                                        fieldFocus = index + currentValue.count
                                    } else {
                                        fieldFocus = nil
                                    }
                                } else if !enterValue[index].isEmpty {
                                    // Move to the next field if not empty
                                    if index < numberOfFields - 1 {
                                        fieldFocus = index + 1
                                    } else {
                                        fieldFocus = nil
                                    }
                                } else {
                                    // Move to the previous field if empty
                                    if index > 0 {
                                        fieldFocus = index - 1
                                    }
                                }
                                
                                //将数组转为字符串
                                enterSMSCode = enterValue.joined()
                                
                            }
                            .onAppear { // 用于确保应用启动时文本字段获得焦点
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    fieldFocus = 0
                                }
                            }
                            
                        }
                }
            }
            .onChange(of: enterValue) {
                        // Check if all fields are filled
                        isComplete = enterValue.allSatisfy { !$0.isEmpty }
                    }
            
//        }
    }
}

#Preview {
    OTPTextField(numberOfFields: 4, enterSMSCode: .constant(""), isComplete: .constant(false))
}
