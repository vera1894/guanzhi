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

    /// 当前投票状态（核心状态，所有派生属性基于此）
    @Published var voteState: VoteState = .none

    /// 赞同数
    @Published var agreeCount: Int = 0

    /// 无感数（当前版本不显示，仅同步服务器数据）
    @Published var neutralCount: Int = 0

    /// 动画状态
    @Published var isAnimating: Bool = false

    /// 错误消息
    @Published var errorMessage: String? = nil

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

    /// 是否正在加载贴纸可用性
    @Published var isLoadingStickerAvailability: Bool = false

    /// 贴纸可用性加载错误
    @Published var stickerAvailabilityError: String? = nil

    // MARK: - 标签贴纸本地统计（临时方案）
    // TODO: 后续后端在分享详情中返回标签统计后，用服务器数据替代

    /// 标签贴纸本地统计（当前用户在此分享上使用的标签）
    /// key: StickerKind, value: 使用次数（通常为 1，因为每人每分享只能用一次）
    @Published var localTagStickerCounts: [StickerKind: Int] = [:]

    // MARK: - Computed Properties（派生属性）

    /// 是否已点赞（只读，派生自 voteState）
    var isLiked: Bool { voteState == .agree }

    /// 是否已无感（只读，派生自 voteState）
    var isNeutral: Bool { voteState == .neutral }

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
    ///   - onStateChanged: 状态变化回调 (shareId, voteState, agreeCount, neutralCount)
    func initialize(share: Share, onStateChanged: ((Int64, VoteState, Int, Int) -> Void)? = nil) {
        self.currentShareId = share.id
        self.agreeCount = share.agreeCount
        self.neutralCount = share.neutralCount

        // ✅ 从后端数据恢复状态
        if let userVoteType = share.currentUserVoteType {
            self.voteState = VoteState(rawValue: userVoteType) ?? .none
        } else {
            self.voteState = .none
        }

        self.onStateChanged = onStateChanged

        // 保存原始值，用于失败回滚
        self.originalVoteState = self.voteState
        self.originalAgreeCount = self.agreeCount
        self.originalNeutralCount = self.neutralCount

        // 重置错误和动画状态
        self.errorMessage = nil
        self.isAnimating = false

        // ✅ 重置本地标签统计（切换分享时需要清空）
        self.localTagStickerCounts = [:]

        #if DEBUG
        print("📊 [ShareInteraction] 初始化:")
        print("   - shareId: \(share.id)")
        print("   - share.currentUserVoteType: \(share.currentUserVoteType?.description ?? "nil")")
        print("   - 解析后 voteState: \(voteState)")
        print("   - agreeCount: \(agreeCount)")
        #endif

        // 构建贴纸统计列表
        rebuildStickerSummaries()

        // ✅ 重建可见贴纸队列（应用互斥逻辑）
        // 注意：此时 availableStickerKinds 可能还未计算，但 rebuildVisibleStickerDefinitions 会处理空集合情况
        rebuildVisibleStickerDefinitions()
    }

    // MARK: - Actions

    /// 切换点赞状态（乐观更新 + 后台同步）
    func toggleLike() {
        vote(to: .agree)
    }

    /// 切换无感状态（当前版本不调用，预留接口）
    func toggleNeutral() {
        vote(to: .neutral)
    }

    /// 统一投票入口（供外部调用）
    /// 所有入口（底部贴纸拖动、右侧按钮、顶部展示条）都应该通过这个方法更新
    func setVote(_ targetState: VoteState) {
        vote(to: targetState)
    }

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

    /// 更新本地状态（乐观更新）
    private func updateLocalState(from oldState: VoteState, to newState: VoteState) {
        // 先撤销旧状态的计数
        switch oldState {
        case .agree:
            agreeCount -= 1
        case .neutral:
            neutralCount -= 1
        case .none:
            break
        }

        // 再应用新状态的计数
        switch newState {
        case .agree:
            agreeCount += 1
        case .neutral:
            neutralCount += 1
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
    /// 从当前的 agreeCount / neutralCount / localTagStickerCounts 构建 StickerSummaryItem 数组
    /// 调用时机：初始化、投票状态变化后、使用标签贴纸后
    private func rebuildStickerSummaries() {
        var items: [StickerSummaryItem] = []

        // 添加赞同贴纸统计（如果有）
        if agreeCount > 0 {
            items.append(StickerSummaryItem(kind: .like, count: agreeCount))
        }

        // 添加无感贴纸统计（如果有）
        if neutralCount > 0 {
            items.append(StickerSummaryItem(kind: .neutral, count: neutralCount))
        }

        // ✅ 添加标签贴纸统计（本地追踪）
        // TODO: 后续从后端返回的分享详情中获取全局统计
        for (kind, count) in localTagStickerCounts where count > 0 {
            items.append(StickerSummaryItem(kind: kind, count: count))
        }

        // 排序：按 StickerSummaryItem 的 Comparable 实现
        // 规则：count 降序 → priority 降序 → displayName 升序
        stickerSummaries = items.sorted()

        #if DEBUG
        print("📊 [ShareInteraction] 重建贴纸统计:")
        print("   - agreeCount: \(agreeCount), neutralCount: \(neutralCount)")
        print("   - localTagCounts: \(localTagStickerCounts.map { "\($0.key.displayName):\($0.value)" })")
        print("   - summaries: \(stickerSummaries.map { "\($0.displayName)(\($0.count))" })")
        #endif
    }

    /// 回滚到指定状态
    private func rollback(to state: VoteState) async {
        await MainActor.run {
            self.voteState = state
            self.agreeCount = self.originalAgreeCount
            self.neutralCount = self.originalNeutralCount
            self.isAnimating = false

            // 重建贴纸统计列表和可见贴纸队列
            self.rebuildStickerSummaries()
            self.rebuildVisibleStickerDefinitions()

            #if DEBUG
            print("🔄 [ShareInteraction] 回滚: voteState=\(state), agreeCount=\(agreeCount)")
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

    /// 重建可见贴纸队列（应用互斥逻辑）
    /// 调用时机：初始化、投票状态变化、权限变化
    func rebuildVisibleStickerDefinitions() {
        var visible = availableStickerKinds

        // ✅ 互斥逻辑修正：已选择的贴纸应该隐藏，让用户可以改变选择
        // 用户已投 agree → 移除 like（已选），保留 neutral（可改选）
        // 用户已投 neutral → 移除 neutral（已选），保留 like（可改选）
        if voteState == .agree {
            visible.remove(.like)      // 已点赞，隐藏赞同贴纸
        } else if voteState == .neutral {
            visible.remove(.neutral)   // 已点无感，隐藏无感贴纸
        }

        // 转换为 StickerDefinition 并按 priority 降序排序
        visibleStickerDefinitions = visible
            .map { StickerDefinition.definition(for: $0) }
            .sorted { $0.priority > $1.priority }

        #if DEBUG
        print("📊 [ShareInteraction] 重建可见贴纸队列:")
        print("   - voteState: \(voteState)")
        print("   - available: \(availableStickerKinds.map { $0.rawValue })")
        print("   - visible: \(visibleStickerDefinitions.map { $0.displayName })")
        #endif
    }

    // MARK: - 贴纸可用性 API 方法

    /// 从服务器加载贴纸可用性列表
    /// - Parameter shareId: 分享 ID
    /// - Note: 如果加载失败，会降级使用本地权限计算
    func loadStickerAvailability(shareId: Int64) async {
        isLoadingStickerAvailability = true
        stickerAvailabilityError = nil

        #if DEBUG
        print("📡 [ShareInteraction] 开始加载贴纸可用性: shareId=\(shareId)")
        #endif

        do {
            let availabilities = try await ShareService.shared.fetchStickerAvailability(shareId: shareId)

            await MainActor.run {
                self.stickerAvailabilities = availabilities
                self.isLoadingStickerAvailability = false

                // 应用服务器返回的可用性数据
                self.applyStickerAvailability(availabilities)
            }

            #if DEBUG
            print("✅ [ShareInteraction] 贴纸可用性加载成功，共 \(availabilities.count) 条:")
            for avail in availabilities {
                print("   - [\(avail.kind.rawValue)] \(avail.kind.displayName):")
                print("       unlocked=\(avail.unlocked), canUse=\(avail.canUse)")
                print("       dailyLimit=\(avail.dailyLimit?.description ?? "nil"), remainingToday=\(avail.remainingToday?.description ?? "nil")")
                print("       group=\(avail.group?.rawValue ?? "nil")")
            }
            // 特别检查珍馐是否存在
            if availabilities.contains(where: { $0.kind == .zhenxiu }) {
                print("🔍 [ShareInteraction] ✅ 珍馐贴纸存在于返回列表中")
            } else {
                print("🔍 [ShareInteraction] ⚠️ 珍馐贴纸 **不在** 返回列表中！后端未返回该贴纸。")
            }
            #endif

        } catch {
            await MainActor.run {
                self.isLoadingStickerAvailability = false
                self.stickerAvailabilityError = error.localizedDescription

                #if DEBUG
                print("⚠️ [ShareInteraction] 贴纸可用性加载失败: \(error.localizedDescription)")
                print("   → 降级使用本地权限计算")
                #endif

                // 降级：使用本地权限计算（投票类贴纸始终可用）
                self.fallbackToLocalAvailability()
            }
        }
    }

    /// 应用服务器返回的贴纸可用性数据
    /// - Parameter availabilities: 贴纸可用性列表
    private func applyStickerAvailability(_ availabilities: [StickerAvailability]) {
        // 从服务器数据构建可用贴纸集合
        // 只包含已解锁且有剩余配额的贴纸
        var available: Set<StickerKind> = []

        // ✅ 重置并重建本地标签统计（基于服务器的 alreadyApplied 数据）
        localTagStickerCounts = [:]

        for avail in availabilities {
            if avail.canUse {
                available.insert(avail.kind)
            }

            // ✅ 如果标签贴纸已使用过（alreadyApplied=true），添加到本地统计
            // 这样重新进入分享时也能在统计看板中看到
            if avail.kind.isTagType && avail.alreadyApplied {
                localTagStickerCounts[avail.kind, default: 0] += 1
            }
        }

        // 确保投票类贴纸始终存在（即使服务器未返回）
        // 这是业务规则：投票对所有用户开放
        available.insert(.like)
        available.insert(.neutral)

        availableStickerKinds = available

        #if DEBUG
        print("📊 [ShareInteraction] 应用服务器可用性:")
        print("   - 服务器返回: \(availabilities.count) 种贴纸")
        print("   - 可用: \(available.map { $0.rawValue })")
        print("   - 已使用的标签: \(localTagStickerCounts.map { "\($0.key.displayName):\($0.value)" })")
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
    /// - Note: 投票类贴纸走 vote API，标签类贴纸走 sticker use API
    func useSticker(_ kind: StickerKind) {
        // 投票类贴纸：使用现有的 vote 逻辑
        if let voteState = kind.asVoteState {
            setVote(voteState)
            return
        }

        // 标签类贴纸：使用新的贴纸 API
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
        print("🎯 [ShareInteraction] 使用标签贴纸: \(kind.displayName) (backendId: \(kind.backendId))")
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

            // ✅ 标签类贴纸：使用后从可用列表中移除（每个分享只能用一次）
            // 投票类贴纸不移除（可以切换投票状态）
            if kind.isTagType {
                availableStickerKinds.remove(kind)
                rebuildVisibleStickerDefinitions()

                // ✅ 更新本地标签统计并刷新统计看板
                localTagStickerCounts[kind, default: 0] += 1
                rebuildStickerSummaries()

                #if DEBUG
                print("📊 [ShareInteraction] 标签贴纸已使用，从队列移除: \(kind.displayName)")
                print("   - 本地统计更新: \(kind.displayName) count=\(localTagStickerCounts[kind] ?? 0)")
                #endif
            }

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
