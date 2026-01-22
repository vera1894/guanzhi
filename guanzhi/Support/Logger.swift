//
//  Logger.swift
//  guanzhi
//
//  Created by Claude Code on 2026/01/22.
//  统一日志工具 - 仅在 DEBUG 模式下输出
//

import Foundation

/// 统一日志工具
/// 所有日志仅在 DEBUG 模式下输出，Release 包中完全移除
enum Logger {

    /// 普通日志
    static func log(_ items: Any..., file: String = #file, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let message = items.map { "\($0)" }.joined(separator: " ")
        print("[\(fileName):\(line)] \(message)")
        #endif
    }

    /// 网络相关日志
    static func network(_ items: Any...) {
        #if DEBUG
        let message = items.map { "\($0)" }.joined(separator: " ")
        print("📡 [Network] \(message)")
        #endif
    }

    /// 成功日志
    static func success(_ items: Any...) {
        #if DEBUG
        let message = items.map { "\($0)" }.joined(separator: " ")
        print("✅ \(message)")
        #endif
    }

    /// 警告日志
    static func warning(_ items: Any...) {
        #if DEBUG
        let message = items.map { "\($0)" }.joined(separator: " ")
        print("⚠️ \(message)")
        #endif
    }

    /// 错误日志
    static func error(_ items: Any...) {
        #if DEBUG
        let message = items.map { "\($0)" }.joined(separator: " ")
        print("❌ \(message)")
        #endif
    }

    /// 调试日志（用于临时调试，后续应删除）
    static func debug(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let message = items.map { "\($0)" }.joined(separator: " ")
        print("🔍 [\(fileName):\(line)] \(function) - \(message)")
        #endif
    }
}

/// 便捷的全局日志函数（替代 print）
/// 使用方式：debugLog("message") 替代 print("message")
func debugLog(_ items: Any..., file: String = #file, line: Int = #line) {
    #if DEBUG
    let message = items.map { "\($0)" }.joined(separator: " ")
    print(message)
    #endif
}
