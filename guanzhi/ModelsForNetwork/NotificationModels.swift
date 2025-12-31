//
//  NotificationModels.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/30.
//

import Foundation

// MARK: - 消息分类

/// 消息分类（rawValue 用英文，UI 用 title）
enum MessageCategory: String, CaseIterable, Codable {
    case interaction  // 互动消息
    case system       // 系统消息

    var title: String {
        switch self {
        case .interaction: return "互动"
        case .system: return "系统"
        }
    }

    var icon: String {
        switch self {
        case .interaction: return "bell.fill"
        case .system: return "megaphone.fill"
        }
    }
}

// MARK: - 通知类型

/// 通知类型（与后端 NotificationDO.TYPE_* 对应）
enum NotificationType: String, Codable {
    case commentReply = "COMMENT_REPLY"
    case commentLike = "COMMENT_LIKE"
    case newComment = "NEW_COMMENT"
    case stickerReceived = "STICKER_RECEIVED"
    case system = "SYSTEM"
    case unknown = "UNKNOWN"

    /// 所属分类
    var category: MessageCategory {
        switch self {
        case .system:
            return .system
        default:
            return .interaction
        }
    }

    /// 消息标题格式
    func titleFormat(userName: String?, stickerName: String? = nil) -> String {
        let name = userName ?? "用户"
        switch self {
        case .commentReply:
            return "\(name) 回复了你"
        case .commentLike:
            return "\(name) 赞了你的评论"
        case .newComment:
            return "\(name) 评论了你的观之"
        case .stickerReceived:
            let sticker = stickerName ?? "贴纸"
            return "\(name) 给你贴了「\(sticker)」"
        case .system:
            return "系统通知"
        case .unknown:
            return "通知"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = NotificationType(rawValue: rawValue) ?? .unknown
    }
}

// MARK: - 通知消息模型

/// 通知消息（对应后端 NotificationVO）
struct NotificationMessage: Identifiable, Codable {
    let id: Int64
    let type: NotificationType
    let content: String
    let shareId: Int64?
    let commentId: Int64?
    let fromUserId: Int?
    let fromUserName: String?
    let fromUserAvatar: String?
    let status: String           // "UNREAD" / "READ"
    let createdAt: Int64         // 毫秒时间戳（后端原始值）
    let deepLink: String?

    /// 转换为 Date（UI 展示用）
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000)
    }

    /// 是否未读
    var isUnread: Bool {
        status == "UNREAD"
    }

    /// 格式化的时间显示
    var formattedTime: String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else if interval < 86400 * 2 {
            return "昨天"
        } else if interval < 86400 * 7 {
            let days = Int(interval / 86400)
            return "\(days)天前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: date)
        }
    }

    /// 头像 URL
    var avatarURL: URL? {
        guard let avatar = fromUserAvatar, !avatar.isEmpty else { return nil }
        if avatar.hasPrefix("http") {
            return URL(string: avatar)
        } else {
            return URL(string: "\(Constants.BASE_HOST)\(avatar)")
        }
    }
}

// MARK: - 未读数统计

/// 未读数统计
struct UnreadCount: Codable {
    let interaction: Int?  // 互动消息未读数
    let system: Int?       // 系统消息未读数
    let total: Int         // 总未读数

    /// 获取指定分类的未读数
    func count(for category: MessageCategory) -> Int {
        switch category {
        case .interaction:
            return interaction ?? 0
        case .system:
            return system ?? 0
        }
    }
}

// MARK: - API 响应模型

/// 通知列表响应
struct NotificationListResponse: Codable {
    let respCode: Int
    let respMsg: String?
    let datas: NotificationListData?
}

struct NotificationListData: Codable {
    let total: Int
    let list: [NotificationMessage]
}

/// 未读数响应
struct UnreadCountResponse: Codable {
    let respCode: Int
    let respMsg: String?
    let datas: UnreadCount?
}

/// 通用操作响应
struct NotificationActionResponse: Codable {
    let respCode: Int
    let respMsg: String?
    let datas: Bool?  // 操作是否成功
}

// MARK: - 通知偏好设置模型 (V1.5)

/// 单个事件的通知偏好
struct NotificationEventPreference: Codable, Identifiable {
    let eventCode: String
    let eventName: String
    let eventGroup: String
    var pushEnabled: Bool
    var inAppEnabled: Bool

    var id: String { eventCode }
}

/// 偏好设置数据
struct NotificationPreferencesData: Codable {
    let globalPushEnabled: Bool
    let preferences: [NotificationEventPreference]
}

/// 偏好设置响应
struct NotificationPreferencesResponse: Codable {
    let respCode: Int
    let respMsg: String?
    let datas: NotificationPreferencesData?
}

/// 偏好更新项
struct PreferenceUpdateItem: Codable {
    let eventCode: String
    let pushEnabled: Bool
    let inAppEnabled: Bool
}

/// 偏好设置更新请求
struct NotificationPreferencesUpdateRequest: Codable {
    let globalPushEnabled: Bool?
    let preferences: [PreferenceUpdateItem]?

    /// 转换为字典（用于网络请求）
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let globalPushEnabled = globalPushEnabled {
            dict["globalPushEnabled"] = globalPushEnabled
        }
        if let preferences = preferences {
            dict["preferences"] = preferences.map { pref in
                [
                    "eventCode": pref.eventCode,
                    "pushEnabled": pref.pushEnabled,
                    "inAppEnabled": pref.inAppEnabled
                ]
            }
        }
        return dict
    }
}

// MARK: - 聚合显示项（用于 UI 展示）

/// 用于展示的消息项（可能是单条消息或聚合消息）
enum DisplayableMessage: Identifiable {
    case single(NotificationMessage)
    case aggregatedStickers(AggregatedStickerNotification)

    var id: String {
        switch self {
        case .single(let msg):
            return "single_\(msg.id)"
        case .aggregatedStickers(let agg):
            return "agg_sticker_\(agg.shareId)"
        }
    }

    /// 是否有未读
    var hasUnread: Bool {
        switch self {
        case .single(let msg):
            return msg.isUnread
        case .aggregatedStickers(let agg):
            return agg.hasUnread
        }
    }

    /// 最近时间
    var latestTime: Date {
        switch self {
        case .single(let msg):
            return msg.date
        case .aggregatedStickers(let agg):
            return agg.latestTime
        }
    }
}

/// 聚合的贴纸通知（同一分享的多个贴纸通知合并显示）
struct AggregatedStickerNotification: Identifiable {
    let shareId: Int64
    let notifications: [NotificationMessage]

    var id: Int64 { shareId }

    /// 包含的通知 ID 列表（用于批量标记已读）
    var notificationIds: [Int64] {
        notifications.map { $0.id }
    }

    /// 贴纸数量
    var stickerCount: Int {
        notifications.count
    }

    /// 参与用户列表（去重，保持顺序）
    var users: [(id: Int?, name: String?, avatar: String?)] {
        var seen = Set<Int>()
        var result: [(id: Int?, name: String?, avatar: String?)] = []
        for n in notifications {
            if let userId = n.fromUserId {
                if !seen.contains(userId) {
                    seen.insert(userId)
                    result.append((id: userId, name: n.fromUserName, avatar: n.fromUserAvatar))
                }
            } else {
                result.append((id: nil, name: n.fromUserName, avatar: n.fromUserAvatar))
            }
        }
        return result
    }

    /// 用户数量
    var userCount: Int {
        users.count
    }

    /// 标题格式
    var title: String {
        let userList = users
        if userList.count == 1 {
            let name = userList[0].name ?? "用户"
            return "\(name) 给你贴了贴纸"
        } else if userList.count == 2 {
            let name1 = userList[0].name ?? "用户"
            let name2 = userList[1].name ?? "用户"
            return "\(name1)、\(name2) 给你贴了贴纸"
        } else {
            let firstName = userList[0].name ?? "用户"
            return "\(firstName) 等\(userList.count)人给你贴了贴纸"
        }
    }

    /// 内容摘要（贴纸数量）
    var contentSummary: String {
        if stickerCount == 1 {
            return notifications.first?.content ?? ""
        }
        return "共收到 \(stickerCount) 个贴纸"
    }

    /// 是否有未读
    var hasUnread: Bool {
        notifications.contains { $0.isUnread }
    }

    /// 最近的通知时间
    var latestTime: Date {
        notifications.map { $0.date }.max() ?? Date()
    }

    /// 格式化的时间显示
    var formattedTime: String {
        let now = Date()
        let interval = now.timeIntervalSince(latestTime)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else if interval < 86400 * 2 {
            return "昨天"
        } else if interval < 86400 * 7 {
            let days = Int(interval / 86400)
            return "\(days)天前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: latestTime)
        }
    }

    /// 第一个用户的头像 URL
    var primaryAvatarURL: URL? {
        guard let avatar = users.first?.avatar, !avatar.isEmpty else { return nil }
        if avatar.hasPrefix("http") {
            return URL(string: avatar)
        } else {
            return URL(string: "\(Constants.BASE_HOST)\(avatar)")
        }
    }

    /// Deep Link（跳转到分享详情）
    var deepLink: String {
        "guanzhi://share/\(shareId)"
    }
}
