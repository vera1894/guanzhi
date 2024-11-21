//
//  NetworkService.swift
//  guanzhi
//
//  Created by Vera on 2024/3/20.
//

import Foundation
import Combine
import UIKit


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
                print("无效的 URL")
                throw OTONetworkError.badURL
            }
            var request = URLRequest(url: url)
            request.httpMethod = req.request.method.rawValue
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if OTOLoginStatusManager.shared.isLoggedIn, let token = OTOLoginStatusManager.shared.getToken() {
                request.setValue(token, forHTTPHeaderField: "Authorization")
                print(token)
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: req.request.param)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP 状态码: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMsg = errorResponse["error"] as? String {
                        throw OTONetworkError.customError(errorMsg)
                    }
                    throw OTONetworkError.badRequest
                }
            }

            if let responseString = String(data: data, encoding: .utf8) {
                print("返回数据: \(responseString)")  // 返回数据在控制台的显示
            }
            return data
        } catch {
            throw error
        }
    }
}
