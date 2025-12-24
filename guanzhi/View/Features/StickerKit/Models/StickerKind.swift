//
//  StickerKind.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/12.
//
//  贴纸种类枚举 - 统一后端 ID 与前端视觉配置的链接点
//
//  重要约束：
//  - 所有贴纸统一使用标签系统（tag_definition 表）
//  - case 必须严格对齐后端 tag_definition 表，不私自增删
//  - 每个用户对每条分享的每种贴纸只能使用一次
//

import Foundation

/// 贴纸种类枚举
/// - 后端负责：贴纸种类的业务含义、是否计数、配额限制
/// - 前端负责：同一个 ID 对应的图标、文案、优先级、动效等视觉和交互
enum StickerKind: String, CaseIterable, Codable, Hashable {

    // MARK: - 贴纸定义
    // ⚠️ 以下 case 必须与 admin-web 配置的 tag_definition 表一一对应

    /// 赞同 - tagCode: LIKE
    case like

    /// 无感 - tagCode: NEUTRAL
    case neutral

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

    /// 对应后端 tagCode
    /// 用于调用贴纸 API: POST /api/shares/{shareId}/stickers/use
    var tagCode: String {
        switch self {
        case .like:      return "LIKE"
        case .neutral:   return "NEUTRAL"
        case .mijing:    return "MIJING"
        case .zhenxiu:   return "ZHENXIU"
        case .wanqu:     return "WANQU"
        case .caikeng:   return "CAIKENG"
        case .maomao:    return "MAOMAO"
        case .chaosheng: return "CHAOSHENG"
        case .richu:     return "RICHU"
        case .jishi:     return "JISHI"
        }
    }

    /// 显示名称（硬编码兜底）
    /// 用于 UI 展示和文字回退，优先使用服务器返回的名称
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

    /// 动态显示名称
    /// 优先使用服务器返回的名称，回退到硬编码默认值
    var dynamicDisplayName: String {
        StickerNameService.shared.getName(for: tagCode, default: displayName)
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

    // MARK: - 后端 ID 映射

    /// 后端使用的贴纸 ID（与 rawValue 相同，但语义更明确）
    var backendId: String {
        rawValue
    }

    /// 从后端 stickerId 创建 StickerKind
    /// - Parameter backendId: 后端返回的贴纸 ID
    ///   支持两种格式：
    ///   - rawValue 格式（小写）: "like", "zhenxiu"
    ///   - tagCode 格式（大写）: "LIKE", "ZHENXIU"
    /// - Returns: 对应的 StickerKind，未知 ID 返回 nil
    init?(backendId: String) {
        // 1. 先尝试直接匹配 rawValue（小写）
        if let kind = StickerKind(rawValue: backendId) {
            self = kind
            return
        }

        // 2. 尝试将大写 tagCode 转换为小写 rawValue
        let lowercased = backendId.lowercased()
        if let kind = StickerKind(rawValue: lowercased) {
            self = kind
            return
        }

        // 3. 尝试通过 tagCode 查找（处理如 "ZHENXIU" -> .zhenxiu）
        if let kind = StickerKind.allCases.first(where: { $0.tagCode == backendId }) {
            self = kind
            return
        }

        return nil
    }

    // MARK: - 静态方法

    /// 从 tagCode 创建
    /// 用于从后端数据构建贴纸
    static func from(tagCode: String) -> StickerKind? {
        allCases.first { $0.tagCode == tagCode }
    }

    /// 从后端 stickerId 创建（推荐使用 init?(backendId:)）
    static func from(backendId: String) -> StickerKind? {
        StickerKind(backendId: backendId)
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
}
