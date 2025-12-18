//
//  SharesData.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/11/3.
//

import SwiftData
import Foundation

@Model
class Share {
    @Attribute(.unique) var id: Int64
    var createDate: Date
    var userId: Int64
    var data: String
    var longitude: Double
    var latitude: Double
    var provinceCode: String?
    var cityCode: String?
    var districtCode: String?
    var address: String
    var imagePathsString: String? // 将属性设为可选
    var title: String
    var deleted: Bool

    // ✅ 新增：互动统计字段
    var agreeCount: Int = 0           // 赞同数
    var neutralCount: Int = 0         // 无感数
    var checkinCount: Int = 0         // 打卡数
    var commentCount: Int = 0         // 评论数
    var currentUserVoteType: Int? = nil // 当前用户的投票状态 (1=赞同, 0=无感, -1或nil=取消)

    // ✅ 新增：褪色度字段
    var fadeScore: Int = 0            // 褪色度 (0-100)

    // 修改计算属性以处理可选值
    var imagePaths: [String] {
        get {
            imagePathsString?.components(separatedBy: ",") ?? []
        }
        set {
            imagePathsString = newValue.joined(separator: ",")
        }
    }

    init(id: Int64, createDate: Date, userId: Int64, data: String, longitude: Double, latitude: Double, provinceCode: String?, cityCode: String?, districtCode: String?, address: String, imagePaths: [String], title: String, deleted: Bool) {
        self.id = id
        self.createDate = createDate
        self.userId = userId
        self.data = data
        self.longitude = longitude
        self.latitude = latitude
        self.provinceCode = provinceCode
        self.cityCode = cityCode
        self.districtCode = districtCode
        self.address = address
        self.imagePathsString = imagePaths.joined(separator: ",") // 存储为字符串
        self.title = title
        self.deleted = deleted

        // ✅ 新增：初始化互动统计字段
        self.agreeCount = 0
        self.neutralCount = 0
        self.checkinCount = 0
        self.commentCount = 0
        self.currentUserVoteType = nil
    }
}

@Model
class MediaFile: Identifiable {
    var id: UUID = UUID()
    var shareId: Int64
    var typeString: String  // 将类型改为 String
    var timestamp: Date
    var fileExtension: String
    var fullPath: String
    var urlString: String?
    var localURLString: String?
    var fileSize: Int64?
    var prefix: String = ""

    // 计算属性，用于获取和设置 MediaType
    var type: MediaType {
        get {
            return MediaType(rawValue: typeString) ?? .unknown
        }
        set {
            typeString = newValue.rawValue
        }
    }

    var url: URL? {
        get {
            if let urlString = urlString {
                return URL(string: urlString)
            }
            return nil
        }
        set {
            urlString = newValue?.absoluteString
        }
    }

    var localURL: URL? {
        get {
            if let localURLString = localURLString {
                return URL(string: localURLString)
            }
            return nil
        }
        set {
            localURLString = newValue?.absoluteString
        }
    }

    init(shareId: Int64, type: MediaType, timestamp: Date, fileExtension: String, fullPath: String, url: URL?, prefix: String) {
        self.id = UUID() // 初始化存储属性
        self.shareId = shareId
        self.typeString = type.rawValue  // 存储原始值
        self.timestamp = timestamp
        self.fileExtension = fileExtension
        self.fullPath = fullPath
        self.urlString = url?.absoluteString  // 直接设置存储属性
        self.prefix = prefix
    }
}

enum MediaType: String {
    case photo = "photo"
    case video = "video"
    case livePhoto = "livePhoto"
    case thumbnail = "thumbnail"
    case unknown = "unknown"
}


