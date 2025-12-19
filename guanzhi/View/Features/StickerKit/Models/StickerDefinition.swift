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

    /// 文字回退（取 displayName 前两个字符）
    /// 用于没有图标的贴纸，显示文字作为视觉标识
    case textFallback(characters: String)

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
        // 投票类
        case .like:
            return .stickerLike
        case .neutral:
            return .stickerNeutral

        // 标签类
        case .mijing:
            return .stickerMijing
        case .zhenxiu:
            return .stickerZhenxiu
        case .wanqu:
            return .stickerWanqu
        case .caikeng:
            return .stickerCaikeng
        case .maomao:
            return .stickerMaomao
        case .chaosheng:
            return .stickerChaosheng
        case .richu:
            return .stickerRichu
        case .jishi:
            return .stickerJishi
        }
    }

    /// 从 StickerKind 集合生成定义数组（按优先级排序）
    static func definitions(for kinds: Set<StickerKind>) -> [StickerDefinition] {
        kinds
            .map { definition(for: $0) }
            .sorted { $0.priority > $1.priority }
    }
}

// MARK: - 投票类贴纸定义

extension StickerDefinition {

    /// 赞同贴纸（使用自定义图片）
    static let stickerLike = StickerDefinition(
        stickerID: StickerID(rawValue: "like"),
        kind: .like,
        displayName: "赞同",
        assetKind: .image(name: "stickers-like"),
        priority: 100,
        meta: [:]
    )

    /// 无感贴纸（临时使用图片，排查 textFallback 崩溃问题）
    /// TODO: 确认 textFallback 问题后恢复为 .textFallback(characters: "无感")
    static let stickerNeutral = StickerDefinition(
        stickerID: StickerID(rawValue: "neutral"),
        kind: .neutral,
        displayName: "无感",
        assetKind: .image(name: "stickers-neutral"),  // ⚠️ 临时改为图片，排查崩溃
        priority: 80,
        meta: [:]
    )
}

// MARK: - 标签类贴纸定义
// ⚠️ 临时：所有贴纸都使用 stickers-good 图片，后续用户会自行替换为各自的图标

extension StickerDefinition {

    /// 秘境贴纸
    static let stickerMijing = StickerDefinition(
        stickerID: StickerID(rawValue: "mijing"),
        kind: .mijing,
        displayName: "秘境",
        assetKind: .image(name: "stickers-like"),  // TODO: 替换为专属图标
        priority: 70,
        meta: ["tagCode": "MIJING"]
    )

    /// 珍馐贴纸
    static let stickerZhenxiu = StickerDefinition(
        stickerID: StickerID(rawValue: "zhenxiu"),
        kind: .zhenxiu,
        displayName: "珍馐美味",
        assetKind: .image(name: "stickers-like"),  // TODO: 替换为专属图标
        priority: 69,
        meta: ["tagCode": "ZHENXIU"]
    )

    /// 玩趣贴纸
    static let stickerWanqu = StickerDefinition(
        stickerID: StickerID(rawValue: "wanqu"),
        kind: .wanqu,
        displayName: "有点儿意思",
        assetKind: .image(name: "stickers-like"),  // TODO: 替换为专属图标
        priority: 68,
        meta: ["tagCode": "WANQU"]
    )

    /// 踩坑预警贴纸
    static let stickerCaikeng = StickerDefinition(
        stickerID: StickerID(rawValue: "caikeng"),
        kind: .caikeng,
        displayName: "踩坑预警！",
        assetKind: .image(name: "stickers-like"),  // TODO: 替换为专属图标
        priority: 67,
        meta: ["tagCode": "CAIKENG"]
    )

    /// 猫猫出没贴纸
    static let stickerMaomao = StickerDefinition(
        stickerID: StickerID(rawValue: "maomao"),
        kind: .maomao,
        displayName: "猫猫出没",
        assetKind: .image(name: "stickers-like"),  // TODO: 替换为专属图标
        priority: 66,
        meta: ["tagCode": "MAOMAO"]
    )

    /// 朝圣贴纸
    static let stickerChaosheng = StickerDefinition(
        stickerID: StickerID(rawValue: "chaosheng"),
        kind: .chaosheng,
        displayName: "朝圣点",
        assetKind: .image(name: "stickers-like"),  // TODO: 替换为专属图标
        priority: 65,
        meta: ["tagCode": "CHAOSHENG"]
    )

    /// 日出贴纸
    static let stickerRichu = StickerDefinition(
        stickerID: StickerID(rawValue: "richu"),
        kind: .richu,
        displayName: "日出点",
        assetKind: .image(name: "stickers-like"),  // TODO: 替换为专属图标
        priority: 64,
        meta: ["tagCode": "RICHU"]
    )

    /// 集市贴纸
    static let stickerJishi = StickerDefinition(
        stickerID: StickerID(rawValue: "jishi"),
        kind: .jishi,
        displayName: "集市",
        assetKind: .image(name: "stickers-like"),  // TODO: 替换为专属图标
        priority: 63,
        meta: ["tagCode": "JISHI"]
    )
}

// MARK: - 兼容性别名（保持旧代码可用）

extension StickerDefinition {

    /// 兼容旧代码：mockLike
    static var mockLike: StickerDefinition { stickerLike }

    /// 兼容旧代码：mockNeutral
    static var mockNeutral: StickerDefinition { stickerNeutral }

    /// 兼容旧代码：mockHeart（已移除，返回 like 作为占位）
    static var mockHeart: StickerDefinition { stickerLike }

    /// 兼容旧代码：mockStar（已移除，返回 like 作为占位）
    static var mockStar: StickerDefinition { stickerLike }

    /// 兼容旧代码：mockFire（已移除，返回 like 作为占位）
    static var mockFire: StickerDefinition { stickerLike }

    /// 兼容旧代码：mockBolt（已移除，返回 like 作为占位）
    static var mockBolt: StickerDefinition { stickerLike }

    /// 兼容旧代码：所有投票类贴纸（按优先级排序）
    static var mockAll: [StickerDefinition] {
        StickerKind.voteTypes.map { definition(for: $0) }.sorted { $0.priority > $1.priority }
    }
}
