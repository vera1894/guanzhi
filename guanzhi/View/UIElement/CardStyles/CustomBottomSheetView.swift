//
//  BaseCardView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/5/16.
//

import SwiftUI

struct CustomBottomSheetView: View {
    
    let placeholder = "🔍想瞧瞧哪里？"
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    @State private var showBottomSheet: Bool = false
    @State private var detents: Set<PresentationDetent> = [.height(60), .medium, .large]
    
    
    var body: some View {
        ZStack {
            
            //内容区
            
            
        }
        .task {
            showBottomSheet = true  //显示底栏
        }
        .sheet(isPresented: $showBottomSheet) {  //底栏
            ScrollView(.vertical, content: {
                VStack(alignment: .leading, spacing: 15, content: {
//                    
                    HStack(spacing: 8) {
                        
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
                        
                        Button(action: {
                                    // 分享地点-胶囊按钮hug
                                }) {
                                    Text("📷 分享地点")
                                }
                                .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: true))
                     
                        
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .frame(width: .infinity, height: .infinity)
                    
                })
                .padding(.top, 20)
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .presentationDetents(detents)  // 动态调整高度
            .presentationCornerRadius(20)
            .presentationBackground(.regularMaterial)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))  //用于对下层的可操控
            .interactiveDismissDisabled()  //用于限制无法下滑关闭
        }
        
        
    }
}

#Preview {
    CustomBottomSheetView()
}


