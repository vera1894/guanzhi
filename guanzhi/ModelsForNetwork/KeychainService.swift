//
//  KeychainService.swift
//  guanzhi
//
//  Created by Claude Code on 2025/1/22.
//
//  安全凭证存储服务 - 使用 iOS Keychain 存储敏感数据（如 Token）

import Foundation
import Security

/// Keychain 存储服务 - 提供安全的凭证存储
final class KeychainService {
    static let shared = KeychainService()

    private let service = Bundle.main.bundleIdentifier ?? "com.guanzhi"

    private init() {}

    // MARK: - Public API

    /// 保存字符串到 Keychain
    /// - Parameters:
    ///   - value: 要保存的字符串
    ///   - key: 存储键名
    /// - Returns: 是否保存成功
    @discardableResult
    func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(data, forKey: key)
    }

    /// 从 Keychain 读取字符串
    /// - Parameter key: 存储键名
    /// - Returns: 存储的字符串，如不存在返回 nil
    func getString(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 删除 Keychain 中的项目
    /// - Parameter key: 存储键名
    /// - Returns: 是否删除成功
    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// 检查 Keychain 中是否存在指定键
    /// - Parameter key: 存储键名
    /// - Returns: 是否存在
    func exists(forKey key: String) -> Bool {
        return getData(forKey: key) != nil
    }

    // MARK: - Private Helpers

    private func save(_ data: Data, forKey key: String) -> Bool {
        // 先尝试删除已存在的项
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}

// MARK: - Keychain Keys

extension KeychainService {
    /// Keychain 存储键名常量
    enum Keys {
        static let loginToken = "loginToken"
        static let userId = "userId"
    }
}
