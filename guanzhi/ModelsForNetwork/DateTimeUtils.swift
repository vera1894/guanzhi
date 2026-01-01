//
//  DateTimeUtils.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/1.
//  统一的时间解析工具 - 处理后端返回的各种时间格式
//

import Foundation

// MARK: - 后端时间格式规则
/*
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                        后端时间格式规范                                      │
 ├─────────────────────────────────────────────────────────────────────────────┤
 │ 1. 后端服务器和数据库统一使用 UTC 时区存储时间                               │
 │ 2. 后端返回的时间格式有两种：                                               │
 │    - 数组格式: [year, month, day, hour, minute, second] - UTC 时间          │
 │    - 字符串格式: "yyyy-MM-dd'T'HH:mm:ss" - 需要看 @JsonFormat 注解          │
 │      * 有 timezone="Asia/Shanghai" 注解 → 北京时间                          │
 │      * 无注解 → UTC 时间                                                    │
 │ 3. iOS 前端解析时必须正确识别时区，否则会出现 8 小时偏差                     │
 └─────────────────────────────────────────────────────────────────────────────┘

 使用示例:
 ```swift
 // 解析 UTC 数组格式
 let date = ServerDateParser.parseUTCArray([2026, 1, 1, 8, 0, 0])

 // 解析北京时间字符串（后端有 @JsonFormat timezone 注解）
 let date = ServerDateParser.parseShanghaiString("2026-01-01T16:00:00")

 // 解析 UTC 字符串（后端无 timezone 注解）
 let date = ServerDateParser.parseUTCString("2026-01-01T08:00:00")

 // 自动解析（优先字符串，其次数组）
 let date = ServerDateParser.parse(from: container, forKey: .createdAt, timezone: .utc)
 ```
*/

// MARK: - 服务器时区枚举

/// 服务器返回时间的时区类型
enum ServerTimezone {
    case utc            // UTC 时间（默认，数组格式通常是 UTC）
    case shanghai       // 北京时间（有 @JsonFormat timezone 注解的字符串）

    var timeZone: TimeZone {
        switch self {
        case .utc:
            return TimeZone(identifier: "UTC")!
        case .shanghai:
            return TimeZone(identifier: "Asia/Shanghai")!
        }
    }
}

// MARK: - 服务器时间解析器

/// 统一的服务器时间解析工具
enum ServerDateParser {

    // MARK: - 数组格式解析

    /// 解析 UTC 时间数组 [year, month, day, hour, minute, second]
    /// - Parameter arr: 时间数组，至少需要5个元素
    /// - Returns: 解析后的 Date 对象
    static func parseUTCArray(_ arr: [Int]) -> Date {
        return parseArray(arr, timezone: .utc)
    }

    /// 解析北京时间数组 [year, month, day, hour, minute, second]
    /// - Parameter arr: 时间数组，至少需要5个元素
    /// - Returns: 解析后的 Date 对象
    static func parseShanghaiArray(_ arr: [Int]) -> Date {
        return parseArray(arr, timezone: .shanghai)
    }

    /// 解析时间数组
    /// - Parameters:
    ///   - arr: 时间数组 [year, month, day, hour, minute, second]
    ///   - timezone: 时区
    /// - Returns: 解析后的 Date 对象
    static func parseArray(_ arr: [Int], timezone: ServerTimezone) -> Date {
        guard arr.count >= 5 else {
            print("⚠️ ServerDateParser: 数组长度不足，至少需要5个元素: \(arr)")
            return Date()
        }

        var components = DateComponents()
        components.year = arr[0]
        components.month = arr[1]
        components.day = arr[2]
        components.hour = arr[3]
        components.minute = arr[4]
        components.second = arr.count > 5 ? arr[5] : 0
        components.timeZone = timezone.timeZone

        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - 字符串格式解析

    /// 解析 UTC 时间字符串
    /// - Parameter dateString: 时间字符串
    /// - Returns: 解析后的 Date 对象
    static func parseUTCString(_ dateString: String) -> Date {
        return parseString(dateString, timezone: .utc)
    }

    /// 解析北京时间字符串（后端有 @JsonFormat timezone="Asia/Shanghai" 注解）
    /// - Parameter dateString: 时间字符串
    /// - Returns: 解析后的 Date 对象
    static func parseShanghaiString(_ dateString: String) -> Date {
        return parseString(dateString, timezone: .shanghai)
    }

    /// 解析时间字符串
    /// - Parameters:
    ///   - dateString: 时间字符串
    ///   - timezone: 时区
    /// - Returns: 解析后的 Date 对象
    static func parseString(_ dateString: String, timezone: ServerTimezone) -> Date {
        let formatter = DateFormatter()
        formatter.timeZone = timezone.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // 尝试标准格式 yyyy-MM-dd'T'HH:mm:ss
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: dateString) {
            return date
        }

        // 尝试带毫秒格式 yyyy-MM-dd'T'HH:mm:ss.SSS
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let date = formatter.date(from: dateString) {
            return date
        }

        // 尝试空格分隔格式 yyyy-MM-dd HH:mm:ss
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: dateString) {
            return date
        }

        // 尝试带时区格式 yyyy-MM-dd'T'HH:mm:ssZ
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = formatter.date(from: dateString) {
            return date
        }

        print("⚠️ ServerDateParser: 无法解析日期字符串: \(dateString)")
        return Date()
    }

    // MARK: - Codable 容器解析（自动检测格式）

    /// 从 Codable 容器中解析时间（自动检测字符串或数组格式）
    /// - Parameters:
    ///   - container: KeyedDecodingContainer
    ///   - key: CodingKey
    ///   - timezone: 时区（默认 UTC）
    /// - Returns: 解析后的 Date 对象
    static func parse<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K,
        timezone: ServerTimezone = .utc
    ) -> Date {
        // 优先尝试字符串格式
        if let dateString = try? container.decode(String.self, forKey: key) {
            return parseString(dateString, timezone: timezone)
        }

        // 其次尝试数组格式
        if let dateArray = try? container.decode([Int].self, forKey: key) {
            return parseArray(dateArray, timezone: timezone)
        }

        print("⚠️ ServerDateParser: 无法解析 \(key) 字段")
        return Date()
    }

    // MARK: - 时间格式化输出

    /// 格式化为相对时间显示（刚刚、x分钟前、x小时前等）
    /// - Parameter date: Date 对象
    /// - Returns: 格式化后的字符串
    static func formatRelativeTime(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 0 {
            // 未来时间，可能是时区问题
            return "刚刚"
        } else if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else if interval < 86400 * 2 {
            return "昨天"
        } else if interval < 86400 * 7 {
            let days = Int(interval / 86400)
            return "\(days)天前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            return formatter.string(from: date)
        }
    }

    /// 格式化为北京时间字符串（用于编码回传给后端）
    /// - Parameter date: Date 对象
    /// - Returns: 格式化后的字符串
    static func formatToShanghaiString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
