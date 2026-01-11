//
//  ServerTime.swift
//  guanzhi
//
//  Created by Claude Code on 2026-01-10.
//
//  服务端时间解析器 - 唯一的时间解析入口
//
//  设计原则：
//  - 网络层 decode：只负责把"原始字段"变成 Date（一次）
//  - 展示层：只负责 Date → String（一次）
//  - 中间不允许 Date ↔ timestamp 来回做补偿
//  - 解析失败返回 nil，不静默返回当前时间
//

import Foundation

// MARK: - ServerTime

/// 服务端时间解析器 - 唯一的时间解析入口
enum ServerTime {

    // MARK: - 固定 Calendar（避免本地化差异）

    /// 固定使用 Gregorian 日历，避免 Calendar.current 带来的不可预测行为
    private static let gregorianCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    // MARK: - 时间戳解析（毫秒）

    /// 解析服务端时间戳（毫秒）- 主入口
    /// - Parameter milliseconds: UTC epoch 毫秒时间戳（Int64 避免溢出）
    /// - Returns: Date 对象（时间戳解析不会失败）
    static func parse(milliseconds: Int64) -> Date {
        return Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000.0)
    }

    /// 便捷重载（Int 版本）
    static func parse(milliseconds: Int) -> Date {
        return parse(milliseconds: Int64(milliseconds))
    }

    // MARK: - 字符串解析（返回 Optional）

    /// 解析 ISO8601 字符串（带时区后缀）
    /// - Parameter string: 时间字符串，如 "2026-01-10T08:00:00Z" 或 "2026-01-10T16:00:00+08:00"
    /// - Returns: Date? 解析失败返回 nil
    static func parse(iso8601 string: String) -> Date? {
        let formatter = ISO8601DateFormatter()

        // 尝试带毫秒格式
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }

        // 尝试不带毫秒格式
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) {
            return date
        }

        // 解析失败，记录日志
        TimeAuditLogger.logParseFailure(input: string, type: "iso8601")
        return nil
    }

    /// 解析不带时区的字符串（需要假设时区）
    /// - Parameters:
    ///   - string: 时间字符串，如 "2026-01-10T16:00:00"
    ///   - assumedTimezone: 假设的时区（字符串无时区后缀时使用）
    /// - Returns: Date? 解析失败返回 nil
    static func parse(string: String, assumedTimezone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")  // 解析用 POSIX
        formatter.timeZone = assumedTimezone

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }

        // 解析失败，记录日志
        TimeAuditLogger.logParseFailure(input: string, type: "string", timezone: assumedTimezone.identifier)
        return nil
    }

    // MARK: - 数组解析（返回 Optional，使用固定 Calendar）

    /// 解析 [year, month, day, hour, minute, second] 数组
    /// - Parameters:
    ///   - array: 时间数组
    ///   - timezone: 数组表示的时区
    /// - Returns: Date? 解析失败返回 nil
    static func parse(array: [Int], timezone: TimeZone = .utc) -> Date? {
        guard array.count >= 5 else {
            TimeAuditLogger.logParseFailure(input: "\(array)", type: "array", reason: "数组长度不足")
            return nil
        }

        var components = DateComponents()
        components.year = array[0]
        components.month = array[1]
        components.day = array[2]
        components.hour = array[3]
        components.minute = array[4]
        components.second = array.count > 5 ? array[5] : 0
        components.timeZone = timezone

        // 使用固定的 Gregorian Calendar，避免本地化差异
        var calendar = gregorianCalendar
        calendar.timeZone = timezone

        guard let date = calendar.date(from: components) else {
            TimeAuditLogger.logParseFailure(input: "\(array)", type: "array", reason: "无效的日期组件")
            return nil
        }

        return date
    }

    // MARK: - 便捷方法（带默认值，用于 UI 层）

    /// 解析字符串，失败时返回默认值
    static func parseOrDefault(string: String, assumedTimezone: TimeZone, default defaultDate: Date = Date()) -> Date {
        return parse(string: string, assumedTimezone: assumedTimezone) ?? defaultDate
    }

    /// 解析 ISO8601，失败时返回默认值
    static func parseOrDefault(iso8601 string: String, default defaultDate: Date = Date()) -> Date {
        return parse(iso8601: string) ?? defaultDate
    }

    /// 解析数组，失败时返回默认值
    static func parseOrDefault(array: [Int], timezone: TimeZone = .utc, default defaultDate: Date = Date()) -> Date {
        return parse(array: array, timezone: timezone) ?? defaultDate
    }
}

// MARK: - TimeZone 扩展

extension TimeZone {
    static let utc = TimeZone(identifier: "UTC")!
    static let shanghai = TimeZone(identifier: "Asia/Shanghai")!
}

// MARK: - TimeAuditLogger（解析失败日志）

/// 时间解析审计日志 - 用于排查"幽灵时间 bug"
enum TimeAuditLogger {

    /// 是否启用日志（建议 Debug 模式启用）
    static var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// 记录解析失败
    static func logParseFailure(input: String, type: String, timezone: String? = nil, reason: String? = nil) {
        guard isEnabled else { return }

        var message = "[TimeAuditLogger] 解析失败 - type: \(type), input: \(input)"
        if let tz = timezone {
            message += ", timezone: \(tz)"
        }
        if let r = reason {
            message += ", reason: \(r)"
        }

        print(message)

        #if DEBUG
        // Debug 模式下可以考虑断言，便于开发时及早发现问题
        // assertionFailure(message)
        #endif
    }
}
