//
//  test.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/1/31.
//

import SwiftUI

struct test: View {
    
    @State private var grayscale: Double = 0
    let animationDuration: Double = 1
    
    @State private var isLocated: Bool = true
    
    var body: some View {
                
        Text("")
        
        Button{
            //定位
        }label: { }
    .buttonStyle(IconStylePosition(isAnimating: $isLocated))
        
        
    }
}




struct IconStylePositionLoading: View {
    
    @Binding var isAnimating: Bool
    let animationDuration: Double = 1 // 定义动画周期为1秒
    
    var body: some View {
        Image("icon-position")
            .frame(width: 24, height: 33)
            .shadow(color: Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
            .grayscale(isAnimating ? 1 : 0)
            .onAppear {
                withAnimation(Animation.linear(duration: animationDuration).repeatForever(autoreverses: true)) {
                    isAnimating = true // 开始动画
                }
            }
            .onDisappear {
                isAnimating = false // 停止动画
            }
    }
}




#Preview {
    test()
}
