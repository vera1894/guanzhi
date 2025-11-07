//
//  UserTimelineViewModel.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/1/15.
//


import SwiftUI
import Combine

/// 专门用于在“个人主页”中，拿到用户所有分享记录并进行【临时】存储展示。
@MainActor
class UserTimelineViewModel: ObservableObject {
    /// 存放返回的所有分享（只放在内存里，不进 SwiftData）
    @Published var userShares: [ResponsedShare] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 如果需要显示错误消息，也可以加一个 @Published var errorMessage: String?

    /// 请求后端 “用户分享列表” 接口，并将结果保存在 userShares
    /// - Parameters:
    ///   - userId: 要查看的用户 id
    ///   - lat/lon: 当前位置/或者任意值
    ///   - radius: 范围
    func fetchUserShareList(
        userId: Int,
        lat: Double,
        lon: Double,
        radius: Double = 10
    ) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let rawList = try await ShareService.shared.fetchUserShareList(
                latitude: lat,
                longitude: lon,
                userId: userId,
                radius: radius,
                size: -1
            )
            // 排序后存到 userShares
            let sorted = rawList.sorted { $0.createDate > $1.createDate }
            self.userShares = sorted
        } catch {
            throw error
        }
    }
    
    
}
