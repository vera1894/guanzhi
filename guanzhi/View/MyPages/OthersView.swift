//
//  OthersView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/1/26.
//

import SwiftUI
import SwiftData
import Combine
import UIKit

struct OthersView: View {
    @Environment(\.appState) var appState
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var searchViewModel: SearchViewModel
    @EnvironmentObject var toastManager: ToastManager
    @State private var navigationPathCount: Int = 0

    let userId: Int

    @State private var isLoading: Bool = true  // 初始为 true，防止显示"无数据"
    @State private var errorMessage: String?

    // SSOT: 使用 @Query 查询用户（自动响应数据变化）
    @Query private var profiles: [UserProfile]

    /// 过滤出目标用户的 profile
    private var targetUserProfile: UserProfile? {
        profiles.first { $0.id == userId }
    }

    var body: some View {
        @Bindable var appState = appState

        VStack {
            // 调试日志
            let _ = print("🔍 [OthersView] isLoading=\(isLoading), profiles.count=\(profiles.count), targetUserProfile=\(targetUserProfile?.id ?? -1)")

            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("加载中...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                }
            } else if let error = errorMessage {
                Text("错误：\(error)")
            } else if let profile = targetUserProfile {
                // SSOT 路径：从 @Query 获取数据
                let displayModel = profile.toDisplayModel()

                ProfileHeaderView(
                    displayModel: displayModel,
                    mode: .other,
                    cachedAvatarImage: nil,
                    onOneCodeTap: {
                        toastManager.showIfNotPresent(ToastMessages.oneCodeHidden)
                    }
                )

                VStack {
                    ShareListView(
                        userId: profile.id,
                        lat: searchViewModel.region.center.latitude,
                        lon: searchViewModel.region.center.longitude,
                        radius: 10)
                    .environment(\.appState, appState)
                    .environmentObject(searchViewModel)
                    .environmentObject(navigationCoordinator)
                }

                Spacer()
            } else if let other = userProfileManager.otherUserProfile, other.id == userId {
                // 回退路径：@Query 暂时没数据时，使用内存中的 otherUserProfile
                let _ = print("⚠️ [OthersView] 使用回退路径 otherUserProfile")

                // 手动构建展示模型
                let masked = (other.name == other.phone) || (other.name == nil) || (other.name?.isEmpty == true)
                let displayModel = UserProfileDisplayModel(
                    id: other.id,
                    displayNickname: other.nickname ?? String(localized: "未知用户"),
                    displayOneCode: masked ? "⬛️⬛️⬛️⬛️" : (other.name ?? "⬛️⬛️⬛️⬛️"),
                    isOneCodeMasked: masked,
                    avatarPath: other.photo,
                    levelName: UserLevelMapping.getName(for: other.levelCode),
                    titleDOS: other.titleDOS
                )

                ProfileHeaderView(
                    displayModel: displayModel,
                    mode: .other,
                    cachedAvatarImage: nil,
                    onOneCodeTap: {
                        toastManager.showIfNotPresent(ToastMessages.oneCodeHidden)
                    }
                )

                VStack {
                    ShareListView(
                        userId: other.id,
                        lat: searchViewModel.region.center.latitude,
                        lon: searchViewModel.region.center.longitude,
                        radius: 10)
                    .environment(\.appState, appState)
                    .environmentObject(searchViewModel)
                    .environmentObject(navigationCoordinator)
                }

                Spacer()
            } else {
                Text("无数据")
            }
            
        }
        .navigationTitle(targetUserProfile?.nickname ?? String(localized: "未知用户"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // 返回上一层
                        print("返回按钮点击")
                        navigationCoordinator.path.removeLast()
                    }) {
                        Image("icon-back")
                    }
                    .buttonStyle(ButtonStyle_m())
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // 更多按钮 - 显示举报等操作
                        showMoreActions()
                    } label: {
                        Image("icon-more")
                    }
                    .buttonStyle(ButtonStyle_m())
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // 返回上一层
                        print("返回按钮点击")
                        navigationCoordinator.path.removeLast()
                    }) {
                        Image("icon-back")
                    }
                    .buttonStyle(ButtonStyle_m())
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // 更多按钮 - 显示举报等操作
                        showMoreActions()
                    } label: {
                        Image("icon-more")
                    }
                    .buttonStyle(ButtonStyle_m())
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            navigationPathCount = navigationCoordinator.path.count
            Task {
                do {
                    isLoading = true
                    try await userProfileManager.fetchUserFullInfo(userId: userId)
                    isLoading = false
                } catch {
                    isLoading = false
                    errorMessage = "\(error)"
                }
            }
        }
        .onDisappear {
            // ✅ 修复：检查是否需要恢复聚合列表
            // 如果 shouldRestoreClusterList 为 true，说明正在从详情页返回聚合列表
            // 此时不应设置 isShowingSearchView = true，否则会覆盖聚合列表的恢复逻辑
            if navigationCoordinator.path.isEmpty && !appState.shouldRestoreClusterList {
                appState.isShowingSearchView = true
            }
        }
    }

    // MARK: - 更多操作

    /// 显示更多操作 ActionSheet（举报用户）
    private func showMoreActions() {
        let alert = UIAlertController(title: String(localized: "更多操作"), message: nil, preferredStyle: .actionSheet)

        // 举报用户按钮
        alert.addAction(UIAlertAction(title: String(localized: "举报用户"), style: .default) { _ in
            // 显示举报功能即将上线提示
            Self.showComingSoonAlert(
                title: String(localized: "举报功能即将上线"),
                message: String(localized: "感谢您的反馈，我们正在完善此功能。如遇紧急情况，请通过「我的 - 设置 - 意见反馈」联系我们。")
            )
        })

        // 取消按钮
        alert.addAction(UIAlertAction(title: String(localized: "取消"), style: .cancel))

        // 展示弹窗
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                // 找到最顶层的 presented view controller
                var topController = rootViewController
                while let presented = topController.presentedViewController {
                    topController = presented
                }
                topController.present(alert, animated: true)
            }
        }
    }

    /// 显示"即将上线"提示弹窗
    private static func showComingSoonAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "知道了"), style: .default))

        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                var topController = rootViewController
                while let presented = topController.presentedViewController {
                    topController = presented
                }
                topController.present(alert, animated: true)
            }
        }
    }
}

// MARK: - Preview

#Preview("OthersView - 带用户数据") {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: UserProfile.self, configurations: config)

        // 插入 mock 数据（他人用户）
        let mockProfile = UserProfile(
            id: 123,
            name: "OtherCode",
            nickname: "他人昵称",
            phone: "9876543210",
            photo: nil,
            code: nil,
            createDate: nil,
            jpushId: nil,
            titleDOSData: nil,
            levelCode: "DENGTA",
            pointsTotal: 500
        )
        container.mainContext.insert(mockProfile)

        let manager = UserProfileManager()

        return AnyView(
            OthersView(userId: 123)
                .modelContainer(container)
                .environment(AppStateModel())
                .environmentObject(NavigationCoordinator())
                .environmentObject(manager)
                .environmentObject(SearchViewModel())
                .environmentObject(ToastManager())
        )
    } catch {
        return AnyView(
            Text("Preview 初始化失败: \(error.localizedDescription)")
                .foregroundColor(.red)
                .padding()
        )
    }
}

