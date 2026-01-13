//
//  OnboardingPersistence.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/9.
//

import Foundation

/// 引导状态持久化管理器
///
/// 关键设计（v2.1 修复）：
/// - key 不包含 version，避免版本升级后读不到旧数据
/// - 使用独立的 savedVersion 字段做迁移判定
/// - userId 隔离，不同账号数据独立
/// - 未登录用户使用 -1 作为 guest key
class OnboardingPersistence {

    /// 当前引导版本（修改引导流程时递增）
    /// 升级策略：保留 hasSkippedAll，清空 completedSteps
    static let currentVersion = 1

    // MARK: - Keys

    private var userId: Int {
        let id = OTOLoginStatusManager.shared.getUserID()
        return id > 0 ? id : -1  // 未登录使用 -1 作为 guest key
    }

    /// 【关键修复】key 不包含 version，避免版本升级后读不到旧数据
    private func key(_ field: String) -> String {
        "onboarding_user\(userId)_\(field)"
    }

    // MARK: - Properties

    /// 是否已跳过全部提示
    var hasSkippedAll: Bool {
        get { UserDefaults.standard.bool(forKey: key("skippedAll")) }
        set { UserDefaults.standard.set(newValue, forKey: key("skippedAll")) }
    }

    /// 已完成的步骤集合
    var completedSteps: Set<OnboardingStep> {
        get {
            guard let data = UserDefaults.standard.data(forKey: key("completedSteps")),
                  let steps = try? JSONDecoder().decode(Set<OnboardingStep>.self, from: data)
            else { return [] }
            return steps
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key("completedSteps"))
            }
        }
    }

    /// 【关键修复】独立的版本字段，用于迁移判定
    var savedVersion: Int {
        get { UserDefaults.standard.integer(forKey: key("version")) }
        set { UserDefaults.standard.set(newValue, forKey: key("version")) }
    }

    // MARK: - Migration

    /// 用户登出时调用（清理当前用户数据，保留 guest 数据）
    func clearCurrentUserData() {
        // 只在 userId > 0 时清理，避免清理 guest 数据
        guard userId > 0 else { return }
        UserDefaults.standard.removeObject(forKey: key("skippedAll"))
        UserDefaults.standard.removeObject(forKey: key("completedSteps"))
        UserDefaults.standard.removeObject(forKey: key("version"))
    }
}
