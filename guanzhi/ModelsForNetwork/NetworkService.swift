//
//  NetworkService.swift
//  guanzhi
//
//  Created by Vera on 2024/3/20.
//

import Foundation
import Combine
import UIKit
import Alamofire

enum OTONetworkError: Error, LocalizedError {
    case badURL
    case badRequest
    case invalidResponse
    case responseNotJson
    case unauthorized      // 401 未授权
    case forbidden         // 403 禁止访问
    case notFound          // 404 未找到
    case serverError       // 5xx 服务器错误
    case customError(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return String(localized: "无效的请求地址")
        case .badRequest: return String(localized: "请求失败")
        case .invalidResponse: return String(localized: "无效的响应")
        case .responseNotJson: return String(localized: "响应格式错误")
        case .unauthorized: return String(localized: "登录已过期，请重新登录")
        case .forbidden: return String(localized: "没有权限访问")
        case .notFound: return String(localized: "请求的资源不存在")
        case .serverError: return String(localized: "服务器繁忙，请稍后再试")
        case .customError(let msg): return msg
        }
    }
}

struct OTONetwork {
    // 连续 401 计数：防止偶发性 401（如 Redis 连接抖动）导致意外登出
    private static var consecutive401Count = 0
    private static let logout401Threshold = 3

    // 延迟登出验证：防止后端部署重启时短暂 401 窗口导致误登出
    private static var pendingLogoutWorkItem: DispatchWorkItem?
    private static var hasSuccessSincePendingLogout = false

    static func request(_ req: OTORequest) async throws -> Data {
        do {
            #if DEBUG
            print("=============开始请求=============")
            print("请求路径: \(req.request.path)")
            print("请求参数: \(req.request.param)")
            #endif

            guard let url = URL(string: "\(Constants.BASE_HOST)\(req.request.path)") else {
                #if DEBUG
                print("❌ 无效的 URL")
                #endif
                throw OTONetworkError.badURL
            }
            #if DEBUG
            print("完整 URL: \(url.absoluteString)")
            #endif

            // ✅ GET/DELETE 请求：参数放 URL 查询字符串；POST/PUT 请求：参数放 Body
            var finalURL = url
            if (req.request.method == .get || req.request.method == .delete) && !req.request.param.isEmpty {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.queryItems = req.request.param.map { key, value in
                    URLQueryItem(name: key, value: "\(value)")
                }
                if let urlWithQuery = components?.url {
                    finalURL = urlWithQuery
                    #if DEBUG
                    print("📎 \(req.request.method.rawValue) 请求 URL（含查询参数）: \(finalURL.absoluteString)")
                    #endif
                }
            }

            var request = URLRequest(url: finalURL)
            request.httpMethod = req.request.method.rawValue
            #if DEBUG
            print("📝 HTTP 方法: \(request.httpMethod ?? "nil")")
            #endif
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // ✅ 添加 Token（如果已登录）
            // 注：Token 有效性由后端 401 响应判断，客户端不预检
            if OTOLoginStatusManager.shared.isLoggedIn, let token = OTOLoginStatusManager.shared.getToken() {
                request.setValue(token, forHTTPHeaderField: "Authorization")
            }

            // ✅ POST/PUT 请求设置 httpBody
            if (req.request.method == .post || req.request.method == .put) && !req.request.param.isEmpty {
                request.httpBody = try JSONSerialization.data(withJSONObject: req.request.param)
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode

                #if DEBUG
                print("📡 响应状态码: \(statusCode)")
                #endif

                // ✅ 根据状态码返回不同的错误类型
                switch statusCode {
                case 200...299:
                    Self.consecutive401Count = 0
                    // 如果有待执行的登出验证，标记已有成功请求（服务器已恢复）
                    if Self.pendingLogoutWorkItem != nil {
                        Self.hasSuccessSincePendingLogout = true
                        Self.pendingLogoutWorkItem?.cancel()
                        Self.pendingLogoutWorkItem = nil
                    }
                    break
                case 401:
                    Self.consecutive401Count += 1
                    if Self.consecutive401Count >= Self.logout401Threshold {
                        Self.consecutive401Count = 0
                        // 不立即登出，改为延迟验证
                        Self.scheduleDelayedLogoutVerification()
                    }
                    throw OTONetworkError.unauthorized
                case 403:
                    throw OTONetworkError.forbidden
                case 404:
                    throw OTONetworkError.notFound
                case 500...599:
                    throw OTONetworkError.serverError
                default:
                    // 尝试从响应中提取错误信息
                    if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let errorMsg = errorResponse["error"] as? String {
                            throw OTONetworkError.customError(errorMsg)
                        }
                        if let respMsg = errorResponse["respMsg"] as? String {
                            throw OTONetworkError.customError(respMsg)
                        }
                    }
                    throw OTONetworkError.badRequest
                }
            }

            return data
        } catch let error as OTONetworkError {
            throw error
        } catch {
            throw error
        }
    }

    // MARK: - 延迟登出验证

    /// 延迟 30 秒后验证 Token 是否真正过期
    /// 区分「后端部署重启导致短暂 401」和「Token 真正过期」
    private static func scheduleDelayedLogoutVerification() {
        // 已有待执行的验证，不重复创建
        guard pendingLogoutWorkItem == nil else { return }

        hasSuccessSincePendingLogout = false

        let workItem = DispatchWorkItem {
            // 延迟期间已有成功请求，说明服务器已恢复，取消登出
            if Self.hasSuccessSincePendingLogout {
                Self.pendingLogoutWorkItem = nil
                return
            }

            // 主动发一次验证请求确认 Token 状态
            Task {
                let isValid = await Self.verifyTokenValidity()
                await MainActor.run {
                    if !isValid {
                        // Token 确实过期，执行登出
                        NotificationCenter.default.post(name: .tokenExpired, object: nil)
                    }
                    Self.pendingLogoutWorkItem = nil
                }
            }
        }

        pendingLogoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: workItem)
    }

    /// 主动验证 Token 有效性（直接用 URLSession，不经过 OTONetwork 避免递归计数）
    private static func verifyTokenValidity() async -> Bool {
        guard OTOLoginStatusManager.shared.isLoggedIn,
              let token = OTOLoginStatusManager.shared.getToken(),
              let url = URL(string: "\(Constants.BASE_HOST)/api/guan/user/info") else {
            return true  // 无法构造请求，保守处理不登出
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [:] as [String: Any])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // 只有明确的 401 才确认 Token 过期
                return httpResponse.statusCode != 401
            }
        } catch {
            // 网络错误不应触发登出（可能是断网或服务暂不可达）
        }
        return true  // 无法验证时保守处理，不登出
    }
}

extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
