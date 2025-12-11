//
//  StickerMotionManager.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/10.
//
//  贴纸运动管理器 - CoreMotion 封装
//

import CoreMotion
import Combine

// MARK: - StickerMotionManager

/// 贴纸运动管理器
/// 封装 CoreMotion 功能，提供设备重力向量
final class StickerMotionManager: ObservableObject {

    // MARK: - 属性（不使用 @Published 避免频繁触发 SwiftUI 更新）

    /// 当前重力 X 分量（-1.0 到 1.0，左负右正）
    private(set) var gravityX: CGFloat = 0

    /// 当前重力 Y 分量（-1.0 到 1.0，下负上正）
    private(set) var gravityY: CGFloat = 0

    /// 设备是否大致水平放置
    var isDeviceFlat: Bool {
        abs(gravityX) < 0.1 && abs(gravityY) < 0.1
    }

    // MARK: - 状态

    /// 是否可用
    var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return motionManager.isDeviceMotionAvailable
        #endif
    }

    /// 是否正在运行
    private(set) var isRunning = false

    // MARK: - 私有属性

    private let motionManager = CMMotionManager()
    private let updateInterval: TimeInterval = 1.0 / 30.0  // 30Hz 足够了，降低 CPU 占用

    // MARK: - 初始化

    init() {
        #if targetEnvironment(simulator)
        print("[StickerMotionManager] Running in simulator, motion data unavailable")
        #endif
    }

    deinit {
        stop()
    }

    // MARK: - 公开方法

    /// 开始监听设备运动
    func start() {
        guard !isRunning else { return }

        #if targetEnvironment(simulator)
        // 模拟器使用默认值
        isRunning = true
        return
        #endif

        guard motionManager.isDeviceMotionAvailable else {
            print("[StickerMotionManager] Device motion not available on this device")
            return
        }

        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self else { return }

            if let error = error {
                print("[StickerMotionManager] Error: \(error.localizedDescription)")
                return
            }

            guard let motion = motion else { return }

            // 更新重力值
            self.gravityX = CGFloat(motion.gravity.x)
            self.gravityY = CGFloat(motion.gravity.y)
        }

        isRunning = true
        print("[StickerMotionManager] Started")
    }

    /// 停止监听
    func stop() {
        guard isRunning else { return }

        #if !targetEnvironment(simulator)
        motionManager.stopDeviceMotionUpdates()
        #endif

        isRunning = false
        gravityX = 0
        gravityY = 0
        print("[StickerMotionManager] Stopped")
    }

    /// 重置重力值
    func reset() {
        gravityX = 0
        gravityY = 0
    }
}

// MARK: - 扩展：调试用

#if DEBUG
extension StickerMotionManager {

    /// 模拟重力（仅用于调试）
    func simulateGravity(x: CGFloat, y: CGFloat) {
        gravityX = x
        gravityY = y
    }

    /// 模拟向左倾斜
    func simulateTiltLeft() {
        simulateGravity(x: -0.5, y: -0.8)
    }

    /// 模拟向右倾斜
    func simulateTiltRight() {
        simulateGravity(x: 0.5, y: -0.8)
    }

    /// 模拟水平放置
    func simulateFlat() {
        simulateGravity(x: 0, y: 0)
    }
}
#endif
