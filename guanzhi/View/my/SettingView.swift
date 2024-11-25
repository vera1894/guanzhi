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

    var items = [
        "账号与绑定",
        "隐私政策",
        "清理缓存",
        "退出登录",
        "系统版本"
    ]

    var body: some View {
        List {
            ForEach(items, id: \.self) { item in
                HStack {
                    Text(item)
                    Spacer()
                    Button(action: {
                        // 添加按钮点击的操作
                        handleAction(for: item)
                    }) {
                        Image(systemName: "chevron.right")
                            .imageScale(.small) // 设置箭头图标
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .navigationBarTitle("设置", displayMode: .inline)
        .navigationBarItems(
            leading:
                Button(action: {
                    // 返回上一层
                    navigationCoordinator.path.removeLast()
                }) {
                    Image("icon-back")
                }.buttonStyle(ButtonStyle_m())
        )
        .navigationBarBackButtonHidden(true)
        .alert("提醒", isPresented: $isLoggingout, actions: {
            Button {
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
    }

    // 根据不同的列表项执行操作
    func handleAction(for item: String) {
        switch item {
        case "账号与绑定":
            print("账号与绑定功能触发")
        case "隐私政策":
            print("打开隐私政策")
        case "清理缓存":
            print("清理缓存中...")
        case "退出登录":
            isLoggingout.toggle()
        case "系统版本":
            print("当前系统版本为 iOS 17.0")
        default:
            break
        }
    }
}

#Preview {
    SettingView()
        .environment(\.appState, AppStateModel())
}
