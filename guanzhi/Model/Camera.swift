/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A protocol that represents the model for the camera view.
*/

import SwiftUI

/// A protocol that represents the model for the camera view. 一个表示相机视图模型的协议。
///
/// The AVFoundation camera APIs require running on a physical device. The app defines the model as a protocol to make it simple to swap out the real camera for a test camera when previewing SwiftUI views. AVFoundation 相机 API 需要在物理设备上运行。应用程序将模型定义为协议，以便在预览 SwiftUI 视图时可以简单地替换真实相机为测试相机。
///
// protocol Camera 的设计并不仅仅是用于模拟器的模拟测试，它是为了抽象出相机模型，使得应用程序在处理相机功能时更加灵活和模块化。这种设计在真实设备和模拟器上都非常有用。
//
//以下是一些具体的用途：
//
//    1.    真机使用：
//    •    在真实设备上运行时，可以有一个具体的实现类（如 CameraModel），它遵循 Camera 协议并与 AVFoundation 框架直接交互。
//    •    这样可以确保代码在真机上执行时，能够利用协议定义的接口与具体的硬件进行交互。
//    2.    模拟器使用：
//    •    在模拟器中，由于模拟器不支持相机硬件，可以有一个测试实现（如 PreviewCameraModel），它遵循 Camera 协议，但不依赖于实际的硬件。
//    •    这样可以在开发和测试过程中使用协议定义的接口进行模拟和测试，而不必担心硬件限制。
//    3.    测试和依赖注入：
//    •    Camera 协议使得相机模型的依赖注入变得简单，可以轻松地在单元测试中使用模拟实现进行测试，而无需依赖实际的相机硬件。
//    •    通过这种方式，可以编写更加健壮和可测试的代码。

@MainActor
protocol Camera: AnyObject {
    
    /// Provides the current status of the camera. 提供相机的当前状态。
    var status: CameraStatus { get }

    /// The camera's current activity state, which can be photo capture, movie capture, or idle. 相机的当前活动状态，可以是照片捕获、视频捕获或空闲。
    var captureActivity: CaptureActivity { get }

    /// The source of video content for a camera preview. 相机预览的视频内容来源。
    var previewSource: PreviewSource { get }
    
    /// Starts the camera capture pipeline. 启动相机捕获管道。
    func start() async

    /// The capture mode, which can be photo or video. 捕获模式，可以是照片或视频。
    var captureMode: CaptureMode { get set }
    
    /// A Boolean value that indicates whether the camera is currently switching capture modes. 一个布尔值，指示相机当前是否正在切换捕获模式。
    var isSwitchingModes: Bool { get }

    /// Switches between video devices available on the host system. 在主机系统上可用的视频设备之间切换。
    func switchVideoDevices() async
    
    /// A Boolean value that indicates whether the camera is currently switching video devices. 一个布尔值，指示相机当前是否正在切换视频设备。
    var isSwitchingVideoDevices: Bool { get }
    
    /// The photo features that a person can enable in the user interface. 用户界面中可以启用的照片功能。
    var photoFeatures: PhotoFeatures { get }

    /// Performs a one-time automatic focus and exposure operation. 执行一次自动对焦和曝光操作。
    func focusAndExpose(at point: CGPoint) async
    
    /// Captures a photo and writes it to the user's photo library. 捕获照片并将其写入用户的照片库。
    func capturePhoto() async
    
    /// A Boolean value that indicates whether to show visual feedback when capture begins. 一个布尔值，指示捕获开始时是否显示视觉反馈。
    var shouldFlashScreen: Bool { get }
    
    /// A Boolean that indicates whether the camera supports HDR video recording. 一个布尔值，指示相机是否支持 HDR 视频录制。
    var isHDRVideoSupported: Bool { get }
    
    /// A Boolean value that indicates whether camera enables HDR video recording. 一个布尔值，指示相机是否启用 HDR 视频录制。
    var isHDRVideoEnabled: Bool { get set }
    
    /// Starts or stops recording a movie, and writes it to the user's photo library when complete. 开始或停止录制视频，并在完成后将其写入用户的照片库。
    func toggleRecording() async
    
    /// A thumbnail image for the most recent photo or video capture. 最近一次照片或视频捕获的缩略图图像。
    var thumbnail: CGImage? { get }
//    var capturedPhotos: Photo? { get set }
    var capturedPhotos: [Photo] { get set }
    var capturedMovies: [Movie] { get set }
    var capturedMedia: [MediaItemProtocol] { get set }
    var selectedMedia: [Bool]  { get set }// 初始状态，所有按钮均未选中
    
    /// An error if the camera encountered a problem. 如果相机遇到问题，则返回错误。
    var error: Error? { get }
}
