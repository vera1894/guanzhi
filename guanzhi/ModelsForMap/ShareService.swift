//
//  ShareService.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/1/20.
//


import Foundation

/// 统一管理「分享」相关的网络请求和响应解析
final class ShareService {
    // 单例写法，也可以不用单例，看你需求
    static let shared = ShareService()
    
    private init() {}
    
    /// 获取附近的分享列表
    func fetchNearbyShares(
        latitude: Double,
        longitude: Double,
        radius: Double,
        size: Int = -1
    ) async throws -> [ResponsedShare] {
        // 使用你原本的 OTONetwork.request(.fetchNearbyShareList(...))，只做解析
        let data = try await OTONetwork.request(
            .fetchNearbyShareList(
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                size: size
            )
        )
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<ResponsedNearbyShareList>.self, from: data)
        
        guard response.respCode == 0 else {
            throw NSError(
                domain: "ShareService",
                code: response.respCode,
                userInfo: [NSLocalizedDescriptionKey: response.respMsg ?? "未知错误"]
            )
        }
        guard let listData = response.datas else {
            throw NSError(
                domain: "ShareService",
                code: -999,
                userInfo: [NSLocalizedDescriptionKey: "datas 为空"]
            )
        }
        
        // 返回记录
        return listData.records
    }
    
    /// 获取指定用户的所有分享列表
    func fetchUserShareList(
        latitude: Double,
        longitude: Double,
        userId: Int,
        radius: Double,
        size: Int = -1
    ) async throws -> [ResponsedShare] {
        let data = try await OTONetwork.request(
            .fetchUserShareList(
                latitude: latitude,
                longitude: longitude,
                userId: userId,
                radius: radius,
                size: size
            )
        )
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<ResponsedNearbyShareList>.self, from: data)
        
        guard response.respCode == 0 else {
            throw NSError(
                domain: "ShareService",
                code: response.respCode,
                userInfo: [NSLocalizedDescriptionKey: response.respMsg ?? "未知错误"]
            )
        }
        guard let listData = response.datas else {
            throw NSError(
                domain: "ShareService",
                code: -999,
                userInfo: [NSLocalizedDescriptionKey: "datas 为空"]
            )
        }
        return listData.records
    }
    
    /// 获取某个分享的详情
    func fetchShareDetail(shareId: Int64) async throws -> ResponsedShare {
        let data = try await OTONetwork.request(.fetchShareDetail(id: shareId))

        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<ResponsedShare>.self, from: data)

        guard response.respCode == 0 else {
            throw NSError(
                domain: "ShareService",
                code: response.respCode,
                userInfo: [NSLocalizedDescriptionKey: response.respMsg ?? "未知错误"]
            )
        }
        guard let detailData = response.datas else {
            throw NSError(
                domain: "ShareService",
                code: -999,
                userInfo: [NSLocalizedDescriptionKey: "datas 为空"]
            )
        }

        return detailData
    }

    /// 删除分享
    func deleteShare(shareId: Int) async throws {
        let data = try await OTONetwork.request(.deleteShare(id: shareId))

        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<EmptyData>.self, from: data)

        guard response.respCode == 0 else {
            throw NSError(
                domain: "ShareService",
                code: response.respCode,
                userInfo: [NSLocalizedDescriptionKey: response.respMsg ?? "删除失败"]
            )
        }
    }
}