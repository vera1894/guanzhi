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

// MARK: - Mock 数据

extension StickerDefinition {

    /// 点赞贴纸（使用自定义图片）
    static let mockLike = StickerDefinition(
        stickerID: StickerID(rawValue: "like"),
        displayName: "点赞",
        assetKind: .image(name: "stickers-good"),
        priority: 100,
        meta: ["type": "like"]
    )

    /// 无感贴纸
    static let mockNeutral = StickerDefinition(
        stickerID: StickerID(rawValue: "neutral"),
        displayName: "无感",
        assetKind: .systemSymbol(name: "face.smiling"),
        priority: 80,
        meta: ["type": "neutral"]
    )

    /// 爱心贴纸
    static let mockHeart = StickerDefinition(
        stickerID: StickerID(rawValue: "heart"),
        displayName: "爱心",
        assetKind: .systemSymbol(name: "heart.fill"),
        priority: 90,
        meta: ["type": "heart"]
    )

    /// 收藏贴纸
    static let mockStar = StickerDefinition(
        stickerID: StickerID(rawValue: "star"),
        displayName: "收藏",
        assetKind: .systemSymbol(name: "star.fill"),
        priority: 70,
        meta: ["type": "star"]
    )

    /// 火焰贴纸
    static let mockFire = StickerDefinition(
        stickerID: StickerID(rawValue: "fire"),
        displayName: "火热",
        assetKind: .systemSymbol(name: "flame.fill"),
        priority: 60,
        meta: ["type": "fire"]
    )

    /// 闪电贴纸
    static let mockBolt = StickerDefinition(
        stickerID: StickerID(rawValue: "bolt"),
        displayName: "闪电",
        assetKind: .systemSymbol(name: "bolt.fill"),
        priority: 50,
        meta: ["type": "bolt"]
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
