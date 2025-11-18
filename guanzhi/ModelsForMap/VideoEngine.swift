//
//  VideoEngine.swift
//  guanzhi
//
//  Created by Claude on 2025/11/18.
//

import AVFoundation
import AVFAudio
import UIKit

/// VideoEngine：专门用于 LivePhoto 视频的快速起播管理
/// - 目标：实现"加载完→立即播放"的秒播体验
/// - 核心：预加载 AVPlayerItem + playImmediately API
@MainActor
final class VideoEngine: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 当前播放器
    @Published private(set) var player: AVPlayer?
    
    /// 是否正在播放
    @Published private(set) var isPlaying: Bool = false
    
    /// 是否已准备好播放
    @Published private(set) var isReadyToPlay: Bool = false
    
    /// 播放进度（0.0 - 1.0）
    @Published private(set) var progress: Double = 0.0
    
    // MARK: - Private Properties
    
    private var currentItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    
    // ✅ 像素级首帧探测
    private var videoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    
    // MARK: - Callbacks
    
    var onReadyToPlay: (() -> Void)?
    var onPlaybackFinished: (() -> Void)?
    var onFirstFrameRendered: (() -> Void)? // ✅ 首帧渲染回调（真正拿到像素）
    
    // MARK: - Initialization
    
    init() {
        configureAudioSession()
        setupPlayer()
    }
    
    // MARK: - Audio Session Configuration
    
    /// 配置音频会话：允许与其他音频混音（不打断后台音乐）
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // ✅ 使用 .playback + .mixWithOthers：与其他音频共存，LivePhoto有声音
            // 不使用 .ambient，因为 .ambient 会受静音键影响
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            
            #if DEBUG
            print("🔊 VideoEngine - 音频会话已配置为 .playback + .mixWithOthers（Mix模式）")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ VideoEngine - 音频会话配置失败: \(error.localizedDescription)")
            #endif
        }
    }
    
    deinit {
        // ✅ deinit 中不执行清理，依赖 ARC 自动管理
        // 观察者和通知会在对象释放时自动清理
        #if DEBUG
        print("🧹 VideoEngine - deinit")
        #endif
    }
    
    // MARK: - Setup
    
    private func setupPlayer() {
        let player = AVPlayer()
        
        // ✅ 关键配置：减少缓冲时间，快速起播
        player.automaticallyWaitsToMinimizeStalling = false
        
        self.player = player
        
        // 监听播放速率变化
        rateObservation = player.observe(\.rate, options: [.new]) { [weak self] player, change in
            Task { @MainActor in
                self?.isPlaying = player.rate > 0
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 预加载视频，准备播放
    /// - Parameters:
    ///   - url: 视频 URL（本地或远程）
    ///   - onReady: 准备完成回调
    func prepare(url: URL, onReady: (() -> Void)? = nil) {
        #if DEBUG
        print("🎬 VideoEngine - 开始预加载视频: \(url.lastPathComponent)")
        #endif
        
        self.onReadyToPlay = onReady
        
        // ✅ 只在有旧内容时才清理（避免过早清理）
        if currentItem != nil {
            #if DEBUG
            print("🧹 VideoEngine - 清理旧的视频内容")
            #endif
            cleanup()
        }
        
        // 创建 AVAsset
        let asset = AVURLAsset(url: url)
        
        // 异步加载 playable 属性
        asset.loadValuesAsynchronously(forKeys: ["playable", "duration"]) { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                var error: NSError?
                let status = asset.statusOfValue(forKey: "playable", error: &error)
                
                guard status == .loaded, error == nil else {
                    #if DEBUG
                    print("❌ VideoEngine - 视频加载失败: \(error?.localizedDescription ?? "未知错误")")
                    #endif
                    return
                }
                
                // 创建 AVPlayerItem
                let item = AVPlayerItem(asset: asset)
                
                // ✅ 关键配置：减少缓冲时间
                item.preferredForwardBufferDuration = 2.0 // 只缓冲 2 秒
                
                // ✅ 添加像素输出，用于精确探测首帧
                let pixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                let output = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBufferAttributes)
                item.add(output)
                self.videoOutput = output
                
                // 监听播放状态
                self.statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                    Task { @MainActor in
                        self?.handleItemStatusChange(item)
                    }
                }
                
                // 监听播放结束
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        self?.handlePlaybackFinished()
                    }
                }
                
                self.currentItem = item
                self.player?.replaceCurrentItem(with: item)
                
                #if DEBUG
                print("✅ VideoEngine - 视频素材已加载，等待 readyToPlay")
                #endif
            }
        }
    }
    
    /// 立即播放（不等待缓冲）
    /// - 使用 playImmediately API，系统会尽快开始播放
    func playImmediately() {
        guard let player = player else { return }
        
        // ✅ Mix模式：不静音，让LivePhoto和后台音乐共存
        player.isMuted = false
        
        #if DEBUG
        print("🎬 VideoEngine - 立即播放, isMuted: false（Mix模式）")
        #endif
        
        // ✅ 核心 API：立即播放，不等待缓冲
        player.playImmediately(atRate: 1.0)
        
        // ✅ 启动像素级首帧探测
        startProbingFirstFrame()
        
        // 触发震动反馈
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        // 开始监听进度
        startProgressObserver()
    }
    
    /// 启动首帧像素探测（比时间边界更精确）
    private func startProbingFirstFrame() {
        // 清理旧的 DisplayLink
        displayLink?.invalidate()
        
        // 创建 DisplayLink 探测真实像素
        let link = CADisplayLink(target: self, selector: #selector(onDisplayTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        
        #if DEBUG
        print("🔍 VideoEngine - 开始探测首帧像素")
        #endif
    }
    
    /// DisplayLink 回调：探测是否有新像素
    @objc private func onDisplayTick() {
        guard let output = videoOutput else { return }
        
        let hostTime = CACurrentMediaTime()
        let itemTime = output.itemTime(forHostTime: hostTime)
        
        // ✅ 真正拿到像素才算"首帧已渲染"
        if output.hasNewPixelBuffer(forItemTime: itemTime),
           let pixelBuffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
            
            // 停止探测
            displayLink?.invalidate()
            displayLink = nil
            
            #if DEBUG
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            print("🎞️ VideoEngine - 首帧像素已到达！尺寸: \(width)x\(height)")
            #endif
            
            // 触发回调
            onFirstFrameRendered?()
        }
    }
    
    /// 暂停播放
    func pause() {
        player?.pause()
        
        #if DEBUG
        print("⏸️ VideoEngine - 暂停播放")
        #endif
    }
    
    /// 停止播放并重置
    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        
        // ✅ 关键：清空 currentItem，避免最后一帧残留在背景
        player?.replaceCurrentItem(with: nil)
        
        // 停止所有观察者
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        // ✅ 停止像素探测
        displayLink?.invalidate()
        displayLink = nil
        videoOutput = nil
        
        isReadyToPlay = false
        isPlaying = false
        progress = 0.0
        
        #if DEBUG
        print("⏹️ VideoEngine - 停止播放，回到静止状态")
        #endif
    }
    
    /// 清理资源
    func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        // ✅ 清理像素探测
        displayLink?.invalidate()
        displayLink = nil
        videoOutput = nil
        
        statusObservation?.invalidate()
        statusObservation = nil
        currentItem = nil
        isReadyToPlay = false
        progress = 0.0
        
        #if DEBUG
        print("🧹 VideoEngine - 清理资源")
        #endif
    }
    
    // MARK: - Private Methods
    
    private func handleItemStatusChange(_ item: AVPlayerItem) {
        switch item.status {
        case .readyToPlay:
            isReadyToPlay = true
            
            #if DEBUG
            print("✅ VideoEngine - 视频准备完成，可以播放")
            #endif
            
            onReadyToPlay?()
            
        case .failed:
            #if DEBUG
            print("❌ VideoEngine - 视频播放失败: \(item.error?.localizedDescription ?? "未知错误")")
            #endif
            
        case .unknown:
            break
            
        @unknown default:
            break
        }
    }
    
    private func handlePlaybackFinished() {
        #if DEBUG
        print("✅ VideoEngine - 播放完成")
        #endif
        
        isPlaying = false
        progress = 1.0
        onPlaybackFinished?()
    }
    
    private func startProgressObserver() {
        guard let player = player else { return }
        
        // 每 0.1 秒更新一次进度
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let duration = self.currentItem?.duration.seconds,
                  duration.isFinite, duration > 0 else { return }
            
            let currentTime = time.seconds
            Task { @MainActor in
                self.progress = currentTime / duration
            }
        }
    }
}

