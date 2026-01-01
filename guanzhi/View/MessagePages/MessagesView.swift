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
    @State private var selectedSystemMessage: NotificationMessage? = nil

    /// 当前分类是否有未读消息
    private var hasUnreadMessages: Bool {
        let count = viewModel.unreadCounts?.count(for: viewModel.selectedCategory) ?? 0
        print("📬 hasUnreadMessages 检查: 分类=\(viewModel.selectedCategory.rawValue), 未读数=\(count)")
        return count > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // 分类 Tab
            MessageTabBar(
                selectedCategory: $viewModel.selectedCategory,
                unreadCounts: viewModel.unreadCounts,
                hasUnreadByCategory: viewModel.hasUnreadByCategory
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
            Button("全部标为已读") {
                Task {
                    await viewModel.markAllAsRead()
                }
            }
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
        // 系统消息详情 Sheet
        .sheet(item: $selectedSystemMessage) { message in
            SystemMessageDetailView(message: message)
        }
    }

    // MARK: - 消息点击处理

    private func handleMessageTap(_ message: NotificationMessage) {
        print("📬 点击消息: id=\(message.id), type=\(message.type), deepLink=\(message.deepLink ?? "nil"), shareId=\(message.shareId ?? -1)")

        // 标记已读
        Task {
            await viewModel.markAsRead(message)
        }

        // 判断跳转方式
        if let deepLink = message.deepLink, !deepLink.isEmpty, let url = URL(string: deepLink) {
            // 检查是否为系统通知的 deepLink（guanzhi://notifications）
            if url.host == "notifications" || url.host == "notification" {
                // 系统消息 - 显示详情 Sheet
                print("📬 系统通知 deepLink，显示详情 Sheet")
                selectedSystemMessage = message
            } else if url.host == "share" {
                // 分享相关的 Deep Link
                print("📬 使用 Deep Link 导航: \(deepLink)")
                handleDeepLink(url)
            } else {
                // 其他未知 deepLink - 显示详情 Sheet
                print("📬 未知 deepLink 类型，显示详情 Sheet")
                selectedSystemMessage = message
            }
        } else if let shareId = message.shareId {
            // 跳转到分享详情
            print("📬 跳转到分享详情: \(shareId)")
            navigationCoordinator.path.append(Route.shareDetailView(annotationID: "\(shareId)"))
        } else {
            // 系统消息（无 deepLink 和 shareId）- 显示详情 Sheet
            print("📬 显示系统消息详情 Sheet")
            selectedSystemMessage = message
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

    /// 各分类是否有未读消息（从消息列表计算）
    @Published var hasUnreadByCategory: [MessageCategory: Bool] = [:]

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
        // 立即清空旧数据，让 UI 显示 loading 状态
        messages = []
        displayableMessages = []

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
                messages[index] = message.asRead()
                print("📬 本地更新消息 \(message.id) 为已读")
                // 重新聚合以更新 hasUnreadByCategory
                aggregateMessages()
            }

            // 刷新未读数
            await loadUnreadCounts()

            // 刷新全局红点
            await NotificationBadgeManager.shared.refresh()
        } catch {
            print("❌ 标记已读失败: \(error)")
        }
    }

    // MARK: - 全部已读

    func markAllAsRead() async {
        print("📬 开始标记全部已读，分类: \(selectedCategory.rawValue)")
        do {
            // 只标记当前分类的通知为已读
            try await NotificationService.shared.markAllAsRead(category: selectedCategory.rawValue)
            print("✅ 标记全部已读 API 调用成功")

            // 刷新列表和未读数
            await refresh()
            await loadUnreadCounts()

            // 刷新全局红点
            await NotificationBadgeManager.shared.refresh()
            print("✅ 全部已读完成，列表已刷新")
        } catch {
            print("❌ 全部已读失败: \(error)")
        }
    }

    // MARK: - 批量标记已读（用于聚合消息）

    func markAsReadBatch(_ ids: [Int64]) async {
        var hasUpdates = false
        for id in ids {
            do {
                try await NotificationService.shared.markAsRead(id: id)
                // 更新本地状态
                if let index = messages.firstIndex(where: { $0.id == id }) {
                    messages[index] = messages[index].asRead()
                    hasUpdates = true
                }
            } catch {
                print("❌ 标记已读失败 (id=\(id)): \(error)")
            }
        }

        if hasUpdates {
            // 重新聚合以更新 hasUnreadByCategory
            aggregateMessages()
        }

        // 刷新未读数
        await loadUnreadCounts()

        // 刷新全局红点
        await NotificationBadgeManager.shared.refresh()
    }

    // MARK: - 聚合消息

    /// 将原始消息列表转换为聚合展示列表
    private func aggregateMessages() {
        var result: [DisplayableMessage] = []

        // 计算各分类是否有未读消息（从所有消息中计算）
        var unreadByCategory: [MessageCategory: Bool] = [:]
        for category in MessageCategory.allCases {
            let hasUnread = messages.contains { $0.type.category == category && $0.isUnread }
            unreadByCategory[category] = hasUnread
        }
        hasUnreadByCategory = unreadByCategory
        print("📬 各分类未读状态: 互动=\(unreadByCategory[.interaction] ?? false), 系统=\(unreadByCategory[.system] ?? false)")

        // 前端按分类过滤（备用方案，以防后端未正确过滤）
        let filteredMessages = messages.filter { $0.type.category == selectedCategory }
        print("📬 消息过滤: 原始 \(messages.count) 条，当前分类 \(selectedCategory.rawValue)，过滤后 \(filteredMessages.count) 条")

        // 按 shareId 分组贴纸通知
        var stickersByShare: [Int64: [NotificationMessage]] = [:]
        var otherMessages: [NotificationMessage] = []

        for msg in filteredMessages {
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

// MARK: - 系统消息详情视图

struct SystemMessageDetailView: View {
    let message: NotificationMessage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 图标和标题
                    HStack(spacing: 12) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color("color-primary").opacity(0.2), lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.type.titleFormat(userName: nil))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color("color-black"))

                            Text(message.formattedTime)
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }

                        Spacer()
                    }
                    .padding(.bottom, 8)

                    Divider()

                    // 消息内容
                    Text(message.content)
                        .font(.system(size: 16))
                        .foregroundColor(Color("color-black"))
                        .lineSpacing(6)

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .navigationTitle("系统消息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(Color("color-primary"))
                }
            }
        }
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
