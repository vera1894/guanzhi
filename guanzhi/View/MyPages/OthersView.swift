//
//  OthersView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/1/26.
//

import SwiftUI
import Combine

struct OthersView: View {
    @Environment(\.appState) var appState
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var searchViewModel: SearchViewModel
    @State private var navigationPathCount: Int = 0
    
    private var localUser: LocalUserProfile {
        return userProfileManager.localUserProfile!
    }
    
    let userId: Int

    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        @Bindable var appState = appState

        VStack {
            if isLoading {
                Text("加载中...")
            } else if let error = errorMessage {
                Text("错误：\(error)")
            } else if let other = userProfileManager.otherUserProfile,
                      other.id == userId {
                HStack(alignment: .center, spacing: Constants.spacingSpacingXs) {
                    // 头像
                    Button(action: {}) {
                        // 头像-l
                    }
                    .buttonStyle(AvatarStyle_l(
                        isEnabled: true,
                        profileImage: Image("例子"),
                        borderThickness: 4
                    ))

                    VStack(alignment: .leading) {
                        Text(other.nickname ?? "未知用户")
                            .font(.headline)
                        // 其他想展示的字段
//                        Text("OneCode: \(other.code ?? "⬛️⬛️⬛️⬛️")")
//                            .font(.subheadline)
                        Text("OneCode: \((other.name == other.phone) ? "⬛️⬛️⬛️⬛️" : (other.name ?? "⬛️⬛️⬛️⬛️"))")
                            .font(.subheadline)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, Constants.spacingSpacingXs)
                
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
        .navigationBarTitle(userProfileManager.otherUserProfile?.nickname ?? "未知用户", displayMode: .inline)
        .navigationBarItems(
            leading: AnyView(
                Button(action: {
                    // 返回上一层
                    print("返回按钮点击")
                    navigationCoordinator.path.removeLast()
                }) {
                    Image("icon-back")
                }.buttonStyle(ButtonStyle_m())
            ),

            trailing: AnyView(
                Button{ //设置按钮-圆形 导航到 SettingView
                    navigationCoordinator.path.append(Route.settingView)
                }label: {
                    Image("icon-setting")
                }
                .buttonStyle(ButtonStyle_m())
            )
        )
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
}

struct OthersView_Previews: PreviewProvider {
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
        return OthersView(userId: 0)
            .environment(AppStateModel())
            .environmentObject(NavigationCoordinator())
            .environmentObject(manager)
            .environmentObject(SearchViewModel())
            .previewDisplayName("带有 MockLocalUser 的预览")
    }
}

