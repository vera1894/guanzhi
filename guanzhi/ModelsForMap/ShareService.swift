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

        #if DEBUG
        // ✅ 调试：打印原始 JSON
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 [ShareService] fetchShareDetail 原始 JSON:")
            print(jsonString)
        }
        #endif

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

        #if DEBUG
        print("🔍 [ShareService] 解析后的数据:")
        print("   - shareId: \(detailData.id)")
        print("   - agreeCount: \(detailData.agreeCount ?? 0)")
        print("   - currentUserVoteType: \(detailData.currentUserVoteType?.description ?? "nil")")
        #endif

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

    /// 对分享进行投票
    /// - Parameters:
    ///   - shareId: 分享ID
    ///   - voteType: 投票类型 (1=赞同, 0=无感, -1=取消)
    /// - Returns: 空结果（成功/失败）
    func voteShare(shareId: Int64, voteType: Int) async throws {
        let data = try await OTONetwork.request(
            .voteShare(shareId: shareId, voteType: voteType)
        )

        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<EmptyData>.self, from: data)

        guard response.respCode == 0 else {
            throw NSError(
                domain: "ShareService",
                code: response.respCode,
                userInfo: [NSLocalizedDescriptionKey: response.respMsg ?? "投票失败"]
            )
        }
    }

    // MARK: - 贴纸系统 API

    /// 获取贴纸可用性列表
    /// - Parameter shareId: 分享 ID
    /// - Returns: 贴纸可用性数组
    func fetchStickerAvailability(shareId: Int64) async throws -> [StickerAvailability] {
        let data = try await OTONetwork.request(
            .fetchStickerAvailability(shareId: shareId)
        )

        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 [ShareService] fetchStickerAvailability 原始 JSON:")
            print(jsonString)
            // 检查原始 JSON 中是否包含 ZHENXIU
            if jsonString.contains("ZHENXIU") || jsonString.contains("zhenxiu") {
                print("🔍 [ShareService] ✅ 原始 JSON 中包含 ZHENXIU/zhenxiu")
            } else {
                print("🔍 [ShareService] ⚠️ 原始 JSON 中 **不包含** ZHENXIU/zhenxiu！")
            }
        }
        #endif

        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<StickerAvailabilityResponse>.self, from: data)

        guard response.respCode == 0 else {
            throw NSError(
                domain: "ShareService",
                code: response.respCode,
                userInfo: [NSLocalizedDescriptionKey: response.respMsg ?? "获取贴纸可用性失败"]
            )
        }

        guard let responseData = response.datas else {
            throw NSError(
                domain: "ShareService",
                code: -999,
                userInfo: [NSLocalizedDescriptionKey: "贴纸可用性数据为空"]
            )
        }

        #if DEBUG
        print("🔍 [ShareService] 解析 DTO，共 \(responseData.stickers.count) 条:")
        for dto in responseData.stickers {
            print("   - stickerId='\(dto.stickerId)', unlocked=\(dto.unlocked), dailyLimit=\(dto.dailyLimit?.description ?? "nil"), remaining=\(dto.remainingToday?.description ?? "nil"), group=\(dto.group ?? "nil"), alreadyApplied=\(dto.alreadyApplied ?? false)")
        }
        #endif

        let availabilities = responseData.toAvailabilities()

        #if DEBUG
        print("🔍 [ShareService] 转换后的 StickerAvailability，共 \(availabilities.count) 条:")
        for avail in availabilities {
            print("   - [\(avail.kind.rawValue)] \(avail.kind.displayName): unlocked=\(avail.unlocked), canUse=\(avail.canUse)")
        }
        // 检查转换过程中是否有丢失
        let dtoCount = responseData.stickers.count
        let availCount = availabilities.count
        if dtoCount != availCount {
            print("⚠️ [ShareService] 转换丢失了 \(dtoCount - availCount) 条记录！")
            print("   可能原因：stickerId 无法匹配到 StickerKind 枚举")
            // 找出哪些被丢弃了
            let convertedIds = Set(availabilities.map { $0.kind.rawValue })
            for dto in responseData.stickers {
                let lowerId = dto.stickerId.lowercased()
                if !convertedIds.contains(lowerId) && StickerKind(backendId: dto.stickerId) == nil {
                    print("   ❌ 丢弃的 stickerId: '\(dto.stickerId)' - 无法匹配到 StickerKind")
                }
            }
        }
        #endif

        return availabilities
    }

    /// 使用贴纸
    /// - Parameters:
    ///   - shareId: 分享 ID
    ///   - stickerId: 贴纸 ID（对应 StickerKind.backendId）
    /// - Returns: 使用结果响应
    func useSticker(shareId: Int64, stickerId: String) async throws -> StickerUseResponse {
        let data = try await OTONetwork.request(
            .useSticker(shareId: shareId, stickerId: stickerId)
        )

        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 [ShareService] useSticker 原始 JSON:")
            print(jsonString)
        }
        #endif

        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<StickerUseResponse>.self, from: data)

        guard response.respCode == 0 else {
            // 解析错误码
            let errorCode = response.respMsg ?? "UNKNOWN"
            if errorCode.contains("LEVEL_LOCKED") {
                throw StickerUseError.serverError(code: "LEVEL_LOCKED", message: "等级不足，无法使用此贴纸")
            } else if errorCode.contains("QUOTA_EXHAUSTED") {
                throw StickerUseError.serverError(code: "QUOTA_EXHAUSTED", message: "今日使用次数已达上限")
            }
            throw NSError(
                domain: "ShareService",
                code: response.respCode,
                userInfo: [NSLocalizedDescriptionKey: response.respMsg ?? "使用贴纸失败"]
            )
        }

        guard let useResponse = response.datas else {
            throw NSError(
                domain: "ShareService",
                code: -999,
                userInfo: [NSLocalizedDescriptionKey: "贴纸使用结果为空"]
            )
        }

        return useResponse
    }
}