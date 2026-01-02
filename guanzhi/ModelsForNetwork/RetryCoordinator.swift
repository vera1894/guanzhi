//
//  RetryCoordinator.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/2.
//  重试协调器 - 网络重试机制核心组件
//

import Foundation

/// 重试协调器
/// - 使用 actor 保证线程安全
/// - 原子操作避免竞态条件
/// - 支持冷却时间和飞行中请求检测
actor RetryCoordinator {
    // MARK: - 单例
    static let shared = RetryCoordinator()

    // MARK: - 私有属性
    private var lastAttemptAt: [String: Date] = [:]
    private var inFlightKeys: Set<String> = []
    private let defaultCooldown: TimeInterval = 5.0

    // MARK: - 公开方法

    /// 原子操作：检查是否允许重试，并标记开始
    /// - Parameters:
    ///   - key: 资源标识
    ///   - bypassCooldown: manual/pullToRefresh 时为 true，绕过冷却时间
    /// - Returns: 是否允许开始请求
    func beginIfAllowed(key: String, bypassCooldown: Bool = false) -> Bool {
        // 1. 检查是否在飞行中（任何情况都要检查）
        if inFlightKeys.contains(key) {
            print("⏳ [RetryCoordinator] [\(key)] 跳过：请求进行中")
            return false
        }

        // 2. 检查冷却时间（除非 bypassCooldown）
        if !bypassCooldown,
           let lastTime = lastAttemptAt[key],
           Date().timeIntervalSince(lastTime) < defaultCooldown {
            print("⏳ [RetryCoordinator] [\(key)] 跳过：冷却中 (\(String(format: "%.1f", defaultCooldown - Date().timeIntervalSince(lastTime)))s)")
            return false
        }

        // 3. 原子标记开始
        inFlightKeys.insert(key)
        lastAttemptAt[key] = Date()
        print("🚀 [RetryCoordinator] [\(key)] 开始请求")
        return true
    }

    /// 标记请求结束
    func finish(key: String) {
        inFlightKeys.remove(key)
        print("✅ [RetryCoordinator] [\(key)] 请求结束")
    }

    /// 检查是否有飞行中的请求
    func isInFlight(key: String) -> Bool {
        return inFlightKeys.contains(key)
    }

    /// 清除所有状态（用于测试或重置）
    func reset() {
        inFlightKeys.removeAll()
        lastAttemptAt.removeAll()
        print("🔄 [RetryCoordinator] 状态已重置")
    }

    // MARK: - Key 生成

    /// 生成资源 key
    static func key(for resource: RetryResource) -> String {
        switch resource {
        case .nearbyShares(let lat, let lng):
            // Gate 检查 #4：不用 String(format:)，避免 Locale 导致小数点变逗号
            // 使用整数化：精度 0.001 度 ≈ 111 米，足够避免频繁变化
            let latKey = Int((lat * 1000).rounded())
            let lngKey = Int((lng * 1000).rounded())
            return "shares-nearby-\(latKey)-\(lngKey)"
        case .shareDetail(let id):
            return "share-detail-\(id)"
        case .userProfile(let id):
            return "user-profile-\(id)"
        case .custom(let key):
            return key
        }
    }
}

// MARK: - 资源类型
enum RetryResource {
    case nearbyShares(lat: Double, lng: Double)
    case shareDetail(id: Int64)
    case userProfile(id: Int)
    case custom(key: String)
}

// MARK: - 刷新原因
enum RefreshReason {
    /// 页面出现时
    case onAppear
    /// 用户手动重试（绕过 cooldown）
    case manual
    /// 网络恢复自动触发（受 cooldown 限制）
    case networkRestored
    /// 下拉刷新（绕过 cooldown）
    case pullToRefresh

    /// 是否应该绕过冷却时间
    var shouldBypassCooldown: Bool {
        switch self {
        case .manual, .pullToRefresh:
            return true
        case .onAppear, .networkRestored:
            return false
        }
    }
}
