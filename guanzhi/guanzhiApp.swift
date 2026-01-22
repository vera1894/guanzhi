//
//  guanzhiApp.swift
//  guanzhi
//
//  Created by Vera on 2024/1/13.
//

import os
import SwiftUI
import SwiftData
import UserNotifications

// MARK: - AppDelegate (推送通知处理)

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 设置通知中心代理
        UNUserNotificationCenter.current().delegate = self

        // 检查是否从推送通知冷启动
        if let notification = launchOptions?[.remoteNotification] as? [AnyHashable: Any],
           let deepLink = notification["deepLink"] as? String {
            print("🚀 App 从推送通知冷启动，Deep Link: \(deepLink)")
            DeviceService.shared.cachePendingDeepLink(deepLink)
        }

        return true
    }

    // MARK: - 推送通知注册

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        // 检查是否有旧 token 需要更新
        if let oldToken = DeviceService.shared.getCachedDeviceToken(), oldToken != token {
            Task {
                try? await DeviceService.shared.updateDeviceToken(oldToken: oldToken, newToken: token)
            }
        } else {
            Task {
                try? await DeviceService.shared.registerDevice(deviceToken: token)
            }
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APNs 注册失败: \(error.localizedDescription)")
    }

    // MARK: - 前台收到通知

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("📬 前台收到通知: \(userInfo)")

        // 通知红点管理器刷新未读数
        NotificationCenter.default.post(name: .refreshUnreadBadge, object: nil)

        // 前台显示 Banner、Badge 和 Sound
        completionHandler([.banner, .badge, .sound])
    }

    // MARK: - 点击通知

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 用户点击通知: \(userInfo)")

        if let deepLink = userInfo["deepLink"] as? String, !deepLink.isEmpty {
            print("🔗 处理 Deep Link: \(deepLink)")
            // 发送通知让 App 处理
            NotificationCenter.default.post(
                name: .handleDeepLink,
                object: nil,
                userInfo: ["deepLink": deepLink]
            )
        } else {
            // 没有 deepLink（如系统消息），跳转到消息页面
            print("📬 没有 Deep Link，跳转到消息页面")
            NotificationCenter.default.post(
                name: .openMessagesPage,
                object: nil
            )
        }

        completionHandler()
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let handleDeepLink = Notification.Name("handleDeepLink")
    static let openMessagesPage = Notification.Name("openMessagesPage")
    static let refreshUnreadBadge = Notification.Name("refreshUnreadBadge")
}

// MARK: - Main App

@main
struct guanzhiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.colorScheme) var colorScheme
    @State var appState = AppStateModel()
    @StateObject var locationManager = LocationManager()
    @StateObject var searchViewModel = SearchViewModel()
    @StateObject var toastManager = ToastManager()
    @StateObject var userProfileManager = UserProfileManager()
    @Namespace private var globalAnimationNamespace
    @StateObject var navigationCoordinator = NavigationCoordinator()
    @StateObject var onboardingCoordinator = OnboardingCoordinator()

    init() {
        _ = CoordinateConverter.shared
        // 预加载贴纸名称（异步，不阻塞启动）
        StickerNameService.shared.preload()
        // Gate 检查 #5：确保 NetworkMonitor 单例常驻，App 启动时初始化
        _ = NetworkMonitor.shared
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
                        case .accountManagementView:
                            AccountManagementView()
                                .environment(appState)
                                .environmentObject(navigationCoordinator)
                                .environmentObject(userProfileManager)
                        case .shareComment(let shareId, let commentId):
                            // 从推送通知跳转，传递 commentId 用于高亮定位
                            ShareDetailView(searchViewModel: searchViewModel, animationNamespace: globalAnimationNamespace, annotationID: "\(shareId)", highlightCommentId: commentId)
                                .environment(appState)
                                .environmentObject(searchViewModel)
                                .environmentObject(navigationCoordinator)
                                .environmentObject(userProfileManager)
                        case .messagesView:
                            MessagesView()
                                .environment(appState)
                                .environmentObject(navigationCoordinator)
                                .environmentObject(userProfileManager)
                        case .notificationSettingsView:
                            NotificationSettingsView()
                                .environmentObject(navigationCoordinator)
                        }
                    }
                }
                .environment(appState)
                .environmentObject(locationManager)
                .environmentObject(searchViewModel)
                .environmentObject(userProfileManager)
                .environmentObject(navigationCoordinator)
                .modelContainer(for: [Share.self, MediaFile.self, LocalUserProfile.self, UserProfile.self])

                GlobalToastContainerView()

                // 【Onboarding】统一在 App 根视图挂载 Banner，避免多处重复
                OnboardingBannerView()
                    .environmentObject(onboardingCoordinator)
            }
            .environmentObject(toastManager)
            .environmentObject(onboardingCoordinator)
            .ignoresSafeArea()
            // Deep Link 处理
            .onOpenURL { url in
                handleDeepLink(url)
            }
            // 接收来自推送通知的 Deep Link
            .onReceive(NotificationCenter.default.publisher(for: .handleDeepLink)) { notification in
                if let deepLink = notification.userInfo?["deepLink"] as? String,
                   let url = URL(string: deepLink) {
                    handleDeepLink(url)
                }
            }
            // 接收打开消息页面的通知
            .onReceive(NotificationCenter.default.publisher(for: .openMessagesPage)) { _ in
                openMessagesPage()
            }
            // 处理冷启动时缓存的 Deep Link
            .onAppear {
                // 【Onboarding】注入 appState 引用
                onboardingCoordinator.appState = appState
                // SSOT: 启动时检查，如果未登录则清空缓存（防止残留数据）
                userProfileManager.checkAndClearIfNotLoggedIn()
                handlePendingDeepLink()
                // 触发 NotificationBadgeManager 初始化并刷新未读数
                Task {
                    await NotificationBadgeManager.shared.refresh()
                }
            }
        }
    }

    // MARK: - Deep Link 处理

    private func handleDeepLink(_ url: URL) {
        print("🔗 处理 Deep Link: \(url.absoluteString)")

        guard url.scheme == "guanzhi" else {
            print("⚠️ 未知的 URL Scheme: \(url.scheme ?? "nil")")
            return
        }

        // 检查用户是否已登录
        guard OTOLoginStatusManager.shared.isLoggedIn else {
            print("⚠️ 用户未登录，缓存 Deep Link 待登录后处理")
            DeviceService.shared.cachePendingDeepLink(url.absoluteString)
            return
        }

        // 解析 Deep Link
        // 格式: guanzhi://share/{shareId}/comment/{commentId}
        guard url.host == "share" else {
            print("⚠️ 不支持的 Deep Link host: \(url.host ?? "nil")")
            return
        }

        let pathComponents = url.pathComponents
        // pathComponents: ["/", "{shareId}", "comment", "{commentId}"]

        if pathComponents.count >= 2,
           let shareId = Int64(pathComponents[1]) {

            if pathComponents.count >= 4,
               pathComponents[2] == "comment",
               let commentId = Int64(pathComponents[3]) {
                // 跳转到分享详情并定位评论
                print("📍 导航到分享 \(shareId)，评论 \(commentId)")
                navigationCoordinator.path.append(Route.shareComment(shareId: shareId, commentId: commentId))
            } else {
                // 只跳转到分享详情
                print("📍 导航到分享 \(shareId)")
                navigationCoordinator.path.append(Route.shareDetailView(annotationID: "\(shareId)"))
            }
        }
    }

    /// 处理冷启动时缓存的 Deep Link
    private func handlePendingDeepLink() {
        if let pendingDeepLink = DeviceService.shared.getPendingDeepLink(),
           let url = URL(string: pendingDeepLink) {
            print("🔗 处理冷启动缓存的 Deep Link: \(pendingDeepLink)")
            // 延迟处理，确保 UI 已初始化
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                handleDeepLink(url)
            }
            DeviceService.shared.clearPendingDeepLink()
        }
    }

    /// 打开消息页面
    private func openMessagesPage() {
        // 检查用户是否已登录
        guard OTOLoginStatusManager.shared.isLoggedIn else {
            print("⚠️ 用户未登录，无法打开消息页面")
            return
        }

        print("📬 打开消息页面")
        // 延迟确保 UI 已准备好
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            navigationCoordinator.path.append(Route.messagesView)
        }
    }
}

/// 系统日志实例（用于相机等底层模块，使用 Apple os.Logger API）
let logger = os.Logger()
