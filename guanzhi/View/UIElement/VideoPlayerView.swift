//
//  VideoPlayerView.swift
//  guanzhi
//
//  Created by Claude on 2025/11/18.
//

import SwiftUI
import AVFoundation
import QuartzCore

/// VideoPlayerView：基于 AVPlayerLayer 的自定义视频播放视图
/// - 比 SwiftUI 的 VideoPlayer 启动更快
/// - 支持淡入淡出动画
/// - 可精确控制播放行为
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer?
    let shouldPlay: Bool
    let isSelected: Bool
    let onReadyForDisplay: (() -> Void)?
    
    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.onReadyForDisplay = onReadyForDisplay
        
        #if DEBUG
        print("🎬 VideoPlayerView makeUIView - NEW VIEW CREATED (全局 Overlay)")
        // ✅ 断言：全局 Overlay 应该永远只创建一次
        // 如果看到多次 NEW VIEW CREATED，说明 SwiftUI 错误地重建了视图
        #endif
        
        return view
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {
        // 更新回调
        uiView.onReadyForDisplay = onReadyForDisplay
        
        // 更新播放器
        if uiView.player !== player {
            uiView.setPlayer(player)
            
            #if DEBUG
            if let player = player {
                print("🔄 VideoPlayerView - 播放器对象变化: \(Unmanaged.passUnretained(player).toOpaque())")
            } else {
                print("🔄 VideoPlayerView - 播放器对象变为 nil")
            }
            #endif
        }
        
        // ✅ 确保视图层正确设置（统一使用 resizeAspectFill）
        uiView.playerLayer.videoGravity = .resizeAspectFill
        uiView.backgroundColor = .clear
        
        // 控制播放/暂停（但不干涉 VideoEngine 的控制）
        if !shouldPlay || !isSelected {
            // 只在需要暂停时才暂停
            if player?.rate ?? 0 > 0 {
                player?.pause()
                
                #if DEBUG
                print("⏸️ VideoPlayerView - 暂停播放")
                #endif
            }
        }
    }
    
    // MARK: - PlayerView
    
    /// 内部 UIView 类，包装 AVPlayerLayer
    class PlayerView: UIView {
        
        override class var layerClass: AnyClass {
            AVPlayerLayer.self
        }
        
        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }
        
        var onReadyForDisplay: (() -> Void)?
        private var displayObservation: NSKeyValueObservation?
        
        // ✅ 确保视图和图层都是透明的
        override init(frame: CGRect) {
            super.init(frame: frame)
            isOpaque = false
            backgroundColor = .clear
            playerLayer.isOpaque = false
            playerLayer.backgroundColor = UIColor.clear.cgColor
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        var player: AVPlayer? {
            get {
                playerLayer.player
            }
            set {
                playerLayer.player = newValue
            }
        }
        
    func setPlayer(_ player: AVPlayer?) {
        playerLayer.player = player
        // ✅ 使用 resizeAspectFill，与封面保持一致的填充策略
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = UIColor.clear.cgColor
        
        // ✅ 核心修复：禁用 AVPlayerLayer 的隐式动画，防止闪烁
        playerLayer.actions = [
            "contents": NSNull(),
            "bounds": NSNull(),
            "position": NSNull(),
            "onOrderIn": NSNull(),
            "onOrderOut": NSNull(),
            "hidden": NSNull()
        ]
        
        // ✅ 关键：监听第一帧可显示（但不直接隐藏封面，只上报）
        displayObservation = playerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] layer, _ in
            guard let self = self else { return }
            if layer.isReadyForDisplay {
                #if DEBUG
                print("📺 PlayerView - 图层可显示（isReadyForDisplay = true）")
                #endif
                DispatchQueue.main.async {
                    self.onReadyForDisplay?()
                }
            }
        }
        
        #if DEBUG
        print("📺 PlayerView - 设置播放器, videoGravity: \(playerLayer.videoGravity), bounds: \(bounds)")
        #endif
    }
    
    // ✅ 新增：查询是否已准备好显示（用于复播判断）
    var isReady: Bool {
        playerLayer.isReadyForDisplay
    }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            // ✅ 使用 CATransaction 防止布局动画闪烁
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = bounds
            CATransaction.commit()
            
            #if DEBUG
            print("📐 PlayerView - layoutSubviews, bounds: \(bounds), playerLayer.frame: \(playerLayer.frame)")
            #endif
        }
        
        deinit {
            displayObservation?.invalidate()
        }
    }
}

