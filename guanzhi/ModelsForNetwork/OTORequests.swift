//
//  OTORequests.swift
//  guanzhi
//
//  Created by Vera on 2024/3/20.
//

import Foundation
import UIKit


enum RequestMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

struct OTOResponseModel<T: Codable>: Codable {
    let respMsg: String?
    let respCode: Int
    let datas: T?
}

struct OTOResponseDataModel: Codable {
    let respMsg: String?
    let respCode: Int
    let datas: dataModel
}

struct dataModel: Codable {
    let phone: String?
    let nickname: String?
    let id: Int?
}

struct OTORequestBaseModel {
    let path: String
    let method: RequestMethod
    let param: Dictionary<String, Any>
}

struct UserFullInfoModel: Codable {
    let id: Int
    let createDate: Int64?
    
    let code: String?
    let phone: String?
    let name: String?
    let nickname: String?
    let password: String?
    
    let registerdate: Int64?
    let lastLoginTime: Int64?
    
    let jpushId: String?
    let platform: String?
    let photo: String?
    let titleDOS: [TitleDO]?
} // 完整的用户信息结构

struct TitleDO: Codable {
    let condition: String?
    let createDate: String?
    let id: Int?
    let level: Int?
    let name: String?
} // TitleDO 对应后端 titleDOS[] 数组里的每个元素

enum OTORequest {
    case checkName(name: String)
    case SendVerifiedCode(phoneNumber: String)
    case checkCodeOrLogin(phoneNumber: String, code: String)
    case Register(phoneNumber: String,nickName: String)
    case insertShare(address: String, cityCode: Int?, data: String, deleted:Int?, districtCode: Int?, imagePath: String, latitude: Double, longitude: Double, provinceCode: Int?, title: String)
    case QueryDoodle(isSelf: Bool, latitude: Double, longitude: Double, page: Int?, radius: Double?, size: Int?)
    case UpdateDoodle(cityCode: Int?, data: String, districtCode: Int?, latitude: Double, longitude: Double, provinceCode: Int?, id: Int)
    case userInfo
    case fetchNearbyShareList(latitude: Double, longitude: Double, radius: Double?, size: Int?)
    case fetchUserShareList(latitude: Double, longitude: Double, userId: Int?,  radius: Double?, size: Int?)
    case fetchShareDetail(id: Int64)
    case fetchUserFullInfo(userId: Int)
    case updateUserName(newName: String)
    case updateUserNickname(newNickname: String)
    case updateUserPlatform(newPlatform: String)
    case updateUserPhoto(newPhoto: String)
    case deleteShare(id: Int)
    /// 记录分享浏览（用于褪色度计算）
    case recordShareView(shareId: Int64)

    // MARK: - 贴纸系统 API
    /// 获取贴纸可用性列表
    case fetchStickerAvailability(shareId: Int64)
    /// 使用贴纸
    case useSticker(shareId: Int64, stickerId: String)

    // MARK: - 评论系统 API
    /// 获取评论列表
    case fetchComments(shareId: Int64, order: String, offset: Int, limit: Int)
    /// 获取回复列表
    case fetchReplies(commentId: Int64, offset: Int, limit: Int)
    /// 发表评论/回复
    case createComment(shareId: Int64, content: String, parentId: Int64?, replyToUserId: Int64?)
    /// 删除评论
    case deleteComment(commentId: Int64)
    /// 点赞评论
    case likeComment(commentId: Int64)
    /// 取消点赞评论
    case unlikeComment(commentId: Int64)
    /// 获取评论上下文（精准定位）
    case getCommentContext(commentId: Int64)

    // MARK: - 设备管理 API (推送通知)
    /// 注册设备
    case registerDevice(deviceToken: String, bundleId: String, deviceId: String?, deviceName: String?, deviceModel: String?, osVersion: String?, appVersion: String?, environment: String?)
    /// 更新设备 Token
    case updateDeviceToken(oldToken: String, newToken: String)
    /// 设备登出
    case logoutDevice(deviceToken: String)
}

extension OTORequest {
    var request: OTORequestBaseModel {
        switch self {
            case .checkName(let name):
                return .init(
                    path: "/api/user/checkName",
                    method: .post,
                    param: [
                        "name": name
                    ])
            
            //发送验证码
            case .SendVerifiedCode(let phoneNumber):
                return .init(
                    path: "/api/guan/sendCode",
                    method: .post,
                    param: [
                        "phone": phoneNumber
                    ])
                
            //登录
            case .checkCodeOrLogin(let phoneNumber, let code):
                return .init(
                    path: "/api/guan/login",
                    method: .post,
                    param: [
                        "phone": phoneNumber,
                        "code": code
                    ])
            
            //注册
            case .Register(let phoneNumber, let nickName):
                return .init(
                    path: "/api/guan/register",
                    method: .post,
                    param: [
                        "phone": phoneNumber,
                        "jpushId":"",
                        "platform":"app",
                        "nickname": nickName
                        
                    ])
                
            //发布分享
            case .insertShare(let address, let cityCode, let data, let deleted, let districtCode, let imagePath, let latitude, let longitude, let provinceCode, let title):
                var param: [String: Any] = [
                    "address": address,
                   // "cityCode": cityCode as Any,
                    "data": data,
                  //  "deleted": deleted as Any,
                   // "districtCode": districtCode as Any,
                    "imagePath": imagePath,
                    "latitude": latitude,
                    "longitude": longitude,
                  //  "provinceCode": provinceCode as Any,
                    "title":title
                ]
                if let cityCode = cityCode {
                    param["cityCode"] = cityCode
                }
                if let deleted = deleted{
                    param["deleted"] = deleted
                }
                if let districtCode = districtCode {
                    param["districtCode"] = districtCode
                }
                if let provinceCode = provinceCode {
                    param["provinceCode"] = provinceCode
                }
                return .init(
                    path: "/api/guan/share/insert",
                    method: .post,
                    param: param
                )
                
            //查询附近分享列表
            case .fetchNearbyShareList(let latitude, let longitude, let radius, let size):
                var param: [String: Any] = [
                    "latitude": latitude,
                    "longitude": longitude
                ]
                if let radius = radius{
                    param["radius"] = radius
                }
                if let size = size {
                    param["size"] = size
                }
                return .init(
                    path: "/api/guan/list",
                    method: .post,
                    param: param
                )
                
            //查询个人分享列表
            case .fetchUserShareList(let latitude, let longitude, let userId, let radius, let size):
                var param: [String: Any] = [
                    "latitude": latitude,
                    "longitude": longitude
                ]
                if let userId = userId {
                    param["userId"] = userId
                }
                if let radius = radius{
                    param["radius"] = radius
                }
                if let size = size {
                    param["size"] = size
                }
                return .init(
                    path: "/api/guan/list",
                    method: .post,
                    param: param
                )
            
            //获取用户信息（登录时使用）
            case .userInfo:
                return .init(
                    path: "/api/guan/user/info",
                    method: .post,
                    param: [ : ]
                )

            //查询分享详情
            case .fetchShareDetail(let id):
                return .init(
                    path: "/api/guan/share/detail",
                    method: .post,
                    param: ["id": id]
                )
                
            //获取完整的用户信息
            case .fetchUserFullInfo(let userId):
                return .init(
                    path: "/api/guan/user/info",
                    method: .post,
                    param: ["userId": userId]
                )
            
            // 更新用户 name
            case .updateUserName(let newName):
                return .init(
                    path: "/api/guan/user/upd",
                    method: .post,
                    param: ["name": newName]
                )
                
            // 更新用户 nickname
            case .updateUserNickname(let newNickname):
                return .init(
                    path: "/api/guan/user/upd",
                    method: .post,
                    param: ["nickname": newNickname]
                )
            
            // 更新用户 platform
            case .updateUserPlatform(let newPlatform):
                return .init(
                    path: "/api/guan/user/upd",
                    method: .post,
                    param: ["platform": newPlatform]
                )
            
            // 更新用户 photo
            case .updateUserPhoto(let newPhoto):
                return .init(
                    path: "/api/guan/user/upd",
                    method: .post,
                    param: ["photo": newPhoto]
                )

            // 删除分享
            case .deleteShare(let id):
                return .init(
                    path: "/api/guan/share/del",
                    method: .post,
                    param: ["id": id]
                )

            // 记录分享浏览（用于褪色度计算）
            case .recordShareView(let shareId):
                return .init(
                    path: "/api/shares/\(shareId)/view",
                    method: .post,
                    param: [:]
                )

            // MARK: - 贴纸系统 API

            // 获取贴纸可用性列表
            case .fetchStickerAvailability(let shareId):
                return .init(
                    path: "/api/stickers/availability",
                    method: .get,
                    param: ["shareId": shareId]
                )

            // 使用贴纸
            case .useSticker(let shareId, let stickerId):
                return .init(
                    path: "/api/shares/\(shareId)/stickers/use",
                    method: .post,
                    param: ["stickerId": stickerId]
                )

            // MARK: - 评论系统 API

            // 获取评论列表
            case .fetchComments(let shareId, let order, let offset, let limit):
                return .init(
                    path: "/api/shares/\(shareId)/comments",
                    method: .get,
                    param: [
                        "order": order,
                        "offset": offset,
                        "limit": limit
                    ]
                )

            // 获取回复列表
            case .fetchReplies(let commentId, let offset, let limit):
                return .init(
                    path: "/api/comments/\(commentId)/replies",
                    method: .get,
                    param: [
                        "offset": offset,
                        "limit": limit
                    ]
                )

            // 发表评论/回复
            case .createComment(let shareId, let content, let parentId, let replyToUserId):
                var param: [String: Any] = ["content": content]
                if let parentId = parentId {
                    param["parentId"] = parentId
                }
                if let replyToUserId = replyToUserId {
                    param["replyToUserId"] = replyToUserId
                }
                return .init(
                    path: "/api/shares/\(shareId)/comments",
                    method: .post,
                    param: param
                )

            // 删除评论
            case .deleteComment(let commentId):
                return .init(
                    path: "/api/comments/\(commentId)",
                    method: .delete,
                    param: [:]
                )

            // 点赞评论
            case .likeComment(let commentId):
                return .init(
                    path: "/api/comments/\(commentId)/like",
                    method: .post,
                    param: [:]
                )

            // 取消点赞评论
            case .unlikeComment(let commentId):
                return .init(
                    path: "/api/comments/\(commentId)/like",
                    method: .delete,
                    param: [:]
                )

            // 获取评论上下文（精准定位）
            case .getCommentContext(let commentId):
                return .init(
                    path: "/api/comments/\(commentId)/context",
                    method: .get,
                    param: [:]
                )

            // MARK: - 设备管理 API (推送通知)

            // 注册设备
            case .registerDevice(let deviceToken, let bundleId, let deviceId, let deviceName, let deviceModel, let osVersion, let appVersion, let environment):
                var param: [String: Any] = [
                    "deviceToken": deviceToken,
                    "bundleId": bundleId
                ]
                if let deviceId = deviceId {
                    param["deviceId"] = deviceId
                }
                if let deviceName = deviceName {
                    param["deviceName"] = deviceName
                }
                if let deviceModel = deviceModel {
                    param["deviceModel"] = deviceModel
                }
                if let osVersion = osVersion {
                    param["osVersion"] = osVersion
                }
                if let appVersion = appVersion {
                    param["appVersion"] = appVersion
                }
                if let environment = environment {
                    param["environment"] = environment
                }
                return .init(
                    path: "/device/register",
                    method: .post,
                    param: param
                )

            // 更新设备 Token
            case .updateDeviceToken(let oldToken, let newToken):
                return .init(
                    path: "/device/token",
                    method: .put,
                    param: [
                        "oldToken": oldToken,
                        "newToken": newToken
                    ]
                )

            // 设备登出
            case .logoutDevice(let deviceToken):
                return .init(
                    path: "/device/logout",
                    method: .delete,
                    param: ["deviceToken": deviceToken]
                )

            //备用的
            case .QueryDoodle(let isSelf, let latitude, let longitude, let page, let radius, let size):
                var param: [String: Any] = [
                    "isSelf": isSelf,
                    "latitude": latitude,
                    "longitude": longitude
                ]
                if let page = page {
                    param["page"] = page
                }
                if let radius = radius {
                    param["radius"] = radius
                }
                if let size = size {
                    param["size"] = size
                }
                return .init(
                    path: "/api/doodle/query",
                    method: .post,
                    param: param
                )
                
            case .UpdateDoodle(let cityCode, let data, let districtCode, let latitude, let longitude, let provinceCode, let id):
                var param: [String: Any] = [
                    "data": data,
                    "latitude": latitude,
                    "longitude": longitude,
                    "id": id,
                ]
                if let cityCode = cityCode {
                    param["cityCode"] = cityCode
                }
                if let districtCode = districtCode {
                    param["districtCode"] = districtCode
                }
                if let provinceCode = provinceCode {
                    param["provinceCode"] = provinceCode
                }
                return .init(
                    path: "/api/doodle/update",
                    method: .post,
                    param: param
                )
        }
    }
}
