/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An object that provides the interface to the features of the camera.
*/

import SwiftUI
import Combine
import AVFoundation
import Observation
import Photos

/// An object that provides the interface to the features of the camera.
///
/// This object provides the default implementation of the `Camera` protocol, which defines the interface
/// to configure the camera hardware and capture media. `CameraModel` doesn't perform capture itself, but is an
/// `@Observable` type that mediates interactions between the app's SwiftUI views and `CaptureService`.
///
/// For SwiftUI previews and Simulator, the app uses `PreviewCameraModel` instead.
///

protocol MediaItemProtocol {}
extension Photo: MediaItemProtocol {}
extension Movie: MediaItemProtocol {}

@Observable final class CameraModel: Camera {
    
    /// The current status of the camera, such as unauthorized, running, or failed.  摄像机的当前状态，例如未授权、运行中或失败。
    private(set) var status = CameraStatus.unknown
    
    /// The current state of photo or movie capture. 当前的照片或视频捕获状态。
    private(set) var captureActivity = CaptureActivity.idle
    
    /// The photo features that a person can enable in the user interface. 用户界面中可以启用的照片功能。
    private(set) var photoFeatures = PhotoFeatures()
    
    /// A Boolean value that indicates whether the app is currently switching video devices.  一个布尔值，指示应用程序当前是否正在切换视频设备。
    private(set) var isSwitchingVideoDevices = false
    
    /// A Boolean value that indicates whether the app is currently switching capture modes. 一个布尔值，指示应用程序当前是否正在切换捕获模式。
    private(set) var isSwitchingModes = false
    
    /// A Boolean value that indicates whether to show visual feedback when capture begins. 一个布尔值，指示是否在捕获开始时显示视觉反馈。
    private(set) var shouldFlashScreen = false
    
    /// A thumbnail for the last captured photo or video. 最近捕获的照片或视频的缩略图。
    private(set) var thumbnail: CGImage?
    
    /// An error that indicates the details of an error during photo or movie capture. 指示在照片或视频捕获期间发生的错误的详细信息的错误对象。
    private(set) var error: Error?
    
    /// An object that provides the connection between the capture session and the video preview layer. 提供捕获会话和视频预览层之间连接的对象。
    var previewSource: PreviewSource { captureService.previewSource }
    
    /// A Boolean that indicates whether the camera supports HDR video recording. 一个布尔值，指示相机是否支持HDR视频录制。
    private(set) var isHDRVideoSupported = false
    
    /// An object that saves captured media to a person's Photos library. 一个对象，用于将捕获的媒体保存到用户的照片库。
    private let mediaLibrary = MediaLibrary()
    
    /// An object that manages the app's capture functionality. 一个管理应用程序捕获功能的对象。
    private let captureService = CaptureService()
    
    public var mediasGroup: [MediaItemProtocol] = []
    let mediaStream: AsyncStream<[MediaItemProtocol]>
    private let mediaContinuation: AsyncStream<[MediaItemProtocol]>.Continuation?
    var captureboxIsLoading = false
    
    
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
    
    private var _selectedMedia: [Bool] = [false, false, false, false]
    var selectedMedia: [Bool] {
        get {
            access(keyPath: \.selectedMedia)
            return self._selectedMedia
        } set {
            withMutation(keyPath: \.selectedMedia) {
                _selectedMedia = newValue
            }
        }
    }
//    var selectedMedia: [Bool] = [false, false, false, false]
    
//    var capturedPhotoBinding: Binding<Photo> {
//        Binding(
//            get: { self.capturedPhotos },
//            set: { self.capturedPhotos = $0 }
//        )
//    }
    
    
    
    private(set) var thumbnailsGroup: [CGImage] = []
//    private(set) var thumbnailForView: CGImage?
    
    init() {
        //
        let (stream, continuation) = AsyncStream.makeStream(of: [MediaItemProtocol].self)
                self.mediaStream = stream
                self.mediaContinuation = continuation
    }
    
    // 添加静态异步创建方法
    static func create() async -> CameraModel {
        // 这里可以进行任何异步的初始化操作
        return CameraModel()
    }

    
    // MARK: - Starting the camera 启动相机
    /// Start the camera and begin the stream of data. 启动相机并开始数据流。
    func start() async {
        // Verify that the person authorizes the app to use device cameras and microphones. 验证用户是否授权应用程序使用设备摄像头和麦克风。
        guard await captureService.isAuthorized else {
            status = .unauthorized
            return
        }
        do {
            // Start the capture service to start the flow of data. 启动捕获服务以开始数据流。
            try await captureService.start()
            observeState()
//            observeMediaGroup() //增加
            status = .running
        } catch {
            logger.error("Failed to start capture service. \(error)")
            status = .failed
        }
    }

    // MARK: - Stopping the camera 停止相机
    /// Stop the camera and release all resources. 停止相机并释放所有资源。
    func stop() async {
        await captureService.stop()
        status = .unknown
    }

    // MARK: - Changing modes and devices 更改模式和设备
    
    /// A value that indicates the mode of capture for the camera. 一个值，指示相机的捕获模式。
    var captureMode = CaptureMode.photo {
        didSet {
            Task {
                isSwitchingModes = true
                defer { isSwitchingModes = false }
                // Update the configuration of the capture service for the new mode. 更新捕获服务的配置以适应新模式。
                try? await captureService.setCaptureMode(captureMode)
            }
        }
    }
    
    /// Selects the next available video device for capture. 选择下一个可用的视频设备进行捕获。
    func switchVideoDevices() async {
        isSwitchingVideoDevices = true
        defer { isSwitchingVideoDevices = false }
        await captureService.selectNextVideoDevice()
    }
    
    // MARK: - Photo capture 照片捕获
    
    /// Captures a photo and writes it to the user's Photos library. 捕获一张照片并将其写入用户的照片库。
    func capturePhoto(saveToLibrary: Bool = false) async {
        self.captureboxIsLoading = true
        do {
            let photo = try await captureService.capturePhoto(with: photoFeatures.current)
            self.capturedPhotos.append(photo)
            self.capturedMedia.append(photo)  // 目前使用的
            
            let currentIndex = self.capturedMedia.count - 1  // 当前捕获的索引
                    self.livePhotoGroup.append(nil)  // 先插入一个占位符

                    if let livePhotoMovieURL = photo.livePhotoMovieURL {
                        let photoURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempPhoto_\(UUID().uuidString).jpg")
                        try? photo.data.write(to: photoURL)

                        // 生成 Live Photo 逻辑
                        PHLivePhoto.request(withResourceFileURLs: [photoURL, livePhotoMovieURL], placeholderImage: nil, targetSize: .zero, contentMode: .aspectFit) { livePhoto, info in
                            DispatchQueue.main.async {
                                if let livePhoto = livePhoto {
                                    self.livePhotoGroup[currentIndex] = livePhoto // 用索引替换占位符
                                } else {
                                    self.livePhotoGroup[currentIndex] = nil // 处理失败或非 Live Photo
                                }
                            }
                        }
                    } else {
                        self.livePhotoGroup[currentIndex] = nil // 非 Live Photo 的情况
                    }
            
            self.captureboxIsLoading = false
            if capturedPhotos.first != nil {
                print("Photo successfully captured")
            }
            
            // 检查是否需要保存到系统照片库
            if saveToLibrary {
//                try await mediaLibrary.save(photo: photo)
                try await saveAllPhotosToLibrary()
            }
            
        } catch {
            self.error = error
        }
    }
    
    func saveAllPhotosToLibrary() async throws {
        for mediaItem in capturedMedia {
            if let photo = mediaItem as? Photo {
                try await mediaLibrary.save(photo: photo)
            }
        }
    }
    
//    func capturePhoto() async {
//        do {
//            let photo = try await captureService.capturePhoto(with: photoFeatures.current)
//            self.capturedPhotos.append(photo)
//            self.capturedMedia.append(photo)  //目前使用的
//            if capturedPhotos.first != nil {
//                print("Photo successfully captured")
//            }
////            try await mediasGroup.append(photo)
//            try await mediaLibrary.save(photo: photo)
//        } catch {
//            self.error = error
//        }
//    }
    
    /// Performs a focus and expose operation at the specified screen point. 在指定的屏幕点执行对焦和曝光操作
    func focusAndExpose(at point: CGPoint) async {
        await captureService.focusAndExpose(at: point)
    }
    
    /// Sets the `showCaptureFeedback` state to indicate that capture is underway. 设置 `showCaptureFeedback` 状态以指示捕获正在进行。
    private func flashScreen() {
        shouldFlashScreen = true
        withAnimation(.linear(duration: 0.01)) {
            shouldFlashScreen = false
        }
    }
    
    // MARK: - Video capture 视频捕获
    /// A Boolean value that indicates whether the camera captures video in HDR format. 一个布尔值，指示相机是否以HDR格式捕获视频。
    var isHDRVideoEnabled = false {
        didSet {
            Task {
                await captureService.setHDRVideoEnabled(isHDRVideoEnabled)
            }
        }
    }
    
    /// Toggles the state of recording. 切换录制状态。
    func toggleRecording() async {
        switch await captureService.captureActivity {
        case .movieCapture:
            do {
                // If currently recording, stop the recording and write the movie to the library. 如果当前正在录制，则停止录制并将视频写入库中。
                let movie = try await captureService.stopRecording()
                self.capturedMovies.append(movie)
                self.capturedMedia.append(movie)
                if capturedMovies.first != nil {
                    print("Movie successfully captured")
                }
                try await mediaLibrary.save(movie: movie)
            } catch {
                self.error = error
            }
        default:
            // In any other case, start recording.
            await captureService.startRecording()
        }
    }
    
    // MARK: - Internal state observations 内部状态观察
    
    // Set up camera's state observations. 设置相机的状态观察。
    private func observeState() {
        Task {
            // Await new thumbnails that the media library generates when saving a file. 等待媒体库在保存文件时生成的新缩略图。
            for await thumbnail in mediaLibrary.thumbnails.compactMap({ $0 }) {
                self.thumbnail = thumbnail
                
            }
        }
        
        Task {
            // Await new capture activity values from the capture service. 等待来自捕获服务的新捕获活动值。
            for await activity in await captureService.$captureActivity.values {
                if activity.willCapture {
                    // Flash the screen to indicate capture is starting. 闪屏以指示捕获即将开始。
                    flashScreen()
                } else {
                    // Forward the activity to the UI. 将活动转发到UI。
                    captureActivity = activity
                }
            }
        }
        
        Task {
            // Await updates to the capabilities that the capture service advertises. 等待捕获服务发布的能力更新。
            for await capabilities in await captureService.$captureCapabilities.values {
                isHDRVideoSupported = capabilities.isHDRSupported
            }
        }
        
//        Task {
//            for await capturedPhoto in await captureService. {
//                
//            }
//        }
    }
    
//    private func observeMediaGroup() {
//        Task {
//            for await media in AsyncStream(unfolding: {
//                self.mediasGroup.isEmpty ? nil : self.mediasGroup.last
//            }) {
//                if let photo = media as? Photo, let cgImage = photo.cgImage {
//                    thumbnailForView = cgImage
//                } else if let movie = media as? Movie, let thumbnail = await generateThumbnail(from: movie.url) {
//                    thumbnailForView = thumbnail
//                }
//            }
//        }
//    }
    
    private func generateThumbnail(from url: URL) async -> CGImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1, preferredTimescale: 60)

        do {
            let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return imageRef
        } catch {
            print("Failed to generate thumbnail: \(error)")
            return nil
        }
    }
}


