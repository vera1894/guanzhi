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
        NavigationView {
            List {
                ForEach(items, id: \.self) { item in
                    HStack{
                        Text(item)
                        Spacer()
                        Button(action: {
                               // 添加按钮点击的操作
                               // 这里是自定义按钮的点击操作
                            handleAction(for: item)
                            
                           }) {
                               Image(systemName: "chevron.right")
                                   .imageScale(.small)// 设置箭头图标
                           }
                    }
                    
                    
                }
            }
            .listStyle(PlainListStyle())
        }
        .navigationBarTitle(Text("设置"))
        .alert("提醒", isPresented: $isLoggingout, actions: {
            Button {
                appState.isShowingSearchView = true
                OTOLoginStatusManager.shared.logout()
//                appState.isShowSettingView = false
//                appState.isShowMyView = false
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
//        .onAppear {
////            if appState.isShowingSearchView == true{
//                appState.isShowingSearchView = false
////            }
//        }
    }
    
    // 根据不同的列表项执行操作
    func handleAction(for item: String) {
        switch item {
        case "账号与绑定":
            // 处理 "账号与绑定" 的操作
            print("账号与绑定功能触发")
        case "隐私政策":
            // 打开隐私政策页面
            print("打开隐私政策")
        case "清理缓存":
            // 执行清理缓存的逻辑
            print("清理缓存中...")
        case "退出登录":
            isLoggingout.toggle()
//            OTOLoginStatusManager.shared.logout()
        case "系统版本":
            // 显示系统版本信息
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
