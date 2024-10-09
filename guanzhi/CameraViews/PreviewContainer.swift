/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that provides a container view around the camera preview.
*/

import SwiftUI

// Portrait-orientation aspect ratios. 纵向方向的宽高比类型别名。
typealias AspectRatio = CGSize
// 照片模式的宽高比。
let photoAspectRatio = AspectRatio(width: 3.0, height: 4.0)
// 视频模式的宽高比。
let movieAspectRatio = AspectRatio(width: 9.0, height: 16.0)

/// A view that provides a container view around the camera preview. 提供相机预览周围的容器视图。
///
/// This view applies transition effects when changing capture modes or switching devices. 该视图在切换捕获模式或切换设备时应用过渡效果。
/// On a compact device size, the app also uses this view to offset the vertical position of the camera preview to better fit the UI when in photo capture mode. 在紧凑设备尺寸上，当处于照片捕获模式时，应用程序还使用此视图偏移相机预览的垂直位置，以更好地适应用户界面。
@MainActor
struct PreviewContainer<Content: View, CameraModel: Camera>: View {
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State var camera: CameraModel
    
    // State values for transition effects. 过渡效果的状态值。
    @State private var blurRadius = CGFloat.zero
    
    // When running in photo capture mode on a compact device size, move the preview area update by the offset amount so that it's better centered between the top and bottom bars. 在紧凑设备尺寸上，当处于照片捕获模式时，将预览区域向上移动指定的偏移量，以便在顶部和底部栏之间更好地居中。
    private let photoModeOffset = CGFloat(-44)
    private let content: Content
    
    /// 初始化方法，设置相机和内容。
    init(camera: CameraModel, @ViewBuilder content: () -> Content) {
        self.camera = camera
        self.content = content()
    }
    
    var body: some View {
        // On compact devices, show a view finder rectangle around the video preview bounds. 在紧凑设备上，在视频预览边界周围显示取景器矩形。
        if horizontalSizeClass == .compact {
            ZStack {
                previewView
            }
            .clipped()
            // Apply an appropriate aspect ratio based on the selected capture mode. 根据选定的捕获模式应用适当的宽高比。
            .aspectRatio(aspectRatio, contentMode: .fit)
            // In photo mode, adjust the vertical offset of the preview area to better fit the UI. 在照片模式下，调整预览区域的垂直偏移以更好地适应用户界面。
//            .offset(y: camera.captureMode == .photo ? photoModeOffset : 0)
        } else {
            // On regular-sized UIs, show the content in full screen. 在常规大小的用户界面上，全屏显示内容。
            previewView
        }
    }
    
    /// Attach animations to the camera preview. 为相机预览附加动画效果。
    var previewView: some View {
        content
            .blur(radius: blurRadius, opaque: true)
        // 监听捕获模式切换时的变化，并更新模糊半径。
            .onChange(of: camera.isSwitchingModes, updateBlurRadius(_:_:))
        // 监听视频设备切换时的变化，并更新模糊半径。
            .onChange(of: camera.isSwitchingVideoDevices, updateBlurRadius(_:_:))
    }
    
    /// 更新模糊半径。
    func updateBlurRadius(_: Bool, _ isSwitching: Bool) {
        withAnimation {
            blurRadius = isSwitching ? 30 : 0
        }
    }
    
    /// 根据捕获模式返回相应的宽高比。
    var aspectRatio: AspectRatio {
        camera.captureMode == .photo ? photoAspectRatio : movieAspectRatio
    }
}
