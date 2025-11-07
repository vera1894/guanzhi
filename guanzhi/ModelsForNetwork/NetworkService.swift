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

enum OTONetworkError: Error {
    case badURL
    case badRequest
    case invalidResponse
    case responseNotJson
    case customError(String)
}

struct OTONetwork {
    static func request(_ req: OTORequest) async throws -> Data {
        do {
            print("=============开始请求=============")
            print("请求路径: \(req.request.path)")
            print("请求参数: \(req.request.param)")

            guard let url = URL(string: "\(Constants.BASE_HOST)\(req.request.path)") else {
                print("❌ 无效的 URL")
                throw OTONetworkError.badURL
            }
            print("完整 URL: \(url.absoluteString)")
            
            var request = URLRequest(url: url)
            request.httpMethod = req.request.method.rawValue
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if OTOLoginStatusManager.shared.isLoggedIn, let token = OTOLoginStatusManager.shared.getToken() {
                request.setValue(token, forHTTPHeaderField: "Authorization")
                print("🔑 Authorization Token: \(token)")
            } else {
                print("⚠️ 未登录或没有 Token")
            }
            
            request.httpBody = try JSONSerialization.data(withJSONObject: req.request.param)

            print("📤 发送请求中...")
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📥 HTTP 状态码: \(httpResponse.statusCode)")
                print("📥 响应头: \(httpResponse.allHeaderFields)")
                
                if httpResponse.statusCode != 200 {
                    print("❌ 服务器返回非 200 状态码")
                    if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("❌ 错误响应: \(errorResponse)")
                        if let errorMsg = errorResponse["error"] as? String {
                            throw OTONetworkError.customError(errorMsg)
                        }
                        // 也检查 respMsg 字段
                        if let respMsg = errorResponse["respMsg"] as? String {
                            throw OTONetworkError.customError(respMsg)
                        }
                    }
                    throw OTONetworkError.badRequest
                }
            }

            if let responseString = String(data: data, encoding: .utf8) {
                print("✅ 返回数据: \(responseString)")
            }
            print("=============请求结束=============\n")
            return data
        } catch let error as OTONetworkError {
            print("❌ OTONetworkError: \(error)")
            throw error
        } catch {
            print("❌ 网络请求异常: \(error.localizedDescription)")
            print("❌ 错误详情: \(error)")
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
