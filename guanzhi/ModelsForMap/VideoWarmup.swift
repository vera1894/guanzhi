//
//  VideoWarmup.swift
//  guanzhi
//
//  Created by Claude on 2025/01/11.
//

import AVFoundation
import Foundation

/// VideoWarmup：全局视频解码器预热
/// - 目的：消除首次播放的冷启动延迟和闪烁
/// - 原理：在 App 启动或进入详情页时预热 VideoToolbox 解码器和渲染通道
@MainActor
enum VideoWarmup {
    /// 是否已预热
    private static var didPrime = false
    
    /// 预热视频解码器
    /// - Parameter url: 任意视频 URL（建议使用第一条 LivePhoto 的 mov）
    static func prime(with url: URL) {
        guard !didPrime else {
            #if DEBUG
            print("🔥 VideoWarmup - 已预热过，跳过")
            #endif
            return
        }
        
        didPrime = true
        
        #if DEBUG
        print("🔥 VideoWarmup - 开始预热视频解码器: \(url.lastPathComponent)")
        #endif
        
        // 创建临时播放器
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true // 静音
        
        // 极慢速播放（0.1倍速），只为激活解码器
        player.playImmediately(atRate: 0.1)
        
        // 250ms 后停止
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            player.pause()
            
            #if DEBUG
            print("✅ VideoWarmup - 预热完成")
            #endif
        }
    }
    
    /// 重置预热状态（用于测试）
    static func reset() {
        didPrime = false
        
        #if DEBUG
        print("🔄 VideoWarmup - 预热状态已重置")
        #endif
    }
}

