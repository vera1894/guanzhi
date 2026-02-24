//
//  UserProfileMapper.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/7.
//  UserProfile 到 UserProfileDisplayModel 的映射扩展
//  分离 UI 逻辑与数据层，避免展示逻辑污染数据模型
//

import Foundation

extension UserProfile {
    /// 转换为展示模型
    /// 封装 OneCode 遮挡规则 + 等级名称映射 + 已注销用户处理
    func toDisplayModel() -> UserProfileDisplayModel {
        let isDeleted = status == 3

        // 已注销用户：覆盖显示名
        if isDeleted {
            return UserProfileDisplayModel(
                id: id,
                displayNickname: String(localized: "账号已注销"),
                displayOneCode: "⬛️⬛️⬛️⬛️",
                isOneCodeMasked: true,
                avatarPath: nil,
                levelName: "",
                titleDOS: nil
            )
        }

        // OneCode 遮挡规则：name == phone 或 name 为空时遮挡
        let masked = (name == phone) || (name == nil) || (name?.isEmpty == true)

        return UserProfileDisplayModel(
            id: id,
            displayNickname: nickname ?? "未知用户",
            displayOneCode: masked ? "⬛️⬛️⬛️⬛️" : (name ?? "⬛️⬛️⬛️⬛️"),
            isOneCodeMasked: masked,
            avatarPath: photo,
            levelName: UserLevelMapping.getName(for: levelCode),
            titleDOS: titleDOS
        )
    }
}
