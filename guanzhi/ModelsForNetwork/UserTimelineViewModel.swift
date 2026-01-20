//
//  UserTimelineViewModel.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/1/15.
//


import SwiftUI
import Combine

/// 专门用于在"个人主页"中，拿到用户所有分享记录并进行【临时】存储展示。
@MainActor
class UserTimelineViewModel: ObservableObject {
    /// 存放返回的所有分享（只放在内存里，不进 SwiftData）
    @Published var userShares: [ResponsedShare] = []

    /// 加载状态（使用通用的 DataLoadingState）
    @Published var loadingState: DataLoadingState<[ResponsedShare]> = .idle

    /// 是否正在加载（保留向后兼容）
    var isLoading: Bool {
        loadingState.isLoading
    }

    /// 是否已完成首次加载（避免返回时重复刷新，覆盖滚动恢复）
    var didInitialLoad = false

    /// 当前请求参数（用于网络恢复时重试）
    private var lastUserId: Int?
    private var lastLat: Double?
    private var lastLon: Double?
    private var lastRadius: Double?

    /// 网络监听
    private var networkRestoredCancellable: AnyCancellable?
    private var networkChangedCancellable: AnyCancellable?
    /// 删除通知监听
    private var shareDeletedCancellable: AnyCancellable?

    init() {
        setupNetworkMonitoring()
        setupDeleteNotificationListener()
    }

    deinit {
        networkRestoredCancellable?.cancel()
        networkChangedCancellable?.cancel()
        shareDeletedCancellable?.cancel()
    }

    /// 设置删除通知监听
    private func setupDeleteNotificationListener() {
        shareDeletedCancellable = NotificationCenter.default
            .publisher(for: .shareDidDelete)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let shareId = notification.userInfo?["shareId"] as? Int else { return }
                print("📋 [UserTimelineViewModel] 收到删除通知，shareId=\(shareId)")
                self.removeShare(id: shareId)
            }
    }

    /// 从列表中移除指定的分享
    private func removeShare(id: Int) {
        if let index = userShares.firstIndex(where: { $0.id == id }) {
            userShares.remove(at: index)
            print("📋 [UserTimelineViewModel] 已从列表移除 shareId=\(id)，剩余 \(userShares.count) 条")
        }
    }

    /// 设置网络恢复监听
    private func setupNetworkMonitoring() {
        networkRestoredCancellable = NotificationCenter.default
            .publisher(for: .networkRestored)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.loadingState.hasError {
                    print("📶 [UserTimelineViewModel] 网络恢复，自动重试")
                    self.retryLastFetch()
                }
            }

        networkChangedCancellable = NotificationCenter.default
            .publisher(for: .networkChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.loadingState.hasError {
                    print("📶 [UserTimelineViewModel] 网络切换，自动重试")
                    self.retryLastFetch()
                }
            }
    }

    /// 重试上次失败的请求
    private func retryLastFetch() {
        guard let userId = lastUserId,
              let lat = lastLat,
              let lon = lastLon,
              let radius = lastRadius else { return }

        Task {
            try? await fetchUserShareList(userId: userId, lat: lat, lon: lon, radius: radius)
        }
    }

    /// 请求后端 "用户分享列表" 接口，并将结果保存在 userShares
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
        // 保存请求参数
        lastUserId = userId
        lastLat = lat
        lastLon = lon
        lastRadius = radius

        // 如果已在加载中，直接返回
        if case .loading = loadingState { return }

        loadingState = .loading

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
            self.loadingState = .loaded(sorted)
        } catch {
            print("❌ [UserTimelineViewModel] 加载失败: \(error.localizedDescription)")
            self.loadingState = .error(error)
            throw error
        }
    }

    /// 手动重试
    func retry() {
        retryLastFetch()
    }

    // MARK: - 防重复加载（用于滚动恢复）

    /// 仅在首次时加载数据，返回时跳过（避免覆盖滚动恢复）
    func loadIfNeeded(
        userId: Int,
        lat: Double,
        lon: Double,
        radius: Double = 10
    ) async throws {
        guard !didInitialLoad else {
            print("📋 [UserTimelineViewModel] loadIfNeeded: 已加载过，跳过（保持滚动位置）")
            return
        }
        didInitialLoad = true
        print("📋 [UserTimelineViewModel] loadIfNeeded: 首次加载")
        try await fetchUserShareList(userId: userId, lat: lat, lon: lon, radius: radius)
    }

    /// 强制刷新（用户主动下拉刷新时使用）
    func forceRefresh(
        userId: Int,
        lat: Double,
        lon: Double,
        radius: Double = 10
    ) async throws {
        print("📋 [UserTimelineViewModel] forceRefresh: 强制刷新")
        try await fetchUserShareList(userId: userId, lat: lat, lon: lon, radius: radius)
    }
}
