//
//  ShareListView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/31.
//

import SwiftUI

struct ShareListView: View {
    @State private var selectedTab: ShareListTab = .all
    @StateObject var timelineVM = UserTimelineViewModel()
    @Environment(\.appState) var appState
    @EnvironmentObject var searchViewModel: SearchViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator

    /// 需要恢复滚动时的目标 ID（传给 HostingTableView）
    @State private var restoreTargetId: Int? = nil

    let userId: Int
    let lat: Double
    let lon: Double
    let radius: Double

    /// 当前 tab 的数据列表
    private var currentShares: [ResponsedShare] {
        switch selectedTab {
        case .all:
            return timelineVM.userShares.filter { $0.deleted == 0 }
        case .faded:
            return timelineVM.userShares.filter { $0.deleted == 0 && ($0.fadeScore ?? 0) >= 100 }
        }
    }

    // 生命周期日志
    init(userId: Int, lat: Double, lon: Double, radius: Double) {
        self.userId = userId
        self.lat = lat
        self.lon = lon
        self.radius = radius
        print("🧬 [ShareList] init userId=\(userId)")
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Tab 按钮
            HStack(alignment: .top, spacing: Constants.iconSizeS) {
                TabButton(title: "全部观之", isSelected: selectedTab == .all) {
                    if selectedTab != .all {
                        selectedTab = .all
                        // 切换 tab 时重置 didRestore，允许恢复
                        navigationCoordinator.resetShareListDidRestore(userId: userId, tab: .all)
                    }
                }
                TabButton(title: "已褪色", isSelected: selectedTab == .faded) {
                    if selectedTab != .faded {
                        selectedTab = .faded
                        // 切换 tab 时重置 didRestore，允许恢复
                        navigationCoordinator.resetShareListDidRestore(userId: userId, tab: .faded)
                    }
                }
                Spacer()
            }
            .padding()
            Divider()

            // 列表内容
            switch timelineVM.loadingState {
            case .idle, .loading:
                VStack {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                }
                .frame(maxWidth: .infinity)

            case .error:
                RetryView(
                    message: "加载失败",
                    detail: "请检查网络连接",
                    onRetry: {
                        timelineVM.retry()
                    }
                )
                .frame(maxWidth: .infinity)

            case .loaded:
                if currentShares.isEmpty {
                    VStack {
                        Spacer()
                        Text(selectedTab == .all ? "暂无观之" : "暂无已褪色的观之")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // 使用 HostingTableView（UIKit）解决底部回弹漂移问题
                    HostingTableView(
                        items: currentShares,
                        id: \.id,
                        row: { shareItem in
                            VStack(spacing: 0) {
                                ShareSingleView(share: shareItem) {
                                    // 1. 保存滚动位置
                                    print("🧭 [Nav] push ShareDetail from ShareList, shareId=\(shareItem.id), userId=\(userId), tab=\(selectedTab)")
                                    navigationCoordinator.saveShareListScrollPosition(
                                        userId: userId,
                                        tab: selectedTab,
                                        shareId: shareItem.id
                                    )
                                    print("💾 [ShareList] save restore state: userId=\(userId), tab=\(selectedTab), targetId=\(shareItem.id)")

                                    // 2. 导航到详情页
                                    let shareIdString = "\(shareItem.id)"
                                    if appState.useOverlayMode {
                                        searchViewModel.selectedAnnotationID = shareIdString
                                        searchViewModel.loadShareDetail(for: Int64(shareItem.id))
                                        searchViewModel.isShareDetailOverlayShown = true
                                    } else {
                                        navigationCoordinator.path.append(Route.shareDetailView(annotationID: shareIdString))
                                    }
                                }
                                .environment(\.appState, appState)
                                .environmentObject(searchViewModel)
                                .environmentObject(navigationCoordinator)

                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    )
                    .bouncesEnabled(true)  // 启用弹性滚动
                    .showsSeparators(false)
                    .endFooterStyle(.text("- 到底啦 -"))  // 底部提示
                    .restoreToID(restoreTargetId)  // 滚动恢复目标
                    .onSelect { shareItem in
                        // HostingTableView 的点击回调（备用，ShareSingleView 内部也有导航）
                    }
                }
            }
        }
        .onAppear {
            print("🧬 [ShareList] onAppear userId=\(userId), tab=\(selectedTab)")
        }
        .onDisappear {
            print("🧬 [ShareList] onDisappear userId=\(userId), tab=\(selectedTab)")
        }
        // 监听通知：从详情页返回时恢复滚动位置
        .onReceive(NotificationCenter.default.publisher(for: .shareDetailDidDisappear)) { _ in
            let state = navigationCoordinator.getShareListScrollState(userId: userId, tab: selectedTab)
            print("📍 [ShareList] 收到 shareDetailDidDisappear 通知, userId=\(userId), tab=\(selectedTab)")
            print("📍 [ShareList] 当前恢复状态: pending=\(state?.pendingRestore ?? false), didRestore=\(state?.didRestore ?? false), savedTarget=\(state?.lastShareId ?? -1)")

            // 检查是否有待恢复的滚动位置
            guard let state = state,
                  state.pendingRestore,
                  !state.didRestore,
                  let targetId = state.lastShareId else {
                print("📍 [ShareList] 无需恢复滚动")
                return
            }

            // 设置恢复目标 ID，HostingTableView 会自动滚动
            print("🟢 [ShareList] 设置 restoreTargetId=\(targetId)")
            restoreTargetId = targetId

            // 标记恢复完成
            navigationCoordinator.markShareListRestoreComplete(userId: userId, tab: selectedTab)
        }
        // 监听导航路径变化：进入详情页时标记 pendingRestore
        .onChange(of: navigationCoordinator.path.count) { oldCount, newCount in
            if newCount > oldCount {
                print("📍 [ShareList] 检测到导航进入，设置 pendingRestore")
                navigationCoordinator.prepareShareListRestore(userId: userId, tab: selectedTab)
            }
        }
        .task {
            // 只在首次加载数据，返回时跳过（避免覆盖滚动恢复）
            do {
                try await timelineVM.loadIfNeeded(
                    userId: userId,
                    lat: lat,
                    lon: lon,
                    radius: radius
                )
            } catch {
                print("加载用户分享列表出错：\(error)")
            }
        }
    }

}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Font.custom("PingFang SC", size: 14))
                .kerning(0.22)
                .foregroundColor(isSelected ? Color("text-black") : Color("text-gray"))
        }
    }
}

#Preview {
    ShareListView(userId: 11, lat: 39.976165771484375, lon: 116.34468640857655, radius: 10)
        .environmentObject(NavigationCoordinator())
        .environmentObject(SearchViewModel())
}
