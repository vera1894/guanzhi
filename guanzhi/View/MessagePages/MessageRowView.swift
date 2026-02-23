//
//  MessageRowView.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/30.
//

import SwiftUI

struct MessageRowView: View {
    let message: NotificationMessage
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // 头像
                avatarView
                    .frame(width: 44, height: 44)

                // 内容区域
                VStack(alignment: .leading, spacing: 4) {
                    // 标题行：用户名 + 时间
                    HStack {
                        Text(message.localizedTitle)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color("color-black"))
                            .lineLimit(1)

                        Spacer()

                        Text(message.formattedTime)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)

                        // 未读红点
                        if message.isUnread {
                            UnreadBadgeView(count: 1, showCount: false)
                        }
                    }

                    // 消息内容
                    Text(message.localizedContent)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(message.isUnread ? Color("color-primary").opacity(0.03) : Color.clear)
    }

    // MARK: - 头像视图

    @ViewBuilder
    private var avatarView: some View {
        if message.type.usesSystemIcon {
            // 系统类消息使用系统图标
            Circle()
                .fill(Color("color-primary").opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: message.type.systemIconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color("color-primary"))
                )
        } else if let shareId = message.shareId {
            // 互动消息显示观之缩略图（本地缓存优先 + 异步加载）
            ShareThumbnailView(shareId: shareId, size: 44, cornerRadius: 8)
        } else if let avatarURL = message.avatarURL {
            // 没有关联观之时显示用户头像
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .empty:
                    placeholderAvatar
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                case .failure:
                    placeholderAvatar
                @unknown default:
                    placeholderAvatar
                }
            }
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
            )
    }

    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            )
    }
}

// MARK: - 未读红点

struct UnreadBadgeView: View {
    let count: Int
    var showCount: Bool = true
    var size: CGFloat = 18

    var body: some View {
        if count > 0 {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: badgeSize, height: badgeSize)

                if showCount {
                    Text(formatCount)
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }

    private var formatCount: String {
        if count > 999 {
            return "999+"
        }
        return "\(count)"
    }

    private var badgeSize: CGFloat {
        if !showCount {
            return 8
        }
        if count > 99 {
            return size + 8
        } else if count > 9 {
            return size + 4
        }
        return size
    }

    private var fontSize: CGFloat {
        if count > 99 {
            return 10
        }
        return 11
    }
}

// MARK: - 聚合贴纸消息行

/// 聚合贴纸通知的行视图
struct AggregatedStickerRowView: View {
    let aggregation: AggregatedStickerNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // 头像
                avatarView
                    .frame(width: 44, height: 44)

                // 内容区域
                VStack(alignment: .leading, spacing: 4) {
                    // 标题行：用户名 + 时间
                    HStack {
                        Text(aggregation.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color("color-black"))
                            .lineLimit(1)

                        Spacer()

                        Text(aggregation.formattedTime)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)

                        // 未读红点
                        if aggregation.hasUnread {
                            UnreadBadgeView(count: 1, showCount: false)
                        }
                    }

                    // 消息内容
                    Text(aggregation.contentSummary)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(aggregation.hasUnread ? Color("color-primary").opacity(0.03) : Color.clear)
    }

    // MARK: - 头像视图

    @ViewBuilder
    private var avatarView: some View {
        // 聚合消息使用 shareId 显示观之缩略图（本地缓存优先 + 异步加载）
        ShareThumbnailView(shareId: aggregation.shareId, size: 44, cornerRadius: 8)
    }

    @ViewBuilder
    private func singleAvatarView(avatar: String?) -> some View {
        if let avatarStr = avatar, !avatarStr.isEmpty {
            let avatarURL: URL? = {
                if avatarStr.hasPrefix("http") {
                    return URL(string: avatarStr)
                } else {
                    let full = avatarStr.hasPrefix("image/") ? avatarStr : "image/\(avatarStr)"
                    return URL(string: "\(Constants.BASE_HOST)/\(full)")
                }
            }()
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .empty:
                    placeholderAvatar
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                case .failure:
                    placeholderAvatar
                @unknown default:
                    placeholderAvatar
                }
            }
        } else {
            placeholderAvatar
        }
    }

    @ViewBuilder
    private func multiAvatarView(users: [(id: Int?, name: String?, avatar: String?)]) -> some View {
        // 显示最多 3 个头像叠加
        let displayUsers = Array(users.prefix(3))
        ZStack {
            ForEach(Array(displayUsers.enumerated().reversed()), id: \.offset) { index, user in
                smallAvatar(avatar: user.avatar)
                    .offset(x: CGFloat(index) * 10, y: 0)
            }
        }
        .frame(width: 44, height: 44)
    }

    @ViewBuilder
    private func smallAvatar(avatar: String?) -> some View {
        if let avatarStr = avatar, !avatarStr.isEmpty {
            let avatarURL: URL? = {
                if avatarStr.hasPrefix("http") {
                    return URL(string: avatarStr)
                } else {
                    let full = avatarStr.hasPrefix("image/") ? avatarStr : "image/\(avatarStr)"
                    return URL(string: "\(Constants.BASE_HOST)/\(full)")
                }
            }()
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .empty:
                    smallPlaceholderAvatar
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                case .failure:
                    smallPlaceholderAvatar
                @unknown default:
                    smallPlaceholderAvatar
                }
            }
        } else {
            smallPlaceholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
            )
    }

    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            )
    }

    private var smallPlaceholderAvatar: some View {
        Circle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 28, height: 28)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            )
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        // 评论回复消息
        MessageRowView(
            message: NotificationMessage(
                id: 1,
                type: .commentReply,
                content: "这个地方太美了！下次我也要去看看",
                shareId: 123,
                commentId: 456,
                fromUserId: 11,
                fromUserName: "张三",
                fromUserAvatar: nil,
                statusCode: 0,  // 0 = UNREAD
                createdAtDate: Date().addingTimeInterval(-180),
                deepLink: "guanzhi://share/123/comment/456"
            )
        ) {
            print("Tapped")
        }

        Divider().padding(.leading, 68)

        // 贴纸消息
        MessageRowView(
            message: NotificationMessage(
                id: 2,
                type: .stickerReceived,
                content: "李四 给你的观之贴了「珍馐」",
                shareId: 789,
                commentId: nil,
                fromUserId: 22,
                fromUserName: "李四",
                fromUserAvatar: nil,
                statusCode: 1,  // 1 = READ
                createdAtDate: Date().addingTimeInterval(-3600),
                deepLink: "guanzhi://share/789"
            )
        ) {
            print("Tapped")
        }

        Divider().padding(.leading, 68)

        // 系统消息
        MessageRowView(
            message: NotificationMessage(
                id: 3,
                type: .system,
                content: "恭喜你升级到「行者」等级！每日贴纸配额已提升",
                shareId: nil,
                commentId: nil,
                fromUserId: nil,
                fromUserName: nil,
                fromUserAvatar: nil,
                statusCode: 0,  // 0 = UNREAD
                createdAtDate: Date().addingTimeInterval(-86400),
                deepLink: nil
            )
        ) {
            print("Tapped")
        }
    }
}
