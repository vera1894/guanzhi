//
//  SettingView.swift
//  guanzhi
//
//  Created by Vera on 2024/2/24.
//

import SwiftUI

struct SettingView: View {
    @Environment(\.appState) var appState
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var isLoggingout = false
    @State private var showAgreement = false
    
    var items = [
        "账号与绑定",
        "通知设置",
        "用户协议与隐私政策",
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
                    Text(item)
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
        .navigationBarTitle("设置", displayMode: .inline)
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
        case "清理缓存":
            print("清理缓存中...")
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
            .navigationBarTitle("用户协议与隐私政策", displayMode: .inline)
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
                // 加载协议文本
                if let path = Bundle.main.path(forResource: "UserAgreement", ofType: "txt"),
                   let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    agreementText = content
                } else {
                    agreementText = "无法加载用户协议内容"
                }
            }
        }
    }
}

#Preview {
    SettingView()
        .environment(\.appState, AppStateModel())
}
