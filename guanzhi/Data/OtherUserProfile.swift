//
//  OtherUserProfile.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/1/22.
//

import SwiftData
import Foundation

@Model
class OtherUserProfile {
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

    init(id: Int, name: String, nickname: String, phone: String, photo: String?, code: String?, createDate: Int64?, jpushId: String?, titleDOS: [TitleDO]?) {
        self.id = id
        self.name = name
        self.nickname = nickname
        self.phone = phone
        self.photo = photo
        self.code = code
        self.createDate = createDate
        self.jpushId = jpushId
        self.titleDOS = titleDOS
    }
}


