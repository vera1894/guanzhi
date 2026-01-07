//
//  UserProfileDisplayModel.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/7.
//  统一用户档案展示模型
//

import Foundation

/// 统一用户档案展示模型
/// UI 层只消费此模型，不直接读取 SwiftData 模型字段
struct UserProfileDisplayModel {
    /// 用户 ID
    let id: Int

    /// 显示用昵称（已处理 fallback）
    let displayNickname: String

    /// 显示用 OneCode（已处理遮挡）
    let displayOneCode: String

    /// OneCode 是否被遮挡
    let isOneCodeMasked: Bool

    /// 头像路径
    let avatarPath: String?

    /// 等级中文名
    let levelName: String

    /// 称号列表
    let titleDOS: [TitleDO]?
}
