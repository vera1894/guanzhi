//
//  SettingView.swift
//  guanzhi
//
//  Created by Vera on 2024/2/24.
//

import SwiftUI
import SwiftData

struct SettingView: View {
    @Environment(\.appState) var appState
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var onboardingCoordinator: OnboardingCoordinator
    @EnvironmentObject var searchViewModel: SearchViewModel
    @State private var isLoggingout = false
    @State private var showAgreement = false
    @State private var showResetOnboardingConfirm = false  // 重置操作提示确认
    @State private var showClearCacheConfirm = false  // 清理缓存确认
    @State private var cacheSize: String = ""  // 缓存大小显示
    @EnvironmentObject var toastManager: ToastManager

    var items = [
        "账号与绑定",
        "通知设置",
        "用户协议与隐私政策",
        "操作提示",
        "网络诊断",
        "清理缓存",
        "退出登录",
        "系统版本"
    ]

    // 添加一个计算属性来获取版本信息
    private var versionInfo: String {
        return AppVersionManager.fullVersionInfo
    }

    var body: some View {
        List {
            ForEach(items, id: \.self) { item in
                HStack {
                    Text(LocalizedStringKey(item))
                    Spacer()
                    
                    // 为系统版本项显示版本信息
                    if item == "系统版本" {
                        Text(versionInfo)
                            .foregroundColor(.gray)
                            .font(.footnote)
                    } else {
                        Button(action: {
                            handleAction(for: item)
                        }) {
                            Image(systemName: "chevron.right")
                                .imageScale(.small)
                        }
                    }
                }
            }
        }
//        .listStyle(PlainListStyle())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // 返回上一层
                        navigationCoordinator.path.removeLast()
                    }) {
                        Image("icon-back")
                    }
                    .buttonStyle(ButtonStyle_m())
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // 返回上一层
                        navigationCoordinator.path.removeLast()
                    }) {
                        Image("icon-back")
                    }
                    .buttonStyle(ButtonStyle_m())
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("提醒", isPresented: $isLoggingout, actions: {
            Button {
                // 注销设备推送（异步，不阻塞退出流程）
                Task {
                    await DeviceService.shared.logoutDevice()
                }
                // SSOT: 清空所有用户缓存（账户隔离）
                try? userProfileManager.clearAllUserProfiles()
                appState.isShowingSearchView = true
                OTOLoginStatusManager.shared.logout()
                navigationCoordinator.path = NavigationPath()
            } label: {
                Text("退出登录")
                    .foregroundStyle(Color.red)
            }

            Button(role: .cancel, action: {}) {
                Text("取消")
            }
        }, message: {
            Text("要退出登录吗？")
        })
        .sheet(isPresented: $showAgreement) {
            UserAgreementView()
        }
        .alert("重置操作提示", isPresented: $showResetOnboardingConfirm) {
            Button("重置", role: .destructive) {
                // 先重置状态（清空 completedSteps），再返回主页
                // 这样主页事件触发时状态已经是干净的
                onboardingCoordinator.resetOnboarding()
                // 返回主页
                navigationCoordinator.path = NavigationPath()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("重置后将重新显示新手引导提示")
        }
        .alert("清理缓存", isPresented: $showClearCacheConfirm) {
            Button("清理", role: .destructive) {
                Self.clearCache(modelContext: modelContext)
                // 清除 SearchViewModel 内存缓存并触发重新加载
                searchViewModel.annotations = []
                searchViewModel.cachedResponsedShares = [:]
                searchViewModel.refreshNearbyShares(reason: .manual)
                toastManager.show(ToastMessages.cacheCleared)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("当前缓存大小：\(cacheSize)，确定要清理吗？\n将清除本地缓存的观之数据和媒体文件，重新打开时会从服务器获取最新数据。")
        }
    }

    // MARK: - 缓存管理

    /// 计算目录大小（递归）
    private static func directorySize(at path: String) -> Int64 {
        var size: Int64 = 0
        if let files = FileManager.default.enumerator(atPath: path) {
            while let file = files.nextObject() as? String {
                let fullPath = (path as NSString).appendingPathComponent(file)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                   let fileSize = attrs[.size] as? Int64 {
                    size += fileSize
                }
            }
        }
        return size
    }

    /// 计算缓存大小（URLCache + tmp + 媒体缓存目录）
    static func calculateCacheSize() -> String {
        var totalSize: Int64 = 0
        // URLCache
        totalSize += Int64(URLCache.shared.currentDiskUsage)
        // tmp 目录
        totalSize += directorySize(at: NSTemporaryDirectory())
        // Caches/Thumbnails、Caches/MediaFiles、Caches/Stickers
        if let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            totalSize += directorySize(at: cachesDir.appendingPathComponent("Thumbnails").path)
            totalSize += directorySize(at: cachesDir.appendingPathComponent("MediaFiles").path)
            totalSize += directorySize(at: cachesDir.appendingPathComponent("Stickers").path)
        }
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    /// 清除缓存（含 SwiftData 本地数据库、媒体文件缓存）
    static func clearCache(modelContext: ModelContext? = nil) {
        // 1. 清除 URLCache
        URLCache.shared.removeAllCachedResponses()

        // 2. 清除 tmp 目录
        let tmpDir = NSTemporaryDirectory()
        if let files = try? FileManager.default.contentsOfDirectory(atPath: tmpDir) {
            for file in files {
                let path = (tmpDir as NSString).appendingPathComponent(file)
                try? FileManager.default.removeItem(atPath: path)
            }
        }

        // 3. 清除 Caches/Thumbnails 和 Caches/MediaFiles
        if let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let thumbnailDir = cachesDir.appendingPathComponent("Thumbnails")
            let mediaDir = cachesDir.appendingPathComponent("MediaFiles")
            try? FileManager.default.removeItem(at: thumbnailDir)
            try? FileManager.default.removeItem(at: mediaDir)
        }

        // 4. 清除 SwiftData 中的 Share 和 MediaFile 记录
        if let context = modelContext {
            do {
                try context.delete(model: Share.self)
                try context.delete(model: MediaFile.self)
                try context.save()
            } catch {
                print("⚠️ 清理 SwiftData 缓存失败: \(error)")
            }
        }

        // 5. 清除内存中的图片缓存
        ImageCache.shared.clearAll()

        // 6. 清除贴纸图片资产缓存（磁盘文件 + 元数据 + 纹理缓存）
        StickerAssetService.shared.clearLocalCache()
        StickerTextureCache.shared.clearCache()
    }

    // 根据不同的列表项执行操作
    func handleAction(for item: String) {
        switch item {
        case "账号与绑定":
            navigationCoordinator.path.append(Route.accountManagementView)
        case "通知设置":
            navigationCoordinator.path.append(Route.notificationSettingsView)
        case "用户协议与隐私政策":
            showAgreement = true  // 显示用户协议 sheet
        case "操作提示":
            showResetOnboardingConfirm = true  // 显示重置确认对话框
        case "网络诊断":
            navigationCoordinator.path.append(Route.networkDiagnosticView)
        case "清理缓存":
            cacheSize = Self.calculateCacheSize()
            showClearCacheConfirm = true
        case "退出登录":
            isLoggingout.toggle()
        case "系统版本":
            // 不需要特别的操作，因为版本信息已经显示在列表中
            break
        default:
            break
        }
    }
}

// 新增的用户协议视图
struct UserAgreementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var agreementText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(agreementText)
                        .padding()
                }
            }
            .navigationTitle("用户协议与隐私政策")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            //关闭按钮-圆形
                            dismiss()
                        } label: {
                            Image("icon-close")
                        }
                        .buttonStyle(ButtonStyle_m())
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            //关闭按钮-圆形
                            dismiss()
                        } label: {
                            Image("icon-close")
                        }
                        .buttonStyle(ButtonStyle_m())
                    }
                }
            }
            .onAppear {
                // 根据设备语言选择协议文件
                let fileName = Locale.current.language.languageCode?.identifier == "zh"
                    ? "UserAgreement"
                    : "UserAgreement_en"
                if let path = Bundle.main.path(forResource: fileName, ofType: "txt"),
                   let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    agreementText = content
                } else {
                    agreementText = String(localized: "无法加载用户协议内容")
                }
            }
        }
    }
}

#Preview {
    SettingView()
        .environment(\.appState, AppStateModel())
        .environmentObject(NavigationCoordinator())
        .environmentObject(UserProfileManager())
        .environmentObject(OnboardingCoordinator())
        .environmentObject(SearchViewModel())
}
