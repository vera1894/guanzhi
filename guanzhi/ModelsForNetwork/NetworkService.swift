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
        case .badURL: return "无效的请求地址"
        case .badRequest: return "请求失败"
        case .invalidResponse: return "无效的响应"
        case .responseNotJson: return "响应格式错误"
        case .unauthorized: return "登录已过期，请重新登录"
        case .forbidden: return "没有权限访问"
        case .notFound: return "请求的资源不存在"
        case .serverError: return "服务器繁忙，请稍后再试"
        case .customError(let msg): return msg
        }
    }
}

struct OTONetwork {
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
                    // 成功
                    break
                case 401:
                    // Token 过期或无效，发送通知并抛出错误
                    NotificationCenter.default.post(name: .tokenExpired, object: nil)
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
}

extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
