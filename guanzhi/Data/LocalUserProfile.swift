//
//  LocalUserProfile.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/1/6.
//

import SwiftData
import Foundation

@Model
class LocalUserProfile {
    // 本机用户的必要字段
    @Attribute(.unique) var id: Int
    var name: String
    var nickname: String
    var phone: String
    var photo: String?
    var code: String?
    var createDate: Int64?
    var jpushId: String?
    var titleDOS: [TitleDO]?

    // 用户等级相关字段
    var levelCode: String?      // 等级代码：YOMIN, CHONGLANG, QIANSHUI, LANDONG, SHUIMU, DENGTA
    var pointsTotal: Int?       // 总积分

    init(id: Int, name: String, nickname: String, phone: String, photo: String?, code: String?, createDate: Int64?, jpushId: String?, titleDOS: [TitleDO]?, levelCode: String? = nil, pointsTotal: Int? = nil) {
        self.id = id
        self.name = name
        self.nickname = nickname
        self.phone = phone
        self.photo = photo
        self.code = code
        self.createDate = createDate
        self.jpushId = jpushId
        self.titleDOS = titleDOS
        self.levelCode = levelCode
        self.pointsTotal = pointsTotal
    }

    /// 获取等级名称（中文）
    var levelName: String {
        UserLevelMapping.getName(for: levelCode)
    }
}

