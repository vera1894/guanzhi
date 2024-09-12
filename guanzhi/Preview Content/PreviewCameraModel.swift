/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A Camera implementation to use when working with SwiftUI previews.
*/

import Foundation
import SwiftUI
import Photos


/// 该类主要用于模拟相机的行为，便于在 SwiftUI 预览中测试相机相关的功能，而不需要实际连接到物理设备。通过使用存根和模拟延迟，可以在开发和测试阶段更方便地进行 UI 调试和功能验证。
// 定义一个可观察的类，用于预览相机模型。
@Observable
class PreviewCameraModel: Camera {

    // 定义一些相机的属性
    var shouldFlashScreen = false
    var isHDRVideoSupported = false
    var isHDRVideoEnabled = false
    
    // 定义一个用于预览的源的存根结构，用于测试目的。
    struct PreviewSourceStub: PreviewSource {
        // Stubbed out for test purposes. 连接到目标的存根方法，不执行任何操作。
        func connect(to target: PreviewTarget) {}
    }
    
    // 使用预览源的存根实例。
    let previewSource: PreviewSource = PreviewSourceStub()
    
    // 定义相机的状态和活动属性。
    private(set) var status = CameraStatus.unknown
    private(set) var captureActivity = CaptureActivity.idle
    var captureMode = CaptureMode.photo {
        didSet {
            // 模拟模式切换的延迟。
            isSwitchingModes = true
            Task {
                // Create a short delay to mimic the time it takes to reconfigure the session. 创建一个短暂的延迟以模拟重新配置会话所需的时间。
                try? await Task.sleep(until: .now + .seconds(0.3), clock: .continuous)
                self.isSwitchingModes = false
            }
        }
    }
    private(set) var isSwitchingModes = false
    private(set) var isVideoDeviceSwitchable = true
    private(set) var isSwitchingVideoDevices = false
    private(set) var photoFeatures = PhotoFeatures()
    private(set) var thumbnail: CGImage?
//    public var mediasGroup: [MediaItemProtocol] = [] //
//    private(set) var _capturedMedia: [MediaItemProtocol] = []
    
    private var _capturedMedia: [MediaItemProtocol] = []
    var capturedMedia: [MediaItemProtocol] {
            get {
                access(keyPath: \.capturedMedia)
                return self._capturedMedia
            } set {
                withMutation(keyPath: \.capturedMedia) {
                    _capturedMedia = newValue
                }
            }
        }
    
    private var _livePhotoGroup: [PHLivePhoto?] = [] // 用于存储 PHLivePhoto
    var livePhotoGroup: [PHLivePhoto?] {
        get {
            access(keyPath: \.livePhotoGroup)
            return self._livePhotoGroup
        }
        set {
            withMutation(keyPath: \.livePhotoGroup) {
                _livePhotoGroup = newValue
            }
        }
    }
    
    private var _capturedPhotos: [Photo] = []
    var capturedPhotos: [Photo] {
        get {
              access(keyPath: \.capturedPhotos)
              return self._capturedPhotos
            } set {
              withMutation(keyPath: \.capturedPhotos) {
                  _capturedPhotos = newValue
              }
        }
    }
    
    private var _capturedMovies: [Movie] = []
    var capturedMovies: [Movie] {
        get {
            access(keyPath: \.capturedMovies)
            return self._capturedMovies
        } set {
            withMutation(keyPath: \.capturedMovies) {
                _capturedMovies = newValue
            }
        }
    }
    
    internal var selectedMedia: [Bool] = [false, false, false, false]
    
    var error: Error?
    
    // 初始化相机模型，设置默认的捕获模式和状态。
    init(captureMode: CaptureMode = .photo, status: CameraStatus = .unknown) {
        self.captureMode = captureMode
        self.status = status
    }
    
    // 启动相机，如果状态未知，则将其设置为运行中。
    func start() async {
        if status == .unknown {
            status = .running
        }
    }
    
    // 模拟切换视频设备的方法，未实现实际功能。
    func switchVideoDevices() {
        logger.debug("Device switching isn't implemented in PreviewCamera.")
    }
    
    // 模拟拍照的方法，未实现实际功能。
    func capturePhoto(saveToLibrary: Bool) {
        logger.debug("Photo capture isn't implemented in PreviewCamera.")
    }
    
    func saveAllPhotosToLibrary() {
        logger.debug("Photo capture isn't implemented in PreviewCamera.")
    }
    
    // 模拟切换录制状态的方法，未实现实际功能。
    func toggleRecording() {
        logger.debug("Moving capture isn't implemented in PreviewCamera.")
    }
    
    // 模拟对焦和曝光的方法，未实现实际功能。
    func focusAndExpose(at point: CGPoint) {
        logger.debug("Focus and expose isn't implemented in PreviewCamera.")
    }
    
    // 获取录制时间，默认返回零。
    var recordingTime: TimeInterval { .zero }
    
    var captureboxIsLoading = false
    
    // 根据捕获模式返回相应的捕获能力。
    private func capabilities(for mode: CaptureMode) -> CaptureCapabilities {
        switch mode {
        case .photo:
            return CaptureCapabilities(isFlashSupported: true,
                                       isLivePhotoCaptureSupported: true)
        case .video:
            return CaptureCapabilities(isFlashSupported: false,
                                       isLivePhotoCaptureSupported: false,
                                       isHDRSupported: true)
        }
    }
}
