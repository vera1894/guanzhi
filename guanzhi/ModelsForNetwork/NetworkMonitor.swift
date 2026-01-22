//
//  NetworkMonitor.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/2.
//  网络状态监听器 - 网络重试机制核心组件
//

import Foundation
import Network
import Combine

/// 网络状态监听器
/// - 监听网络连接状态变化
/// - 在网络恢复或切换时发送通知
/// - 支持 WiFi/蜂窝/以太网 类型识别
class NetworkMonitor: ObservableObject {
    // MARK: - 单例
    // Gate 检查 #5：单例必须常驻，App 启动时访问一次确保初始化
    static let shared = NetworkMonitor()

    // MARK: - Published 属性
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    // MARK: - 私有属性
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.guanzhi.NetworkMonitor")

    // P1 改进：防抖 - 避免快速切换网络时产生通知风暴
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.5  // 500ms 防抖

    // MARK: - 连接类型
    enum ConnectionType: Equatable {
        case wifi
        case cellular
        case ethernet
        case unknown

        var description: String {
            switch self {
            case .wifi: return "WiFi"
            case .cellular: return "蜂窝网络"
            case .ethernet: return "以太网"
            case .unknown: return "未知"
            }
        }
    }

    // MARK: - 初始化
    private init() {
        startMonitoring()
    }

    // MARK: - 监听方法
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }

                let wasDisconnected = !self.isConnected
                let newConnectionType = self.getConnectionType(path)
                // P0 修复：先保存当前值到局部变量，再比较
                let oldType = self.connectionType
                let connectionTypeChanged = oldType != newConnectionType

                self.isConnected = path.status == .satisfied
                self.connectionType = newConnectionType

                // 触发条件扩展：不只是 disconnected → connected
                // 还包括 connectionType 变化（WiFi ↔ Cellular）
                if path.status == .satisfied {
                    if wasDisconnected {
                        // 从断网恢复：立即通知（用户等待已久）
                        print("📶 [NetworkMonitor] 网络恢复: \(newConnectionType.description)")
                        NotificationCenter.default.post(name: .networkRestored, object: nil)
                    } else if connectionTypeChanged {
                        // P1 改进：网络类型切换使用防抖
                        // 避免 WiFi ↔ 蜂窝 快速切换时产生多次通知
                        print("📶 [NetworkMonitor] 网络切换: \(oldType.description) → \(newConnectionType.description)")
                        self.debounceWorkItem?.cancel()
                        let workItem = DispatchWorkItem {
                            NotificationCenter.default.post(name: .networkChanged, object: nil)
                        }
                        self.debounceWorkItem = workItem
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + self.debounceInterval,
                            execute: workItem
                        )
                    }
                } else {
                    print("📶 [NetworkMonitor] 网络断开")
                }
            }
        }
        monitor.start(queue: queue)
        print("📶 [NetworkMonitor] 开始监听网络状态")
    }

    func stopMonitoring() {
        monitor.cancel()
        debounceWorkItem?.cancel()
        print("📶 [NetworkMonitor] 停止监听网络状态")
    }

    // MARK: - 私有方法
    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        return .unknown
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    /// 网络从断开恢复连接
    static let networkRestored = Notification.Name("com.guanzhi.networkRestored")
    /// 网络类型切换（WiFi ↔ 蜂窝）
    static let networkChanged = Notification.Name("com.guanzhi.networkChanged")
    /// Token 已过期，需要重新登录
    static let tokenExpired = Notification.Name("com.guanzhi.tokenExpired")
}
