//
//  TimeDisplay.swift
//  guanzhi
//
//  Created by Claude Code on 2026-01-10.
//
//  时间显示格式化器 - 唯一的时间显示出口
//
//  设计原则：
//  - 相对时间使用 RelativeDateTimeFormatter，自动跟随系统语言
//  - 绝对时间使用 DateFormatter 的 dateStyle/timeStyle，自动本地化
//  - 每次调用前更新 locale/timezone，确保系统设置变更后立即生效
//  - @MainActor 确保线程安全
//

import Foundation

// MARK: - TimeDisplay

/// 时间显示格式化器 - 唯一的时间显示出口
@MainActor
final class TimeDisplay {

    static let shared = TimeDisplay()

    /// 时区提供者（默认跟随系统，测试时可注入）
    var timeZoneProvider: () -> TimeZone = { TimeZone.current }

    /// 本地化提供者（默认跟随系统，测试时可注入）
    var localeProvider: () -> Locale = { Locale.current }

    // MARK: - 相对时间（使用 RelativeDateTimeFormatter）

    /// 相对时间（自动跟随系统语言：刚刚/x分钟前/昨天...）
    /// - Parameter date: Date 对象
    /// - Returns: 本地化的相对时间字符串
    func relativeTime(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        // 每次调用前更新 locale，避免缓存不一致
        relativeFormatter.locale = localeProvider()

        // 特殊处理：未来时间或极短时间 → "刚刚"（产品风格修饰）
        if interval < 10 {
            let result = relativeFormatter.localizedString(for: date, relativeTo: now)
            // 兜底处理 "0 seconds ago" / "in 0 seconds" 等不友好文案
            if result.contains("0 second") || result.contains("0秒") {
                return localizedJustNow
            }
            return result
        }

        return relativeFormatter.localizedString(for: date, relativeTo: now)
    }

    /// "刚刚" 的本地化文案
    /// 使用 localeProvider() 而非 Locale.current，确保测试注入生效
    private var localizedJustNow: String {
        let locale = localeProvider()
        let lang = locale.language.languageCode?.identifier ?? "zh"
        switch lang {
        case "zh": return "刚刚"
        case "en": return "Just now"
        case "ja": return "たった今"
        default: return "Just now"
        }
    }

    // MARK: - 绝对时间（跟随系统本地化）

    /// 绝对时间（跟随系统时区和本地化格式）
    /// - Parameters:
    ///   - date: Date 对象
    ///   - style: 显示样式
    /// - Returns: 本地化的绝对时间字符串
    func absoluteTime(from date: Date, style: DateStyle = .medium) -> String {
        let formatter = cachedFormatter(for: style)

        // 使用系统当前时区
        let currentTZ = TimeZone.current
        formatter.timeZone = currentTZ

        #if DEBUG
        // 调试输出（仅 DEBUG 模式）
        print("🕐[TimeDisplay] timezone: \(currentTZ.identifier), date: \(date), style: \(style)")
        #endif

        // 对于 fixedFormat，保持 en_US_POSIX locale；其他样式跟随系统
        if case .fixedFormat = style {
            // 已在 cachedFormatter 中设置 en_US_POSIX，不覆盖
        } else {
            formatter.locale = localeProvider()
        }
        return formatter.string(from: date)
    }

    /// 智能显示（7天内相对时间，否则绝对时间）
    func smartTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval >= 0 && interval < 86400 * 7 {
            return relativeTime(from: date)
        }
        return absoluteTime(from: date, style: .medium)
    }

    // MARK: - 样式定义（拆分 template vs fixedFormat）

    enum DateStyle: Hashable {
        case short          // 短日期（如 1/10 或 Jan 10）
        case medium         // 中等（如 2026/1/10 16:00 或 Jan 10, 2026, 4:00 PM）
        case dateOnly       // 仅日期
        case timeOnly       // 仅时间

        /// 本地化骨架模板（如 "yMMMdHm"）
        /// 系统会根据 locale 自动排布为正确的本地化格式
        /// 示例：
        ///   - "yMMMd" → 英文 "Jan 10, 2026" / 中文 "2026年1月10日"
        ///   - "Hm" → 24小时制 "16:00"
        ///   - "hm" → 12小时制 "4:00 PM"
        case customTemplate(String)

        /// 固定格式串（如 "yyyy-MM-dd HH:mm"）
        /// 警告：这会完全破坏本地化！
        /// 仅在产品明确要求"所有用户看到相同格式"时使用
        case fixedFormat(String)
    }

    // MARK: - Private

    /// RelativeDateTimeFormatter（lazy 初始化，每次使用前更新 locale）
    private lazy var relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full  // "2 minutes ago" vs "2 min ago"
        return formatter
    }()

    /// DateFormatter 缓存（按样式缓存，但每次使用前更新 locale/timezone）
    private var formatterCache: [DateStyle: DateFormatter] = [:]

    private func cachedFormatter(for style: DateStyle) -> DateFormatter {
        if let formatter = formatterCache[style] {
            return formatter
        }

        let formatter = DateFormatter()

        switch style {
        case .short:
            formatter.dateStyle = .short
            formatter.timeStyle = .none

        case .medium:
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

        case .dateOnly:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none

        case .timeOnly:
            formatter.dateStyle = .none
            formatter.timeStyle = .short

        case .customTemplate(let template):
            // 使用本地化骨架模板，系统自动排布
            formatter.setLocalizedDateFormatFromTemplate(template)

        case .fixedFormat(let format):
            // 固定格式，完全破坏本地化
            // 仅在产品明确要求时使用
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
        }

        formatterCache[style] = formatter
        return formatter
    }
}
