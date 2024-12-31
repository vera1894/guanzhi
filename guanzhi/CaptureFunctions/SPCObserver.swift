/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An object that provides an asynchronous stream capture devices that represent the system-preferred camera.
*/
import AVFoundation

/// An object that provides an asynchronous stream capture devices that represent the system-preferred camera. 一个提供表示系统首选摄像头的异步流捕获设备的对象。
class SystemPreferredCameraObserver: NSObject {
    
    // 用于表示系统首选摄像头的键路径。
    private let systemPreferredKeyPath = "systemPreferredCamera"
    
    // 一个异步流，用于捕获系统首选摄像头的变化。
    let changes: AsyncStream<AVCaptureDevice?>
    // 用于控制异步流的 continuation。
    private var continuation: AsyncStream<AVCaptureDevice?>.Continuation?

    override init() {
        // 创建一个异步流来捕获 AVCaptureDevice 的变化。
        let (changes, continuation) = AsyncStream.makeStream(of: AVCaptureDevice?.self)
        self.changes = changes
        self.continuation = continuation
        
        super.init()
        
        /// Key-value observe the `systemPreferredCamera` class property on `AVCaptureDevice`. 通过键值观察 `AVCaptureDevice` 类的 `systemPreferredCamera` 属性。
        AVCaptureDevice.self.addObserver(self, forKeyPath: systemPreferredKeyPath, options: [.new], context: nil)
    }
    
    // 在对象销毁时，结束 continuation。
    deinit {
        continuation?.finish()
    }
    
    // 处理键值观察的变化。
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case systemPreferredKeyPath:
            // Update the observer's system-preferred camera value. 更新观察者的系统首选摄像头值。
            let newDevice = change?[.newKey] as? AVCaptureDevice
            continuation?.yield(newDevice)
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}
