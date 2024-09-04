/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Supporting data types for the app.
*/

import AVFoundation

// MARK: - Supporting types

/// An enumeration that describes the current status of the camera. 一个枚举，描述了相机的当前状态。
enum CameraStatus {
    /// The initial status upon creation. 创建时的初始状态。
    case unknown
    /// A status that indicates a person disallows access to the camera or microphone. 表示用户不允许访问相机或麦克风的状态。
    case unauthorized
    /// A status that indicates the camera failed to start. 表示相机启动失败的状态。
    case failed
    /// A status that indicates the camera is successfully running. 表示相机成功运行的状态。
    case running
    /// A status that indicates higher-priority media processing is interrupting the camera. 表示有更高优先级的媒体处理中断了相机的状态。
    case interrupted
}

/// An enumeration that defines the activity states the capture service supports. 一个枚举，定义了捕获服务支持的活动状态。
///
/// This type provides feedback to the UI regarding the active status of the `CaptureService` actor. 此类型为 UI 提供有关 `CaptureService` actor 的活动状态反馈。
enum CaptureActivity {
    case idle
    /// A status that indicates the capture service is performing photo capture. 表示捕获服务正在执行照片捕获的状态。
    case photoCapture(willCapture: Bool = false, isLivePhoto: Bool = false)
    /// A status that indicates the capture service is performing movie capture. 表示捕获服务正在执行视频捕获的状态。
    case movieCapture(duration: TimeInterval = 0.0)
    
    /// 检查当前状态是否为 Live Photo。
    var isLivePhoto: Bool {
        if case .photoCapture(_, let isLivePhoto) = self {
            return isLivePhoto
        }
        return false
    }
    
    /// 检查当前状态是否即将捕获照片。
    var willCapture: Bool {
        if case .photoCapture(let willCapture, _) = self {
            return willCapture
        }
        return false
    }
    
    /// 获取当前视频捕获的时间。
    var currentTime: TimeInterval {
        if case .movieCapture(let duration) = self {
            return duration
        }
        return .zero
    }
    
    /// 检查当前状态是否正在录制。
    var isRecording: Bool {
        if case .movieCapture(_) = self {
            return true
        }
        return false
    }
}

/// An enumeration of the capture modes that the camera supports. 一个枚举，表示相机支持的捕获模式。
enum CaptureMode: String, Identifiable, CaseIterable {
    var id: Self { self }
    /// A mode that enables photo capture. 启用照片捕获的模式。
    case photo
    /// A mode that enables video capture. 启用视频捕获的模式。
    case video
    
    /// 返回系统名称字符串，用于图标显示。
    var systemName: String {
        switch self {
        case .photo:
            "camera.fill"
        case .video:
            "video.fill"
        }
    }
}

/// A structure that represents a captured photo. 一个结构体，表示捕获的照片。
struct Photo: Sendable {
    let data: Data
    let isProxy: Bool
    let livePhotoMovieURL: URL?
    
    var cgImage: CGImage? {
        guard let dataProvider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(jpegDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}

/// A structure that contains the uniform type identifier and movie URL. 一个结构体，包含统一类型标识符和视频 URL。
struct Movie: Sendable {
    /// The temporary location of the file on disk. 文件在磁盘上的临时位置。
    let url: URL
}

@Observable
/// An object that stores the state of a person's enabled photo features. 一个存储用户启用的照片功能状态的对象。
class PhotoFeatures {
    var isFlashEnabled = false
    var isLivePhotoEnabled = true //
    var qualityPrioritization: QualityPrioritization = .balanced
    
/// 获取当前启用的照片功能。
    var current: EnabledPhotoFeatures {
        .init(isFlashEnabled: isFlashEnabled,
              isLivePhotoEnabled: isLivePhotoEnabled,
              qualityPrioritization: qualityPrioritization)
    }
}

/// 一个结构体，表示启用的照片功能。
struct EnabledPhotoFeatures {
    let isFlashEnabled: Bool
    let isLivePhotoEnabled: Bool
    let qualityPrioritization: QualityPrioritization
}

/// A structure that represents the capture capabilities of `CaptureService` in its current configuration. 一个结构体，表示 `CaptureService` 在当前配置下的捕获能力。
struct CaptureCapabilities {
    let isFlashSupported: Bool
    let isLivePhotoCaptureSupported: Bool
    let isHDRSupported: Bool
    
    init(isFlashSupported: Bool = false,
         isLivePhotoCaptureSupported: Bool = false,
         isHDRSupported: Bool = false) {
        
        self.isFlashSupported = isFlashSupported
        self.isLivePhotoCaptureSupported = isLivePhotoCaptureSupported
        self.isHDRSupported = isHDRSupported
    }
    
    /// 未知捕获能力的静态常量。
    static let unknown = CaptureCapabilities()
}

/// 一个枚举，表示质量优先级。
enum QualityPrioritization: Int, Identifiable, CaseIterable, CustomStringConvertible {
    var id: Self { self }
    case speed = 1
    case balanced
    case quality
    var description: String {
        switch self {
        case.speed:
            return "Speed"
        case .balanced:
            return "Balanced"
        case .quality:
            return "Quality"
        }
    }
}

/// 一个枚举，表示可能发生的相机错误。
enum CameraError: Error {
    case videoDeviceUnavailable
    case audioDeviceUnavailable
    case addInputFailed
    case addOutputFailed
    case setupFailed
    case deviceChangeFailed
}

/// 一个协议，表示输出服务。
protocol OutputService {
    associatedtype Output: AVCaptureOutput
    var output: Output { get }
    var captureActivity: CaptureActivity { get }
    var capabilities: CaptureCapabilities { get }
    func updateConfiguration(for device: AVCaptureDevice)
    func setVideoRotationAngle(_ angle: CGFloat)
}

/// OutputService 协议的扩展，提供默认实现。
extension OutputService {
    /// 设置输出对象的视频连接的旋转角度。
    func setVideoRotationAngle(_ angle: CGFloat) {
        // Set the rotation angle on the output object's video connection.
        output.connection(with: .video)?.videoRotationAngle = angle
    }
    /// 更新设备配置的默认实现（空实现）。
    func updateConfiguration(for device: AVCaptureDevice) {}
}
