/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that displays an appropriate capture button for the selected capture mode.
*/

import SwiftUI

/// A view that displays an appropriate capture button for the selected mode. 一个视图，根据选择的模式显示适当的捕获按钮。
@MainActor
struct CaptureButton<CameraModel: Camera, AppStateModel: AppState>: View {
    
    @State var camera: CameraModel
    @State var appState: AppStateModel
    private let mainButtonDimension: CGFloat = 68
    
    var body: some View {
        captureButton
            .aspectRatio(1.0, contentMode: .fit)
            .frame(width: mainButtonDimension)
    }
    
    @ViewBuilder
    var captureButton: some View {
        // 根据相机的捕获模式显示不同的捕获按钮。
        switch camera.captureMode {
        case .photo:
            PhotoCaptureButton {
                // 调用相机的拍照方法。
                Task {
                    await camera.capturePhoto(saveToLibrary: false)
                    appState.captureboxIsLoading = true
                }
            }
        case .video:
            MovieCaptureButton { _ in
                // 切换录制状态。
                Task {
                    await camera.toggleRecording()
                    appState.captureboxIsLoading = true
                }
            }
        }
    }
}

#Preview("Photo") {
    CaptureButton(camera: PreviewCameraModel(captureMode: .photo), appState: AppStateModel())
}

#Preview("Video") {
    CaptureButton(camera: PreviewCameraModel(captureMode: .video), appState: AppStateModel())
}

/// 拍照按钮的视图结构。
private struct PhotoCaptureButton: View {
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
                Circle()
                    .inset(by: lineWidth * 1.2)
                    .fill(.white)
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

/// 录像按钮的视图结构。
private struct MovieCaptureButton: View {
    
    private let action: (Bool) -> Void
    private let lineWidth = CGFloat(4.0)
    
    @State private var isRecording = false
    
    init(action: @escaping (Bool) -> Void) {
        self.action = action
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: lineWidth)
                .foregroundColor(Color.white)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isRecording.toggle()
                }
                action(isRecording)
            } label: {
                GeometryReader { geometry in
                    // 根据录制状态改变按钮的形状和尺寸。
                    RoundedRectangle(cornerRadius: geometry.size.width / (isRecording ? 4.0 : 2.0))
                        .inset(by: lineWidth * 1.2)
                        .fill(.red)
                        .scaleEffect(isRecording ? 0.6 : 1.0)
                }
            }
            .buttonStyle(NoFadeButtonStyle())
        }
    }
    
    struct NoFadeButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
        }
    }
}
