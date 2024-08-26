/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An object that manages a photo capture output to take photographs.
*/

import AVFoundation
import CoreImage

// 定义一个用于表示照片捕获错误的枚举
enum PhotoCaptureError: Error {
    case noPhotoData // 没有照片数据
}

// 定义一个最终类 PhotoCapture，它实现了 OutputService 协议
final class PhotoCapture: OutputService {
    
    // 发布属性，用于表示捕获活动的当前状态
    @Published private(set) var captureActivity: CaptureActivity = .idle
    
    // 捕获输出对象
    let output = AVCapturePhotoOutput()
    
    // 内部别名，用于获取 photoOutput
    private var photoOutput: AVCapturePhotoOutput { output }
    
    // 发布属性，用于表示当前可用的捕获能力
    private(set) var capabilities: CaptureCapabilities = .unknown
    
    // 用于记录正在进行的 Live Photo 捕获的计数
    private var livePhotoCount = 0
    
    // 捕获照片的方法
    func capturePhoto(with features: EnabledPhotoFeatures) async throws -> Photo {
        // 使用 continuation 模式将委托基于的捕获 API 包装在异步上下文中
        try await withCheckedThrowingContinuation { continuation in
            // 创建一个设置对象来配置照片捕获
            let photoSettings = createPhotoSettings(with: features)
            // 创建一个委托对象来处理捕获事件
            let delegate = PhotoCaptureDelegate(continuation: continuation)
            // 监控委托的进度
            monitorProgress(of: delegate)
            // 使用指定的设置捕获新照片
            photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
        }
    }
    
    // 创建照片设置对象的方法
    private func createPhotoSettings(with features: EnabledPhotoFeatures) -> AVCapturePhotoSettings {
        // 创建一个新的设置对象来配置照片捕获
        var photoSettings = AVCapturePhotoSettings()
        // 如果设备支持，以 HEIF 格式捕获照片
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        }
        // 设置预览图像的格式
        if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
        }
        // 设置照片输出支持的最大尺寸
        photoSettings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        // 设置闪光灯模式
        photoSettings.flashMode = features.isFlashEnabled ? .auto : .off
        // 设置电影 URL，如果照片输出支持 Live Photo 捕获
        photoSettings.livePhotoMovieFileURL = features.isLivePhotoEnabled ? URL.movieFileURL : nil
        // 设置此捕获期间速度与质量的优先级
        if let prioritization = AVCapturePhotoOutput.QualityPrioritization(rawValue: features.qualityPrioritization.rawValue) {
            photoSettings.photoQualityPrioritization = prioritization
        }
        return photoSettings
    }
    
    // 监控照片捕获委托进度的方法
    private func monitorProgress(of delegate: PhotoCaptureDelegate) {
        Task {
            var isLivePhoto = false
            // 异步监控委托的活动
            for await activity in delegate.activityStream {
                var currentActivity = activity
                // 如果 Live Photo 状态发生变化，更新计数
                if activity.isLivePhoto != isLivePhoto {
                    isLivePhoto = activity.isLivePhoto
                    livePhotoCount += isLivePhoto ? 1 : -1
                    // 如果有多个 Live Photos 同时进行，确保 UI 不闪烁
                    if livePhotoCount > 1 {
                        currentActivity = .photoCapture(willCapture: activity.willCapture, isLivePhoto: true)
                    }
                }
                captureActivity = currentActivity
            }
        }
    }
    
    // 更新照片输出配置的方法
    func updateConfiguration(for device: AVCaptureDevice) {
        // 启用所有支持的功能
        photoOutput.maxPhotoDimensions = device.activeFormat.supportedMaxPhotoDimensions.last ?? .zero
        photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
        photoOutput.maxPhotoQualityPrioritization = .quality
        photoOutput.isResponsiveCaptureEnabled = photoOutput.isResponsiveCaptureSupported
        photoOutput.isFastCapturePrioritizationEnabled = photoOutput.isFastCapturePrioritizationSupported
        photoOutput.isAutoDeferredPhotoDeliveryEnabled = photoOutput.isAutoDeferredPhotoDeliverySupported
        updateCapabilities(for: device)
    }
    
    // 更新捕获能力的方法
    private func updateCapabilities(for device: AVCaptureDevice) {
        capabilities = CaptureCapabilities(isFlashSupported: device.isFlashAvailable,
                                           isLivePhotoCaptureSupported: photoOutput.isLivePhotoCaptureSupported)
    }
}

// 定义一个类型别名，用于表示照片捕获的 continuation
typealias PhotoContinuation = CheckedContinuation<Photo, Error>

// 定义一个类 PhotoCaptureDelegate，它实现了 AVCapturePhotoCaptureDelegate 协议
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    
    private let continuation: PhotoContinuation
    
    private var isLivePhoto = false
    private var isProxyPhoto = false
    
    private var photoData: Data?
    private var livePhotoMovieURL: URL?
    
    // 一个流，用于表示捕获活动的当前状态
    let activityStream: AsyncStream<CaptureActivity>
    private let activityContinuation: AsyncStream<CaptureActivity>.Continuation
    
    init(continuation: PhotoContinuation) {
        self.continuation = continuation
        
        let (activityStream, activityContinuation) = AsyncStream.makeStream(of: CaptureActivity.self)
        self.activityStream = activityStream
        self.activityContinuation = activityContinuation
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        isLivePhoto = resolvedSettings.livePhotoMovieDimensions != .zero
        activityContinuation.yield(.photoCapture(isLivePhoto: isLivePhoto))
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        activityContinuation.yield(.photoCapture(willCapture: true, isLivePhoto: isLivePhoto))
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        activityContinuation.yield(.photoCapture(isLivePhoto: false))
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error {
            logger.debug("Error processing Live Photo companion movie: \(String(describing: error))")
        }
        livePhotoMovieURL = outputFileURL
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCapturingDeferredPhotoProxy deferredPhotoProxy: AVCaptureDeferredPhotoProxy?, error: Error?) {
        if let error = error {
            logger.debug("Error capturing deferred photo: \(error)")
            return
        }
        photoData = deferredPhotoProxy?.fileDataRepresentation()
        isProxyPhoto = true
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            logger.debug("Error capturing photo: \(String(describing: error))")
            return
        }
        photoData = photo.fileDataRepresentation()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        defer {
            activityContinuation.finish()
        }
        if let error {
            continuation.resume(throwing: error)
            return
        }
        guard let photoData else {
            continuation.resume(throwing: PhotoCaptureError.noPhotoData)
            return
        }
        let photo = Photo(data: photoData, isProxy: isProxyPhoto, livePhotoMovieURL: livePhotoMovieURL)
        continuation.resume(returning: photo)
    }
}
