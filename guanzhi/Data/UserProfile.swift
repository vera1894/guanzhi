//
//  UserProfile.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/7.
//  SSOT 统一用户档案模型
//

import SwiftData
import Foundation

/// 统一用户档案模型（SSOT）
/// 替代原有的 LocalUserProfile 和 OtherUserProfile
/// 所有用户（当前用户和他人）统一使用此模型存储
@Model
class UserProfile {
    /// 用户 ID（主键）
    @Attribute(.unique) var id: Int

    /// OneCode 原始值
    var name: String?

    /// 昵称
    var nickname: String?

    /// 手机号
    var phone: String?

    /// 头像路径
    var photo: String?

    /// 用户码
    var code: String?

    /// 创建时间
    var createDate: Int64?

    /// 极光推送 ID
    var jpushId: String?

    /// 称号列表（JSON 编码存储）
    var titleDOSData: Data?

    /// 等级代码：YOMIN, CHONGLANG, QIANSHUI, LANDONG, SHUIMU, DENGTA
    var levelCode: String?

    /// 总积分
    var pointsTotal: Int?

    /// 平台
    var platform: String?

    /// 缓存更新时间
    var lastUpdated: Date?

    init(id: Int,
         name: String? = nil,
         nickname: String? = nil,
         phone: String? = nil,
         photo: String? = nil,
         code: String? = nil,
         createDate: Int64? = nil,
         jpushId: String? = nil,
         titleDOSData: Data? = nil,
         levelCode: String? = nil,
         pointsTotal: Int? = nil,
         platform: String? = nil) {
        self.id = id
        self.name = name
        self.nickname = nickname
        self.phone = phone
        self.photo = photo
        self.code = code
        self.createDate = createDate
        self.jpushId = jpushId
        self.titleDOSData = titleDOSData
        self.levelCode = levelCode
        self.pointsTotal = pointsTotal
        self.platform = platform
        self.lastUpdated = Date()
    }

    /// 解码 TitleDO 数组
    var titleDOS: [TitleDO]? {
        guard let data = titleDOSData else { return nil }
        return try? JSONDecoder().decode([TitleDO].self, from: data)
    }
}
