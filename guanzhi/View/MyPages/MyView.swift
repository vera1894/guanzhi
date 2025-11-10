//  
//  MyView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/13.
//

import SwiftUI
import Combine

struct MyView: View {
    @Environment(\.appState) var appState
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var searchViewModel: SearchViewModel
    @EnvironmentObject var toastManager: ToastManager
    @State private var navigationPathCount: Int = 0
    @State private var isEditAvatarView = false
    
    var body: some View {
        @Bindable var appState = appState
        
        // 提前计算头像图片，避免在 ButtonStyle 中进行异步操作
        let avatarImage: Image = {
            if let uiImage = userProfileManager.avatarImage {
                return Image(uiImage: uiImage)
            } else {
                return Image("例子")
            }
        }()

        // 检查用户信息是否已加载
        Group {
            if let localUser = userProfileManager.localUserProfile {
                VStack {
                    HStack(alignment: .center, spacing: Constants.spacingSpacingXs) {
                        // 头像
                        Button(action: {
                            isEditAvatarView.toggle()
                        }) {
                            // 头像-l
                        }
                        .buttonStyle(AvatarStyle_l(
                            isEnabled: true,
                            profileImage: avatarImage,
                            borderThickness: 4
                        ))

                        VStack(alignment: .leading) {
                            Text(localUser.nickname)
                                .font(.headline)
                            // 其他想展示的字段
                            Text("OneCode: \((localUser.name == localUser.phone) ? "⬛️⬛️⬛️⬛️" : (localUser.name ?? "⬛️⬛️⬛️⬛️"))")
                                .font(.subheadline)
                                .onTapGesture {
                                    showNotification(message: "🔏 与手机号相同的OneCode会被隐藏") 
                                }
                        }

                        Spacer()
                        
                        Button(action: {
                            navigationCoordinator.path.append(Route.editProfileView)
                        }) {
                            Text("修改资料")
                        }
                        .buttonStyle(ButtonStyle_capsuleHugPrimary_s(isEnabled: true))
                    }
                    .padding(.horizontal)
                    .padding(.top, Constants.spacingSpacingXs)
                    

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
        .navigationBarTitle("我的主页", displayMode: .inline)
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
            
            // 获取最新用户信息
            let userId = OTOLoginStatusManager.shared.getUserID()
            Task {
                do {
                    try await userProfileManager.fetchUserFullInfo(userId: userId)
                } catch {
                    print("获取本机用户信息失败: \(error)")
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
        .sheet(isPresented: $isEditAvatarView) {
            EditAvatarView()
        }
//        .fullScreenCover(isPresented: $isEditAvatarView) {
//            EditAvatarView()
//        }
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
        toastManager.show(newItem)
    }
}

struct MyView_Previews: PreviewProvider {
    static var previews: some View {
        // 1. 构造一个 UserProfileManager
        let manager = UserProfileManager()
        // 2. 人工创建一个 mock 的 LocalUserProfile
        let mockLocalUser = LocalUserProfile(
            id: 999,
            name: "MockName",
            nickname: "预览测试昵称",
            phone: "1234567890",
            photo: nil,
            code: nil,
            createDate: nil,
            jpushId: nil,
            titleDOS: nil
        )
        // 3. 把它放进 manager
        manager.localUserProfile = mockLocalUser

        // 4. 把 manager 注入到预览环境即可
        return MyView()
            .environment(AppStateModel())
            .environmentObject(NavigationCoordinator())
            .environmentObject(manager)
            .environmentObject(SearchViewModel())
            .environmentObject(ToastManager())
            .previewDisplayName("带有 MockLocalUser 的预览")
    }
}
