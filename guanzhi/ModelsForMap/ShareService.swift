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

    /// 记录分享浏览（用于褪色度计算）
    /// - Parameter shareId: 分享ID
    /// - Note: 此接口用于上报用户浏览行为，后端会根据浏览数据计算褪色度
    func recordShareView(shareId: Int64) async throws {
        let data = try await OTONetwork.request(
            .recordShareView(shareId: shareId)
        )

        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<EmptyData>.self, from: data)

        // 允许 respCode != 0 的情况（比如后端还没实现），不抛出错误
        #if DEBUG
        if response.respCode == 0 {
            print("✅ [ShareService] recordShareView 成功: shareId=\(shareId)")
        } else {
            print("⚠️ [ShareService] recordShareView 返回非0: respCode=\(response.respCode), msg=\(response.respMsg ?? "无")")
        }
        #endif
    }

    // MARK: - 贴纸系统 API

    /// 获取贴纸可用性列表（包含统计数据和当前用户使用的贴纸）
    /// - Parameter shareId: 分享 ID
    /// - Returns: 完整的贴纸可用性结果
    func fetchStickerAvailability(shareId: Int64) async throws -> StickerAvailabilityResult {
        let data = try await OTONetwork.request(
            .fetchStickerAvailability(shareId: shareId)
        )

        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 [ShareService] fetchStickerAvailability 原始 JSON:")
            print(jsonString)
            // 检查原始 JSON 中是否包含 stickerSummaries
            if jsonString.contains("stickerSummaries") {
                print("🔍 [ShareService] ✅ 原始 JSON 中包含 stickerSummaries")
            } else {
                print("🔍 [ShareService] ⚠️ 原始 JSON 中 **不包含** stickerSummaries！")
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

        // 解析贴纸统计
        if let summaries = responseData.stickerSummaries {
            print("🔍 [ShareService] 贴纸统计，共 \(summaries.count) 条:")
            for summary in summaries {
                print("   - stickerId='\(summary.stickerId)', stickerName='\(summary.stickerName)', count=\(summary.count)")
            }
        } else {
            print("🔍 [ShareService] ⚠️ 贴纸统计为空")
        }

        // 解析当前用户贴纸
        if let current = responseData.currentUserSticker {
            print("🔍 [ShareService] 当前用户已使用贴纸: stickerId='\(current.stickerId)', stickerName='\(current.stickerName)'")
        } else {
            print("🔍 [ShareService] 当前用户未使用贴纸")
        }
        #endif

        let availabilities = responseData.toAvailabilities()
        let summaries = responseData.toSummaryItems()
        let currentUserSticker = responseData.toCurrentUserSticker()

        #if DEBUG
        print("🔍 [ShareService] 转换后的 StickerAvailability，共 \(availabilities.count) 条")
        print("🔍 [ShareService] 转换后的 StickerSummary，共 \(summaries.count) 条:")
        for summary in summaries {
            print("   - [\(summary.kind.rawValue)] \(summary.displayName): count=\(summary.count)")
        }
        #endif

        return StickerAvailabilityResult(
            availabilities: availabilities,
            summaries: summaries,
            currentUserSticker: currentUserSticker
        )
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