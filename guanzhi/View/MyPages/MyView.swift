//  
//  MyView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/13.
//

import SwiftUI
import SwiftData
import Combine

struct MyView: View {
    @Environment(\.appState) var appState
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var searchViewModel: SearchViewModel
    @EnvironmentObject var toastManager: ToastManager
    @State private var navigationPathCount: Int = 0
    @State private var isEditAvatarView = false

    // SSOT: 使用 @Query 查询当前用户（自动响应数据变化）
    @Query private var profiles: [UserProfile]

    /// 当前用户 ID（从 OTOLoginStatusManager 获取）
    private var currentUserId: Int {
        OTOLoginStatusManager.shared.getUserID()
    }

    /// 过滤出当前用户的 profile
    private var currentUserProfile: UserProfile? {
        profiles.first { $0.id == currentUserId }
    }

    var body: some View {
        @Bindable var appState = appState

        // 检查用户信息是否已加载
        Group {
            if let profile = currentUserProfile {
                // 转换为展示模型
                let displayModel = profile.toDisplayModel()

                VStack {
                    // 使用统一的 ProfileHeaderView 组件
                    ProfileHeaderView(
                        displayModel: displayModel,
                        mode: .me,
                        cachedAvatarImage: userProfileManager.avatarImage,
                        onAvatarTap: {
                            isEditAvatarView.toggle()
                        },
                        onEditProfileTap: {
                            navigationCoordinator.path.append(Route.editProfileView)
                        },
                        onOneCodeTap: {
                            toastManager.showIfNotPresent(ToastMessages.oneCodeHidden)
                        }
                    )
                    

                    VStack {
                        ShareListView(
                            userId: OTOLoginStatusManager.shared.getUserID(),
                            lat: searchViewModel.region.center.latitude,
                            lon: searchViewModel.region.center.longitude,
                            radius: 10)
                        .environment(\.appState, appState)
                        .environmentObject(searchViewModel)
                        .environmentObject(navigationCoordinator)
                    }
                    
                    Spacer()
                }
            } else {
                // 加载中视图
                VStack {
                    Spacer()
                    ProgressView("加载中...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                }
            }
        }
        .navigationTitle("我的主页")
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
            // 尝试加载缓存的头像
            userProfileManager.loadCachedAvatar()

            // 懒加载用户信息：先从缓存加载，再从服务器刷新
            let userId = OTOLoginStatusManager.shared.getUserID()
            Task {
                await userProfileManager.loadUserProfileWithCache(userId: userId)
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
        .sheet(isPresented: $isEditAvatarView) {
            EditAvatarView()
        }
//        .fullScreenCover(isPresented: $isEditAvatarView) {
//            EditAvatarView()
//        }
    }
    
}

// MARK: - Preview

#Preview("MyView - 带用户数据") {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: UserProfile.self, configurations: config)

        // 插入 mock 数据
        let mockProfile = UserProfile(
            id: 999,
            name: "MockCode",
            nickname: "预览测试昵称",
            phone: "1234567890",
            photo: nil,
            code: nil,
            createDate: nil,
            jpushId: nil,
            titleDOSData: nil,
            levelCode: "CHONGLANG",
            pointsTotal: 100
        )
        container.mainContext.insert(mockProfile)

        let manager = UserProfileManager()

        return AnyView(
            MyView()
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
