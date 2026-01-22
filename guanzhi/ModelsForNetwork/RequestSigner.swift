//
//  RequestSigner.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/22.
//  P3 安全加固：API 请求签名机制
//
//  使用方法：
//  1. 后端需要实现验签逻辑
//  2. 双方约定相同的签名密钥（通过安全渠道分发）
//  3. 在 NetworkService 中调用 RequestSigner.sign() 添加签名 Header
//
//  签名算法：HMAC-SHA256
//  签名内容：method + path + timestamp + nonce + body_hash
//

import Foundation
import CommonCrypto

/// 请求签名器
/// 用于 API 请求防篡改验证
enum RequestSigner {

    // MARK: - 配置

    /// 签名是否启用（需要后端支持后开启）
    static var isEnabled: Bool = false

    /// 签名密钥（应从安全配置中读取，不要硬编码）
    /// 生产环境应通过 Keychain 或 Info.plist 注入
    private static var secretKey: String {
        // TODO: 从安全配置读取
        // 当前返回空，启用时需要配置
        return ""
    }

    // MARK: - 签名 Header 名称

    struct Headers {
        static let signature = "X-Signature"
        static let timestamp = "X-Timestamp"
        static let nonce = "X-Nonce"
    }

    // MARK: - 公开方法

    /// 为请求生成签名 Headers
    /// - Parameters:
    ///   - method: HTTP 方法（GET, POST 等）
    ///   - path: 请求路径（不含 host）
    ///   - body: 请求体数据（可选）
    /// - Returns: 签名相关的 Headers 字典
    static func signHeaders(method: String, path: String, body: Data? = nil) -> [String: String] {
        guard isEnabled, !secretKey.isEmpty else {
            return [:]
        }

        let timestamp = String(Int(Date().timeIntervalSince1970))
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()

        // 计算 body hash（空 body 使用空字符串的 hash）
        let bodyHash = sha256Hash(body ?? Data())

        // 构造签名字符串
        let signatureString = [
            method.uppercased(),
            path,
            timestamp,
            nonce,
            bodyHash
        ].joined(separator: "\n")

        // 计算 HMAC-SHA256 签名
        let signature = hmacSHA256(signatureString, key: secretKey)

        return [
            Headers.signature: signature,
            Headers.timestamp: timestamp,
            Headers.nonce: nonce
        ]
    }

    /// 验证响应签名（可选，用于双向验证）
    /// - Parameters:
    ///   - signature: 响应中的签名
    ///   - body: 响应体
    ///   - timestamp: 响应时间戳
    /// - Returns: 签名是否有效
    static func verifyResponse(signature: String, body: Data, timestamp: String) -> Bool {
        guard isEnabled, !secretKey.isEmpty else {
            return true // 未启用时默认通过
        }

        // 检查时间戳是否在有效范围内（防重放，5分钟窗口）
        if let ts = Int(timestamp) {
            let now = Int(Date().timeIntervalSince1970)
            if abs(now - ts) > 300 {
                #if DEBUG
                print("⚠️ RequestSigner: 响应时间戳超出有效范围")
                #endif
                return false
            }
        }

        // 计算预期签名
        let bodyHash = sha256Hash(body)
        let signatureString = [timestamp, bodyHash].joined(separator: "\n")
        let expectedSignature = hmacSHA256(signatureString, key: secretKey)

        return signature == expectedSignature
    }

    // MARK: - 私有方法

    /// 计算 SHA256 Hash
    private static func sha256Hash(_ data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// 计算 HMAC-SHA256
    private static func hmacSHA256(_ message: String, key: String) -> String {
        guard let keyData = key.data(using: .utf8),
              let messageData = message.data(using: .utf8) else {
            return ""
        }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        keyData.withUnsafeBytes { keyBytes in
            messageData.withUnsafeBytes { messageBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    keyBytes.baseAddress,
                    keyData.count,
                    messageBytes.baseAddress,
                    messageData.count,
                    &hash
                )
            }
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - URLRequest 扩展

extension URLRequest {
    /// 为请求添加签名 Headers
    mutating func addSignatureHeaders() {
        guard let url = self.url,
              let method = self.httpMethod else {
            return
        }

        let path = url.path
        let signHeaders = RequestSigner.signHeaders(
            method: method,
            path: path,
            body: self.httpBody
        )

        for (key, value) in signHeaders {
            self.setValue(value, forHTTPHeaderField: key)
        }
    }
}
