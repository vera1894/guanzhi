//
//  NotificationService.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/30.
//

import Foundation

/// 通知服务
class NotificationService {

    static let shared = NotificationService()

    private init() {}

    // MARK: - 获取通知列表

    /// 获取通知列表
    /// - Parameters:
    ///   - category: 消息分类（nil 表示全部）
    ///   - status: 状态筛选（"UNREAD"/"READ"，nil 表示全部）
    ///   - page: 页码（从 1 开始）
    ///   - size: 每页数量
    /// - Returns: 通知列表数据
    func getNotifications(
        category: MessageCategory? = nil,
        status: String? = nil,
        page: Int = 1,
        size: Int = 20
    ) async throws -> NotificationListData {
        print("📬 NotificationService: 获取通知列表...")
        print("   分类: \(category?.rawValue ?? "全部")")
        print("   状态: \(status ?? "全部")")
        print("   页码: \(page), 每页: \(size)")

        let data = try await OTONetwork.request(.getNotifications(
            category: category?.rawValue,
            status: status,
            page: page,
            size: size
        ))

        let decoder = JSONDecoder()
        let response = try decoder.decode(NotificationListResponse.self, from: data)

        guard response.respCode == 0, let listData = response.datas else {
            print("❌ NotificationService: 获取通知列表失败 - \(response.respMsg ?? "未知错误")")
            throw OTONetworkError.customError(response.respMsg ?? "获取通知列表失败")
        }

        print("✅ NotificationService: 获取到 \(listData.list.count) 条通知，共 \(listData.total) 条")
        return listData
    }

    // MARK: - 获取未读数量

    /// 获取未读数量
    /// - Returns: 未读数统计
    func getUnreadCount() async throws -> UnreadCount {
        print("📬 NotificationService: 获取未读数量...")

        let data = try await OTONetwork.request(.getUnreadCount)

        // 打印原始响应用于调试
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📬 NotificationService: 原始响应 = \(jsonString)")
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(UnreadCountResponse.self, from: data)

        guard response.respCode == 0, let unreadCount = response.datas else {
            print("❌ NotificationService: 获取未读数量失败 - \(response.respMsg ?? "未知错误")")
            throw OTONetworkError.customError(response.respMsg ?? "获取未读数量失败")
        }

        print("✅ NotificationService: 未读数 - 互动: \(unreadCount.interaction ?? 0), 系统: \(unreadCount.system ?? 0), 总计: \(unreadCount.total)")
        return unreadCount
    }

    // MARK: - 标记已读

    /// 标记单条通知已读
    /// - Parameter id: 通知 ID
    func markAsRead(id: Int64) async throws {
        print("📬 NotificationService: 标记通知 \(id) 已读...")

        let data = try await OTONetwork.request(.markNotificationRead(id: id))

        let decoder = JSONDecoder()
        let response = try decoder.decode(NotificationActionResponse.self, from: data)

        guard response.respCode == 0 else {
            print("❌ NotificationService: 标记已读失败 - \(response.respMsg ?? "未知错误")")
            throw OTONetworkError.customError(response.respMsg ?? "标记已读失败")
        }

        print("✅ NotificationService: 通知 \(id) 已标记为已读")
    }

    /// 标记全部通知已读
    /// - Parameter category: 分类（nil 表示全部，"interaction" 互动，"system" 系统）
    func markAllAsRead(category: String? = nil) async throws {
        let categoryDesc = category ?? "全部"
        print("📬 NotificationService: 标记\(categoryDesc)通知已读...")

        let data = try await OTONetwork.request(.markAllNotificationsRead(category: category))

        let decoder = JSONDecoder()
        let response = try decoder.decode(NotificationActionResponse.self, from: data)

        guard response.respCode == 0 else {
            print("❌ NotificationService: 标记全部已读失败 - \(response.respMsg ?? "未知错误")")
            throw OTONetworkError.customError(response.respMsg ?? "标记全部已读失败")
        }

        print("✅ NotificationService: \(categoryDesc)通知已标记为已读")
    }

    // MARK: - 删除通知

    /// 删除单条通知
    /// - Parameter id: 通知 ID
    func deleteNotification(id: Int64) async throws {
        print("📬 NotificationService: 删除通知 \(id)...")

        let data = try await OTONetwork.request(.deleteNotification(id: id))

        // 打印原始响应用于调试
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📬 NotificationService: 删除响应 = \(jsonString)")
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(NotificationActionResponse.self, from: data)

        guard response.respCode == 0 else {
            print("❌ NotificationService: 删除通知失败 - \(response.respMsg ?? "未知错误")")
            throw OTONetworkError.customError(response.respMsg ?? "删除通知失败")
        }

        print("✅ NotificationService: 通知 \(id) 已删除")
    }

    // MARK: - 通知偏好设置 (V1.5)

    /// 获取用户通知偏好设置
    /// - Returns: 偏好设置数据
    func getPreferences() async throws -> NotificationPreferencesData {
        print("📬 NotificationService: 获取通知偏好设置...")

        let data = try await OTONetwork.request(.getNotificationPreferences)

        let decoder = JSONDecoder()
        let response = try decoder.decode(NotificationPreferencesResponse.self, from: data)

        guard response.respCode == 0, let prefsData = response.datas else {
            print("❌ NotificationService: 获取偏好设置失败 - \(response.respMsg ?? "未知错误")")
            throw OTONetworkError.customError(response.respMsg ?? "获取偏好设置失败")
        }

        print("✅ NotificationService: 获取到 \(prefsData.preferences.count) 个事件偏好")
        return prefsData
    }

    /// 更新全局推送开关
    /// - Parameter enabled: 是否启用推送
    func updateGlobalPushEnabled(_ enabled: Bool) async throws {
        print("📬 NotificationService: 更新全局推送开关 -> \(enabled)")

        let data = try await OTONetwork.request(.updateNotificationPreferences(
            globalPushEnabled: enabled,
            preferences: nil
        ))

        let decoder = JSONDecoder()
        let response = try decoder.decode(NotificationActionResponse.self, from: data)

        guard response.respCode == 0 else {
            print("❌ NotificationService: 更新全局开关失败 - \(response.respMsg ?? "未知错误")")
            throw OTONetworkError.customError(response.respMsg ?? "更新失败")
        }

        print("✅ NotificationService: 全局推送开关已更新为 \(enabled)")
    }

    /// 更新单个事件的推送开关
    /// - Parameters:
    ///   - eventCode: 事件代码
    ///   - pushEnabled: 是否启用推送
    func updateEventPreference(eventCode: String, pushEnabled: Bool) async throws {
        print("📬 NotificationService: 更新事件偏好 \(eventCode) -> \(pushEnabled)")

        let prefItem = PreferenceUpdateItem(
            eventCode: eventCode,
            pushEnabled: pushEnabled,
            inAppEnabled: true  // 站内通知始终开启
        )

        let data = try await OTONetwork.request(.updateNotificationPreferences(
            globalPushEnabled: nil,
            preferences: [prefItem]
        ))

        let decoder = JSONDecoder()
        let response = try decoder.decode(NotificationActionResponse.self, from: data)

        guard response.respCode == 0 else {
            print("❌ NotificationService: 更新事件偏好失败 - \(response.respMsg ?? "未知错误")")
            throw OTONetworkError.customError(response.respMsg ?? "更新失败")
        }

        print("✅ NotificationService: 事件 \(eventCode) 推送开关已更新为 \(pushEnabled)")
    }
}
