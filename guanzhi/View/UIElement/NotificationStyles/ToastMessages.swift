//
//  ToastMessages.swift
//  guanzhi
//
//  集中管理所有 Toast 通知消息，便于多语言维护。
//  调用方式：toastManager.show(ToastMessages.editSuccess)
//

import SwiftUI

enum ToastMessages {

    // MARK: - 资料编辑

    static var nameInvalidChars: ToastItem {
        notification(String(localized: "❌ 名字不能包含无效字符"))
    }

    static var nameLengthInvalid: ToastItem {
        notification(String(localized: "❌ 名字字数不符合要求"))
    }

    static var editSuccess: ToastItem {
        notification(String(localized: "✅ 修改成功"))
    }

    static var editFailed: ToastItem {
        notification(String(localized: "❌ 修改失败"))
    }

    static var oneCodeInvalidChars: ToastItem {
        notification(String(localized: "❌ 仅可使用英文、数字、下划线"))
    }

    static var oneCodeLengthInvalid: ToastItem {
        notification(String(localized: "❌ OneCode长度须为6-16个字符"))
    }

    static var avatarEditSuccess: ToastItem {
        notification(String(localized: "✅ 修改头像成功"))
    }

    static var avatarEditFailed: ToastItem {
        notification(String(localized: "❌ 修改头像失败"))
    }

    // MARK: - 用户信息

    static var oneCodeHidden: ToastItem {
        notification(String(localized: "🔏 与手机号相同的OneCode会被隐藏"))
    }

    static var phoneChangeNotReady: ToastItem {
        notification(String(localized: "😂 修改手机号功能还没做"))
    }

    // MARK: - 评论

    static var commentDeleted: ToastItem {
        ToastItem(style: .notificationOnly(
            title: String(localized: "评论已删除"),
            symbol: "checkmark.circle.fill",
            tint: .green,
            isUserInteractionEnabled: false,
            timing: .short,
            isAutoClose: true
        ))
    }

    static var replyDeleted: ToastItem {
        ToastItem(style: .notificationOnly(
            title: String(localized: "回复已删除"),
            symbol: "checkmark.circle.fill",
            tint: .green,
            isUserInteractionEnabled: false,
            timing: .short,
            isAutoClose: true
        ))
    }

    // MARK: - 分享操作

    static var shareLinkCopied: ToastItem {
        ToastItem(style: .notificationOnly(
            title: String(localized: "分享链接已复制，去粘贴吧～"),
            symbol: "arrowshape.turn.up.right",
            tint: Color("color-primary"),
            isUserInteractionEnabled: true,
            timing: .short,
            isAutoClose: true
        ))
    }

    static var publishSuccess: ToastItem {
        notification(String(localized: "🌍 发布成功"))
    }

    // MARK: - 账号注销

    static var accountDeleted: ToastItem {
        notification(String(localized: "账号已注销"))
    }

    static var accountDeleteFailed: ToastItem {
        notification(String(localized: "❌ 注销失败，请稍后重试"))
    }

    // MARK: - 系统

    static var welcome: ToastItem {
        ToastItem(style: .notificationOfWelcome(
            title: String(localized: "🌍世界虽大 吾可观之👀"),
            symbol: "",
            tint: Color("color-primary"),
            isUserInteractionEnabled: true,
            timing: .medium,
            isAutoClose: true
        ))
    }

    static var cacheCleared: ToastItem {
        ToastItem(style: .notificationOnly(
            title: String(localized: "缓存已清理"),
            symbol: "checkmark.circle",
            tint: .green,
            isUserInteractionEnabled: true,
            timing: .short,
            isAutoClose: true
        ))
    }

    static var tokenExpired: ToastItem {
        ToastItem(style: .notificationOnly(
            title: String(localized: "登录已过期，请重新登录"),
            symbol: "exclamationmark.triangle",
            tint: .orange,
            isUserInteractionEnabled: true,
            timing: .medium,
            isAutoClose: true
        ))
    }

    // MARK: - Private

    /// 默认通知样式（color-primary、无图标、短时显示）
    private static func notification(_ title: String) -> ToastItem {
        ToastItem(style: .notificationOnly(
            title: title,
            symbol: "",
            tint: Color("color-primary"),
            isUserInteractionEnabled: true,
            timing: .short,
            isAutoClose: true
        ))
    }
}
