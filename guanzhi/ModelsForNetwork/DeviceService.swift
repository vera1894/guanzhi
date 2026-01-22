//
//  DeviceService.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/29.
//
//  设备管理服务 - 处理 APNs 推送通知的设备注册、更新和注销

import Foundation
import UIKit

/// 设备 API 响应模型（后端返回 respCode/respMsg/datas 格式）
struct DeviceApiResponse<T: Codable>: Codable {
    let respCode: Int
    let respMsg: String?
    let datas: T?
}

/// 设备服务 - 管理 APNs 设备注册
class DeviceService {
    static let shared = DeviceService()

    private init() {}

    // MARK: - UserDefaults Keys
    private let apnsDeviceTokenKey = "apnsDeviceToken"
    private let pendingDeepLinkKey = "pendingDeepLink"

    // MARK: - 设备 Token 本地缓存

    /// 获取缓存的设备 Token
    func getCachedDeviceToken() -> String? {
        return UserDefaults.standard.string(forKey: apnsDeviceTokenKey)
    }

    /// 缓存设备 Token
    func cacheDeviceToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: apnsDeviceTokenKey)
    }

    /// 清除缓存的设备 Token
    func clearCachedDeviceToken() {
        UserDefaults.standard.removeObject(forKey: apnsDeviceTokenKey)
    }

    // MARK: - Deep Link 缓存（冷启动用）

    /// 获取待处理的 Deep Link
    func getPendingDeepLink() -> String? {
        return UserDefaults.standard.string(forKey: pendingDeepLinkKey)
    }

    /// 缓存待处理的 Deep Link（冷启动时使用）
    func cachePendingDeepLink(_ deepLink: String) {
        UserDefaults.standard.set(deepLink, forKey: pendingDeepLinkKey)
    }

    /// 清除待处理的 Deep Link
    func clearPendingDeepLink() {
        UserDefaults.standard.removeObject(forKey: pendingDeepLinkKey)
    }

    // MARK: - API 调用

    /// 注册设备到后端
    /// - Parameter deviceToken: APNs 设备 Token
    /// - Returns: 是否成功
    func registerDevice(deviceToken: String) async throws {
        // 检查登录状态
        guard OTOLoginStatusManager.shared.isLoggedIn else {
            return
        }

        // 缓存 token
        cacheDeviceToken(deviceToken)

        // 获取设备信息
        let device = UIDevice.current
        let bundleId = Bundle.main.bundleIdentifier ?? "com.onetto"
        let deviceId = device.identifierForVendor?.uuidString
        let deviceName = device.name
        let deviceModel = getDeviceModel()
        let osVersion = device.systemVersion
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

        // APNs 环境：根据编译配置自动判断
        // - DEBUG (Xcode 运行): sandbox
        // - RELEASE (App Store/TestFlight): production
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif

        do {
            let data = try await OTONetwork.request(.registerDevice(
                deviceToken: deviceToken,
                bundleId: bundleId,
                deviceId: deviceId,
                deviceName: deviceName,
                deviceModel: deviceModel,
                osVersion: osVersion,
                appVersion: appVersion,
                environment: environment
            ))

            let decoder = JSONDecoder()
            // datas 可能是数字或 null，使用 Int? 解析
            let response = try decoder.decode(DeviceApiResponse<Int?>.self, from: data)

            if response.respCode != 0 && response.respCode != 200 {
                throw OTONetworkError.customError(response.respMsg ?? "设备注册失败")
            }
        }
    }

    /// 更新设备 Token
    /// - Parameters:
    ///   - oldToken: 旧的设备 Token
    ///   - newToken: 新的设备 Token
    func updateDeviceToken(oldToken: String, newToken: String) async throws {
        guard OTOLoginStatusManager.shared.isLoggedIn else {
            cacheDeviceToken(newToken)
            return
        }

        let data = try await OTONetwork.request(.updateDeviceToken(
            oldToken: oldToken,
            newToken: newToken
        ))

        let decoder = JSONDecoder()
        let response = try decoder.decode(DeviceApiResponse<Int?>.self, from: data)

        if response.respCode == 0 || response.respCode == 200 {
            cacheDeviceToken(newToken)
        } else {
            throw OTONetworkError.customError(response.respMsg ?? "Token 更新失败")
        }
    }

    /// 设备登出（用户退出登录时调用）
    func logoutDevice() async {
        guard let deviceToken = getCachedDeviceToken() else {
            return
        }

        do {
            let data = try await OTONetwork.request(.logoutDevice(deviceToken: deviceToken))
            let decoder = JSONDecoder()
            _ = try decoder.decode(DeviceApiResponse<Int?>.self, from: data)
        } catch {
            // 忽略登出错误
        }

        // 无论成功与否，都清除本地缓存
        clearCachedDeviceToken()
    }

    // MARK: - 辅助方法

    /// 获取设备型号
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    /// 用户登录后调用 - 检查是否需要注册设备
    func onUserLogin() {
        guard let cachedToken = getCachedDeviceToken() else {
            return
        }

        Task {
            try? await registerDevice(deviceToken: cachedToken)
        }
    }
}
