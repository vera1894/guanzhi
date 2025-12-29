//
//  DeviceService.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/29.
//
//  设备管理服务 - 处理 APNs 推送通知的设备注册、更新和注销

import Foundation
import UIKit

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
        print("📱 DeviceService: 已缓存设备 Token")
    }

    /// 清除缓存的设备 Token
    func clearCachedDeviceToken() {
        UserDefaults.standard.removeObject(forKey: apnsDeviceTokenKey)
        print("📱 DeviceService: 已清除设备 Token 缓存")
    }

    // MARK: - Deep Link 缓存（冷启动用）

    /// 获取待处理的 Deep Link
    func getPendingDeepLink() -> String? {
        return UserDefaults.standard.string(forKey: pendingDeepLinkKey)
    }

    /// 缓存待处理的 Deep Link（冷启动时使用）
    func cachePendingDeepLink(_ deepLink: String) {
        UserDefaults.standard.set(deepLink, forKey: pendingDeepLinkKey)
        print("🔗 DeviceService: 已缓存待处理 Deep Link: \(deepLink)")
    }

    /// 清除待处理的 Deep Link
    func clearPendingDeepLink() {
        UserDefaults.standard.removeObject(forKey: pendingDeepLinkKey)
        print("🔗 DeviceService: 已清除待处理 Deep Link")
    }

    // MARK: - API 调用

    /// 注册设备到后端
    /// - Parameter deviceToken: APNs 设备 Token
    /// - Returns: 是否成功
    func registerDevice(deviceToken: String) async throws {
        // 检查登录状态
        guard OTOLoginStatusManager.shared.isLoggedIn else {
            print("⚠️ DeviceService: 用户未登录，跳过设备注册")
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

        // 判断环境（DEBUG 为 sandbox，否则为 production）
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif

        print("📱 DeviceService: 开始注册设备...")
        print("   Token: \(deviceToken.prefix(20))...")
        print("   BundleId: \(bundleId)")
        print("   Environment: \(environment)")

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
            let response = try decoder.decode(OTOResponseModel<String?>.self, from: data)

            if response.respCode == 200 || response.respCode == 0 {
                print("✅ DeviceService: 设备注册成功")
            } else {
                print("❌ DeviceService: 设备注册失败 - \(response.respMsg ?? "未知错误")")
                throw OTONetworkError.customError(response.respMsg ?? "设备注册失败")
            }
        } catch {
            print("❌ DeviceService: 设备注册异常 - \(error.localizedDescription)")
            throw error
        }
    }

    /// 更新设备 Token
    /// - Parameters:
    ///   - oldToken: 旧的设备 Token
    ///   - newToken: 新的设备 Token
    func updateDeviceToken(oldToken: String, newToken: String) async throws {
        guard OTOLoginStatusManager.shared.isLoggedIn else {
            print("⚠️ DeviceService: 用户未登录，跳过 Token 更新")
            // 仍然缓存新 token，等登录后注册
            cacheDeviceToken(newToken)
            return
        }

        print("📱 DeviceService: 开始更新设备 Token...")

        do {
            let data = try await OTONetwork.request(.updateDeviceToken(
                oldToken: oldToken,
                newToken: newToken
            ))

            let decoder = JSONDecoder()
            let response = try decoder.decode(OTOResponseModel<String?>.self, from: data)

            if response.respCode == 200 || response.respCode == 0 {
                cacheDeviceToken(newToken)
                print("✅ DeviceService: 设备 Token 更新成功")
            } else {
                print("❌ DeviceService: Token 更新失败 - \(response.respMsg ?? "未知错误")")
                throw OTONetworkError.customError(response.respMsg ?? "Token 更新失败")
            }
        } catch {
            print("❌ DeviceService: Token 更新异常 - \(error.localizedDescription)")
            throw error
        }
    }

    /// 设备登出（用户退出登录时调用）
    func logoutDevice() async {
        guard let deviceToken = getCachedDeviceToken() else {
            print("⚠️ DeviceService: 没有缓存的设备 Token，跳过登出")
            return
        }

        print("📱 DeviceService: 开始注销设备...")

        do {
            let data = try await OTONetwork.request(.logoutDevice(deviceToken: deviceToken))

            let decoder = JSONDecoder()
            let response = try decoder.decode(OTOResponseModel<String?>.self, from: data)

            if response.respCode == 200 || response.respCode == 0 {
                print("✅ DeviceService: 设备注销成功")
            } else {
                print("⚠️ DeviceService: 设备注销返回非成功状态 - \(response.respMsg ?? "")")
            }
        } catch {
            print("⚠️ DeviceService: 设备注销异常（忽略）- \(error.localizedDescription)")
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
            print("📱 DeviceService: 用户登录但没有缓存的设备 Token")
            return
        }

        Task {
            do {
                try await registerDevice(deviceToken: cachedToken)
            } catch {
                print("❌ DeviceService: 登录后设备注册失败 - \(error)")
            }
        }
    }
}
