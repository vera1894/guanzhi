/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An object that retrieves camera and microphone devices.
*/

import AVFoundation
import Combine

/// An object that retrieves camera and microphone devices. 一个用于检索相机和麦克风设备的对象。
final class DeviceLookup {
    
    // Discovery sessions to find the front and back cameras, and external cameras in iPadOS. 用于查找前置和后置摄像头，以及在 iPadOS 中的外部摄像头的发现会话。
    private let frontCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    private let backCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    private let externalCameraDiscoverSession: AVCaptureDevice.DiscoverySession
    
    // 初始化方法，设置设备发现会话。
    init() {
        backCameraDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera],
                                                                      mediaType: .video,
                                                                      position: .back)
        frontCameraDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInWideAngleCamera],
                                                                       mediaType: .video,
                                                                       position: .front)
        externalCameraDiscoverSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.external],
                                                                         mediaType: .video,
                                                                         position: .unspecified)
        
        // If the host doesn't currently define a system-preferred camera device, set the user's preferred selection to the back camera. 如果主机当前没有定义系统首选摄像设备，则将用户首选选择设置为后置摄像头。
        if AVCaptureDevice.systemPreferredCamera == nil {
            AVCaptureDevice.userPreferredCamera = backCameraDiscoverySession.devices.first
        }
    }
    
    /// Returns the system-preferred camera for the host system. 返回主机系统的系统首选摄像头。
    var defaultCamera: AVCaptureDevice {
        get throws {
            // 获取系统首选摄像头，如果不可用则抛出错误。
            guard let videoDevice = AVCaptureDevice.systemPreferredCamera else {
                throw CameraError.videoDeviceUnavailable
            }
            return videoDevice
        }
    }
    
    /// Returns the default microphone for the device on which the app runs. 返回运行该应用程序的设备的默认麦克风。
    var defaultMic: AVCaptureDevice {
        get throws {
            // 获取默认麦克风，如果不可用则抛出错误。
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                throw CameraError.audioDeviceUnavailable
            }
            return audioDevice
        }
    }
    
    /// 返回可用摄像头的数组。
    var cameras: [AVCaptureDevice] {
        // Populate the cameras array with the available cameras. 填充可用摄像头的数组。
        var cameras: [AVCaptureDevice] = []
        if let backCamera = backCameraDiscoverySession.devices.first {
            cameras.append(backCamera)
        }
        if let frontCamera = frontCameraDiscoverySession.devices.first {
            cameras.append(frontCamera)
        }
        // iPadOS supports connecting external cameras. iPadOS 支持连接外部摄像头。
        if let externalCamera = externalCameraDiscoverSession.devices.first {
            cameras.append(externalCamera)
        }
        
        // 在非模拟器环境中，如果没有找到摄像头，则抛出致命错误。
#if !targetEnvironment(simulator)
        if cameras.isEmpty {
            fatalError("No camera devices are found on this system.")
        }
#endif
        return cameras
    }
}
