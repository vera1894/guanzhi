/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that presents a status message over the camera user interface.
*/

import SwiftUI

/// A view that presents a status message over the camera user interface. 一个视图，用于在相机用户界面上显示状态消息。
struct StatusOverlayView: View {
	
    // 当前相机的状态。
	let status: CameraStatus
    // 需要处理的相机状态列表。
    let handled: [CameraStatus] = [.unauthorized, .failed, .interrupted]
    
	var body: some View {
        // 如果当前相机状态在 handled 列表中，则显示叠加视图。
		if handled.contains(status) {
			// Dimming view. 变暗的背景视图。
			Rectangle()
				.fill(Color(white: 0.0, opacity: 0.5))
			// Status message. 状态消息文本。
			Text(message)
				.font(.headline)
                .foregroundColor(color == .yellow ? .init(white: 0.25) : .white)
				.padding()
				.background(color)
				.cornerRadius(8.0)
                .frame(maxWidth: 600)
		}
	}
	
    // 根据相机状态返回相应的背景颜色。
	var color: Color {
		switch status {
		case .unauthorized:
			return .red
		case .failed:
			return .orange
		case .interrupted:
			return .yellow
		default:
			return .clear
		}
	}
	
    // 根据相机状态返回相应的状态消息。
	var message: String {
		switch status {
		case .unauthorized:
			return "You haven't authorized AVCam to use the camera or microphone. Change these settings in Settings -> Privacy & Security"
		case .interrupted:
			return "The camera was interrupted by higher-priority media processing."
		case .failed:
			return "The camera failed to start. Please try relaunching the app."
		default:
			return ""
		}
	}
}

#if DEBUG
#Preview("Interrupted") {
    // 创建状态为 .interrupted 未授权 的 CameraView 预览。
    CameraView(camera: PreviewCameraModel(status: .interrupted), appState: AppStateModel())
}

#Preview("Failed") {
    // 创建状态为 .failed 失败 的 CameraView 预览。
    CameraView(camera: PreviewCameraModel(status: .failed), appState: AppStateModel())
}

#Preview("Unauthorized") {
    // 创建状态为 .unauthorized 中断 的 CameraView 预览。
    CameraView(camera: PreviewCameraModel(status: .unauthorized), appState: AppStateModel())
}
#endif
