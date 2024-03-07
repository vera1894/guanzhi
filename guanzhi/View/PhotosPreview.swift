//
//  test.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/1/31.
//

import SwiftUI

struct PhotosPreview: View {
    
    @State private var selectedPhoto: String? = nil
    @State private var isSelected = [false, false, false, false] // 初始状态，所有按钮均未选中
    let photoNames = ["例子", "例子", "", ""] // 示例照片名称，空字符串表示没有照片
    @State private var buttonColors: [Color] = []
    init() {
        _buttonColors = State(initialValue: PhotoButton.availableColors.shuffled().prefix(4).map { $0 })
    }

    
    var body: some View {
                
        VStack {  //摄像控件
            VStack {
                    // 展示选中的照片
                    if let selectedPhoto = selectedPhoto, !selectedPhoto.isEmpty {
                        Image(selectedPhoto)
                            .resizable()
                            .frame(width: 100, height: 100)
                    }

                    HStack {
                        ForEach(0..<4, id: \.self) { index in
                                           PhotoButton(photoName: photoNames[index], isSelected: isSelected[index], action: {
                                               // 点击按钮时的操作
                                               isSelected = isSelected.indices.map { $0 == index }
                                               selectedPhoto = photoNames[index]
                                           }, backgroundColor: buttonColors[index]) // 使用指定颜色
                                       }
                    }

                    Button("清除选中") {
                        // 清除所有选中状态
                        for i in isSelected.indices {
                            isSelected[i] = false
                        }
                        selectedPhoto = nil
                    }
                }
                .padding()
            
        }
    }
}



struct PhotoButton: View {
    let photoName: String? // 可选的照片名称
    var isSelected: Bool // 是否选中
    let action: () -> Void
    var backgroundColor: Color // 这将是从外部传入的颜色

        // 定义一组可选颜色
        static let availableColors: [Color] = [.red, .green, .blue, .orange, .pink, .purple, .yellow]

    var body: some View {
        Button(action: action) {
            // 显示照片或默认颜色
            if let photoName = photoName, !photoName.isEmpty {
                Image(photoName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                backgroundColor // 使用自定义颜色或默认占位符
            }
        }
        .frame(width: 42, height: isSelected ? 42 : 32)
        .background(backgroundColor) // 设置背景颜色，也可根据需要调整
        .cornerRadius(10) // 设置圆角
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(style: isSelected ? StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [2, 10]) : StrokeStyle(lineWidth: 4))
                .foregroundColor(isSelected ? Color.white : Color.black) // 边框颜色
        )
        .disabled(photoName == nil || photoName!.isEmpty) // 如果没有照片，则禁用按钮
    }
    
}


#Preview {
    PhotosPreview()
}
