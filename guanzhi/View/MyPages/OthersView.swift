//
//  OthersView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/1/26.
//

import SwiftUI
import SwiftData
import Combine

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
                        showNotification(message: "🔏 与手机号相同的OneCode会被隐藏")
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
                    displayNickname: other.nickname ?? "未知用户",
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
                        showNotification(message: "🔏 与手机号相同的OneCode会被隐藏")
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
        .navigationBarTitle(targetUserProfile?.nickname ?? "未知用户", displayMode: .inline)
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
                        //设置按钮-圆形 导航到 SettingView
                        navigationCoordinator.path.append(Route.settingView)
                    } label: {
                        Image("icon-setting")
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
                        //设置按钮-圆形 导航到 SettingView
                        navigationCoordinator.path.append(Route.settingView)
                    } label: {
                        Image("icon-setting")
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
//            if navigationCoordinator.path.count < navigationPathCount {
//                // 导航路径长度减少，说明返回到了上一层
//                appState.isShowingSearchView = true
//            }
            if navigationCoordinator.path.isEmpty {
                appState.isShowingSearchView = true
            }
        }
    }

    private func showNotification(message: String) {
        let newItem = ToastItem(style: .notificationOnly(
            title: message,
            symbol: "",
            tint: Color("color-primary"),
            isUserInteractionEnabled: true,
            timing: .short,
            isAutoClose: true
        ))
        toastManager.showIfNotPresent(newItem)
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

