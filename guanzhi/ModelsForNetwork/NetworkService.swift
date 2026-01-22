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
            
            // ✅ GET/DELETE 请求：参数放 URL 查询字符串；POST/PUT 请求：参数放 Body
            var finalURL = url
            if (req.request.method == .get || req.request.method == .delete) && !req.request.param.isEmpty {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.queryItems = req.request.param.map { key, value in
                    URLQueryItem(name: key, value: "\(value)")
                }
                if let urlWithQuery = components?.url {
                    finalURL = urlWithQuery
                    print("📎 \(req.request.method.rawValue) 请求 URL（含查询参数）: \(finalURL.absoluteString)")
                }
            }

            var request = URLRequest(url: finalURL)
            request.httpMethod = req.request.method.rawValue
            print("📝 HTTP 方法: \(request.httpMethod ?? "nil")")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if OTOLoginStatusManager.shared.isLoggedIn, let token = OTOLoginStatusManager.shared.getToken() {
                request.setValue(token, forHTTPHeaderField: "Authorization")
            }

            // ✅ POST/PUT 请求设置 httpBody
            if (req.request.method == .post || req.request.method == .put) && !req.request.param.isEmpty {
                request.httpBody = try JSONSerialization.data(withJSONObject: req.request.param)
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
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
