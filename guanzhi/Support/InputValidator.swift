//
//  InputValidator.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/22.
//  P3 安全加固：统一输入验证库
//

import Foundation

/// 输入验证结果
enum ValidationResult {
    case valid
    case invalid(message: String)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .invalid(let message) = self { return message }
        return nil
    }
}

/// 统一输入验证器
/// 提供客户端侧的输入验证（注意：后端验证才是安全保障）
enum InputValidator {

    // MARK: - 手机号验证

    /// 验证中国大陆手机号
    /// - Parameter phone: 手机号字符串
    /// - Returns: 验证结果
    static func validatePhone(_ phone: String) -> ValidationResult {
        // 去除空格
        let trimmed = phone.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            return .invalid(message: "请输入手机号")
        }

        guard trimmed.count == 11 else {
            return .invalid(message: "手机号应为11位")
        }

        // 中国大陆手机号正则（覆盖主流运营商号段）
        let pattern = "^1[3-9]\\d{9}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)

        if predicate.evaluate(with: trimmed) {
            return .valid
        } else {
            return .invalid(message: "手机号格式不正确")
        }
    }

    // MARK: - 验证码验证

    /// 验证短信验证码
    /// - Parameter code: 验证码字符串
    /// - Returns: 验证结果
    static func validateSMSCode(_ code: String) -> ValidationResult {
        let trimmed = code.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            return .invalid(message: "请输入验证码")
        }

        guard trimmed.count == 6 else {
            return .invalid(message: "验证码应为6位")
        }

        // 只允许数字
        let pattern = "^\\d{6}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)

        if predicate.evaluate(with: trimmed) {
            return .valid
        } else {
            return .invalid(message: "验证码只能包含数字")
        }
    }

    // MARK: - 昵称验证

    /// 验证用户昵称
    /// - Parameter nickname: 昵称字符串
    /// - Returns: 验证结果
    static func validateNickname(_ nickname: String) -> ValidationResult {
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            return .invalid(message: "请输入昵称")
        }

        // 计算字符长度（中文算2个字符）
        let charCount = countCharacters(trimmed)

        guard charCount >= 1 && charCount <= 32 else {
            return .invalid(message: "昵称最多16个汉字/32个字符")
        }

        // 只允许中文、英文、数字
        let pattern = "^[\\u4e00-\\u9fa5a-zA-Z0-9]+$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)

        if predicate.evaluate(with: trimmed) {
            return .valid
        } else {
            return .invalid(message: "仅支持中文、英文、数字")
        }
    }

    // MARK: - 评论内容验证

    /// 验证评论内容
    /// - Parameter content: 评论内容
    /// - Returns: 验证结果
    static func validateComment(_ content: String) -> ValidationResult {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .invalid(message: "评论内容不能为空")
        }

        guard trimmed.count >= 1 && trimmed.count <= 230 else {
            return .invalid(message: "评论内容应在1-230字符之间")
        }

        // 检查是否包含危险控制字符
        if containsControlCharacters(trimmed) {
            return .invalid(message: "评论内容包含非法字符")
        }

        return .valid
    }

    // MARK: - 观之标题验证

    /// 验证观之标题
    /// - Parameter title: 标题内容
    /// - Returns: 验证结果
    static func validateShareTitle(_ title: String) -> ValidationResult {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // 标题可以为空
        if trimmed.isEmpty {
            return .valid
        }

        guard trimmed.count <= 100 else {
            return .invalid(message: "标题最多100个字符")
        }

        // 检查是否包含危险控制字符
        if containsControlCharacters(trimmed) {
            return .invalid(message: "标题包含非法字符")
        }

        return .valid
    }

    // MARK: - 辅助方法

    /// 计算字符长度（中文算2个字符）
    private static func countCharacters(_ string: String) -> Int {
        var count = 0
        for char in string {
            // 中文字符范围
            if char >= "\u{4e00}" && char <= "\u{9fa5}" {
                count += 2
            } else {
                count += 1
            }
        }
        return count
    }

    /// 检查是否包含控制字符
    private static func containsControlCharacters(_ string: String) -> Bool {
        // 检查 ASCII 控制字符（0x00-0x1F，0x7F）
        // 但允许换行符和 Tab
        for scalar in string.unicodeScalars {
            let value = scalar.value
            if value < 0x20 && value != 0x09 && value != 0x0A && value != 0x0D {
                return true
            }
            if value == 0x7F {
                return true
            }
        }
        return false
    }

    /// 过滤危险字符，返回安全字符串
    static func sanitize(_ string: String) -> String {
        var result = ""
        for scalar in string.unicodeScalars {
            let value = scalar.value
            // 跳过控制字符（保留换行和 Tab）
            if value < 0x20 && value != 0x09 && value != 0x0A && value != 0x0D {
                continue
            }
            if value == 0x7F {
                continue
            }
            result.append(Character(scalar))
        }
        return result
    }
}

// MARK: - 便捷扩展

extension String {
    /// 验证是否为有效手机号
    var isValidPhone: Bool {
        InputValidator.validatePhone(self).isValid
    }

    /// 验证是否为有效验证码
    var isValidSMSCode: Bool {
        InputValidator.validateSMSCode(self).isValid
    }

    /// 验证是否为有效昵称
    var isValidNickname: Bool {
        InputValidator.validateNickname(self).isValid
    }

    /// 过滤危险字符
    var sanitized: String {
        InputValidator.sanitize(self)
    }
}
