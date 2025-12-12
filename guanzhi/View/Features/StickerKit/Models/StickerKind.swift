//
//  StickerKind.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/12.
//
//  贴纸种类枚举 - 统一后端 ID 与前端视觉配置的链接点
//  注意：此枚举是贴纸系统的核心标识，避免使用魔法字符串
//

import Foundation

/// 贴纸种类枚举
/// - 后端负责：贴纸种类的业务含义、是否计数、是否互斥
/// - 前端负责：同一个 ID 对应的图标、文案、优先级、动效等视觉和交互
enum StickerKind: String, CaseIterable, Codable, Hashable {
    // MARK: - 可持久化贴纸（与后端投票系统对应）

    /// 赞同/点赞 - 对应后端 voteType=1
    case like

    /// 无感 - 对应后端 voteType=0
    case neutral

    // MARK: - 本地贴纸（仅前端展示，不上报服务器）

    /// 爱心
    case heart

    /// 收藏/星标
    case star

    /// 火热
    case fire

    /// 闪电
    case bolt

    // MARK: - 属性

    /// 是否需要持久化到服务器
    /// 当前阶段：只有 like / neutral 需要计入服务器，其它贴纸本地玩
    var isPersistable: Bool {
        switch self {
        case .like, .neutral:
            return true
        default:
            return false
        }
    }

    /// 转换为 VoteState（仅限可持久化的类型）
    /// 用于将贴纸使用动作转换为投票操作
    var voteState: VoteState? {
        switch self {
        case .like:
            return .agree
        case .neutral:
            return .neutral
        default:
            return nil
        }
    }

    /// 从 VoteState 反向获取对应的 StickerKind
    /// 用于从投票状态构建贴纸统计
    static func from(voteState: VoteState) -> StickerKind? {
        switch voteState {
        case .agree:
            return .like
        case .neutral:
            return .neutral
        case .none:
            return nil
        }
    }
}
