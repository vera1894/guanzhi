//
//  StickerKind.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/12.
//
//  贴纸种类枚举 - 统一后端 ID 与前端视觉配置的链接点
//
//  重要约束：
//  - 投票类 (like/neutral) 对所有用户开放，互斥
//  - 标签类 case 必须严格对齐后端 tag_definition 表，不私自增删
//  - 使用 asVoteState 进行映射，避免 like/agree 命名混用
//

import Foundation

/// 贴纸种类枚举
/// - 后端负责：贴纸种类的业务含义、是否计数、是否互斥
/// - 前端负责：同一个 ID 对应的图标、文案、优先级、动效等视觉和交互
enum StickerKind: String, CaseIterable, Codable, Hashable {

    // MARK: - 投票类（互斥，对所有用户开放）

    /// 赞同/点赞 - 对应后端 voteType=1
    case like

    /// 无感 - 对应后端 voteType=0
    case neutral

    // MARK: - 标签类（基于用户权限，必须与后端 TagDefinition 严格对齐）
    // ⚠️ 以下 case 必须与 admin-web 配置的 tag_definition 表一一对应

    /// 秘境 - tagCode: MIJING
    case mijing

    /// 珍馐 - tagCode: ZHENXIU
    case zhenxiu

    /// 玩趣 - tagCode: WANQU
    case wanqu

    /// 踩坑预警 - tagCode: CAIKENG
    case caikeng

    /// 猫猫出没 - tagCode: MAOMAO
    case maomao

    /// 朝圣 - tagCode: CHAOSHENG
    case chaosheng

    /// 日出 - tagCode: RICHU
    case richu

    /// 集市 - tagCode: JISHI
    case jishi

    // MARK: - 属性

    /// 是否为投票类贴纸（互斥组）
    /// 投票类贴纸：like 和 neutral 互斥，用户只能选一个
    var isVoteType: Bool {
        self == .like || self == .neutral
    }

    /// 是否为标签类贴纸
    /// 标签类贴纸：基于用户等级权限，可以贴多个
    var isTagType: Bool {
        !isVoteType
    }

    /// 是否需要持久化到服务器
    /// 投票类和标签类都需要持久化
    var isPersistable: Bool {
        // 所有类型都需要持久化（投票类走 vote 接口，标签类走 tag 接口）
        true
    }

    /// 转换为 VoteState（仅投票类有效）
    /// 统一映射入口，避免在代码中混用 like/agree
    var asVoteState: VoteState? {
        switch self {
        case .like:
            return .agree
        case .neutral:
            return .neutral
        default:
            return nil
        }
    }

    /// 对应后端 tagCode（仅标签类有效）
    /// 用于调用标签 API: POST /api/guan/share/tag
    var tagCode: String? {
        switch self {
        case .mijing:    return "MIJING"
        case .zhenxiu:   return "ZHENXIU"
        case .wanqu:     return "WANQU"
        case .caikeng:   return "CAIKENG"
        case .maomao:    return "MAOMAO"
        case .chaosheng: return "CHAOSHENG"
        case .richu:     return "RICHU"
        case .jishi:     return "JISHI"
        default:         return nil
        }
    }

    /// 显示名称
    /// 用于 UI 展示和文字回退
    var displayName: String {
        switch self {
        case .like:      return "赞同"
        case .neutral:   return "无感"
        case .mijing:    return "秘境"
        case .zhenxiu:   return "珍馐"
        case .wanqu:     return "玩趣"
        case .caikeng:   return "踩坑"
        case .maomao:    return "猫猫"
        case .chaosheng: return "朝圣"
        case .richu:     return "日出"
        case .jishi:     return "集市"
        }
    }

    /// 默认优先级（数值越大越靠前）
    /// 用于贴纸队列排序
    var defaultPriority: Int {
        switch self {
        case .like:      return 100
        case .neutral:   return 80
        case .mijing:    return 70
        case .zhenxiu:   return 69
        case .wanqu:     return 68
        case .caikeng:   return 67
        case .maomao:    return 66
        case .chaosheng: return 65
        case .richu:     return 64
        case .jishi:     return 63
        }
    }

    // MARK: - 静态方法

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

    /// 从 tagCode 创建（仅标签类）
    /// 用于从后端数据构建贴纸
    static func from(tagCode: String) -> StickerKind? {
        allCases.first { $0.tagCode == tagCode }
    }

    /// 所有投票类贴纸
    static var voteTypes: [StickerKind] {
        allCases.filter { $0.isVoteType }
    }

    /// 所有标签类贴纸
    static var tagTypes: [StickerKind] {
        allCases.filter { $0.isTagType }
    }
}

// MARK: - 兼容性别名（保持旧代码可用）

extension StickerKind {
    /// 兼容旧代码的 voteState 属性
    /// 建议使用 asVoteState 以保持命名一致性
    var voteState: VoteState? {
        asVoteState
    }
}

// MARK: - UserLevelConfig

/// 用户等级配置
/// 单点维护等级与权限的映射关系，方便后续切换为后端驱动
///
/// TODO: 临时方案，后续改成后端驱动
/// - 当前：前端维护等级 → taggingAllowance 映射表
/// - 后续：从后端 /api/config/levels 接口获取，或后端直接返回 canTag: Bool
enum UserLevelConfig {

    // MARK: - 等级 → taggingAllowance 映射

    /// 等级代码对应的每日贴纸使用配额
    /// - 等级越高，每日可用次数越多
    /// - 0 表示没有贴标签权限
    ///
    /// 注意：此映射必须与后端 level_definition 表保持同步
    private static let levelTaggingAllowanceMap: [String: Int] = [
        "YOMIN": 0,       // 幼民 - 无贴标签权限
        "CHONGLANG": 0,   // 冲浪 - 无贴标签权限
        "QIANSHUI": 5,    // 潜水 - 每日 5 次
        "LANDONG": 10,    // 懒洞 - 每日 10 次
        "SHUIMU": 15,     // 水母 - 每日 15 次
        "DENGTA": 20      // 灯塔 - 每日 20 次
    ]

    /// 获取指定等级的 taggingAllowance
    /// - Parameter levelCode: 等级代码（如 "YOMIN", "CHONGLANG" 等）
    /// - Returns: 每日贴纸使用配额，未知等级返回 0
    static func getTaggingAllowance(for levelCode: String?) -> Int {
        guard let code = levelCode else { return 0 }
        return levelTaggingAllowanceMap[code] ?? 0
    }

    /// 判断指定等级是否有贴标签权限
    /// - Parameter levelCode: 等级代码
    /// - Returns: 是否有权限
    static func canTag(for levelCode: String?) -> Bool {
        getTaggingAllowance(for: levelCode) > 0
    }

    // MARK: - 便捷方法

    /// 计算用户可用的贴纸种类
    /// - Parameters:
    ///   - levelCode: 用户等级代码
    ///   - activeTagCodes: 启用的标签列表（空集合表示全部启用）
    /// - Returns: 可用的贴纸种类集合
    static func computeAvailableKinds(
        for levelCode: String?,
        activeTagCodes: Set<String> = []
    ) -> Set<StickerKind> {
        // 投票类对所有人开放
        var available: Set<StickerKind> = [.like, .neutral]

        // 有标签权限时，添加启用的标签类贴纸
        if canTag(for: levelCode) {
            let tagKinds = StickerKind.tagTypes.filter { kind in
                guard let tagCode = kind.tagCode else { return false }
                // 空集合表示全部启用
                return activeTagCodes.isEmpty || activeTagCodes.contains(tagCode)
            }
            available.formUnion(tagKinds)
        }

        return available
    }
}
