//
//  StickerSummaryItem.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/12.
//
//  贴纸统计数据模型 - 用于顶部展示条和详细统计覆层
//

import Foundation

/// 贴纸统计项
/// 代表「当前这条分享下，某种贴纸的统计信息」
struct StickerSummaryItem: Identifiable, Hashable {
    /// 使用 StickerKind 作为唯一标识
    var id: StickerKind { kind }

    /// 贴纸种类
    let kind: StickerKind

    /// 显示名称（从 StickerDefinition 获取）
    let displayName: String

    /// 该贴纸的数量
    let count: Int

    /// 贴纸定义（包含视觉配置）
    let definition: StickerDefinition

    // MARK: - 便捷构造器

    /// 从 StickerKind 和数量创建统计项
    /// 自动从 StickerDefinition 获取显示名称和视觉配置
    init(kind: StickerKind, count: Int) {
        let definition = StickerDefinition.definition(for: kind)
        self.kind = kind
        self.displayName = definition.displayName
        self.count = count
        self.definition = definition
    }

    /// 完整构造器（用于需要自定义显示名称的场景）
    init(kind: StickerKind, displayName: String, count: Int, definition: StickerDefinition) {
        self.kind = kind
        self.displayName = displayName
        self.count = count
        self.definition = definition
    }
}

// MARK: - 排序支持

extension StickerSummaryItem: Comparable {
    /// 排序规则：
    /// 1. count 降序（数量多的排前面）
    /// 2. priority 降序（优先级高的排前面）
    /// 3. displayName 升序（按名称字母序）
    static func < (lhs: StickerSummaryItem, rhs: StickerSummaryItem) -> Bool {
        if lhs.count != rhs.count {
            return lhs.count > rhs.count  // 数量降序
        }
        if lhs.definition.priority != rhs.definition.priority {
            return lhs.definition.priority > rhs.definition.priority  // 优先级降序
        }
        return lhs.displayName < rhs.displayName  // 名称升序
    }
}
