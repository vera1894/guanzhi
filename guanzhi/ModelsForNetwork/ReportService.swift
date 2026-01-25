//
//  ReportService.swift
//  guanzhi
//
//  Created by Claude on 2025/1/24.
//

import Foundation

/// 举报原因枚举
enum ReportReason: String, CaseIterable {
    case fakeLocation = "FAKE_LOCATION"
    case privacyLeak = "PRIVACY_LEAK"
    case harassment = "HARASSMENT"
    case spamAd = "SPAM_AD"
    case misinformation = "MISINFORMATION"
    case copyright = "COPYRIGHT"
    case nsfw = "NSFW"
    case violence = "VIOLENCE"
    case illegal = "ILLEGAL"
    case other = "OTHER"

    /// 显示文字
    var displayText: String {
        switch self {
        case .fakeLocation:
            return "地点不实 / 恶意标注"
        case .privacyLeak:
            return "隐私泄露：暴露个人信息"
        case .harassment:
            return "骚扰 / 霸凌 / 仇恨言论"
        case .spamAd:
            return "垃圾广告 / 引流"
        case .misinformation:
            return "虚假信息 / 误导"
        case .copyright:
            return "侵权：盗用我的图片/文字"
        case .nsfw:
            return "不当内容：色情或露骨"
        case .violence:
            return "暴力 / 血腥 / 自残相关"
        case .illegal:
            return "危险行为 / 违法内容"
        case .other:
            return "其他"
        }
    }
}

/// 举报结果
enum ReportResult {
    case success
    case alreadyReported
    case failed(String)
}

/// 举报服务
final class ReportService {
    static let shared = ReportService()

    private init() {}

    /// 提交举报
    /// - Parameters:
    ///   - shareId: 分享 ID
    ///   - reason: 举报原因
    /// - Returns: 举报结果
    func submitReport(shareId: Int64, reason: ReportReason) async -> ReportResult {
        do {
            let data = try await OTONetwork.request(
                .reportShare(shareId: shareId, reasonCode: reason.rawValue)
            )

            let decoder = JSONDecoder()
            let response = try decoder.decode(OTOResponseModel<EmptyData>.self, from: data)

            if response.respCode == 0 {
                return .success
            } else {
                let errorMsg = response.respMsg ?? "未知错误"
                if errorMsg.contains("已举报") {
                    return .alreadyReported
                }
                return .failed(errorMsg)
            }
        } catch {
            #if DEBUG
            print("❌ [ReportService] submitReport 失败: \(error)")
            #endif
            return .failed(error.localizedDescription)
        }
    }
}
