import Foundation
import UIKit

struct AppVersionManager {
    /// 获取应用市场版本号（如1.0.0）
    static var marketVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? String(localized: "未知版本")
    }
    
    /// 获取应用构建版本号（如123）
    static var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? String(localized: "未知构建")
    }
    
    /// 获取格式化的完整版本信息
    static var fullVersionInfo: String {
        return "\(marketVersion) (\(buildNumber))" 
    }
    
    /// 获取设备iOS版本
    static var systemVersion: String {
        return UIDevice.current.systemVersion
    }
    
    /// 获取格式化的系统版本信息
    static var fullSystemInfo: String {
        let device = UIDevice.current
        return "\(device.systemName) \(device.systemVersion)"
    }
} 
