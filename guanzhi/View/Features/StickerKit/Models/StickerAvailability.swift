//
//  StickerAvailability.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/15.
//
//  贴纸可用性模型 - 表示用户对某个贴纸的使用权限和配额
//
//  数据来源：后端 GET /api/stickers/availability?shareId=...
//

import Foundation

// MARK: - StickerGroup

/// 贴纸分组（用于 UI 分组展示）
enum StickerGroup: String, Codable {
    /// 投票类（赞同/无感）
    case vote
    /// 标签类（秘境/珍馐/...）
    case tag
    /// 趣味类（预留，不计数）
    case fun

    /// 从后端字符串创建
    init?(from string: String?) {
        guard let str = string else { return nil }
        self.init(rawValue: str.lowercased())
    }
}

// MARK: - StickerAvailability

/// 贴纸可用性信息
/// 表示当前用户对某个贴纸在某个分享上的使用权限和配额
struct StickerAvailability: Identifiable, Equatable {

    /// 唯一标识（使用 kind 的 backendId）
    var id: String { kind.backendId }

    /// 贴纸种类
    let kind: StickerKind

    /// 是否已解锁（基于用户等级）
    let unlocked: Bool

    /// 每日使用上限（nil 表示无限制）
    let dailyLimit: Int?

    /// 今日已使用次数
    let usedToday: Int?

    /// 今日剩余可用次数（nil 表示无限制）
    let remainingToday: Int?

    /// 贴纸分组
    let group: StickerGroup?

    /// 当前用户是否已对此分享使用过该贴纸
    let alreadyApplied: Bool

    // MARK: - 计算属性

    /// 是否可以使用（解锁、有剩余配额、且未对此分享使用过）
    var canUse: Bool {
        // 已经使用过则不能再使用
        guard !alreadyApplied else { return false }
        guard unlocked else { return false }
        // 如果没有 remainingToday 信息，假设可以使用
        guard let remaining = remainingToday else { return true }
        return remaining > 0
    }

    /// 是否已达到每日上限
    var isQuotaExhausted: Bool {
        guard let remaining = remainingToday else { return false }
        return remaining <= 0
    }

    /// 用于 UI 显示的剩余次数文本
    var remainingText: String? {
        guard let remaining = remainingToday, let limit = dailyLimit else { return nil }
        if remaining <= 0 {
            return "今日已用完"
        } else if limit > 0 {
            return "剩余 \(remaining) 次"
        }
        return nil
    }
}

// MARK: - StickerAvailabilityDTO

/// 后端返回的贴纸可用性 DTO
/// 用于 JSON 解码，然后转换为 StickerAvailability
struct StickerAvailabilityDTO: Codable {
    let stickerId: String
    let unlocked: Bool
    let dailyLimit: Int?
    let usedToday: Int?
    let remainingToday: Int?
    let group: String?
    /// 当前用户是否已对此分享使用过该贴纸
    let alreadyApplied: Bool?

    /// 转换为 StickerAvailability
    func toAvailability() -> StickerAvailability? {
        guard let kind = StickerKind(backendId: stickerId) else {
            #if DEBUG
            print("⚠️ [StickerAvailability] 未知的 stickerId: \(stickerId)")
            #endif
            return nil
        }

        return StickerAvailability(
            kind: kind,
            unlocked: unlocked,
            dailyLimit: dailyLimit,
            usedToday: usedToday,
            remainingToday: remainingToday,
            group: StickerGroup(from: group),
            alreadyApplied: alreadyApplied ?? false
        )
    }
}

// MARK: - StickerSummaryDTO

/// 后端返回的贴纸统计 DTO
/// 字段名与后端 StickerQuotaService.StickerSummary 对齐
struct StickerSummaryDTO: Codable {
    let stickerId: String      // 后端字段名是 stickerId，不是 tagCode
    let stickerName: String    // 后端字段名是 stickerName，不是 tagName
    let group: String?
    let count: Int

    /// 转换为 StickerSummaryItem
    func toSummaryItem() -> StickerSummaryItem? {
        guard let kind = StickerKind(backendId: stickerId) else {
            #if DEBUG
            print("⚠️ [StickerSummaryDTO] 未知的 stickerId: \(stickerId)")
            #endif
            return nil
        }
        return StickerSummaryItem(kind: kind, count: count)
    }
}

// MARK: - CurrentUserStickerDTO

/// 后端返回的当前用户已使用贴纸 DTO
/// 字段名与后端 StickerQuotaService.CurrentUserSticker 对齐
struct CurrentUserStickerDTO: Codable {
    let stickerId: String      // 后端字段名是 stickerId，不是 tagCode
    let stickerName: String    // 后端字段名是 stickerName，不是 tagName
    let group: String?

    /// 转换为 UsedStickerInfo
    func toUsedStickerInfo() -> UsedStickerInfo? {
        guard let kind = StickerKind(backendId: stickerId) else {
            #if DEBUG
            print("⚠️ [CurrentUserStickerDTO] 未知的 stickerId: \(stickerId)")
            #endif
            return nil
        }
        return UsedStickerInfo(kind: kind, name: stickerName)
    }
}

// MARK: - StickerAvailabilityResponse

/// 后端返回的贴纸可用性列表响应
struct StickerAvailabilityResponse: Codable {
    let stickers: [StickerAvailabilityDTO]

    /// 贴纸统计（每种贴纸的使用数量）
    let stickerSummaries: [StickerSummaryDTO]?

    /// 当前用户在此分享上已使用的贴纸（nil 表示未使用）
    let currentUserSticker: CurrentUserStickerDTO?

    /// 转换为 StickerAvailability 数组
    func toAvailabilities() -> [StickerAvailability] {
        stickers.compactMap { $0.toAvailability() }
    }

    /// 转换为 StickerSummaryItem 数组
    func toSummaryItems() -> [StickerSummaryItem] {
        (stickerSummaries ?? []).compactMap { $0.toSummaryItem() }.sorted()
    }

    /// 转换为 UsedStickerInfo（当前用户已使用的贴纸）
    func toCurrentUserSticker() -> UsedStickerInfo? {
        currentUserSticker?.toUsedStickerInfo()
    }
}

// MARK: - StickerAvailabilityResult

/// fetchStickerAvailability 的完整返回结果
/// 包含贴纸可用性列表、统计数据、当前用户使用的贴纸
struct StickerAvailabilityResult {
    /// 贴纸可用性列表
    let availabilities: [StickerAvailability]

    /// 贴纸统计列表（按数量降序排序）
    let summaries: [StickerSummaryItem]

    /// 当前用户在此分享上已使用的贴纸（nil 表示未使用）
    let currentUserSticker: UsedStickerInfo?
}

// MARK: - StickerUseResponse

/// 后端返回的贴纸使用结果响应
struct StickerUseResponse: Codable {
    /// 是否成功
    let success: Bool

    /// 剩余可用次数（更新后）
    let remainingToday: Int?

    /// 错误码（如果失败）
    let errorCode: String?

    /// 错误信息（如果失败）
    let errorMessage: String?
}

// MARK: - StickerUseError

/// 贴纸使用错误
enum StickerUseError: Error, LocalizedError {
    /// 贴纸未解锁（等级不足）
    case levelLocked(kind: StickerKind)

    /// 今日配额已用完
    case quotaExhausted(kind: StickerKind)

    /// 已经使用过贴纸（每个分享只能使用一个贴纸）
    /// - Parameters:
    ///   - usedKind: 已使用的贴纸种类
    ///   - usedName: 已使用的贴纸名称（来自服务器）
    case alreadyUsed(usedKind: StickerKind?, usedName: String?)

    /// 网络错误
    case networkError(underlying: Error)

    /// 服务器返回错误
    case serverError(code: String, message: String)

    /// 未知错误
    case unknown

    var errorDescription: String? {
        switch self {
        case .levelLocked(let kind):
            return "\"\(kind.dynamicDisplayName)\"贴纸需要更高等级才能使用"
        case .quotaExhausted(let kind):
            return "\"\(kind.dynamicDisplayName)\"今日使用次数已达上限"
        case .alreadyUsed(_, let usedName):
            if let name = usedName {
                return "这条观之已使用过「\(name)」贴纸"
            }
            return "这条观之已使用过贴纸"
        case .networkError:
            return "网络连接失败，请稍后重试"
        case .serverError(_, let message):
            return message
        case .unknown:
            return "操作失败，请稍后重试"
        }
    }
}
