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
    case fetchUserShareList(latitude: Double, userId: Int?, longitude: Double, radius: Double?)
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
        case .fetchUserShareList(let latitude, let userId, let longitude, let radius):
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
            return .init(
                path: "/api/guan/list",
                method: .post,
                param: param
            )
        
        //获取用户信息
        case .userInfo :
            return .init(
                path: "/api/guan/user/info",
                method: .post,
                param: [:]
                )
            
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
