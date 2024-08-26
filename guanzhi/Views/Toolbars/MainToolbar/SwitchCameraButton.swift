/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that displays a button to switch between available cameras.
*/

import SwiftUI

/// A view that displays a button to switch between available cameras. 一个视图，显示一个按钮用于在可用的相机之间切换。
struct SwitchCameraButton<CameraModel: Camera>: View {
    
    @State var camera: CameraModel
    
    var body: some View {
        Button { // 创建一个按钮，当点击时切换相机。
            Task { // 异步任务，调用相机的切换视频设备方法。
                await camera.switchVideoDevices()
            }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
        }
        .buttonStyle(DefaultButtonStyle(size: .large))
        .frame(width: largeButtonSize.width, height: largeButtonSize.height)
        .disabled(camera.captureActivity.isRecording) // 如果相机正在录制，则禁用按钮。
        .allowsHitTesting(!camera.isSwitchingVideoDevices) // 如果相机正在切换视频设备，则禁用点击事件。
    }
}
