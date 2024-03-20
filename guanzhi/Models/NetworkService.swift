//
//  NetworkService.swift
//  guanzhi
//
//  Created by Vera on 2024/3/20.
//

import Foundation
import Combine


enum OTONetworkError: Error {
    case badURL
    case badRequest
    case invalidResponse
    case responseNotJson
    case customError(String)
}

struct OTONetwork {
    static func setHeader(_ header: [String: String]) {
        header.forEach { key, value in
            URLSessionConfiguration.default.httpAdditionalHeaders?[key] = value
        }
    }

    
    static func request(_ req: OTORequest) async throws -> [String: Any] {
        do {
//            print("""
//=============开始请求=============
//请求路径: \(req.request.path),
//请求参数: \(req.request.param)
//""")
            guard let url = URL(string: "\(Constants.BASE_HOST)\(req.request.path)") else { throw OTONetworkError.badURL }
            var request = URLRequest(url: url)
            request.httpMethod = req.request.method.rawValue
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if OTOLoginStatusManager.shared.isLoggedIn, let token = OTOLoginStatusManager.shared.getToken() {
                request.setValue(token, forHTTPHeaderField: "Authorization")
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: req.request.param)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OTONetworkError.invalidResponse
            }
            guard let resultData = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw OTONetworkError.responseNotJson
            }
            guard httpResponse.statusCode == 200 else {
                if let errorMsg = resultData["error"] as? String {
                    throw OTONetworkError.customError(errorMsg)
                }
                throw OTONetworkError.badRequest
            }
//            print("返回数据: \(resultData)")
            return resultData
        } catch {
            if let error = error as? OTONetworkError {
                switch error {
                case .customError(let errorMsg):
                    DispatchQueue.main.async {
                       // ProgressHUD.showFailed(errorMsg)
                    }
                    print("服务器返回的错误信息: \(errorMsg)")
                default:
                    print("OTONetworkError: \(error.localizedDescription)")
                }
            }
            throw error
        }
    }

    // 创建一个request方法，返回一个AnyPublisher
    static func requestPublisher(_ req: OTORequest) -> AnyPublisher<[String: Any], Error> {
        do {
            guard let url = URL(string: "\(Constants.BASE_HOST)\(req.request.path)") else { throw OTONetworkError.badURL }
            var request = URLRequest(url: url)
            request.httpMethod = req.request.method.rawValue
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: req.request.param)
            return URLSession.shared.dataTaskPublisher(for: request)
                .tryMap { data, response in
                    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw OTONetworkError.badRequest }
                    guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        throw OTONetworkError.responseNotJson
                    }
                    return result
                }
                .eraseToAnyPublisher()
        } catch {
            print("请求错误: path: \(req.request.path), 参数: \(req.request.param), 错误: \(error.localizedDescription)")
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
}
