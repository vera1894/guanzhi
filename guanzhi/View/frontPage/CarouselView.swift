//
//  CarouselView.swift
//  guanzhi
//  轮播图
//  Created by Vera on 2024/3/10.
//

import SwiftUI

struct CarouselView: View {
    let images = ["Rectangle 70","测试长图", "IMG-2", "IMG-1"] // 图片名称数组

    var body: some View {
        GeometryReader { geometry in
//            Rectangle()
//                .foregroundStyle(Color.red)
//                .frame(width: geometry.size.width, height: geometry.size.height)

                TabView {
                    ForEach(images, id: \.self) { imageName in
                        Image(imageName)
                            .resizable()
                            .scaledToFit() // 使用 scaledToFill 以确保图片填充屏幕
                            .frame(width: geometry.size.width, height: geometry.size.height)
//                                .clipped() // 裁剪超出屏幕的部分
                            .edgesIgnoringSafeArea(.all)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
//                .ignoresSafeArea(.all) // 忽略所有安全区域
                .frame(width: geometry.size.width, height: geometry.size.height)
                
            }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    CarouselView()
}
