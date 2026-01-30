//
//  ShareInteractionViewModel.swift
//  guanzhi
//
//  Created by Claude Code on 2025/11/27.
//

import Foundation
import Combine

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

    /// 便捷初始化（使用动态名称）
    init(kind: StickerKind, name: String? = nil, iconURL: URL? = nil) {
        self.kind = kind
        self.name = name ?? kind.dynamicDisplayName  // 使用动态名称
        self.iconURL = iconURL
    }
}

/// 分享互动 ViewModel
///
/// 关键特性：
/// - 统一贴纸系统：所有贴纸（包括赞同/无感）都使用标签系统
/// - 乐观更新：立即响应用户操作，后台同步服务器
/// - 竞态保护：通过全局唯一 operationId 确保只有最后一次操作生效
/// - 失败回滚：网络错误时恢复原始状态
@MainActor
class ShareInteractionViewModel: ObservableObject {
    // MARK: - Published State

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

    /// 是否显示贴纸面板（底部贴纸队列或已使用状态）
    @Published var isStickerPanelVisible: Bool = false

    /// 用户可用的贴纸种类（基于权限，已过滤 isActive）
    @Published var availableStickerKinds: Set<StickerKind> = []

    /// 当前应显示的贴纸队列定义
    @Published var visibleStickerDefinitions: [StickerDefinition] = []

    // MARK: - Sticker Availability State (服务器驱动)

    /// 贴纸可用性列表（从服务器加载）
    @Published var stickerAvailabilities: [StickerAvailability] = []

    /// 贴纸加载状态（统一状态管理）
    @Published var stickerLoadingState: StickerLoadingState = .idle

    /// 贴纸可用性加载错误信息（用于显示）
    @Published var stickerAvailabilityError: String? = nil

    // MARK: - Computed Properties for Loading State

    /// 是否正在加载贴纸可用性
    var isLoadingStickerAvailability: Bool {
        stickerLoadingState == .loading
    }

    /// 是否加载失败且需要显示重试按钮
    var shouldShowStickerRetryButton: Bool {
        stickerLoadingState.shouldShowRetryButton
    }

    // MARK: - 本地贴纸统计

    /// 贴纸本地统计（当前用户在此分享上使用的贴纸）
    /// key: StickerKind, value: 使用次数（通常为 1，因为每人每分享只能用一次）
    @Published var localStickerCounts: [StickerKind: Int] = [:]

    // MARK: - Computed Properties（派生属性）

    /// 是否已使用赞同贴纸
    var isLiked: Bool {
        currentUserSticker?.kind == .like
    }

    /// 是否已使用无感贴纸
    var isNeutral: Bool {
        currentUserSticker?.kind == .neutral
    }

    /// 赞同数（从贴纸统计获取）
    var agreeCount: Int {
        stickerSummaries.first(where: { $0.kind == .like })?.count ?? 0
    }

    /// 无感数（从贴纸统计获取）
    var neutralCount: Int {
        stickerSummaries.first(where: { $0.kind == .neutral })?.count ?? 0
    }

    // MARK: - Private State

    private var currentShareId: Int64?

    /// 全局唯一的操作序号（防止竞态）
    private var operationId: Int = 0

    // MARK: - Initialization

    /// 初始化状态（从 Share 对象加载）
    /// - Parameter share: 分享对象
    func initialize(share: Share) {
        self.currentShareId = share.id

        // 重置所有状态（所有状态都将从 loadStickerAvailability API 获取）
        self.errorMessage = nil
        self.isAnimating = false
        self.localStickerCounts = [:]
        self.currentUserSticker = nil
        self.stickerSummaries = []
        self.isStickerPanelVisible = false

        #if DEBUG
        print("📊 [ShareInteraction] 初始化:")
        print("   - shareId: \(share.id)")
        print("   - 所有状态已重置，等待从贴纸 API 加载")
        #endif

        // 重建可见贴纸队列
        rebuildVisibleStickerDefinitions()
    }

    // MARK: - Actions

    /// 切换贴纸面板显示状态
    func toggleStickerPanel() {
        isStickerPanelVisible.toggle()
    }

    /// 使用赞同贴纸
    func toggleLike() {
        useSticker(.like)
    }

    /// 使用无感贴纸
    func toggleNeutral() {
        useSticker(.neutral)
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
        var available: Set<StickerKind> = []

        // 所有启用的贴纸都可用（基于配额）
        let activeKinds = StickerKind.allCases.filter { kind in
            // 空集合表示全部启用
            return activeTagCodes.isEmpty || activeTagCodes.contains(kind.tagCode)
        }
        available.formUnion(activeKinds)

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

    /// 重建可见贴纸队列
    /// 调用时机：初始化、贴纸使用后、权限变化
    ///
    /// 贴纸规则（模拟真实贴纸，贴上就撕不下来）：
    /// - 未使用过贴纸：显示所有可用贴纸
    /// - 已使用过贴纸：该贴纸从队列中移除
    func rebuildVisibleStickerDefinitions() {
        var visible = availableStickerKinds

        // 移除已使用的贴纸
        for avail in stickerAvailabilities where avail.alreadyApplied {
            visible.remove(avail.kind)
        }

        // 转换为 StickerDefinition 并按 priority 降序排序
        visibleStickerDefinitions = visible
            .map { StickerDefinition.definition(for: $0) }
            .sorted { $0.priority > $1.priority }

        #if DEBUG
        print("📊 [ShareInteraction] 重建可见贴纸队列:")
        print("   - currentUserSticker: \(currentUserSticker?.name ?? "nil")")
        print("   - available: \(availableStickerKinds.map { $0.rawValue })")
        print("   - visible: \(visible.map { $0.rawValue })")
        print("   - visibleDefinitions: \(visibleStickerDefinitions.map { $0.displayName })")
        #endif
    }

    /// 重建贴纸统计列表
    /// 从 localStickerCounts 构建 StickerSummaryItem 数组
    private func rebuildStickerSummaries() {
        var items: [StickerSummaryItem] = []

        // 从本地统计构建
        for (kind, count) in computedStickerCounts where count > 0 {
            items.append(StickerSummaryItem(kind: kind, count: count))
        }

        // 排序：按 StickerSummaryItem 的 Comparable 实现
        stickerSummaries = items.sorted()

        #if DEBUG
        print("📊 [ShareInteraction] 重建贴纸统计:")
        print("   - summaries: \(stickerSummaries.map { "\($0.displayName)(\($0.count))" })")
        #endif
    }

    /// 本地贴纸统计（合并 stickerAvailabilities 和 localStickerCounts）
    private var computedStickerCounts: [StickerKind: Int] {
        var counts: [StickerKind: Int] = [:]

        // 从 stickerAvailabilities 中提取已使用的贴纸统计
        for avail in stickerAvailabilities where avail.alreadyApplied {
            counts[avail.kind, default: 0] += 1
        }

        // 合并本地统计（临时追踪，用于刚使用但未刷新的情况）
        for (kind, count) in localStickerCounts {
            if counts[kind] == nil {
                counts[kind] = count
            }
        }

        return counts
    }

    // MARK: - 贴纸可用性 API 方法

    /// 从服务器加载贴纸可用性列表（带自动重试机制）
    /// - Parameters:
    ///   - shareId: 分享 ID
    ///   - isManualRetry: 是否为用户手动重试（重置重试计数）
    func loadStickerAvailability(shareId: Int64, isManualRetry: Bool = false) async {
        let currentRetryCount: Int
        if isManualRetry {
            currentRetryCount = 0
        } else {
            currentRetryCount = stickerLoadingState.currentRetryCount
        }

        stickerLoadingState = .loading
        stickerAvailabilityError = nil

        #if DEBUG
        print("📡 [ShareInteraction] 开始加载贴纸可用性: shareId=\(shareId), retry=\(currentRetryCount)")
        #endif

        do {
            let result = try await ShareService.shared.fetchStickerAvailability(shareId: shareId)

            await MainActor.run {
                // 应用贴纸可用性
                self.stickerAvailabilities = result.availabilities
                self.applyStickerAvailability(result.availabilities)

                // 应用服务器返回的贴纸统计（优先于本地计算）
                self.stickerSummaries = result.summaries

                // 应用当前用户已使用的贴纸
                if let current = result.currentUserSticker {
                    self.currentUserSticker = current
                }

                self.stickerLoadingState = .loaded
            }

            #if DEBUG
            print("✅ [ShareInteraction] 贴纸可用性加载成功:")
            print("   - availabilities: \(result.availabilities.count) 条")
            print("   - summaries: \(result.summaries.count) 条")
            for summary in result.summaries {
                print("       [\(summary.kind.rawValue)] \(summary.displayName): \(summary.count)")
            }
            if let current = result.currentUserSticker {
                print("   - currentUserSticker: \(current.kind.rawValue) (\(current.name))")
            } else {
                print("   - currentUserSticker: nil")
            }
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

            if newRetryCount < StickerLoadingConfig.maxRetryCount {
                let delayMs = StickerLoadingConfig.retryBaseDelayMs * UInt64(1 << (newRetryCount - 1))

                #if DEBUG
                print("🔄 [ShareInteraction] 将在 \(delayMs)ms 后自动重试...")
                #endif

                try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
                await loadStickerAvailability(shareId: shareId, isManualRetry: false)
            } else {
                await MainActor.run {
                    #if DEBUG
                    print("❌ [ShareInteraction] 达到最大重试次数，保持失败状态供用户手动重试")
                    #endif
                    // 保持 .failed 状态，让 UI 显示错误提示和重试按钮
                    // 不再自动降级为 .loaded，避免用户无法感知加载失败
                    self.stickerLoadingState = .failed(retryCount: newRetryCount)
                }
            }
        }
    }

    /// 用户手动重试加载贴纸可用性
    func retryStickerAvailability(shareId: Int64) async {
        #if DEBUG
        print("🔁 [ShareInteraction] 用户点击重试，重新加载贴纸可用性")
        #endif
        await loadStickerAvailability(shareId: shareId, isManualRetry: true)
    }

    /// 应用服务器返回的贴纸可用性数据
    private func applyStickerAvailability(_ availabilities: [StickerAvailability]) {
        var available: Set<StickerKind> = []
        localStickerCounts = [:]
        var usedSticker: UsedStickerInfo? = nil

        for avail in availabilities {
            if avail.canUse {
                available.insert(avail.kind)
            }

            if avail.alreadyApplied {
                if usedSticker == nil {
                    let definition = StickerDefinition.definition(for: avail.kind)
                    usedSticker = UsedStickerInfo(
                        kind: avail.kind,
                        name: definition.dynamicDisplayName,  // 使用动态名称
                        iconURL: nil
                    )
                }
                localStickerCounts[avail.kind, default: 0] += 1
            }
        }

        currentUserSticker = usedSticker
        availableStickerKinds = available

        #if DEBUG
        print("📊 [ShareInteraction] 应用服务器可用性:")
        print("   - 服务器返回: \(availabilities.count) 种贴纸")
        print("   - 可用: \(available.map { $0.rawValue })")
        print("   - currentUserSticker: \(usedSticker?.name ?? "nil")")
        #endif

        rebuildVisibleStickerDefinitions()
        rebuildStickerSummaries()
    }

    /// 降级：使用本地权限计算贴纸可用性
    private func fallbackToLocalAvailability() {
        // 所有贴纸都开放（配额由服务器控制）
        availableStickerKinds = Set(StickerKind.allCases)

        #if DEBUG
        print("📊 [ShareInteraction] 降级到本地可用性: \(availableStickerKinds.map { $0.rawValue })")
        #endif

        rebuildVisibleStickerDefinitions()
    }

    /// 获取指定贴纸的可用性信息
    func getAvailability(for kind: StickerKind) -> StickerAvailability? {
        stickerAvailabilities.first { $0.kind == kind }
    }

    // MARK: - 统一贴纸使用方法

    /// 使用贴纸（统一入口）
    /// - Parameter kind: 贴纸种类
    func useSticker(_ kind: StickerKind) {
        guard let shareId = currentShareId else {
            #if DEBUG
            print("⚠️ [ShareInteraction] 使用贴纸失败：shareId 为空")
            #endif
            return
        }

        // 检查可用性
        if let availability = getAvailability(for: kind) {
            if !availability.unlocked {
                errorMessage = "\"\(kind.dynamicDisplayName)\"贴纸需要更高等级才能使用"
                clearErrorAfterDelay()
                return
            }
            if availability.isQuotaExhausted {
                errorMessage = "\"\(kind.dynamicDisplayName)\"今日使用次数已达上限"
                clearErrorAfterDelay()
                return
            }
        }

        errorMessage = nil

        #if DEBUG
        print("🎯 [ShareInteraction] 使用贴纸: \(kind.displayName) (backendId: \(kind.backendId))")
        #endif

        Task { @MainActor in
            do {
                let response = try await ShareService.shared.useSticker(
                    shareId: shareId,
                    stickerId: kind.backendId
                )

                if response.success {
                    #if DEBUG
                    print("✅ [ShareInteraction] 贴纸使用成功: \(kind.displayName)")
                    #endif

                    // 设置已使用贴纸状态
                    let definition = StickerDefinition.definition(for: kind)
                    self.currentUserSticker = UsedStickerInfo(
                        kind: kind,
                        name: definition.dynamicDisplayName,  // 使用动态名称
                        iconURL: nil
                    )

                    // 触发动画
                    self.isAnimating = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        self.isAnimating = false
                    }

                    // 更新统计和可用性
                    self.rebuildStickerSummaries()
                    if let newRemaining = response.remainingToday {
                        self.updateLocalAvailability(for: kind, remainingToday: newRemaining)
                    }
                } else {
                    let errorMsg = response.errorMessage ?? "使用贴纸失败"
                    self.errorMessage = errorMsg
                    self.clearErrorAfterDelay()

                    #if DEBUG
                    print("❌ [ShareInteraction] 贴纸使用失败: \(errorMsg)")
                    #endif
                }

            } catch let error as StickerUseError {
                self.errorMessage = error.localizedDescription
                self.clearErrorAfterDelay()

                #if DEBUG
                print("❌ [ShareInteraction] 贴纸使用错误: \(error.localizedDescription)")
                #endif

                if case .alreadyUsed(let usedKind, let usedName) = error {
                    if let kind = usedKind {
                        let definition = StickerDefinition.definition(for: kind)
                        self.currentUserSticker = UsedStickerInfo(
                            kind: kind,
                            name: usedName ?? definition.dynamicDisplayName,  // 使用动态名称
                            iconURL: nil
                        )
                    }
                }

            } catch {
                self.errorMessage = "网络错误，请稍后重试"
                self.clearErrorAfterDelay()

                #if DEBUG
                print("❌ [ShareInteraction] 贴纸使用网络错误: \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// 更新本地贴纸可用性数据
    private func updateLocalAvailability(for kind: StickerKind, remainingToday: Int) {
        if let index = stickerAvailabilities.firstIndex(where: { $0.kind == kind }) {
            let old = stickerAvailabilities[index]
            let updated = StickerAvailability(
                kind: old.kind,
                unlocked: old.unlocked,
                dailyLimit: old.dailyLimit,
                usedToday: (old.usedToday ?? 0) + 1,
                remainingToday: remainingToday,
                group: old.group,
                alreadyApplied: true
            )
            stickerAvailabilities[index] = updated

            availableStickerKinds.remove(kind)
            rebuildVisibleStickerDefinitions()

            localStickerCounts[kind, default: 0] += 1
            rebuildStickerSummaries()

            #if DEBUG
            print("📊 [ShareInteraction] 贴纸已使用，从队列移除: \(kind.displayName)")
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
