/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that presents a video preview of the captured content.
*/

import SwiftUI
@preconcurrency import AVFoundation

/// 一个视图，用于展示相机预览。
struct CameraPreview: UIViewRepresentable {
    
    private let source: PreviewSource
    
    /// 初始化方法，设置预览源。
    init(source: PreviewSource) {
        self.source = source
    }
    
    /// 创建并配置一个新的 `PreviewView` 实例。
    func makeUIView(context: Context) -> PreviewView {
        let preview = PreviewView()
        // Connect the preview layer to the capture session. 将预览层连接到捕获会话。
        source.connect(to: preview)
        return preview
    }
    
    /// 更新 `PreviewView`，在这里没有操作。
    func updateUIView(_ previewView: PreviewView, context: Context) {
        // No-op.
    }
    
    /// A class that presents the captured content. 一个类，用于展示捕获的内容。
    ///
    /// This class owns the `AVCaptureVideoPreviewLayer` that presents the captured content. 这个类拥有 `AVCaptureVideoPreviewLayer`，用于展示捕获的内容。
    ///
    class PreviewView: UIView, PreviewTarget {
        
        init() {
            super.init(frame: .zero)
    #if targetEnvironment(simulator)
            // The capture APIs require running on a real device. If running in Simulator, display a static image to represent the video feed. 捕获 API 需要在真实设备上运行。如果在模拟器中运行，显示一个静态图像以表示视频流。
            let imageView = UIImageView(frame: UIScreen.main.bounds)
            imageView.image = UIImage(named: "video_mode")
            imageView.contentMode = .scaleAspectFill
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(imageView)
    #endif
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        // Use the preview layer as the view's backing layer. 使用预览层作为视图的背景层。
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        /// 获取预览层。
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
        
        /// 设置捕获会话。
        nonisolated func setSession(_ session: AVCaptureSession) {
            // Connects the session with the preview layer, which allows the layer to provide a live view of the captured content. 将会话连接到预览层，允许该层提供捕获内容的实时视图。
            Task { @MainActor in
                previewLayer.session = session
            }
        }
    }
}

/// A protocol that enables a preview source to connect to a preview target. 一个协议，使预览源能够连接到预览目标。
///
/// The app provides an instance of this type to the client tier so it can connect the capture session to the `PreviewView` view. It uses these protocols to prevent explicitly exposing the capture objects to the UI layer. 应用程序向客户端提供此类型的实例，以便它可以将捕获会话连接到 `PreviewView` 视图。它使用这些协议来防止将捕获对象显式暴露给 UI 层。
///
protocol PreviewSource: Sendable {
    // Connects a preview destination to this source. 将预览目标连接到此源。
    func connect(to target: PreviewTarget)
}

/// A protocol that passes the app's capture session to the `CameraPreview` view. 一个协议，将应用程序的捕获会话传递给 `CameraPreview` 视图。
protocol PreviewTarget {
    // Sets the capture session on the destination. 在目标上设置捕获会话。
    func setSession(_ session: AVCaptureSession)
}

/// The app's default `PreviewSource` implementation. 应用程序的默认 `PreviewSource` 实现。
struct DefaultPreviewSource: PreviewSource {
    
    private let session: AVCaptureSession
    
    /// 初始化方法，设置捕获会话。
    init(session: AVCaptureSession) {
        self.session = session
    }
    
    /// 将捕获会话连接到预览目标。
    func connect(to target: PreviewTarget) {
        target.setSession(session)
    }
}


#Preview {
    CameraView(camera: PreviewCameraModel())
}
