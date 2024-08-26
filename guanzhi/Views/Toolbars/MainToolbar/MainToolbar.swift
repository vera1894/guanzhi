/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that displays controls to capture, switch cameras, and view the last captured media item.
*/

import SwiftUI
import PhotosUI

/// A view that displays controls to capture, switch cameras, and view the last captured media item. 一个视图，显示用于捕获、切换相机和查看最近捕获的媒体项的控件。
struct MainToolbar<CameraModel: Camera>: PlatformView {

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State var camera: CameraModel
    var cameraMainHeight: CGFloat = 180
    
    var body: some View {
        VStack {
            HStack {
                PhotosPreview(camera: camera)
                    .frame(height: 60)
//                    .background(Color.blue)
            }
            Spacer()
            HStack {
                ThumbnailButton(camera: camera)
                Spacer()
                
                if let selectedIndex = camera.selectedMedia.firstIndex(of: true) {
                    DeleteButton(camera: camera)
                } else {
                    CaptureButton(camera: camera)
                        .disabled(camera.capturedMedia.count>3)
    //                    .background(Color.red)  //height 68
                }
                
                Spacer()
                SwitchCameraButton(camera: camera) //修改并放置到上方
            }
            .padding(.bottom, 32)
        }
        .frame(height: cameraMainHeight)
        .frame(maxWidth: .infinity)
//        .background(Color.gray) //
        .foregroundColor(.white)
//        .font(.system(size: 24))
//        .padding([.leading, .trailing])
    }
    // 根据设备尺寸类别确定工具栏的宽度。
    var width: CGFloat? { isRegularSize ? 250 : nil }
    // 设置工具栏的固定高度。
    var height: CGFloat? { 80 }
}

#Preview {
    Group {
        MainToolbar(camera: PreviewCameraModel())
    }
}
