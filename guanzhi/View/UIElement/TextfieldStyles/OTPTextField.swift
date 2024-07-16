//
//  OTPTextField.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/3/6.
//

import SwiftUI

struct OTPTextField: View {
    
    @State private var text: String = ""
    
    let numberOfFields: Int
    
    @State var enterValue: [String]
    @FocusState private var fieldFocus: Int?
    @State private var oldValue = ""
    
    init(numberOfFields: Int) {
        self.numberOfFields = numberOfFields
        self.enterValue = Array(repeating: "", count: numberOfFields)
    }
    
    var body: some View {
        
        ZStack { //用于在最底层增加点击收起键盘
            Color.clear // 最底层放置的收起键盘透明背景
                .contentShape(Rectangle())
                .onTapGesture {
                    fieldFocus = nil
                }
                .edgesIgnoringSafeArea(.all)
            
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
                            .onChange(of: enterValue[index]) { newValue in
                                if enterValue[index].count > 1 {
                                    let currentValue = Array(enterValue[index])
                                    
                                    if currentValue[0] == Character(oldValue) {
                                        enterValue[index] = String(enterValue[index].suffix(1))
                                    } else {
                                        enterValue[index] = String(enterValue[index].prefix(1))
                                    }
                                }
                                
                                if !newValue.isEmpty {
                                    if index == numberOfFields - 1 {
                                        fieldFocus = nil
                                    } else {
                                        fieldFocus = (fieldFocus ?? 0) + 1
                                    }
                                } else {
                                    fieldFocus = (fieldFocus ?? 0) - 1
                                }
                            }
                            .onAppear { // 用于确保应用启动时文本字段获得焦点
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    fieldFocus = 0
                                }
                            }
                            
                        }
                    
                    
                    
                }
            }
            
        }
    }
}

#Preview {
    OTPTextField(numberOfFields: 4)
}
