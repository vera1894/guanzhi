/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that displays a thumbnail of the last captured media.
*/

import SwiftUI
import PhotosUI

/// 这个视图结构显示了最近捕获的媒体缩略图，并在点击时打开照片选择器，允许用户从照片库中选择图像。
/// A view that displays a thumbnail of the last captured media. 一个视图，显示最近捕获的媒体缩略图。
///
/// Tapping the view opens the Photos picker. 点击视图打开照片选择器。
struct ThumbnailButton<CameraModel: Camera>: View {
    
	@State var camera: CameraModel
    
    @State private var selectedItems: [PhotosPickerItem] = []
	
    var body: some View {
        // 使用 PhotosPicker 来创建一个选择器按钮。
        PhotosPicker( selection: $selectedItems, matching: .images, photoLibrary: .shared()) {
            Group {
                // 如果相机有缩略图，则显示缩略图图像。
                if let thumbnail = camera.thumbnail {
                    Image(thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .animation(.easeInOut(duration: 0.3), value: camera.thumbnail)
                } else {
                    // 如果没有缩略图，则显示默认图标。
                    Image(systemName: "photo.on.rectangle")
                }
            }
        }
		.frame(width: 64.0, height: 64.0)
		.cornerRadius(8)
        .disabled(camera.captureActivity.isRecording) // 如果相机正在录制，则禁用按钮。
    }
}

#if DEBUG
#Preview("Photo") {
    ThumbnailButton(camera: PreviewCameraModel(captureMode: .photo))
}
#endif
