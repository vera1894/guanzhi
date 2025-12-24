//
//  guanzhiApp.swift
//  guanzhi
//
//  Created by Vera on 2024/1/13.
//

import os
import SwiftUI

@main
struct guanzhiApp: App {
    @Environment(\.colorScheme) var colorScheme
    @State var appState = AppStateModel()
    @StateObject var locationManager = LocationManager()
    @StateObject var searchViewModel = SearchViewModel()
    @StateObject var toastManager = ToastManager()
    @StateObject var userProfileManager = UserProfileManager()
    @Namespace private var globalAnimationNamespace
    @StateObject var navigationCoordinator = NavigationCoordinator()

    init() {
        _ = CoordinateConverter.shared
        // 预加载贴纸名称（异步，不阻塞启动）
        StickerNameService.shared.preload()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack{
                //主页面
                NavigationStack(path: $navigationCoordinator.path) {
                    SearchView(
                        animationNamespace: globalAnimationNamespace,
                        userlogin: UserLoginModel()
                    )
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .myView:
                            MyView()
                                .environment(appState)
                                .environmentObject(navigationCoordinator)
                                .environmentObject(userProfileManager)
                                .environmentObject(searchViewModel)
                        case .othersView(let userId):
                           OthersView(userId: userId)
                                .environment(appState)
                                .environmentObject(navigationCoordinator)
                                .environmentObject(userProfileManager)
                                .environmentObject(searchViewModel)
                        case .settingView:
                            SettingView()
                                .environment(appState)
                                .environmentObject(navigationCoordinator)
                                .environmentObject(userProfileManager)
                        case .editProfileView:
                            EditProfileView()
                                .environment(appState)
                                .environmentObject(navigationCoordinator)
                                .environmentObject(userProfileManager)
                        case .shareDetailView(let annotationID):
                            ShareDetailView(searchViewModel: searchViewModel, animationNamespace: globalAnimationNamespace, annotationID: annotationID)
                                .environment(appState)
                                .environmentObject(searchViewModel)
                                .environmentObject(navigationCoordinator)
                                .environmentObject(userProfileManager)
//                                .matchedGeometryEffect(id: "sharedElement\(annotationID)", in: globalAnimationNamespace)
                        case .accountManagementView:
                            AccountManagementView()
                                .environment(appState)
                                .environmentObject(navigationCoordinator)
                                .environmentObject(userProfileManager)
                        }
                    }
                }
                .environment(appState)
                .environmentObject(locationManager)
                .environmentObject(searchViewModel)
                .environmentObject(userProfileManager)
                .environmentObject(navigationCoordinator)
                .modelContainer(for: [Share.self, MediaFile.self, LocalUserProfile.self])
                
                GlobalToastContainerView()
            }
            .environmentObject(toastManager)
            .ignoresSafeArea()
        }
    }
}

/// A global logger for the app.  为应用程序定义一个全局的 logger 实例，用于日志记录
let logger = Logger()
