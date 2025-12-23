//
//  ShareInteractionViewModel.swift
//  guanzhi
//
//  Created by Claude Code on 2025/11/27.
//

import Foundation
import Combine

/// 投票状态枚举（与后端 voteType 对应）
enum VoteState: Int, Codable {
    case none    = -1  // 取消/默认状态（后端删除记录）
    case neutral = 0   // 无感/踩（后端支持，前端预留）
    case agree   = 1   // 赞同/点赞

    /// 切换到目标状态（用于 toggle 逻辑）
    func toggled(to target: VoteState) -> VoteState {
        return self == target ? .none : target
    }
}

/// 贴纸可用性加载状态枚举
/// 参考主流 App 图片加载逻辑：idle -> loading -> loaded/failed
enum StickerLoadingState: Equatable {
    /// 空闲状态（初始状态）
    case idle

    /// 加载中（显示 loading 动画）
    case loading

    /// 加载成功
    case loaded

    /// 加载失败（可重试）
    /// - Parameter retryCount: 已重试次数
    case failed(retryCount: Int)

    /// 是否可以重试（未达到最大重试次数）
    var canRetry: Bool {
        if case .failed(let count) = self {
            return count < StickerLoadingConfig.maxRetryCount
        }
        return false
    }

    /// 是否显示重试按钮（达到最大重试次数）
    var shouldShowRetryButton: Bool {
        if case .failed(let count) = self {
            return count >= StickerLoadingConfig.maxRetryCount
        }
        return false
    }

    /// 当前重试次数
    var currentRetryCount: Int {
        if case .failed(let count) = self {
            return count
        }
        return 0
    }
}

/// 贴纸加载配置
enum StickerLoadingConfig {
    /// 最大重试次数（主流 App 通常为 3 次）
    static let maxRetryCount = 3

    /// 重试延迟基数（毫秒）- 使用指数退避
    static let retryBaseDelayMs: UInt64 = 500

    /// 请求超时时间（秒）
    static let requestTimeoutSeconds: Double = 10.0
}

// MARK: - 已使用贴纸信息

/// 用户在当前分享上已使用的贴纸信息
/// 用于显示"已使用了「xx」贴纸"的状态条
struct UsedStickerInfo: Equatable {
    /// 贴纸种类
    let kind: StickerKind

    /// 贴纸显示名称（优先使用服务器返回的名称）
    let name: String

    /// 贴纸图标 URL（可选，用于显示服务器端图标）
    let iconURL: URL?

    /// 便捷初始化（使用本地定义的名称）
    init(kind: StickerKind, name: String? = nil, iconURL: URL? = nil) {
        self.kind = kind
        self.name = name ?? kind.displayName
        self.iconURL = iconURL
    }
}

/// 分享互动 ViewModel（点赞、打卡等）
///
/// 关键特性：
/// - 三态互斥：使用 VoteState 枚举强制状态唯一性
/// - 乐观更新：立即响应用户操作，后台同步服务器
/// - 竞态保护：通过全局唯一 operationId 确保只有最后一次操作生效
/// - 失败回滚：网络错误时恢复原始状态
/// - 数据同步：通过回调通知外层 ViewModel 更新
@MainActor
class ShareInteractionViewModel: ObservableObject {
    // MARK: - Published State

    /// ⚠️ 已废弃：当前投票状态（保留兼容，实际使用 currentUserSticker）
    @Published var voteState: VoteState = .none

    /// ⚠️ 已废弃：赞同数（保留兼容）
    /// 现在应该从 stickerSummaries 获取，但为了 InteractionOverlayView 兼容性保留
    @Published private var _agreeCount: Int = 0

    /// 赞同数（从贴纸统计获取）
    var agreeCount: Int {
        // 优先从 stickerSummaries 获取
        if let likeSummary = stickerSummaries.first(where: { $0.kind == .like }) {
            return likeSummary.count
        }
        // 回退到本地追踪值
        return _agreeCount
    }

    /// ⚠️ 已废弃：无感数（保留兼容）
    @Published private var _neutralCount: Int = 0

    /// 无感数（从贴纸统计获取）
    var neutralCount: Int {
        if let neutralSummary = stickerSummaries.first(where: { $0.kind == .neutral }) {
            return neutralSummary.count
        }
        return _neutralCount
    }

    /// 动画状态
    @Published var isAnimating: Bool = false

    /// 错误消息
    @Published var errorMessage: String? = nil

    /// 当前用户在此分享上已使用的贴纸（nil 表示未使用过任何贴纸）
    /// 当此值非 nil 时，底部贴纸队列应隐藏，改为显示"已使用了「xx」贴纸"状态条
    @Published var currentUserSticker: UsedStickerInfo? = nil

    /// 贴纸统计列表（用于顶部展示条）
    @Published var stickerSummaries: [StickerSummaryItem] = []

    /// 是否显示贴纸统计覆层
    @Published var isShowingStickerSummaryOverlay: Bool = false

    /// 用户可用的贴纸种类（基于权限，已过滤 isActive）
    @Published var availableStickerKinds: Set<StickerKind> = []

    /// 当前应显示的贴纸队列定义（应用互斥逻辑后）
    @Published var visibleStickerDefinitions: [StickerDefinition] = []

    // MARK: - Sticker Availability State (服务器驱动)

    /// 贴纸可用性列表（从服务器加载）
    @Published var stickerAvailabilities: [StickerAvailability] = []

    /// 贴纸加载状态（统一状态管理）
    @Published var stickerLoadingState: StickerLoadingState = .idle

    /// 贴纸可用性加载错误信息（用于显示）
    @Published var stickerAvailabilityError: String? = nil

    // MARK: - Computed Properties for Loading State (向后兼容)

    /// 是否正在加载贴纸可用性（派生属性，向后兼容）
    var isLoadingStickerAvailability: Bool {
        stickerLoadingState == .loading
    }

    /// 是否加载失败且需要显示重试按钮
    var shouldShowStickerRetryButton: Bool {
        stickerLoadingState.shouldShowRetryButton
    }

    // MARK: - 标签贴纸本地统计（临时方案）
    // TODO: 后续后端在分享详情中返回标签统计后，用服务器数据替代

    /// 标签贴纸本地统计（当前用户在此分享上使用的标签）
    /// key: StickerKind, value: 使用次数（通常为 1，因为每人每分享只能用一次）
    @Published var localTagStickerCounts: [StickerKind: Int] = [:]

    // MARK: - Computed Properties（派生属性）

    /// 是否已点赞（只读，派生自 currentUserSticker）
    /// 优先使用 currentUserSticker，回退到 voteState（兼容旧数据）
    var isLiked: Bool {
        if let sticker = currentUserSticker {
            return sticker.kind == .like
        }
        // 兼容：初始化时可能还没有 currentUserSticker，但有 voteState
        return voteState == .agree
    }

    /// 是否已无感（只读，派生自 currentUserSticker）
    /// 优先使用 currentUserSticker，回退到 voteState（兼容旧数据）
    var isNeutral: Bool {
        if let sticker = currentUserSticker {
            return sticker.kind == .neutral
        }
        // 兼容：初始化时可能还没有 currentUserSticker，但有 voteState
        return voteState == .neutral
    }

    // MARK: - Private State

    private var currentShareId: Int64?
    private var originalVoteState: VoteState = .none
    private var originalAgreeCount: Int = 0
    private var originalNeutralCount: Int = 0

    /// ✅ 全局唯一的操作序号（点赞、无感、取消共用）
    private var operationId: Int = 0

    /// 状态变化回调（通知外层更新）
    private var onStateChanged: ((Int64, VoteState, Int, Int) -> Void)?

    // MARK: - Initialization

    /// 初始化状态（从 Share 对象加载）
    /// - Parameters:
    ///   - share: 分享对象
    ///   - onStateChanged: 状态变化回调 (shareId, voteState, agreeCount, neutralCount) - 已废弃，保留兼容
    func initialize(share: Share, onStateChanged: ((Int64, VoteState, Int, Int) -> Void)? = nil) {
        self.currentShareId = share.id

        // ✅ 重置所有状态（不再依赖旧的 share.agreeCount/neutralCount/currentUserVoteType）
        // 所有状态都将从 loadStickerAvailability API 获取
        self._agreeCount = 0
        self._neutralCount = 0
        self.voteState = .none

        self.onStateChanged = onStateChanged

        // 保存原始值（已废弃，保留兼容）
        self.originalVoteState = .none
        self.originalAgreeCount = 0
        self.originalNeutralCount = 0

        // 重置错误和动画状态
        self.errorMessage = nil
        self.isAnimating = false

        // ✅ 重置本地标签统计（切换分享时需要清空）
        self.localTagStickerCounts = [:]

        // ✅ 重置已使用贴纸状态（切换分享时需要清空，等待服务器数据）
        self.currentUserSticker = nil

        // ✅ 重置贴纸统计（等待从服务器加载）
        self.stickerSummaries = []

        #if DEBUG
        print("📊 [ShareInteraction] 初始化:")
        print("   - shareId: \(share.id)")
        print("   - 所有状态已重置，等待从贴纸 API 加载")
        #endif

        // ✅ 重建可见贴纸队列（应用互斥逻辑）
        // 注意：此时 availableStickerKinds 可能还未计算，但 rebuildVisibleStickerDefinitions 会处理空集合情况
        rebuildVisibleStickerDefinitions()
    }

    // MARK: - Actions

    /// 切换点赞状态
    /// 现在统一使用贴纸 API（不再使用旧的 vote API）
    func toggleLike() {
        // ✅ 统一使用贴纸系统
        useSticker(.like)
    }

    /// 切换无感状态
    /// 现在统一使用贴纸 API（不再使用旧的 vote API）
    func toggleNeutral() {
        // ✅ 统一使用贴纸系统
        useSticker(.neutral)
    }

    /// 统一投票入口（供外部调用）
    /// 现在统一使用贴纸 API（不再使用旧的 vote API）
    func setVote(_ targetState: VoteState) {
        // ✅ 转换为贴纸调用
        if let kind = StickerKind.from(voteState: targetState) {
            useSticker(kind)
        }
    }

    // MARK: - Deprecated Vote Methods（已废弃，保留向后兼容）

    /// ⚠️ 已废弃：核心投票逻辑
    /// 此方法保留用于向后兼容，新代码请使用 useSticker(_:)

    // MARK: - Private Methods

    /// ✅ 核心投票逻辑（点赞、无感、取消共用）
    private func vote(to targetState: VoteState) {
        guard let shareId = currentShareId else {
            #if DEBUG
            print("⚠️ [ShareInteraction] 操作失败：shareId 为空")
            #endif
            return
        }

        // 清除之前的错误消息
        errorMessage = nil

        // ✅ 1. 增加全局操作序号（防止竞态）
        operationId += 1
        let currentOp = operationId

        #if DEBUG
        print("🎯 [ShareInteraction] 操作 #\(currentOp): vote to \(targetState)")
        #endif

        // 2. 计算新状态（toggle 逻辑）
        let oldState = voteState
        let newState = oldState.toggled(to: targetState)

        // 3. 乐观更新 UI（立即响应）
        updateLocalState(from: oldState, to: newState)
        isAnimating = true

        // 4. 启动动画（0.5秒后重置）
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            // ✅ 只有当前操作仍然有效时才重置动画
            if currentOp == self.operationId {
                self.isAnimating = false
            }
        }

        // 5. 后台同步到服务器
        Task { @MainActor in
            do {
                let voteType = newState.rawValue  // -1/0/1

                #if DEBUG
                print("📤 [ShareInteraction] 发送请求 #\(currentOp): voteType=\(voteType)")
                #endif

                try await ShareService.shared.voteShare(
                    shareId: shareId,
                    voteType: voteType
                )

                // ✅ 关键：检查这个响应是否已经过期
                guard currentOp == self.operationId else {
                    #if DEBUG
                    print("⏭️ [ShareInteraction] 响应 #\(currentOp) 已过期，丢弃")
                    #endif
                    return
                }

                #if DEBUG
                print("✅ [ShareInteraction] 操作 #\(currentOp) 成功")
                #endif

                // 6. 成功后更新原始值（用于下次比较）
                self.originalVoteState = self.voteState
                self.originalAgreeCount = self.agreeCount
                self.originalNeutralCount = self.neutralCount

                // ✅ 如果投票成功（非取消状态），设置已使用贴纸状态
                if newState != .none {
                    let voteStickerKind: StickerKind = newState == .agree ? .like : .neutral
                    // 使用 StickerDefinition 的 displayName 保持与贴纸列表一致
                    let definition = StickerDefinition.definition(for: voteStickerKind)
                    self.currentUserSticker = UsedStickerInfo(
                        kind: voteStickerKind,
                        name: definition.displayName,
                        iconURL: nil
                    )
                }

                // 7. 通知外层更新
                self.onStateChanged?(shareId, self.voteState, self.agreeCount, self.neutralCount)

            } catch {
                // ✅ 关键：只有最新操作失败才回滚
                guard currentOp == self.operationId else {
                    #if DEBUG
                    print("⏭️ [ShareInteraction] 错误响应 #\(currentOp) 已过期，丢弃")
                    #endif
                    return
                }

                #if DEBUG
                print("❌ [ShareInteraction] 操作 #\(currentOp) 失败: \(error.localizedDescription)")
                #endif

                // 8. 失败时回滚 UI
                await self.rollback(to: oldState)

                // 9. 显示错误提示
                self.errorMessage = "操作失败，请重试"

                // 3秒后自动清除错误消息
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if self.errorMessage == "操作失败，请重试" {
                        self.errorMessage = nil
                    }
                }
            }
        }
    }

    /// ⚠️ 已废弃：更新本地状态（乐观更新）
    /// 此方法保留用于向后兼容旧的 vote(to:) 方法
    private func updateLocalState(from oldState: VoteState, to newState: VoteState) {
        // 先撤销旧状态的计数
        switch oldState {
        case .agree:
            _agreeCount -= 1
        case .neutral:
            _neutralCount -= 1
        case .none:
            break
        }

        // 再应用新状态的计数
        switch newState {
        case .agree:
            _agreeCount += 1
        case .neutral:
            _neutralCount += 1
        case .none:
            break
        }

        // 更新状态
        voteState = newState

        // 重建贴纸统计列表和可见贴纸队列
        rebuildStickerSummaries()
        rebuildVisibleStickerDefinitions()
    }

    /// 重建贴纸统计列表
    /// 从 localStickerCounts 构建 StickerSummaryItem 数组
    /// 调用时机：初始化、贴纸使用后
    /// 注意：统计数据应该从服务器获取，本地只做临时追踪
    private func rebuildStickerSummaries() {
        var items: [StickerSummaryItem] = []

        // ✅ 从本地统计构建（包括投票贴纸和标签贴纸）
        for (kind, count) in localStickerCounts where count > 0 {
            items.append(StickerSummaryItem(kind: kind, count: count))
        }

        // 排序：按 StickerSummaryItem 的 Comparable 实现
        // 规则：count 降序 → priority 降序 → displayName 升序
        stickerSummaries = items.sorted()

        #if DEBUG
        print("📊 [ShareInteraction] 重建贴纸统计:")
        print("   - localStickerCounts: \(localStickerCounts.map { "\($0.key.displayName):\($0.value)" })")
        print("   - summaries: \(stickerSummaries.map { "\($0.displayName)(\($0.count))" })")
        #endif
    }

    // MARK: - 本地贴纸统计（统一追踪）

    /// 本地贴纸统计（包括投票贴纸和标签贴纸）
    /// key: StickerKind, value: 使用次数
    /// 数据来源：从 stickerAvailabilities 的 alreadyApplied 初始化，使用贴纸后更新
    private var localStickerCounts: [StickerKind: Int] {
        var counts: [StickerKind: Int] = [:]

        // 从 stickerAvailabilities 中提取已使用的贴纸统计
        for avail in stickerAvailabilities where avail.alreadyApplied {
            counts[avail.kind, default: 0] += 1
        }

        // 合并本地标签统计（临时追踪，用于刚使用但未刷新的情况）
        for (kind, count) in localTagStickerCounts {
            // 只有当 stickerAvailabilities 中没有该贴纸时才添加
            if counts[kind] == nil {
                counts[kind] = count
            }
        }

        return counts
    }

    /// 回滚到指定状态（已废弃，保留兼容）
    private func rollback(to state: VoteState) async {
        await MainActor.run {
            self.voteState = state
            self._agreeCount = self.originalAgreeCount
            self._neutralCount = self.originalNeutralCount
            self.isAnimating = false

            // 重建贴纸统计列表和可见贴纸队列
            self.rebuildStickerSummaries()
            self.rebuildVisibleStickerDefinitions()

            #if DEBUG
            print("🔄 [ShareInteraction] 回滚: voteState=\(state)")
            #endif
        }
    }

    // MARK: - 贴纸可用性计算

    /// 计算用户可用的贴纸种类
    /// - Parameters:
    ///   - userTaggingAllowance: 用户的 taggingAllowance（从等级获取）
    ///   - activeTagCodes: 后端启用的标签 tagCode 列表（isActive=true，空集合表示全部启用）
    func computeAvailableStickerKinds(
        userTaggingAllowance: Int,
        activeTagCodes: Set<String> = []
    ) {
        // 投票类对所有人开放
        var available: Set<StickerKind> = [.like, .neutral]

        // 有标签权限时，添加启用的标签类贴纸
        if userTaggingAllowance > 0 {
            let activeTagKinds = StickerKind.allCases.filter { kind in
                guard kind.isTagType, let tagCode = kind.tagCode else { return false }
                // 空集合表示全部启用
                return activeTagCodes.isEmpty || activeTagCodes.contains(tagCode)
            }
            available.formUnion(activeTagKinds)
        }

        availableStickerKinds = available

        #if DEBUG
        print("📊 [ShareInteraction] 计算可用贴纸:")
        print("   - taggingAllowance: \(userTaggingAllowance)")
        print("   - available: \(available.map { $0.rawValue })")
        #endif

        // 重建可见贴纸队列
        rebuildVisibleStickerDefinitions()
    }

    /// 使用 UserLevelConfig 计算可用贴纸（便捷方法）
    /// - Parameter levelCode: 用户等级代码（如 "YOMIN", "CHONGLANG" 等）
    func computeAvailableStickerKinds(for levelCode: String?) {
        let allowance = UserLevelConfig.getTaggingAllowance(for: levelCode)
        computeAvailableStickerKinds(userTaggingAllowance: allowance)
    }

    /// 重建可见贴纸队列（应用贴纸使用规则）
    /// 调用时机：初始化、贴纸使用后、权限变化
    ///
    /// 贴纸规则（模拟真实贴纸，贴上就撕不下来）：
    /// - 未使用过贴纸：显示所有可用贴纸
    /// - 已使用过贴纸：所有贴纸队列隐藏（UI 层显示"已使用"状态条）
    /// - 投票贴纸特殊规则：使用一个后，另一个也消失（互斥）
    func rebuildVisibleStickerDefinitions() {
        var visible = availableStickerKinds

        // ✅ 检查是否已使用过任何贴纸
        let hasUsedSticker = currentUserSticker != nil

        // ✅ 检查是否已使用过投票贴纸（基于 stickerAvailabilities 的 alreadyApplied）
        let hasUsedVoteSticker = stickerAvailabilities.contains { avail in
            avail.kind.isVoteType && avail.alreadyApplied
        }

        // ✅ 投票规则：一旦使用投票贴纸，两个投票贴纸都消失
        if hasUsedVoteSticker || (currentUserSticker?.kind.isVoteType == true) {
            visible.remove(.like)
            visible.remove(.neutral)
        }

        // 转换为 StickerDefinition 并按 priority 降序排序
        visibleStickerDefinitions = visible
            .map { StickerDefinition.definition(for: $0) }
            .sorted { $0.priority > $1.priority }

        #if DEBUG
        print("📊 [ShareInteraction] 重建可见贴纸队列:")
        print("   - currentUserSticker: \(currentUserSticker?.name ?? "nil")")
        print("   - hasUsedVoteSticker: \(hasUsedVoteSticker)")
        print("   - available: \(availableStickerKinds.map { $0.rawValue })")
        print("   - visible: \(visible.map { $0.rawValue })")
        print("   - visibleDefinitions: \(visibleStickerDefinitions.map { $0.displayName })")
        #endif
    }

    // MARK: - 贴纸可用性 API 方法

    /// 从服务器加载贴纸可用性列表（带自动重试机制）
    /// - Parameters:
    ///   - shareId: 分享 ID
    ///   - isManualRetry: 是否为用户手动重试（重置重试计数）
    /// - Note: 自动重试 3 次，使用指数退避策略；超过后显示重试按钮
    func loadStickerAvailability(shareId: Int64, isManualRetry: Bool = false) async {
        // 如果是手动重试，重置状态
        let currentRetryCount: Int
        if isManualRetry {
            currentRetryCount = 0
        } else {
            currentRetryCount = stickerLoadingState.currentRetryCount
        }

        // 设置为加载中状态
        stickerLoadingState = .loading
        stickerAvailabilityError = nil

        #if DEBUG
        print("📡 [ShareInteraction] 开始加载贴纸可用性: shareId=\(shareId), retry=\(currentRetryCount)")
        #endif

        do {
            let availabilities = try await ShareService.shared.fetchStickerAvailability(shareId: shareId)

            await MainActor.run {
                self.stickerAvailabilities = availabilities

                // ✅ 修复：先应用贴纸数据，再设置状态为 loaded
                // 这样 SwiftUI 渲染时 visibleStickerDefinitions 已经有值
                // 避免 StickerFieldView 因 stickers.isEmpty 而设置透明度为 0
                self.applyStickerAvailability(availabilities)
                self.stickerLoadingState = .loaded
            }

            #if DEBUG
            print("✅ [ShareInteraction] 贴纸可用性加载成功，共 \(availabilities.count) 条:")
            for avail in availabilities {
                print("   - [\(avail.kind.rawValue)] \(avail.kind.displayName):")
                print("       unlocked=\(avail.unlocked), canUse=\(avail.canUse)")
                print("       alreadyApplied=\(avail.alreadyApplied)")  // ← 关键诊断信息
                print("       dailyLimit=\(avail.dailyLimit?.description ?? "nil"), remainingToday=\(avail.remainingToday?.description ?? "nil")")
            }
            // 统计 alreadyApplied=true 的数量
            let appliedCount = availabilities.filter { $0.alreadyApplied }.count
            print("🔍 [ShareInteraction] alreadyApplied=true 的贴纸数量: \(appliedCount) / \(availabilities.count)")
            #endif

        } catch {
            let newRetryCount = currentRetryCount + 1

            await MainActor.run {
                self.stickerLoadingState = .failed(retryCount: newRetryCount)
                self.stickerAvailabilityError = error.localizedDescription

                #if DEBUG
                print("⚠️ [ShareInteraction] 贴纸可用性加载失败 (第 \(newRetryCount) 次): \(error.localizedDescription)")
                #endif
            }

            // 判断是否需要自动重试
            if newRetryCount < StickerLoadingConfig.maxRetryCount {
                // 使用指数退避策略重试
                let delayMs = StickerLoadingConfig.retryBaseDelayMs * UInt64(1 << (newRetryCount - 1))

                #if DEBUG
                print("🔄 [ShareInteraction] 将在 \(delayMs)ms 后自动重试...")
                #endif

                try? await Task.sleep(nanoseconds: delayMs * 1_000_000)

                // 递归重试（非手动重试，保留重试计数）
                await loadStickerAvailability(shareId: shareId, isManualRetry: false)
            } else {
                // 达到最大重试次数，降级到本地可用性
                await MainActor.run {
                    #if DEBUG
                    print("❌ [ShareInteraction] 达到最大重试次数 (\(StickerLoadingConfig.maxRetryCount))，降级使用本地权限计算")
                    #endif

                    // 降级：使用本地权限计算（投票类贴纸始终可用）
                    self.fallbackToLocalAvailability()

                    // ✅ 关键修复：降级后将状态设为 loaded，让 UI 显示降级后的贴纸
                    self.stickerLoadingState = .loaded
                }
            }
        }
    }

    /// 用户手动重试加载贴纸可用性
    /// - Parameter shareId: 分享 ID
    func retryStickerAvailability(shareId: Int64) async {
        #if DEBUG
        print("🔁 [ShareInteraction] 用户点击重试，重新加载贴纸可用性")
        #endif
        await loadStickerAvailability(shareId: shareId, isManualRetry: true)
    }

    /// 应用服务器返回的贴纸可用性数据
    /// - Parameter availabilities: 贴纸可用性列表
    private func applyStickerAvailability(_ availabilities: [StickerAvailability]) {
        // 从服务器数据构建可用贴纸集合
        // 只包含已解锁且有剩余配额的贴纸
        var available: Set<StickerKind> = []

        // ✅ 重置并重建本地标签统计（基于服务器的 alreadyApplied 数据）
        localTagStickerCounts = [:]

        // ✅ 查找用户是否已对此分享使用过任何贴纸
        var usedSticker: UsedStickerInfo? = nil

        // ✅ 检查是否已使用过投票贴纸
        var hasUsedVoteSticker = false

        for avail in availabilities {
            if avail.canUse {
                available.insert(avail.kind)
            }

            // ✅ 如果贴纸已使用过（alreadyApplied=true）
            if avail.alreadyApplied {
                // 记录已使用的贴纸（只记录第一个，因为每个分享只能用一个贴纸）
                if usedSticker == nil {
                    // 使用 StickerDefinition 的 displayName 保持与贴纸列表一致
                    let definition = StickerDefinition.definition(for: avail.kind)
                    usedSticker = UsedStickerInfo(
                        kind: avail.kind,
                        name: definition.displayName,
                        iconURL: nil  // TODO: 后续从服务器获取 iconURL
                    )
                }

                // ✅ 检查是否使用过投票贴纸
                if avail.kind.isVoteType {
                    hasUsedVoteSticker = true
                }

                // 如果是标签贴纸，添加到本地统计（用于统计看板）
                if avail.kind.isTagType {
                    localTagStickerCounts[avail.kind, default: 0] += 1
                }
            }
        }

        // ✅ 设置已使用贴纸状态
        currentUserSticker = usedSticker

        // ✅ 投票类贴纸处理：
        // - 如果已使用过投票贴纸：两个投票贴纸都不可用（互斥规则）
        // - 如果未使用过：确保两个投票贴纸都可用（投票对所有用户开放）
        if hasUsedVoteSticker {
            available.remove(.like)
            available.remove(.neutral)
        } else {
            available.insert(.like)
            available.insert(.neutral)
        }

        availableStickerKinds = available

        #if DEBUG
        print("📊 [ShareInteraction] 应用服务器可用性:")
        print("   - 服务器返回: \(availabilities.count) 种贴纸")
        print("   - hasUsedVoteSticker: \(hasUsedVoteSticker)")
        print("   - 可用: \(available.map { $0.rawValue })")
        print("   - 已使用的标签: \(localTagStickerCounts.map { "\($0.key.displayName):\($0.value)" })")
        print("   - currentUserSticker: \(usedSticker?.name ?? "nil")")
        #endif

        // 重建可见贴纸队列和统计看板
        rebuildVisibleStickerDefinitions()
        rebuildStickerSummaries()
    }

    /// 降级：使用本地权限计算贴纸可用性
    /// 在服务器 API 不可用时调用
    private func fallbackToLocalAvailability() {
        // 投票类贴纸对所有用户开放
        availableStickerKinds = [.like, .neutral]

        #if DEBUG
        print("📊 [ShareInteraction] 降级到本地可用性: \(availableStickerKinds.map { $0.rawValue })")
        #endif

        // 重建可见贴纸队列
        rebuildVisibleStickerDefinitions()
    }

    /// 获取指定贴纸的可用性信息
    /// - Parameter kind: 贴纸种类
    /// - Returns: 可用性信息，如果服务器未返回则为 nil
    func getAvailability(for kind: StickerKind) -> StickerAvailability? {
        stickerAvailabilities.first { $0.kind == kind }
    }

    // MARK: - 统一贴纸使用方法

    /// 使用贴纸（统一入口）
    /// - Parameter kind: 贴纸种类
    /// - Note: 所有贴纸（包括投票类）统一走 sticker use API
    func useSticker(_ kind: StickerKind) {
        // ✅ 统一使用贴纸 API（不再区分投票类和标签类）
        guard let shareId = currentShareId else {
            #if DEBUG
            print("⚠️ [ShareInteraction] 使用贴纸失败：shareId 为空")
            #endif
            return
        }

        // 检查可用性
        if let availability = getAvailability(for: kind) {
            if !availability.unlocked {
                errorMessage = "\"\(kind.displayName)\"贴纸需要更高等级才能使用"
                clearErrorAfterDelay()
                return
            }
            if availability.isQuotaExhausted {
                errorMessage = "\"\(kind.displayName)\"今日使用次数已达上限"
                clearErrorAfterDelay()
                return
            }
        }

        // 清除之前的错误消息
        errorMessage = nil

        #if DEBUG
        let typeDesc = kind.isVoteType ? "投票" : "标签"
        print("🎯 [ShareInteraction] 使用\(typeDesc)贴纸: \(kind.displayName) (backendId: \(kind.backendId))")
        #endif

        // 后台调用 API
        Task { @MainActor in
            do {
                let response = try await ShareService.shared.useSticker(
                    shareId: shareId,
                    stickerId: kind.backendId
                )

                if response.success {
                    #if DEBUG
                    print("✅ [ShareInteraction] 贴纸使用成功: \(kind.displayName)")
                    print("   - remainingToday: \(response.remainingToday?.description ?? "nil")")
                    #endif

                    // ✅ 设置已使用贴纸状态（立即切换到"已使用"状态条）
                    // 使用 StickerDefinition 的 displayName 保持与贴纸列表一致
                    let definition = StickerDefinition.definition(for: kind)
                    self.currentUserSticker = UsedStickerInfo(
                        kind: kind,
                        name: definition.displayName,
                        iconURL: nil
                    )

                    // ✅ 投票贴纸特殊处理：更新计数和动画
                    if kind.isVoteType {
                        // 触发动画
                        self.isAnimating = true

                        // 乐观更新本地计数（用于 UI 立即响应）
                        if kind == .like {
                            self._agreeCount += 1
                        } else if kind == .neutral {
                            self._neutralCount += 1
                        }

                        // 0.5秒后重置动画状态
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            self.isAnimating = false
                        }
                    }

                    // 重建统计看板（所有贴纸类型都需要）
                    self.rebuildStickerSummaries()

                    // 更新本地可用性数据
                    if let newRemaining = response.remainingToday {
                        self.updateLocalAvailability(for: kind, remainingToday: newRemaining)
                    }
                } else {
                    // 服务器返回失败
                    let errorMsg = response.errorMessage ?? "使用贴纸失败"
                    self.errorMessage = errorMsg
                    self.clearErrorAfterDelay()

                    #if DEBUG
                    print("❌ [ShareInteraction] 贴纸使用失败: \(errorMsg)")
                    #endif
                }

            } catch let error as StickerUseError {
                // 处理已知的贴纸使用错误
                self.errorMessage = error.localizedDescription
                self.clearErrorAfterDelay()

                #if DEBUG
                print("❌ [ShareInteraction] 贴纸使用错误: \(error.localizedDescription)")
                #endif

                // ✅ 特殊处理：STICKER_ALREADY_USED 错误 - 切换到"已使用"状态
                if case .alreadyUsed(let usedKind, let usedName) = error {
                    // 使用服务器返回的已使用贴纸信息
                    if let kind = usedKind {
                        // 使用 StickerDefinition 的 displayName 保持与贴纸列表一致
                        let definition = StickerDefinition.definition(for: kind)
                        self.currentUserSticker = UsedStickerInfo(
                            kind: kind,
                            name: usedName ?? definition.displayName,
                            iconURL: nil
                        )
                    }
                }

            } catch {
                // 网络或其他错误
                self.errorMessage = "网络错误，请稍后重试"
                self.clearErrorAfterDelay()

                #if DEBUG
                print("❌ [ShareInteraction] 贴纸使用网络错误: \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// 更新本地贴纸可用性数据（使用贴纸成功后调用）
    /// - Parameters:
    ///   - kind: 贴纸种类
    ///   - remainingToday: 新的剩余次数
    private func updateLocalAvailability(for kind: StickerKind, remainingToday: Int) {
        // 查找并更新对应的可用性记录
        if let index = stickerAvailabilities.firstIndex(where: { $0.kind == kind }) {
            let old = stickerAvailabilities[index]
            let updated = StickerAvailability(
                kind: old.kind,
                unlocked: old.unlocked,
                dailyLimit: old.dailyLimit,
                usedToday: (old.usedToday ?? 0) + 1,
                remainingToday: remainingToday,
                group: old.group,
                alreadyApplied: true  // ✅ 标记为已对此分享使用过
            )
            stickerAvailabilities[index] = updated

            // ✅ 所有贴纸使用后都从可用列表中移除（每个分享只能用一次贴纸）
            availableStickerKinds.remove(kind)

            // ✅ 投票类贴纸：两个互斥，使用一个后另一个也移除
            if kind.isVoteType {
                availableStickerKinds.remove(.like)
                availableStickerKinds.remove(.neutral)
            }

            rebuildVisibleStickerDefinitions()

            // ✅ 更新本地统计并刷新统计看板
            if kind.isTagType {
                localTagStickerCounts[kind, default: 0] += 1
            }
            rebuildStickerSummaries()

            #if DEBUG
            print("📊 [ShareInteraction] 贴纸已使用，从队列移除: \(kind.displayName)")
            if kind.isTagType {
                print("   - 本地标签统计更新: \(kind.displayName) count=\(localTagStickerCounts[kind] ?? 0)")
            }
            #endif

            #if DEBUG
            print("📊 [ShareInteraction] 更新本地可用性: \(kind.displayName) remaining=\(remainingToday), alreadyApplied=true")
            #endif
        }
    }

    /// 延迟清除错误消息
    private func clearErrorAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.errorMessage != nil {
                self.errorMessage = nil
            }
        }
    }
}
