//
//  NotificationBadgeManager.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/30.
//

import SwiftUI
import Combine
import UIKit
import UserNotifications

/// 全局未读消息红点管理器
@MainActor
class NotificationBadgeManager: ObservableObject {

    static let shared = NotificationBadgeManager()

    @Published var unreadCount: Int = 0

    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    /// 上次刷新时间
    private var lastRefreshTime: Date = .distantPast
    /// 进入前台刷新的最小间隔（秒）
    private let foregroundRefreshInterval: TimeInterval = 30

    private init() {
        print("📬 NotificationBadgeManager: 初始化")

        // 首次加载
        Task {
            await refresh()
        }

        // 定时刷新（每 60 秒）
        startPeriodicRefresh()

        // 监听刷新通知（收到推送时触发）
        NotificationCenter.default.publisher(for: .refreshUnreadBadge)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)

        // 监听进入前台事件
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refreshIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 刷新未读数

    func refresh() async {
        // ✅ 检查登录状态，未登录时跳过请求
        guard OTOLoginStatusManager.shared.isLoggedIn else {
            print("📬 NotificationBadgeManager: 用户未登录，跳过刷新")
            return
        }

        do {
            let counts = try await NotificationService.shared.getUnreadCount()
            unreadCount = counts.total
            lastRefreshTime = Date()
            print("📬 NotificationBadgeManager: 刷新成功，未读数=\(counts.total)")

            // 更新 App 图标 badge
            updateAppIconBadge(counts.total)
        } catch {
            print("❌ NotificationBadgeManager: 获取未读数失败 - \(error)")
        }
    }

    /// 更新 App 图标角标
    private func updateAppIconBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error = error {
                print("❌ NotificationBadgeManager: 设置 App 图标 badge 失败 - \(error)")
            } else {
                print("📬 NotificationBadgeManager: App 图标 badge 已设置为 \(count)")
            }
        }
    }

    /// 检查间隔后刷新（用于进入前台）
    func refreshIfNeeded() async {
        let elapsed = Date().timeIntervalSince(lastRefreshTime)
        if elapsed >= foregroundRefreshInterval {
            print("📬 NotificationBadgeManager: 进入前台，距上次刷新 \(Int(elapsed))秒，执行刷新")
            await refresh()
        } else {
            print("📬 NotificationBadgeManager: 进入前台，距上次刷新 \(Int(elapsed))秒，跳过")
        }
    }

    // MARK: - 手动更新

    func decrementCount() {
        if unreadCount > 0 {
            unreadCount -= 1
        }
    }

    func clearCount() {
        unreadCount = 0
        updateAppIconBadge(0)
    }

    // MARK: - 定时刷新

    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }
}

// MARK: - NotificationBadge View

/// 显示未读消息数量的红点组件
struct NotificationBadge: View {
    @ObservedObject var manager: NotificationBadgeManager = .shared

    var body: some View {
        let _ = print("📬 NotificationBadge: 渲染，unreadCount=\(manager.unreadCount)")
        if manager.unreadCount > 0 {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: badgeSize, height: badgeSize)

                Text(formatCount)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private var formatCount: String {
        if manager.unreadCount > 999 {
            return "999+"
        }
        return "\(manager.unreadCount)"
    }

    private var badgeSize: CGFloat {
        let count = manager.unreadCount
        if count > 99 {
            return 24
        } else if count > 9 {
            return 20
        }
        return 18
    }

    private var fontSize: CGFloat {
        if manager.unreadCount > 99 {
            return 9
        }
        return 10
    }
}

#Preview {
    VStack(spacing: 20) {
        // 模拟按钮带红点
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 46, height: 46)

            NotificationBadge()
                .offset(x: 4, y: -4)
        }
    }
    .padding()
}
