/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An object that manages a movie capture output to record videos.
*/

import AVFoundation
import Combine

/// An object that manages a movie capture output to record videos. 管理视频捕获输出以录制视频的对象。
final class MovieCapture: OutputService {
    
    /// A value that indicates the current state of movie capture. 表示当前视频捕获状态的值。
    @Published private(set) var captureActivity: CaptureActivity = .idle
    
    /// The capture output type for this service. 此服务的捕获输出类型。
    let output = AVCaptureMovieFileOutput()
    // An internal alias for the output. 内部别名，用于获取 movieOutput。
    private var movieOutput: AVCaptureMovieFileOutput { output }
    
    // A delegate object to respond to movie capture events. 响应视频捕获事件的委托对象。
    private var delegate: MovieCaptureDelegate?
    
    // The interval at which to update the recording time. 更新录制时间的间隔。
    private let refreshInterval = TimeInterval(0.25)
    private var timerCancellable: AnyCancellable?
    
    // A Boolean value that indicates whether the currently selected camera's active format supports HDR. 表示当前选择的相机的活动格式是否支持 HDR 的布尔值。
    private var isHDRSupported = false
    
    // MARK: - Capturing a movie 捕获视频
    
    /// Starts movie recording. 开始视频录制。
    func startRecording() {
        // Return early if already recording. 如果已经在录制，提前返回。
        guard !movieOutput.isRecording else { return }
        
        guard let connection = movieOutput.connection(with: .video) else {
            fatalError("Configuration error. No video connection found.")
        }

        // Configure connection for HEVC capture. 配置 HEVC 捕获连接。
        if movieOutput.availableVideoCodecTypes.contains(.hevc) {
            movieOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: connection)
        }

        // Enable video stabilization if the connection supports it. 如果连接支持视频稳定，启用视频稳定。
        if connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .auto
        }
        
        // Start a timer to update the recording time. 启动一个计时器来更新录制时间。
        startMonitoringDuration()
        
        delegate = MovieCaptureDelegate()
        movieOutput.startRecording(to: URL.movieFileURL, recordingDelegate: delegate!)
    }
    
    /// Stops movie recording. 停止视频录制。
    /// - Returns: A `Movie` object that represents the captured movie. 表示捕获视频的 `Movie` 对象。
    func stopRecording() async throws -> Movie {
        // Use a continuation to adapt the delegate-based capture API to an async interface. 使用 continuation 将委托基于的捕获 API 适配到异步接口。
        return try await withCheckedThrowingContinuation { continuation in
            // Set the continuation on the delegate to handle the capture result. 在委托上设置 continuation 以处理捕获结果。
            delegate?.continuation = continuation
            
            /// Stops recording, which causes the output to call the `MovieCaptureDelegate` object. 停止录制，这将导致输出调用 `MovieCaptureDelegate` 对象。
            movieOutput.stopRecording()
            stopMonitoringDuration()
        }
    }
    
    // MARK: - Movie capture delegate 视频捕获委托
    /// A delegate object that responds to the capture output finalizing movie recording. 响应捕获输出最终完成视频录制的委托对象。
    private class MovieCaptureDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
        
        var continuation: CheckedContinuation<Movie, Error>?
        
        func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
            if let error {
                // If an error occurs, throw it to the caller. 如果发生错误，将其抛给调用者。
                continuation?.resume(throwing: error)
            } else {
                // Return a new movie object. 返回一个新的电影对象。
                continuation?.resume(returning: Movie(url: outputFileURL))
            }
        }
    }
    
    // MARK: - Monitoring recorded duration 监控录制时长
    
    // Starts a timer to update the recording time. 启动一个计时器来更新录制时间。
    private func startMonitoringDuration() {
        captureActivity = .movieCapture()
        timerCancellable = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                // Poll the movie output for its recorded duration. 轮询 movieOutput 获取其录制时长。
                let duration = movieOutput.recordedDuration.seconds
                captureActivity = .movieCapture(duration: duration)
            }
    }
    
    /// Stops the timer and resets the time to `CMTime.zero`. 停止计时器并将时间重置为 `CMTime.zero`。
    private func stopMonitoringDuration() {
        timerCancellable?.cancel()
        captureActivity = .idle
    }
    
    // 更新设备配置的方法
    func updateConfiguration(for device: AVCaptureDevice) {
        // The app supports HDR video capture if the active format supports it. 如果活动格式支持 HDR，则应用程序支持 HDR 视频捕获。
        isHDRSupported = device.activeFormat10BitVariant != nil
    }

    // MARK: - Configuration
    /// Returns the capabilities for this capture service. 返回此捕获服务的能力。
    var capabilities: CaptureCapabilities {
        CaptureCapabilities(isHDRSupported: isHDRSupported)
    }
}
