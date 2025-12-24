//
//  CommentModels.swift
//  guanzhi
//
//  Created by Claude Code on 2024/12/23.
//  评论系统数据模型
//

import Foundation

// MARK: - 评论状态枚举
enum CommentStatus: Int, Codable {
    case normal = 0    // 正常
    case deleted = 1   // 已删除
    case blocked = 2   // 已违规
}

// MARK: - 用户摘要（用于评论展示）
struct CommentUserSummary: Codable, Identifiable {
    let id: Int64
    let nickname: String?
    let avatar: String?
}

// MARK: - 评论视图数据（一级评论）
struct CommentViewData: Identifiable, Codable {
    let id: Int64
    let shareId: Int64
    let userId: Int64
    let userNickname: String?
    let userAvatar: String?
    let parentId: Int64?
    let replyToUserId: Int64?          // 新增：被回复的用户ID（用于新建评论返回值）
    let replyToUserNickname: String?   // 新增：被回复的用户昵称
    let content: String?
    var status: Int            // 需要可修改（删除时更新）
    var statusText: String?    // "该评论已删除" / "该评论已违规"
    var likeCount: Int
    var replyCount: Int
    let isAuthor: Bool?        // 是否是分享作者
    var liked: Bool            // 当前用户是否已点赞
    let createdAt: String

    // 预览回复（默认2条）
    var repliesPreview: [ReplyViewData]?

    // 本地状态（非服务器返回，使用 CodingKeys 排除）
    var isExpanded: Bool = false           // 回复是否已展开
    var loadedReplies: [ReplyViewData] = [] // 已加载的完整回复列表
    var isLoadingReplies: Bool = false     // 是否正在加载回复

    // 计算属性
    var displayStatus: CommentStatus {
        CommentStatus(rawValue: status) ?? .normal
    }

    var canDelete: Bool {
        guard displayStatus == .normal else { return false }
        return userId == Int64(OTOLoginStatusManager.shared.getUserID())
    }

    // CodingKeys 排除本地状态字段
    enum CodingKeys: String, CodingKey {
        case id, shareId, userId, userNickname, userAvatar, parentId
        case replyToUserId, replyToUserNickname // 新增
        case content, status, statusText, likeCount, replyCount
        case isAuthor, liked, createdAt, repliesPreview
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        shareId = try container.decode(Int64.self, forKey: .shareId)
        userId = try container.decode(Int64.self, forKey: .userId)
        userNickname = try container.decodeIfPresent(String.self, forKey: .userNickname)
        userAvatar = try container.decodeIfPresent(String.self, forKey: .userAvatar)
        parentId = try container.decodeIfPresent(Int64.self, forKey: .parentId)
        replyToUserId = try container.decodeIfPresent(Int64.self, forKey: .replyToUserId) // 新增
        replyToUserNickname = try container.decodeIfPresent(String.self, forKey: .replyToUserNickname) // 新增
        content = try container.decodeIfPresent(String.self, forKey: .content)
        status = try container.decode(Int.self, forKey: .status)
        statusText = try container.decodeIfPresent(String.self, forKey: .statusText)
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        replyCount = try container.decode(Int.self, forKey: .replyCount)
        isAuthor = try container.decodeIfPresent(Bool.self, forKey: .isAuthor)
        liked = try container.decode(Bool.self, forKey: .liked)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        repliesPreview = try container.decodeIfPresent([ReplyViewData].self, forKey: .repliesPreview)

        // 本地状态初始化
        isExpanded = false
        loadedReplies = []
        isLoadingReplies = false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(shareId, forKey: .shareId)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(userNickname, forKey: .userNickname)
        try container.encodeIfPresent(userAvatar, forKey: .userAvatar)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encodeIfPresent(replyToUserId, forKey: .replyToUserId) // 新增
        try container.encodeIfPresent(replyToUserNickname, forKey: .replyToUserNickname) // 新增
        try container.encodeIfPresent(content, forKey: .content)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(statusText, forKey: .statusText)
        try container.encode(likeCount, forKey: .likeCount)
        try container.encode(replyCount, forKey: .replyCount)
        try container.encodeIfPresent(isAuthor, forKey: .isAuthor)
        try container.encode(liked, forKey: .liked)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(repliesPreview, forKey: .repliesPreview)
    }

    // 用于本地创建（乐观更新）
    init(id: Int64, shareId: Int64, userId: Int64, userNickname: String?, userAvatar: String?,
         parentId: Int64?, replyToUserId: Int64? = nil, replyToUserNickname: String? = nil, // 新增
         content: String?, status: Int, statusText: String?,
         likeCount: Int, replyCount: Int, isAuthor: Bool?, liked: Bool, createdAt: String,
         repliesPreview: [ReplyViewData]? = nil) {
        self.id = id
        self.shareId = shareId
        self.userId = userId
        self.userNickname = userNickname
        self.userAvatar = userAvatar
        self.parentId = parentId
        self.replyToUserId = replyToUserId // 新增
        self.replyToUserNickname = replyToUserNickname // 新增
        self.content = content
        self.status = status
        self.statusText = statusText
        self.likeCount = likeCount
        self.replyCount = replyCount
        self.isAuthor = isAuthor
        self.liked = liked
        self.createdAt = createdAt
        self.repliesPreview = repliesPreview
        self.isExpanded = false
        self.loadedReplies = []
        self.isLoadingReplies = false
    }
}

// MARK: - 回复视图数据（二级评论）
struct ReplyViewData: Identifiable, Codable {
    let id: Int64
    let userId: Int64
    let userNickname: String?
    let userAvatar: String?
    let replyToUserId: Int64?
    let replyToUserNickname: String?  // "回复 @xxx"
    let content: String?
    var status: Int
    var statusText: String?
    var likeCount: Int
    var liked: Bool
    let createdAt: String

    var displayStatus: CommentStatus {
        CommentStatus(rawValue: status) ?? .normal
    }

    var canDelete: Bool {
        guard displayStatus == .normal else { return false }
        return userId == Int64(OTOLoginStatusManager.shared.getUserID())
    }
}

// MARK: - 评论上下文（精准定位用）
struct CommentContextResponse: Codable {
    let comment: CommentViewData
    let parentComment: CommentViewData?
    let shareId: Int64
    let position: CommentPositionInfo
}

struct CommentPositionInfo: Codable {
    let isFirstLevel: Bool
    let parentId: Int64?
    let index: Int
}

// MARK: - 评论排序方式
enum CommentSortOrder: String, CaseIterable {
    case `default` = "default"  // 热度
    case latest = "latest"      // 最新
    case likes = "likes"        // 最多点赞

    var displayName: String {
        switch self {
        case .default: return "默认排序"
        case .latest: return "最新"
        case .likes: return "最多点赞"
        }
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let navigateToComment = Notification.Name("navigateToComment")
    static let showLoginRequired = Notification.Name("showLoginRequired")
}

// MARK: - 时间格式化工具
func formatCommentTime(_ dateString: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    formatter.locale = Locale(identifier: "zh_CN")

    guard let date = formatter.date(from: dateString) else {
        // 尝试其他格式
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date2 = formatter.date(from: dateString) else {
            return dateString
        }
        return formatRelativeTime(date2)
    }
    return formatRelativeTime(date)
}

private func formatRelativeTime(_ date: Date) -> String {
    let now = Date()
    let interval = now.timeIntervalSince(date)

    if interval < 60 {
        return "刚刚"
    } else if interval < 3600 {
        return "\(Int(interval / 60))分钟前"
    } else if interval < 86400 {
        return "\(Int(interval / 3600))小时前"
    } else if interval < 86400 * 7 {
        return "\(Int(interval / 86400))天前"
    } else {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
}
