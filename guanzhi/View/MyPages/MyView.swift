//  我的
//  MyView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/13.
//

import SwiftUI
import Combine

struct MyView: View {
    @Environment(\.appState) var appState
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var navigationPathCount: Int = 0

    var body: some View {
        @Bindable var appState = appState

        VStack {
            //name
            HStack(alignment: .center, spacing: Constants.spacingSpacingXs) {
                HStack(alignment: .center, spacing: Constants.iconSizeS) {
                    Image("icon-avatar")
                        .frame(width: Constants.iconSizeXl, height: Constants.iconSizeXl)
                    VStack {
                        // tx/OptionPageTitle
                        Text("一只鸡腿儿")
                            .font(
                                Font.custom("PingFang SC", size: 18)
                                    .weight(.semibold)
                            )
                            .kerning(0.22)
                            .foregroundColor(Color("color-black"))
                        // tx/SecondaryInfo
                        HStack {
                            Text("☠️")
                                .font(Font.custom("PingFang SC", size: 14))
                                .kerning(0.22)
                                .foregroundColor(Color(red: 0.61, green: 0.61, blue: 0.61))
                            Text("Onettoooo")
                                .font(Font.custom("PingFang SC", size: 14))
                                .kerning(0.22)
                                .foregroundColor(Constants.textColorTxGery)
                        }
                    }
                }
                .padding(.horizontal, Constants.iconSizeM)
            }
            .frame(width: 430, alignment: .leading)

            inforView()
            Spacer()
        }
        .navigationBarTitle("我的", displayMode: .inline)
        .navigationBarItems(
            leading:
                Button(action: {
                    // 返回上一层
                    print("返回按钮点击")
                    navigationCoordinator.path.removeLast()
                }) {
                    Image("icon-back")
                }.buttonStyle(ButtonStyle_m()),

            trailing:
                Button(action: {
                    // 导航到 SettingView
                    navigationCoordinator.path.append(Route.settingView)
                }) {
                    Image(systemName: "gear") // 设置图标
                }
        )
        .navigationBarBackButtonHidden(true)
        .onAppear {
            navigationPathCount = navigationCoordinator.path.count
        }
        .onDisappear {
            if navigationCoordinator.path.count < navigationPathCount {
                // 导航路径长度减少，说明返回到了上一层
                appState.isShowingSearchView = true
            }
        }
    }
}

struct MyView_Previews: PreviewProvider {
    static var previews: some View {
        MyView()
            .environment(AppStateModel())
    }
}
