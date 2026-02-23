//
//  MessagesView.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/30.
//

import SwiftUI
import SwipeActions
import UIKit

struct MessagesView: View {
    @Environment(\.appState) var appState
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var userProfileManager: UserProfileManager

    @StateObject private var viewModel = MessagesViewModel()
    @State private var showMoreMenu = false
    @State private var selectedSystemMessage: NotificationMessage? = nil

    /// 当前展开 swipe 的行 ID
    @State private var openedSwipeId: String? = nil
    /// 当前处于"确认删除"态的行 ID
    @State private var confirmingDeleteId: String? = nil

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
                // 消息列表（使用 ScrollView + LazyVStack + SwipeActions 库）
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.displayableMessages) { item in
                                swipeableRow(for: item)
                                    .id(item.id)
                            }

                            // 加载更多
                            if viewModel.hasMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
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
                        // 刷新时清空状态
                        openedSwipeId = nil
                        confirmingDeleteId = nil
                        await viewModel.refresh()
                    }
                    // 恢复滚动位置：当数据数量变化时检查
                    .onChange(of: viewModel.displayableMessages.count) { _, _ in
                        restoreScrollIfPossible(proxy)
                    }
                    // 恢复滚动位置：onAppear 时也检查（返回时触发）
                    .onAppear {
                        restoreScrollIfPossible(proxy)
                    }
                }
            }
        }
        .navigationTitle("消息")
        .navigationBarTitleDisplayMode(.inline)
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
        .task {
            // 只在首次加载数据，返回时不刷新（避免覆盖滚动恢复）
            await viewModel.loadIfNeeded()
        }
        .onDisappear {
            if navigationCoordinator.path.isEmpty {
                appState.isShowingSearchView = true
            }
        }
        .onChange(of: viewModel.selectedCategory) { _, _ in
            // 切换分类时清空状态
            openedSwipeId = nil
            confirmingDeleteId = nil
            Task {
                await viewModel.refresh()
            }
        }
        // 系统消息详情 Sheet（仅用于无 shareId 的纯系统消息）
        .sheet(item: $selectedSystemMessage) { message in
            SystemMessageDetailView(message: message)
        }
    }

    // MARK: - 消息点击处理

    private func handleMessageTap(_ message: NotificationMessage) {
        // 标记已读
        Task {
            await viewModel.markAsRead(message)
        }

        // 简化的跳转逻辑：
        // 1. 有 shareId 的消息（评论、点赞、贴纸、褪色等）→ 直接跳转观之详情
        // 2. 无 shareId 的纯系统消息（升级、警告、冻结等）→ 显示详情弹窗
        if let shareId = message.shareId {
            // 跳转到观之详情页面
            print("📬 跳转到观之详情: \(shareId)")
            navigationCoordinator.path.append(Route.shareDetailView(annotationID: "\(shareId)"))
        } else {
            // 纯系统消息 - 显示详情 Sheet
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
                // 跳转到观之详情并定位评论
                navigationCoordinator.path.append(Route.shareComment(shareId: shareId, commentId: commentId))
            } else {
                // 只跳转到观之详情
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

        // 跳转到观之详情
        navigationCoordinator.path.append(Route.shareDetailView(annotationID: "\(aggregation.shareId)"))
    }

    // MARK: - 可滑动的消息行

    /// 使用 SwipeActions 库构建可滑动的行
    @ViewBuilder
    private func swipeableRow(for item: DisplayableMessage) -> some View {
        let isConfirming = confirmingDeleteId == item.id

        SwipeView {
            // 行内容
            VStack(spacing: 0) {
                switch item {
                case .single(let message):
                    MessageRowView(message: message) {
                        // 保存当前点击的消息 ID 到 NavigationCoordinator
                        print("✅ [Messages] 保存滚动位置 id=\(item.id)")
                        navigationCoordinator.messagesScrolledItemId = item.id
                        navigationCoordinator.messagesDidRestore = false
                        // 关闭 swipe 状态
                        openedSwipeId = nil
                        confirmingDeleteId = nil
                        handleMessageTap(message)
                    }
                case .aggregatedStickers(let agg):
                    AggregatedStickerRowView(aggregation: agg) {
                        // 保存当前点击的消息 ID 到 NavigationCoordinator
                        print("✅ [Messages] 保存滚动位置 id=\(item.id)")
                        navigationCoordinator.messagesScrolledItemId = item.id
                        navigationCoordinator.messagesDidRestore = false
                        // 关闭 swipe 状态
                        openedSwipeId = nil
                        confirmingDeleteId = nil
                        handleAggregatedStickerTap(agg)
                    }
                }

                Divider()
                    .padding(.leading, 68)
            }
            .background(Color(UIColor.systemBackground))
        } trailingActions: { context in
            // 删除按钮（二段式确认）
            SwipeAction {
                if isConfirming {
                    // 第二次点击：执行删除
                    Task {
                        await performDelete(item: item)
                        confirmingDeleteId = nil
                        openedSwipeId = nil
                        context.state.wrappedValue = .closed
                    }
                } else {
                    // 第一次点击：进入确认态，保持展开
                    confirmingDeleteId = item.id
                    // 保持展开状态
                    context.state.wrappedValue = .expanded
                }
            } label: { _ in
                // 根据状态显示不同文案和颜色
                Text(isConfirming ? "确认删除" : "删除")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: isConfirming ? 90 : 70)
                    .frame(maxHeight: .infinity)
                    .background(isConfirming ? Color.red : Color.orange)
            } background: { _ in
                isConfirming ? Color.red : Color.orange
            }
        }
        .swipeActionsStyle(.mask)
        .swipeActionCornerRadius(0)
        .swipeActionsMaskCornerRadius(0)
        .swipeMinimumDistance(20)
        .onChange(of: openedSwipeId) { _, newValue in
            // 当其他行展开时，关闭当前行
            if newValue != item.id && newValue != nil {
                confirmingDeleteId = nil
            }
        }
    }

    // MARK: - 删除处理

    /// 执行删除操作
    private func performDelete(item: DisplayableMessage) async {
        print("🗑️ [Messages] 执行删除 id=\(item.id)")
        switch item {
        case .single(let message):
            await viewModel.deleteNotification(message.id)
        case .aggregatedStickers(let agg):
            await viewModel.deleteAggregatedNotifications(agg.notificationIds)
        }
    }

    // MARK: - 滚动位置辅助

    /// 恢复滚动位置（如果需要）
    @MainActor
    private func restoreScrollIfPossible(_ proxy: ScrollViewProxy) {
        // 确认删除态时不执行滚动恢复，避免和 swipe 动画冲突
        guard confirmingDeleteId == nil else { return }

        // 检查是否已恢复
        guard !navigationCoordinator.messagesDidRestore else {
            print("📬 [Messages] restoreScrollIfPossible: 已恢复过，跳过")
            return
        }

        // 检查是否有目标 ID
        guard let targetId = navigationCoordinator.messagesScrolledItemId else {
            print("📬 [Messages] restoreScrollIfPossible: 无目标 ID，跳过")
            return
        }

        // 检查目标 ID 是否存在于列表中
        let exists = viewModel.displayableMessages.contains(where: { $0.id == targetId })
        print("📬 [Messages] restoreScrollIfPossible: targetId=\(targetId), exists=\(exists), count=\(viewModel.displayableMessages.count)")

        guard exists else {
            return
        }

        // 立即标记已恢复（在执行滚动前，避免重复触发）
        navigationCoordinator.messagesDidRestore = true
        print("🟢 [Messages] 执行滚动恢复到 id=\(targetId)")

        // 计算动态 anchor
        let anchor = dynamicAnchor(for: targetId)

        // 延迟一帧执行（等布局完成）+ 禁用动画
        DispatchQueue.main.async {
            withTransaction(Transaction(animation: nil)) {
                proxy.scrollTo(targetId, anchor: anchor)
            }
            print("🟢 [Messages] scrollTo 完成")
        }
    }

    /// 根据 index 动态选择 anchor，避免边缘过冲跳动
    private func dynamicAnchor(for targetId: String) -> UnitPoint {
        guard let index = viewModel.displayableMessages.firstIndex(where: { $0.id == targetId }) else {
            return .center
        }
        let count = viewModel.displayableMessages.count
        // 靠近顶部用 .top，靠近底部用 .bottom，中间用 .center
        if index <= 1 {
            return .top
        } else if index >= max(0, count - 2) {
            return .bottom
        } else {
            return .center
        }
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

    /// 是否已完成首次加载（避免返回时重复刷新）
    var didInitialLoad = false

    private var currentPage = 1
    private let pageSize = 20

    // MARK: - 加载初始数据（仅首次）

    func loadIfNeeded() async {
        guard !didInitialLoad else {
            print("📬 [Messages] loadIfNeeded: 已加载过，跳过")
            return
        }
        didInitialLoad = true
        print("📬 [Messages] loadIfNeeded: 首次加载")
        await loadUnreadCounts()
        await refresh()
    }

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

    // MARK: - 删除通知

    /// 删除单条通知
    func deleteNotification(_ id: Int64) async {
        print("📬 删除通知 id=\(id)")
        do {
            try await NotificationService.shared.deleteNotification(id: id)

            // 从本地列表移除
            messages.removeAll { $0.id == id }
            // 重新聚合
            aggregateMessages()

            // 刷新未读数
            await loadUnreadCounts()
            // 刷新全局红点
            await NotificationBadgeManager.shared.refresh()

            print("✅ 通知 \(id) 已删除")
        } catch {
            print("❌ 删除通知失败: \(error)")
        }
    }

    /// 删除聚合通知中的所有消息
    func deleteAggregatedNotifications(_ ids: [Int64]) async {
        print("📬 批量删除通知 ids=\(ids)")
        for id in ids {
            do {
                try await NotificationService.shared.deleteNotification(id: id)
                messages.removeAll { $0.id == id }
            } catch {
                print("❌ 删除通知失败 (id=\(id)): \(error)")
            }
        }
        // 重新聚合
        aggregateMessages()
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
// 仅用于纯系统消息（升级、警告、冻结等无 shareId 的消息）
// 有 shareId 的消息会直接跳转到观之详情页面

struct SystemMessageDetailView: View {
    let message: NotificationMessage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 图标和标题
                    HStack(spacing: 12) {
                        // 系统图标
                        Circle()
                            .fill(Color("color-primary").opacity(0.15))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: message.type.systemIconName)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(Color("color-primary"))
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.localizedTitle)
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
                    Text(message.localizedContent)
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
