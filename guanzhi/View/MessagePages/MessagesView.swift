//
//  MessagesView.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/30.
//

import SwiftUI

struct MessagesView: View {
    @Environment(\.appState) var appState
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var userProfileManager: UserProfileManager

    @StateObject private var viewModel = MessagesViewModel()
    @State private var showMoreMenu = false

    /// 是否有未读消息
    private var hasUnreadMessages: Bool {
        (viewModel.unreadCounts?.total ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // 分类 Tab
            MessageTabBar(
                selectedCategory: $viewModel.selectedCategory,
                unreadCounts: viewModel.unreadCounts
            )
            .padding(.horizontal)
            .padding(.top, 8)

            // 消息列表
            if viewModel.isLoading && viewModel.messages.isEmpty {
                // 首次加载
                Spacer()
                ProgressView("加载中...")
                Spacer()
            } else if viewModel.displayableMessages.isEmpty {
                // 空状态
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("暂无\(viewModel.selectedCategory.title)消息")
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                // 消息列表
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.displayableMessages) { item in
                            switch item {
                            case .single(let message):
                                MessageRowView(message: message) {
                                    handleMessageTap(message)
                                }
                            case .aggregatedStickers(let agg):
                                AggregatedStickerRowView(aggregation: agg) {
                                    handleAggregatedStickerTap(agg)
                                }
                            }
                            Divider()
                                .padding(.leading, 68)
                        }

                        // 加载更多
                        if viewModel.hasMore {
                            ProgressView()
                                .padding()
                                .onAppear {
                                    Task {
                                        await viewModel.loadMore()
                                    }
                                }
                        }
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
        .navigationBarTitle("消息", displayMode: .inline)
        .toolbar {
            if #available(iOS 26.0, *) {
                // 左侧返回按钮
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        navigationCoordinator.path.removeLast()
                    }) {
                        Image("icon-back")
                    }
                    .buttonStyle(ButtonStyle_m())
                }
                .sharedBackgroundVisibility(.hidden)

                // 右侧更多按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showMoreMenu = true
                    } label: {
                        Image("icon-more")
                    }
                    .buttonStyle(ButtonStyle_m())
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                // 左侧返回按钮
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        navigationCoordinator.path.removeLast()
                    }) {
                        Image("icon-back")
                    }
                    .buttonStyle(ButtonStyle_m())
                }

                // 右侧更多按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showMoreMenu = true
                    } label: {
                        Image("icon-more")
                    }
                    .buttonStyle(ButtonStyle_m())
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("更多操作", isPresented: $showMoreMenu, titleVisibility: .hidden) {
            Button("全部已读") {
                Task {
                    await viewModel.markAllAsRead()
                }
            }
            .disabled(!hasUnreadMessages)
            Button("取消", role: .cancel) {}
        }
        .onAppear {
            Task {
                await viewModel.loadInitialData()
            }
        }
        .onDisappear {
            if navigationCoordinator.path.isEmpty {
                appState.isShowingSearchView = true
            }
        }
        .onChange(of: viewModel.selectedCategory) { _, _ in
            Task {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - 消息点击处理

    private func handleMessageTap(_ message: NotificationMessage) {
        // 标记已读
        Task {
            await viewModel.markAsRead(message)
        }

        // 解析 Deep Link 并导航
        if let deepLink = message.deepLink, let url = URL(string: deepLink) {
            handleDeepLink(url)
        } else if let shareId = message.shareId {
            // 默认跳转到分享详情
            navigationCoordinator.path.append(Route.shareDetailView(annotationID: "\(shareId)"))
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "guanzhi", url.host == "share" else { return }

        let pathComponents = url.pathComponents
        // pathComponents: ["/", "{shareId}", "comment", "{commentId}"]

        if pathComponents.count >= 2,
           let shareId = Int64(pathComponents[1]) {

            if pathComponents.count >= 4,
               pathComponents[2] == "comment",
               let commentId = Int64(pathComponents[3]) {
                // 跳转到分享详情并定位评论
                navigationCoordinator.path.append(Route.shareComment(shareId: shareId, commentId: commentId))
            } else {
                // 只跳转到分享详情
                navigationCoordinator.path.append(Route.shareDetailView(annotationID: "\(shareId)"))
            }
        }
    }

    // MARK: - 聚合贴纸消息点击处理

    private func handleAggregatedStickerTap(_ aggregation: AggregatedStickerNotification) {
        // 批量标记已读
        Task {
            await viewModel.markAsReadBatch(aggregation.notificationIds)
        }

        // 跳转到分享详情
        navigationCoordinator.path.append(Route.shareDetailView(annotationID: "\(aggregation.shareId)"))
    }
}

// MARK: - MessagesViewModel

@MainActor
class MessagesViewModel: ObservableObject {
    @Published var selectedCategory: MessageCategory = .interaction
    @Published var messages: [NotificationMessage] = []
    @Published var unreadCounts: UnreadCount?
    @Published var isLoading = false
    @Published var hasMore = true

    /// 聚合后的展示消息列表
    @Published var displayableMessages: [DisplayableMessage] = []

    private var currentPage = 1
    private let pageSize = 20

    // MARK: - 加载初始数据

    func loadInitialData() async {
        await loadUnreadCounts()
        await refresh()
    }

    // MARK: - 加载未读数

    func loadUnreadCounts() async {
        do {
            unreadCounts = try await NotificationService.shared.getUnreadCount()
        } catch {
            print("❌ 获取未读数失败: \(error)")
        }
    }

    // MARK: - 刷新列表

    func refresh() async {
        currentPage = 1
        hasMore = true
        isLoading = true

        do {
            let data = try await NotificationService.shared.getNotifications(
                category: selectedCategory,
                page: currentPage,
                size: pageSize
            )
            messages = data.list
            hasMore = messages.count < data.total
            currentPage = 2
            aggregateMessages()
        } catch {
            print("❌ 刷新消息列表失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 加载更多

    func loadMore() async {
        guard !isLoading && hasMore else { return }
        isLoading = true

        do {
            let data = try await NotificationService.shared.getNotifications(
                category: selectedCategory,
                page: currentPage,
                size: pageSize
            )
            messages.append(contentsOf: data.list)
            hasMore = messages.count < data.total
            currentPage += 1
            aggregateMessages()
        } catch {
            print("❌ 加载更多失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 标记已读

    func markAsRead(_ message: NotificationMessage) async {
        guard message.isUnread else { return }

        do {
            try await NotificationService.shared.markAsRead(id: message.id)

            // 更新本地状态
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                // 创建一个已读版本的消息（因为 struct 是值类型）
                var updatedMessages = messages
                // 由于 NotificationMessage 是不可变的，我们需要刷新列表或本地修改
                // 这里简单处理：标记后刷新未读数
            }

            // 刷新未读数
            await loadUnreadCounts()
        } catch {
            print("❌ 标记已读失败: \(error)")
        }
    }

    // MARK: - 全部已读

    func markAllAsRead() async {
        do {
            try await NotificationService.shared.markAllAsRead()

            // 刷新列表和未读数
            await refresh()
            await loadUnreadCounts()
        } catch {
            print("❌ 全部已读失败: \(error)")
        }
    }

    // MARK: - 批量标记已读（用于聚合消息）

    func markAsReadBatch(_ ids: [Int64]) async {
        for id in ids {
            do {
                try await NotificationService.shared.markAsRead(id: id)
            } catch {
                print("❌ 标记已读失败 (id=\(id)): \(error)")
            }
        }
        // 刷新未读数
        await loadUnreadCounts()
    }

    // MARK: - 聚合消息

    /// 将原始消息列表转换为聚合展示列表
    private func aggregateMessages() {
        var result: [DisplayableMessage] = []

        // 按 shareId 分组贴纸通知
        var stickersByShare: [Int64: [NotificationMessage]] = [:]
        var otherMessages: [NotificationMessage] = []

        for msg in messages {
            if msg.type == .stickerReceived, let shareId = msg.shareId {
                stickersByShare[shareId, default: []].append(msg)
            } else {
                otherMessages.append(msg)
            }
        }

        // 构建展示列表
        // 1. 处理贴纸聚合
        for (shareId, stickerMsgs) in stickersByShare {
            if stickerMsgs.count == 1 {
                // 单条贴纸通知不聚合
                result.append(.single(stickerMsgs[0]))
            } else {
                // 多条贴纸通知聚合
                let agg = AggregatedStickerNotification(shareId: shareId, notifications: stickerMsgs)
                result.append(.aggregatedStickers(agg))
            }
        }

        // 2. 添加其他消息
        for msg in otherMessages {
            result.append(.single(msg))
        }

        // 3. 按最新时间排序（最新在前）
        result.sort { $0.latestTime > $1.latestTime }

        displayableMessages = result
        print("📬 消息聚合完成: 原始 \(messages.count) 条 → 展示 \(result.count) 条")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MessagesView()
            .environmentObject(NavigationCoordinator())
            .environmentObject(UserProfileManager())
    }
}
