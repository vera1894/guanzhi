//
//  NotificationModels.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/30.
//

import Foundation

// MARK: - 消息分类

/// 消息分类（rawValue 用大写英文匹配后端，UI 用 title）
enum MessageCategory: String, CaseIterable, Codable {
    case interaction = "INTERACTION"  // 互动消息
    case system = "SYSTEM"            // 系统消息

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
    // V1.0 类型
    case commentReply = "COMMENT_REPLY"
    case commentLike = "COMMENT_LIKE"
    case newComment = "NEW_COMMENT"
    case stickerReceived = "STICKER_RECEIVED"
    case system = "SYSTEM"

    // V2.0 类型
    case levelUp = "LEVEL_UP"               // 用户升级
    case userWarned = "USER_WARNED"         // 用户被警告
    case userFrozen = "USER_FROZEN"         // 用户被冻结
    case shareRemoved = "SHARE_REMOVED"     // 观之被删除
    case reportResult = "REPORT_RESULT"     // 举报处理结果
    case fadeWarning = "FADE_WARNING"       // 观之即将褪色
    case fadeComplete = "FADE_COMPLETE"     // 观之已褪色

    case unknown = "UNKNOWN"

    /// 所属分类
    var category: MessageCategory {
        switch self {
        // 互动消息
        case .commentReply, .commentLike, .newComment, .stickerReceived:
            return .interaction
        // 系统消息
        case .system, .levelUp, .userWarned, .userFrozen, .shareRemoved,
             .reportResult, .fadeWarning, .fadeComplete, .unknown:
            return .system
        }
    }

    /// 消息标题格式
    func titleFormat(userName: String?, stickerName: String? = nil) -> String {
        let name = userName ?? "用户"
        switch self {
        // V1.0 类型
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

        // V2.0 类型
        case .levelUp:
            return "恭喜升级"
        case .userWarned:
            return "账号警告"
        case .userFrozen:
            return "账号冻结"
        case .shareRemoved:
            return "内容被移除"
        case .reportResult:
            return "举报处理结果"
        case .fadeWarning:
            return "观之即将褪色"
        case .fadeComplete:
            return "观之已褪色"

        case .unknown:
            return "通知"
        }
    }

    /// 是否需要特殊图标（非观之缩略图）
    /// 与特定观之相关的消息应该显示观之缩略图，纯系统消息才显示系统图标
    var usesSystemIcon: Bool {
        switch self {
        // 互动消息：显示观之缩略图
        case .commentReply, .commentLike, .newComment, .stickerReceived:
            return false
        // 褪色相关：显示观之缩略图（因为是针对特定观之的）
        case .fadeWarning, .fadeComplete, .shareRemoved:
            return false
        // 纯系统消息：显示系统图标
        default:
            return true
        }
    }

    /// 系统消息的 SF Symbol 图标名称
    var systemIconName: String {
        switch self {
        case .system:
            return "megaphone.fill"           // 系统通知
        case .levelUp:
            return "arrow.up.circle.fill"     // 升级
        case .userWarned:
            return "exclamationmark.triangle.fill"  // 警告
        case .userFrozen:
            return "snowflake"                // 冻结
        case .shareRemoved:
            return "trash.fill"               // 内容被删除
        case .reportResult:
            return "checkmark.shield.fill"    // 举报结果
        case .fadeWarning:
            return "clock.badge.exclamationmark.fill"  // 即将褪色
        case .fadeComplete:
            return "moon.zzz.fill"            // 已褪色
        default:
            return "bell.fill"                // 默认铃铛
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = NotificationType(rawValue: rawValue) ?? .unknown
    }
}

// MARK: - 时间格式化辅助

/// 通知模块专用的时间格式化工具
/// 使用 TimeKit 统一处理时间
private enum NotificationDateHelper {
    /// 格式化为相对时间显示（MainActor，用于 UI）
    /// 使用 TimeDisplay.shared.smartTime() 统一处理
    @MainActor
    static func formatRelativeTime(_ date: Date) -> String {
        return TimeDisplay.shared.smartTime(from: date)
    }

    /// 格式化为 UTC 字符串（用于编码，非 MainActor）
    /// 使用 ServerTime.formatUTCString() 统一处理
    static func formatToUTCString(_ date: Date) -> String {
        return ServerTime.formatUTCString(date)
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
    let shareThumbnail: String?  // 相关观之的缩略图 URL
    let statusCode: Int          // 0 = UNREAD, 1 = READ
    let createdAtDate: Date      // 解析后的日期
    let deepLink: String?

    /// 自定义解码（处理后端特殊格式）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int64.self, forKey: .id)
        type = try container.decode(NotificationType.self, forKey: .type)
        content = try container.decode(String.self, forKey: .content)
        shareId = try container.decodeIfPresent(Int64.self, forKey: .shareId)
        commentId = try container.decodeIfPresent(Int64.self, forKey: .commentId)
        fromUserId = try container.decodeIfPresent(Int.self, forKey: .fromUserId)
        fromUserName = try container.decodeIfPresent(String.self, forKey: .fromUserName)
        fromUserAvatar = try container.decodeIfPresent(String.self, forKey: .fromUserAvatar)
        shareThumbnail = try container.decodeIfPresent(String.self, forKey: .shareThumbnail)
        deepLink = try container.decodeIfPresent(String.self, forKey: .deepLink)

        // 解析 status（后端返回数字 0/1）
        statusCode = try container.decode(Int.self, forKey: .status)

        // 解析 createdAt（后端返回 UTC 时间数组或字符串）
        createdAtDate = NotificationMessage.parseCreatedAt(from: container)
    }

    /// 解析 createdAtMs（毫秒时间戳）
    /// 后端字段名为 createdAtMs，返回毫秒级 UTC 时间戳
    private static func parseCreatedAt(from container: KeyedDecodingContainer<CodingKeys>) -> Date {
        // 解析毫秒时间戳（后端字段名 createdAtMs）
        if let timestamp = try? container.decode(Int64.self, forKey: .createdAtMs) {
            let result = ServerTime.parse(milliseconds: timestamp)
            print("📅 [Notification] 解析时间戳: \(timestamp) -> \(result)")
            return result
        }
        print("⚠️ [Notification] 时间解析失败，使用当前时间")
        return Date()
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, content, shareId, commentId
        case fromUserId, fromUserName, fromUserAvatar, shareThumbnail
        case status, deepLink
        case createdAtMs  // 后端返回毫秒时间戳字段名
    }

    /// 编码（Encodable 协议要求）
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(shareId, forKey: .shareId)
        try container.encodeIfPresent(commentId, forKey: .commentId)
        try container.encodeIfPresent(fromUserId, forKey: .fromUserId)
        try container.encodeIfPresent(fromUserName, forKey: .fromUserName)
        try container.encodeIfPresent(fromUserAvatar, forKey: .fromUserAvatar)
        try container.encodeIfPresent(shareThumbnail, forKey: .shareThumbnail)
        try container.encode(statusCode, forKey: .status)
        // 转换为毫秒时间戳
        let timestamp = Int64(createdAtDate.timeIntervalSince1970 * 1000)
        try container.encode(timestamp, forKey: .createdAtMs)
        try container.encodeIfPresent(deepLink, forKey: .deepLink)
    }

    /// 内部初始化器（用于 Preview 和测试）
    init(
        id: Int64,
        type: NotificationType,
        content: String,
        shareId: Int64? = nil,
        commentId: Int64? = nil,
        fromUserId: Int? = nil,
        fromUserName: String? = nil,
        fromUserAvatar: String? = nil,
        shareThumbnail: String? = nil,
        statusCode: Int,
        createdAtDate: Date,
        deepLink: String? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.shareId = shareId
        self.commentId = commentId
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.fromUserAvatar = fromUserAvatar
        self.shareThumbnail = shareThumbnail
        self.statusCode = statusCode
        self.createdAtDate = createdAtDate
        self.deepLink = deepLink
    }

    /// 转换为 Date（UI 展示用）
    var date: Date {
        createdAtDate
    }

    /// 是否未读
    var isUnread: Bool {
        statusCode == 0
    }

    /// 格式化的时间显示（MainActor，用于 UI）
    @MainActor
    var formattedTime: String {
        NotificationDateHelper.formatRelativeTime(date)
    }

    /// 头像 URL
    var avatarURL: URL? {
        guard let avatar = fromUserAvatar, !avatar.isEmpty else { return nil }
        if avatar.hasPrefix("http") {
            return URL(string: avatar)
        } else {
            let full = avatar.hasPrefix("image/") ? avatar : "image/\(avatar)"
            return URL(string: "\(Constants.BASE_HOST)/\(full)")
        }
    }

    /// 观之缩略图 URL
    var shareThumbnailURL: URL? {
        guard let thumbnail = shareThumbnail, !thumbnail.isEmpty else { return nil }
        if thumbnail.hasPrefix("http") {
            return URL(string: thumbnail)
        } else {
            return URL(string: "\(Constants.BASE_HOST)\(thumbnail)")
        }
    }

    /// 创建已读版本
    func asRead() -> NotificationMessage {
        return NotificationMessage(
            id: id,
            type: type,
            content: content,
            shareId: shareId,
            commentId: commentId,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            fromUserAvatar: fromUserAvatar,
            shareThumbnail: shareThumbnail,
            statusCode: 1,  // 1 = READ
            createdAtDate: createdAtDate,
            deepLink: deepLink
        )
    }
}

// MARK: - 未读数统计

/// 未读数统计
struct UnreadCount: Codable {
    let interaction: Int?  // 互动消息未读数
    let system: Int?       // 系统消息未读数
    let total: Int         // 总未读数

    /// 内部初始化器（用于 Preview 和测试）
    init(interaction: Int? = nil, system: Int? = nil, total: Int) {
        self.interaction = interaction
        self.system = system
        self.total = total
    }

    /// 获取指定分类的未读数
    func count(for category: MessageCategory) -> Int {
        switch category {
        case .interaction:
            return interaction ?? 0
        case .system:
            return system ?? 0
        }
    }

    /// 自定义解码（兼容后端可能返回不同字段名的情况）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 尝试小写和大写字段名
        if let val = try container.decodeIfPresent(Int.self, forKey: .interaction) {
            interaction = val
        } else if let val = try container.decodeIfPresent(Int.self, forKey: .INTERACTION) {
            interaction = val
        } else {
            interaction = nil
        }

        if let val = try container.decodeIfPresent(Int.self, forKey: .system) {
            system = val
        } else if let val = try container.decodeIfPresent(Int.self, forKey: .SYSTEM) {
            system = val
        } else {
            system = nil
        }

        // 优先取 total，如果没有则取 count，最后计算
        if let totalValue = try container.decodeIfPresent(Int.self, forKey: .total) {
            total = totalValue
        } else if let countValue = try container.decodeIfPresent(Int.self, forKey: .count) {
            total = countValue
        } else {
            total = (interaction ?? 0) + (system ?? 0)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case interaction, system, total, count
        case INTERACTION, SYSTEM  // 大写版本
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(interaction, forKey: .interaction)
        try container.encodeIfPresent(system, forKey: .system)
        try container.encode(total, forKey: .total)
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

/// 聚合的贴纸通知（同一观之的多个贴纸通知合并显示）
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

    /// 格式化的时间显示（MainActor，用于 UI）
    @MainActor
    var formattedTime: String {
        NotificationDateHelper.formatRelativeTime(latestTime)
    }

    /// 第一个用户的头像 URL
    var primaryAvatarURL: URL? {
        guard let avatar = users.first?.avatar, !avatar.isEmpty else { return nil }
        if avatar.hasPrefix("http") {
            return URL(string: avatar)
        } else {
            let full = avatar.hasPrefix("image/") ? avatar : "image/\(avatar)"
            return URL(string: "\(Constants.BASE_HOST)/\(full)")
        }
    }

    /// 观之缩略图 URL（从第一个通知获取，因为都是同一个观之）
    var shareThumbnailURL: URL? {
        guard let thumbnail = notifications.first?.shareThumbnail, !thumbnail.isEmpty else { return nil }
        if thumbnail.hasPrefix("http") {
            return URL(string: thumbnail)
        } else {
            return URL(string: "\(Constants.BASE_HOST)\(thumbnail)")
        }
    }

    /// Deep Link（跳转到观之详情）
    var deepLink: String {
        "guanzhi://share/\(shareId)"
    }
}
