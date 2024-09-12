//
//  DeleteButton.swift
//  AVCam
//
//  Created by 晨光 訾 on 2024/8/22.
//  Copyright © 2024 Apple. All rights reserved.
//

import SwiftUI

struct DeleteButton<CameraModel: Camera>: View {
    
    @State var camera: CameraModel
    private let mainButtonDimension: CGFloat = 68
    
    var body: some View {
        MediaDeleteButton{
            // 删除选中的媒体
            if let selectedIndex = camera.selectedMedia.firstIndex(of: true) {
                camera.capturedMedia.remove(at: selectedIndex)
                camera.livePhotoGroup.remove(at: selectedIndex)
                camera.selectedMedia[selectedIndex] = false
                
                // 如果有剩余的媒体，将其向前移动
                if selectedIndex < camera.capturedMedia.count {
                    camera.selectedMedia[selectedIndex] = true
                }
                
                if selectedIndex > 0 {
                    if selectedIndex == camera.capturedMedia.count {
                        camera.selectedMedia[selectedIndex-1] = true
                    }
                }
                
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
        .frame(width: mainButtonDimension)
    }
}

private struct MediaDeleteButton: View {
    private let action: () -> Void
    private let lineWidth = CGFloat(4.0)
    
    init(action: @escaping () -> Void) {
        self.action = action
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: lineWidth)
                .fill(.white)
            Button {
                action()
            } label: {
                ZStack {
                    Circle()
                        .inset(by: lineWidth * 1.2)
                        .fill(.red)
                    Image(systemName: "trash.fill")
                        .resizable()
                            .frame(width: 32, height: 40)
                }
                
            }
            .buttonStyle(PhotoButtonStyle())
        }
    }
    
    struct PhotoButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            // 当按钮被按下时，改变其缩放比例，并添加动画效果。
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

#Preview {
    DeleteButton(camera: PreviewCameraModel())
}
