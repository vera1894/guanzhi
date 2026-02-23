//
//  EditProfileView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/2/13.
//


import SwiftUI

struct EditProfileView: View {
    @Environment(\.appState) var appState
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var userProfileManager: UserProfileManager
    
    @State private var isShowEditNameView = false
    @State private var isShowEditOneCodeView = false
    
    var body: some View {
        // 1. 拿到本机用户信息
        let localUser = userProfileManager.localUserProfile
        
        // 2. 列表数据：左侧标题 + 中间的用户信息
        let items: [(label: String, value: String)] = [
            ("名字", localUser?.nickname ?? ""),
            ("OneCode", localUser?.name ?? "")
        ]
        
        List {
            ForEach(items, id: \.label) { item in
                HStack {
                    // 左侧固定文字
                    Text(LocalizedStringKey(item.label))
                    Spacer()

                    // 中间：本机用户资料
                    Text(item.value)
                    
                    // 右侧 chevron 按钮
                    Button {
                        handleAction(label: item.label)
                    } label: {
                        Image(systemName: "chevron.right")
                            .imageScale(.small)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
//        .listStyle(.plain)
        .navigationTitle("编辑资料")
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
        .sheet(isPresented: $isShowEditNameView) {
            EditNameView()
                .environmentObject(userProfileManager)
        }
        .sheet(isPresented: $isShowEditOneCodeView) {
            EditOneCodeView()
                .environmentObject(userProfileManager)
        }
    }
    
    // 根据不同的列表项执行操作
    private func handleAction(label: String) {
        switch label {
        case "名字":
            isShowEditNameView.toggle()
        case "OneCode":
            isShowEditOneCodeView.toggle()
        default:
            break
        }
    }
}

#Preview {
    // 模拟一个 UserProfileManager
    let manager = UserProfileManager()
    // 构造一个 mock 的 LocalUserProfile
    let mockLocalUser = LocalUserProfile(
        id: 999,
        name: "MockOneCode",
        nickname: "MockNickname",
        phone: "1234567890",
        photo: nil,
        code: nil,
        createDate: nil,
        jpushId: nil,
        titleDOS: nil
    )
    manager.localUserProfile = mockLocalUser
    
    return NavigationView {
        EditProfileView()
            .environment(AppStateModel())
            .environmentObject(NavigationCoordinator())
            .environmentObject(manager)
    }
}
