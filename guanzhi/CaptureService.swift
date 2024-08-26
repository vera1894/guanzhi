import Foundation
import AVFoundation
import Combine

// 定义一个管理捕获管道的 actor，包括捕获会话、设备输入和捕获输出。
actor CaptureService {
    // 公开的发布属性，用于指示捕获活动的当前状态。
    @Published private(set) var captureActivity: CaptureActivity = .idle
    // 公开的发布属性，用于指示捕获服务的当前能力。
    @Published private(set) var captureCapabilities = CaptureCapabilities.unknown
    // 公开的发布属性，用于指示应用程序是否被更高优先级的事件打断。
    @Published private(set) var isInterrupted = false
    // 公开的发布属性，用于指示用户是否启用了 HDR 视频捕获。
    @Published var isHDRVideoEnabled = false
    // 非隔离的预览源对象，用于连接预览视图和捕获会话。
    nonisolated let previewSource: PreviewSource
    // 捕获会话对象。
    private let captureSession = AVCaptureSession()
    // 管理照片捕获行为的对象。
    private let photoCapture = PhotoCapture()
    // 管理视频捕获行为的对象。
    private let movieCapture = MovieCapture()
    // 内部的输出服务集合。
    private var outputServices: [any OutputService] { [photoCapture, movieCapture] }
    // 当前选择的视频输入设备。
    private var activeVideoInput: AVCaptureDeviceInput?
    // 捕获模式，默认为照片模式。
    private(set) var captureMode = CaptureMode.photo
    // 用于检索捕获设备的对象。
    private let deviceLookup = DeviceLookup()
    // 用于监控系统首选相机状态的对象。
    private let systemPreferredCamera = SystemPreferredCameraObserver()
    // 用于管理视频设备旋转的对象。
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator!
    // 用于管理旋转观察者的集合。
    private var rotationObservers = [AnyObject]()
    // 一个布尔值，指示 actor 是否已完成必要的配置。
    private var isSetUp = false
    
    init() {
        // 创建一个源对象以连接预览视图和捕获会话。
        previewSource = DefaultPreviewSource(session: captureSession)
    }
    
    // 授权状态，指示用户是否授权应用程序使用设备摄像头和麦克风。
    var isAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            var isAuthorized = status == .authorized
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            }
            return isAuthorized
        }
    }
    
    // 开始捕获会话的方法。
    func start() async throws {
        guard await isAuthorized, !captureSession.isRunning else { return }
        try setUpSession()
        captureSession.startRunning()
    }
    
    // 初始化捕获会话的方法。
    private func setUpSession() throws {
        guard !isSetUp else { return }
        
        observeOutputServices()
        
        do {
            let defaultCamera = try deviceLookup.defaultCamera
            let defaultMic = try deviceLookup.defaultMic
            
            activeVideoInput = try addInput(for: defaultCamera)
            try addInput(for: defaultMic)
            
            captureSession.sessionPreset = .photo
            try addOutput(photoCapture.output)
            
            monitorSystemPreferredCamera()
            
            createRotationCoordinator(for: defaultCamera)
            observeSubjectAreaChanges(of: defaultCamera)
            updateCaptureCapabilities()
            
            isSetUp = true
        } catch {
            throw CameraError.setupFailed
        }
    }
    
    // 添加输入设备到捕获会话的方法。
    @discardableResult
    private func addInput(for device: AVCaptureDevice) throws -> AVCaptureDeviceInput {
        let input = try AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        } else {
            throw CameraError.addInputFailed
        }
        return input
    }
    
    // 添加输出设备到捕获会话的方法。
    private func addOutput(_ output: AVCaptureOutput) throws {
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        } else {
            throw CameraError.addOutputFailed
        }
    }
    
    // 获取当前使用的捕获设备。
    private var currentDevice: AVCaptureDevice {
        guard let device = activeVideoInput?.device else {
            fatalError("No device found for current video input.")
        }
        return device
    }
    
    // 设置捕获模式的方法。
    func setCaptureMode(_ captureMode: CaptureMode) throws {
        self.captureMode = captureMode
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        switch captureMode {
        case .photo:
            captureSession.sessionPreset = .photo
            captureSession.removeOutput(movieCapture.output)
        case .video:
            captureSession.sessionPreset = .high
            try addOutput(movieCapture.output)
            if isHDRVideoEnabled {
                setHDRVideoEnabled(true)
            }
        }
        
        updateCaptureCapabilities()
    }
    
    // 选择下一个可用的视频设备的方法。
    func selectNextVideoDevice() {
        let videoDevices = deviceLookup.cameras
        let selectedIndex = videoDevices.firstIndex(of: currentDevice) ?? 0
        var nextIndex = selectedIndex + 1
        if nextIndex == videoDevices.endIndex {
            nextIndex = 0
        }
        
        let nextDevice = videoDevices[nextIndex]
        changeCaptureDevice(to: nextDevice)
        AVCaptureDevice.userPreferredCamera = nextDevice
    }
    
    // 更换捕获设备的方法。
    private func changeCaptureDevice(to device: AVCaptureDevice) {
        guard let currentInput = activeVideoInput else { fatalError() }
        
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        captureSession.removeInput(currentInput)
        do {
            activeVideoInput = try addInput(for: device)
            createRotationCoordinator(for: device)
            observeSubjectAreaChanges(of: device)
            updateCaptureCapabilities()
        } catch {
            captureSession.addInput(currentInput)
        }
    }
    
    // 监控系统首选相机状态的方法。
    private func monitorSystemPreferredCamera() {
        Task {
            for await camera in systemPreferredCamera.changes {
                if let camera, currentDevice != camera {
                    logger.debug("Switching camera selection to the system-preferred camera.")
                    changeCaptureDevice(to: camera)
                }
            }
        }
    }
    
    // 创建用于设备旋转管理的协调器。
    private func createRotationCoordinator(for device: AVCaptureDevice) {
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: videoPreviewLayer)
        
        updatePreviewRotation(rotationCoordinator.videoRotationAngleForHorizonLevelPreview)
        updateCaptureRotation(rotationCoordinator.videoRotationAngleForHorizonLevelCapture)
        
        rotationObservers.removeAll()
        
        rotationObservers.append(
            rotationCoordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: .new) { [weak self] _, change in
                guard let self, let angle = change.newValue else { return }
                Task { await self.updatePreviewRotation(angle) }
            }
        )
        
        rotationObservers.append(
            rotationCoordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: .new) { [weak self] _, change in
                guard let self, let angle = change.newValue else { return }
                Task { await self.updateCaptureRotation(angle) }
            }
        )
    }
    
    // 更新预览旋转的方法。
    private func updatePreviewRotation(_ angle: CGFloat) {
        let previewLayer = videoPreviewLayer
        Task { @MainActor in
            previewLayer.connection?.videoRotationAngle = angle
        }
    }
    
    // 更新捕获旋转的方法。
    private func updateCaptureRotation(_ angle: CGFloat) {
        outputServices.forEach { $0.setVideoRotationAngle(angle) }
    }
    
    // 获取视频预览层。
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let previewLayer = captureSession.connections.compactMap({ $0.videoPreviewLayer }).first else {
            fatalError("The app is misconfigured. The capture session should have a connection to a preview layer.")
        }
        return previewLayer
    }
    
    // 执行对焦和曝光操作的方法。
    func focusAndExpose(at point: CGPoint) {
        let devicePoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
        do {
            try focusAndExpose(at: devicePoint, isUserInitiated: true)
        } catch {
            logger.debug("Unable to perform focus and exposure operation. \(error)")
        }
    }
    
    // 观察设备的 subject area 更改的方法。
    private func observeSubjectAreaChanges(of device: AVCaptureDevice) {
        subjectAreaChangeTask?.cancel()
        subjectAreaChangeTask = Task {
            for await _ in NotificationCenter.default.notifications(named: .AVCaptureDeviceSubjectAreaDidChange, object: device) {
                try? focusAndExpose(at: CGPoint(x: 0.5, y: 0.5), isUserInitiated: false)
            }
        }
    }
    private var subjectAreaChangeTask: Task<Void, Never>?
    
    // 执行对焦和曝光的方法。
    private func focusAndExpose(at devicePoint: CGPoint, isUserInitiated: Bool) throws {
        let device = currentDevice
        try device.lockForConfiguration()
        
        let focusMode = isUserInitiated ? AVCaptureDevice.FocusMode.autoFocus : .continuousAutoFocus
        if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
            device.focusPointOfInterest = devicePoint
            device.focusMode = focusMode
        }
        
        let exposureMode = isUserInitiated ? AVCaptureDevice.ExposureMode.autoExpose : .continuousAutoExposure
        if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
            device.exposurePointOfInterest = devicePoint
            device.exposureMode = exposureMode
        }
        device.isSubjectAreaChangeMonitoringEnabled = isUserInitiated
        
        device.unlockForConfiguration()
    }
    
    // 捕获照片的方法。
    func capturePhoto(with features: EnabledPhotoFeatures) async throws -> Photo {
        try await photoCapture.capturePhoto(with: features)
    }
    
    // 开始录制视频的方法。
    func startRecording() {
        movieCapture.startRecording()
    }
    
    // 停止录制视频的方法。
    func stopRecording() async throws -> Movie {
        try await movieCapture.stopRecording()
    }
    
    // 设置 HDR 视频捕获的方法。
    func setHDRVideoEnabled(_ isEnabled: Bool) {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        do {
            if isEnabled, let format = currentDevice.activeFormat10BitVariant {
                try currentDevice.lockForConfiguration()
                currentDevice.activeFormat = format
                currentDevice.unlockForConfiguration()
                isHDRVideoEnabled = true
            } else {
                captureSession.sessionPreset = .high
                isHDRVideoEnabled = false
            }
        } catch {
            logger.error("Unable to obtain lock on device and can’t enable HDR video capture.")
        }
    }
    
    // 更新捕获服务的能力。
    private func updateCaptureCapabilities() {
        outputServices.forEach { $0.updateConfiguration(for: currentDevice) }
        switch captureMode {
        case .photo:
            captureCapabilities = photoCapture.capabilities
        case .video:
            captureCapabilities = movieCapture.capabilities
        }
    }
    
    // 观察输出服务的方法。
    private func observeOutputServices() {
        Publishers.Merge(photoCapture.$captureActivity, movieCapture.$captureActivity)
            .assign(to: &$captureActivity)
    }
    
    // 观察通知的方法。
    private func observeNotifications() {
        Task {
            for await reason in NotificationCenter.default.notifications(named: .AVCaptureSessionWasInterrupted)
                .compactMap({ $0.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject? })
                .compactMap({ AVCaptureSession.InterruptionReason(rawValue: $0.integerValue) }) {
                isInterrupted = [.audioDeviceInUseByAnotherClient, .videoDeviceInUseByAnotherClient].contains(reason)
            }
        }
        
        Task {
            for await _ in NotificationCenter.default.notifications(named: .AVCaptureSessionInterruptionEnded) {
                isInterrupted = false
            }
        }
        
        Task {
            for await error in NotificationCenter.default.notifications(named: .AVCaptureSessionRuntimeError)
                .compactMap({ $0.userInfo?[AVCaptureSessionErrorKey] as? AVError }) {
                if error.code == .mediaServicesWereReset {
                    if !captureSession.isRunning {
                        captureSession.startRunning()
                    }
                }
            }
        }
    }
}
