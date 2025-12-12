//
//  StickerDefinition.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/10.
//
//  贴纸数据模型 - 用于互动贴纸系统
//  注意：此模块与 CameraViews 中的 Badge 系统完全独立
//

import SwiftUI

// MARK: - StickerID

/// 贴纸唯一标识
struct StickerID: Hashable, Codable, Equatable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - StickerAssetKind

/// 贴纸资源类型（支持扩展）
enum StickerAssetKind: Equatable {
    /// Assets 中的 PNG/PDF 图像
    case image(name: String)

    /// SF Symbol
    case systemSymbol(name: String)

    /// 未来：SVG 渲染
    case svg(name: String)

    /// 未来：3D 贴纸（SK3DNode 或 Snapshot）
    case threeD(configID: String)
}

// MARK: - StickerDefinition

/// 贴纸定义
struct StickerDefinition: Identifiable, Hashable {
    var id: StickerID { stickerID }

    /// 贴纸唯一标识
    let stickerID: StickerID

    /// 贴纸种类（统一 ID，链接后端与前端）
    let kind: StickerKind

    /// 显示名称
    let displayName: String

    /// 资源类型
    let assetKind: StickerAssetKind

    /// 排序优先级（数值越大越靠前）
    let priority: Int

    /// 扩展元数据（如绑定的互动类型）
    let meta: [String: String]

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(stickerID)
    }

    static func == (lhs: StickerDefinition, rhs: StickerDefinition) -> Bool {
        lhs.stickerID == rhs.stickerID
    }
}

// MARK: - 工厂方法

extension StickerDefinition {
    /// 从 StickerKind 获取对应的贴纸定义
    /// 这是获取贴纸配置的统一入口，避免在各处使用魔法字符串
    static func definition(for kind: StickerKind) -> StickerDefinition {
        switch kind {
        case .like:
            return .mockLike
        case .neutral:
            return .mockNeutral
        case .heart:
            return .mockHeart
        case .star:
            return .mockStar
        case .fire:
            return .mockFire
        case .bolt:
            return .mockBolt
        }
    }
}

// MARK: - Mock 数据

extension StickerDefinition {

    /// 点赞贴纸（使用自定义图片）
    static let mockLike = StickerDefinition(
        stickerID: StickerID(rawValue: "like"),
        kind: .like,
        displayName: "赞同",
        assetKind: .image(name: "stickers-good"),
        priority: 100,
        meta: [:]
    )

    /// 无感贴纸
    static let mockNeutral = StickerDefinition(
        stickerID: StickerID(rawValue: "neutral"),
        kind: .neutral,
        displayName: "无感",
        assetKind: .systemSymbol(name: "face.smiling"),
        priority: 80,
        meta: [:]
    )

    /// 爱心贴纸
    static let mockHeart = StickerDefinition(
        stickerID: StickerID(rawValue: "heart"),
        kind: .heart,
        displayName: "爱心",
        assetKind: .systemSymbol(name: "heart.fill"),
        priority: 90,
        meta: [:]
    )

    /// 收藏贴纸
    static let mockStar = StickerDefinition(
        stickerID: StickerID(rawValue: "star"),
        kind: .star,
        displayName: "收藏",
        assetKind: .systemSymbol(name: "star.fill"),
        priority: 70,
        meta: [:]
    )

    /// 火焰贴纸
    static let mockFire = StickerDefinition(
        stickerID: StickerID(rawValue: "fire"),
        kind: .fire,
        displayName: "火热",
        assetKind: .systemSymbol(name: "flame.fill"),
        priority: 60,
        meta: [:]
    )

    /// 闪电贴纸
    static let mockBolt = StickerDefinition(
        stickerID: StickerID(rawValue: "bolt"),
        kind: .bolt,
        displayName: "闪电",
        assetKind: .systemSymbol(name: "bolt.fill"),
        priority: 50,
        meta: [:]
    )

    /// 所有 Mock 贴纸（按优先级排序）
    static let mockAll: [StickerDefinition] = [
        .mockLike,
        .mockHeart,
        .mockNeutral,
        .mockStar,
        .mockFire,
        .mockBolt
    ].sorted { $0.priority > $1.priority }
}
