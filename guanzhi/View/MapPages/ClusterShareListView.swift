//
//  ClusterShareListView.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/4.
//
//  Stage 2: 聚合分享列表
//  - 使用系统 sheet 呈现，与主页搜索结果卡片风格一致
//  - 复用 ShareSingleView 显示列表
//  - 点击列表项可跳转分享详情
//

import SwiftUI

struct ClusterShareListView: View {

    /// 聚合内的标注列表
    let annotations: [CustomAnnotation]

    /// 关闭回调，参数 forDetail: 是否因进入详情而关闭；tappedShareId: 点击的 share ID
    var onDismiss: (_ forDetail: Bool, _ tappedShareId: Int?) -> Void

    /// 恢复时滚动到的 share ID（Binding，用完后清空，避免重复滚动）
    @Binding var scrollToShareId: Int?

    @Environment(\.appState) var appState
    @EnvironmentObject var searchViewModel: SearchViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var onboardingCoordinator: OnboardingCoordinator

    /// 冻结的列表数据快照，避免 body 重算时数据源抖动导致布局修正
    @State private var stableShares: [ResponsedShare] = []
    /// 是否已执行过滚动恢复（防止重复触发）
    @State private var didRestore = false
    /// 底部保留区高度（每个 session 只初始化一次，确保稳定）
    @State private var bottomReserve: CGFloat = 0

    var body: some View {
        let _ = print("🔶 [ClusterList] body 重算, stableShares.count=\(stableShares.count), didRestore=\(didRestore), scrollToShareId=\(String(describing: scrollToShareId))")
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Text("附近的观之")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color("text-black"))
                    .padding(.top, 8)

                Spacer()

                Text("\(annotations.count) 条")
                    .font(.system(size: 14))
                    .foregroundColor(Color("text-gray"))

                Button {
                    onDismiss(false, nil)  // 手动关闭，非进入详情
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color("text-gray"))
                }
            }
            .padding(.horizontal, Constants.spacingSpacingM)
            .padding(.top, Constants.spacingSpacingS)
            .padding(.bottom, Constants.spacingSpacingS)

            Divider()

            // 分享列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(stableShares, id: \.id) { share in
                            ShareSingleView(share: share)
                                .id(share.id)  // 用于 ScrollViewReader
                                .environment(appState)
                                .environmentObject(searchViewModel)
                                .environmentObject(navigationCoordinator)
                                // 点击时延迟关闭聚合列表 sheet，确保导航先执行
                                .simultaneousGesture(
                                    TapGesture().onEnded { _ in
                                        // 【Onboarding】触发标注点击事件（用于步骤 B）
                                        onboardingCoordinator.handleEvent(.annotationTapped)
                                        // 延迟 0.1 秒关闭，确保 ShareSingleView 的导航先执行
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            onDismiss(true, share.id)  // 进入详情，传递点击的 share ID
                                        }
                                    }
                                )

                            Divider()
                                .padding(.leading, 120 + Constants.spacingSpacingM)
                        }
                    }
                    .transaction { $0.animation = nil }  // 禁用内容变化时的隐式动画
                }
                // 底部保留区：确保最后一条完整露出，避免边界回弹
                .contentMargins(.bottom, bottomReserve, for: .scrollContent)
                .scrollBounceBehavior(.basedOnSize)  // 根据内容大小决定是否弹性
                // 获取 safeArea 并初始化 bottomReserve（每个 session 只执行一次）
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .task {
                                if bottomReserve == 0 {
                                    // safeAreaInsets.bottom + 小余量，确保最后一条完整露出
                                    bottomReserve = geo.safeAreaInsets.bottom + 16
                                    print("🔶 [ClusterList] 初始化 bottomReserve=\(bottomReserve), safeArea.bottom=\(geo.safeAreaInsets.bottom)")
                                }
                            }
                    }
                )
                // 初始化数据快照
                .task {
                    print("🔶 [ClusterList] .task 触发, stableShares.isEmpty=\(stableShares.isEmpty)")
                    if stableShares.isEmpty {
                        stableShares = convertToResponsedShares()
                        print("🔶 [ClusterList] 初始化 stableShares, count=\(stableShares.count)")
                    }
                }
                // 恢复滚动位置：只在 stableShares 准备好后执行一次
                .task(id: stableShares.count) {
                    print("🔶 [ClusterList] .task(id: \(stableShares.count)) 触发, didRestore=\(didRestore), scrollToShareId=\(String(describing: scrollToShareId))")
                    // 防止重复触发 + 确保有数据
                    guard !didRestore,
                          let shareId = scrollToShareId,
                          stableShares.contains(where: { $0.id == shareId }) else {
                        print("🔶 [ClusterList] 跳过滚动恢复: didRestore=\(didRestore), scrollToShareId=\(String(describing: scrollToShareId))")
                        return
                    }

                    // 立刻标记已恢复 + 清空 scrollToShareId，防止任何重复触发
                    didRestore = true
                    scrollToShareId = nil
                    print("🔶 [ClusterList] 执行滚动恢复到 shareId=\(shareId)")

                    // 计算动态 anchor
                    let anchor = dynamicAnchor(for: shareId, in: stableShares)
                    print("🔶 [ClusterList] anchor=\(anchor)")

                    // 下一帧执行 + 禁用动画
                    DispatchQueue.main.async {
                        print("🔶 [ClusterList] 执行 scrollTo")
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            proxy.scrollTo(shareId, anchor: anchor)
                        }
                        print("🔶 [ClusterList] scrollTo 完成")
                    }
                }
            }
        }
    }

    /// 根据 index 动态选择 anchor，避免边缘过冲跳动
    private func dynamicAnchor(for shareId: Int, in shares: [ResponsedShare]) -> UnitPoint {
        guard let index = shares.firstIndex(where: { $0.id == shareId }) else {
            return .center
        }
        let count = shares.count
        // 靠近顶部用 .top，靠近底部用 .bottom，中间用 .center
        if index <= 1 {
            return .top
        } else if index >= max(0, count - 2) {
            return .bottom
        } else {
            return .center
        }
    }

    // MARK: - Helper

    /// 将 CustomAnnotation 转换为 ResponsedShare（ShareSingleView 需要）
    /// 优先从 SearchViewModel 的缓存获取原始数据（包含正确的 fadeScore）
    private func convertToResponsedShares() -> [ResponsedShare] {
        // 🔍 调试日志
        print("🔍 [DEBUG] ClusterList convertToResponsedShares called, annotations.count=\(annotations.count)")
        print("🔍 [DEBUG] cachedResponsedShares.count=\(searchViewModel.cachedResponsedShares.count)")

        return annotations.compactMap { annotation -> ResponsedShare? in
            guard let share = annotation.annotationData else { return nil }
            let shareId = Int(share.id)

            // 优先从缓存获取原始的 ResponsedShare（包含正确的 fadeScore 等字段）
            if let cached = searchViewModel.cachedResponsedShares[shareId] {
                print("🔍 [DEBUG] shareId=\(shareId) cache HIT, fadeScore=\(cached.fadeScore as Any)")
                return cached
            }

            print("🔍 [DEBUG] shareId=\(shareId) cache MISS, local fadeScore=\(share.fadeScore)")

            // 回退：从本地 Share 对象转换（可能 fadeScore 不准确）
            let createDateTs = Int(share.createDate.timeIntervalSince1970) * 1000
            let userId = Int(share.userId)
            let dataText = share.data
            let lon = share.longitude
            let lat = share.latitude
            let addr = share.address
            let imgPath = share.imagePathsString ?? ""
            let titleText = share.title
            let agree = share.agreeCount
            let neutral = share.neutralCount
            let checkin = share.checkinCount
            let comment = share.commentCount
            let fade = share.fadeScore

            return ResponsedShare(
                id: shareId,
                createDate: createDateTs,
                userId: userId,
                data: dataText,
                longitude: lon,
                latitude: lat,
                provinceCode: nil,
                cityCode: nil,
                districtCode: nil,
                address: addr,
                imagePath: imgPath,
                title: titleText,
                deleted: 0,
                agreeCount: agree,
                neutralCount: neutral,
                checkinCount: checkin,
                commentCount: comment,
                currentUserVoteType: nil,
                fadeScore: fade
            )
        }
    }
}

#Preview {
    @Previewable @State var scrollToId: Int? = nil
    ClusterShareListView(
        annotations: [],
        onDismiss: { _, _ in },
        scrollToShareId: $scrollToId
    )
    .environment(\.appState, AppStateModel())
    .environmentObject(SearchViewModel())
    .environmentObject(NavigationCoordinator())
    .environmentObject(OnboardingCoordinator())
}
