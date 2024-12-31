//
//  GlobalToastContainerView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/12/31.
//


import SwiftUI

/// 最顶层的 Toast 容器视图
struct GlobalToastContainerView: View {
    /// 从 Environment 拿到全局 toastManager
    @EnvironmentObject var toastManager: ToastManager
    
    var body: some View {
        ZStack(alignment: .top) {
            /// ForEach 全部要显示的 ToastItem
            VStack{
                ForEach(toastManager.toasts) { toast in
                    SingleToastView(item: toast)
                        // 你还可以在这里添加 offset/transition
                        .transition(.move(edge: .top))
                }
                Spacer()
            }
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)   // 允许手势
        .ignoresSafeArea()
    }
}
