//
//  OTORequests.swift
//  guanzhi
//
//  Created by Vera on 2024/3/20.
//

import Foundation


enum RequestMethod: String {
    case get = "GET"
    case post = "POST"
}

struct OTOResponseModel: Codable {
    let respMsg: String?
    let respCode: Int
    let datas: String?
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
    case Register(phoneNumber: String, code: String, nickName: String, userName: String)
    case InsertDoodle(cityCode: Int?, data: String, districtCode: Int?, latitude: Double, longitude: Double, provinceCode: Int?)
    case QueryDoodle(isSelf: Bool, latitude: Double, longitude: Double, page: Int?, radius: Double?, size: Int?)
    case UpdateDoodle(cityCode: Int?, data: String, districtCode: Int?, latitude: Double, longitude: Double, provinceCode: Int?, id: Int)
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
            
        case .SendVerifiedCode(let phoneNumber):
            return .init(
                path: "/api/user/sendCode",
                method: .post,
                param: [
                    "phone": phoneNumber
                ])
            
        case .checkCodeOrLogin(let phoneNumber, let code):
            return .init(
                path: "/api/user/checkCodeOrLogin",
                method: .post,
                param: [
                    "phone": phoneNumber,
                    "code": code
                ])
            
        case .Register(let phoneNumber, let code, let nickName, let userName):
            return .init(
                path: "/api/user/register",
                method: .post,
                param: [
                    "phone": phoneNumber,
                    "nickname": nickName,
                    "name": userName,
                    "code": code,
                ])
            
        case .InsertDoodle(let cityCode, let data, let districtCode, let latitude, let longitude, let provinceCode):
            var param: [String: Any] = [
                "data": data,
                "latitude": latitude,
                "longitude": longitude
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
                path: "/api/doodle/insert",
                method: .post,
                param: param
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
