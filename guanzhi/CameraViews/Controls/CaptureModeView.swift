/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that toggles the camera's capture mode.
*/

import SwiftUI

/// A view that toggles the camera's capture mode. 一个视图，用于切换相机的捕获模式。
struct CaptureModeView<CameraModel: Camera>: View {
    
    @State var camera: CameraModel
    @Binding private var direction: SwipeDirection
    
    /// 初始化方法，设置相机和滑动方向绑定。
    init(camera: CameraModel, direction: Binding<SwipeDirection>) {
        self.camera = camera
        _direction = direction
    }
    
    var body: some View {
        Picker("Capture Mode", selection: $camera.captureMode) {
            // 为每种捕获模式创建一个选项。
            ForEach(CaptureMode.allCases) {
                Image(systemName: $0.systemName)
                    .tag($0.rawValue)
            }
        }
        .frame(width: 180)
        .pickerStyle(.segmented) // 使用分段选择器样式。
        .disabled(camera.captureActivity.isRecording) // 如果相机正在录制，则禁用选择器。
        .onChange(of: direction) { _, _ in
            // 当滑动方向发生变化时，更新捕获模式。
            let modes = CaptureMode.allCases
            let selectedIndex = modes.firstIndex(of: camera.captureMode) ?? -1
            // Increment the selected index when swiping right. 向右滑动时增加选定索引。
            let increment = direction == .right
            let newIndex = selectedIndex + (increment ? 1 : -1)
            
            // 确保新索引在有效范围内。
            guard newIndex >= 0, newIndex < modes.count else { return }
            camera.captureMode = modes[newIndex]
        }
    }
}

#if DEBUG
#Preview {
    CaptureModeView(camera: PreviewCameraModel(), direction: .constant(.left))
}
#endif
