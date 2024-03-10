//
//  SwiftUIView.swift
//  guanzhi
//  轮播图
//  Created by Vera on 2024/3/10.
//

import SwiftUI

struct CarouselView: View {
    let images = ["Rectangle 70", "IMG-2", "IMG-1"] // 图片名称数组

    var body: some View {
        TabView {
            ForEach(images, id: \.self) { imageName in
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .tabViewStyle(PageTabViewStyle()) // 设置页面样式为轮播
        .frame(height: 334) // 设置轮播视图的高度
    }
}

#Preview {
    CarouselView()
}
