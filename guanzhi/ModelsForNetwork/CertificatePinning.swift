//
//  CertificatePinning.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/22.
//  P3 安全加固：HTTPS 证书固定（Certificate Pinning）
//
//  使用方法：
//  1. 获取服务器证书的公钥 SHA256 Hash
//  2. 将 Hash 添加到 pinnedPublicKeyHashes 数组
//  3. 将 isEnabled 设置为 true
//  4. 使用 PinnedURLSession.shared 发起请求
//
//  获取公钥 Hash 的方法：
//  openssl s_client -connect your-server.com:443 2>/dev/null | \
//  openssl x509 -pubkey -noout | \
//  openssl pkey -pubin -outform DER | \
//  openssl dgst -sha256 -binary | base64
//

import Foundation
import Security
import CommonCrypto

/// 证书固定管理器
final class CertificatePinningManager: NSObject {

    // MARK: - 配置

    /// 是否启用证书固定（默认关闭，配置好公钥后开启）
    var isEnabled: Bool = false

    /// 固定的公钥 SHA256 哈希（Base64 编码）
    /// 可以配置多个，支持证书轮换
    var pinnedPublicKeyHashes: [String] = [
        // 示例（需要替换为实际服务器证书的公钥 Hash）：
        // "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    ]

    /// 允许的域名（只对这些域名进行证书固定）
    var pinnedDomains: [String] = [
        // 示例：
        // "api.example.com",
        // "52.83.127.15"
    ]

    // MARK: - 单例

    static let shared = CertificatePinningManager()

    private override init() {
        super.init()
    }

    // MARK: - 公钥验证

    /// 验证服务器证书的公钥
    /// - Parameters:
    ///   - trust: 服务器信任对象
    ///   - host: 服务器主机名
    /// - Returns: 验证是否通过
    func validateServerTrust(_ trust: SecTrust, forHost host: String) -> Bool {
        // 未启用或域名不在列表中，跳过固定检查
        guard isEnabled else {
            return true
        }

        guard pinnedDomains.contains(where: { host.contains($0) }) else {
            return true // 非固定域名，使用默认验证
        }

        guard !pinnedPublicKeyHashes.isEmpty else {
            #if DEBUG
            print("⚠️ CertificatePinning: 已启用但未配置公钥 Hash")
            #endif
            return false
        }

        // 获取证书链中的公钥
        guard let certificateChain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              !certificateChain.isEmpty else {
            #if DEBUG
            print("❌ CertificatePinning: 无法获取证书链")
            #endif
            return false
        }

        // 检查证书链中是否有任何证书的公钥匹配
        for certificate in certificateChain {
            if let publicKeyHash = getPublicKeyHash(from: certificate),
               pinnedPublicKeyHashes.contains(publicKeyHash) {
                #if DEBUG
                print("✅ CertificatePinning: 公钥验证通过")
                #endif
                return true
            }
        }

        #if DEBUG
        print("❌ CertificatePinning: 公钥验证失败")
        // 输出实际的公钥 Hash（用于调试和配置）
        for certificate in certificateChain {
            if let hash = getPublicKeyHash(from: certificate) {
                print("   证书公钥 Hash: \(hash)")
            }
        }
        #endif

        return false
    }

    // MARK: - 私有方法

    /// 从证书中提取公钥的 SHA256 Hash
    private func getPublicKeyHash(from certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            return nil
        }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        // 计算 SHA256
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        publicKeyData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(publicKeyData.count), &hash)
        }

        // 返回 Base64 编码
        return Data(hash).base64EncodedString()
    }
}

// MARK: - URLSessionDelegate

/// 支持证书固定的 URLSession Delegate
final class PinnedURLSessionDelegate: NSObject, URLSessionDelegate {

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // 只处理服务器信任验证
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host

        // 先进行系统默认验证
        var error: CFError?
        let isServerTrusted = SecTrustEvaluateWithError(serverTrust, &error)

        guard isServerTrusted else {
            #if DEBUG
            print("❌ CertificatePinning: 系统证书验证失败 - \(error?.localizedDescription ?? "未知错误")")
            #endif
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // 进行证书固定验证
        if CertificatePinningManager.shared.validateServerTrust(serverTrust, forHost: host) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - 便捷 URLSession

/// 支持证书固定的 URLSession
enum PinnedURLSession {
    /// 共享的支持证书固定的 URLSession
    static let shared: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        return URLSession(
            configuration: configuration,
            delegate: PinnedURLSessionDelegate(),
            delegateQueue: nil
        )
    }()
}
