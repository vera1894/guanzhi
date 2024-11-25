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
    @State private var isShowSettingView: Bool = false
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var navigationPathCount: Int = 0
    
    var body: some View {
        @Bindable var appState = appState
        NavigationView {
            VStack{
                //name
                HStack(alignment: .center, spacing: Constants.spacingSpacingXs) {
                    HStack(alignment: .center, spacing: Constants.iconSizeS) { Image("icon-avatar")
                            .frame(width: Constants.iconSizeXl, height: Constants.iconSizeXl)
                        VStack{
                            // tx/OptionPageTitle
                            Text("一只鸡腿儿")
                                .font(
                                    Font.custom("PingFang SC", size: 18)
                                        .weight(.semibold)
                                )
                                .kerning(0.22)
                                .foregroundColor(Color("color-black"))
                            // tx/SecondaryInfo
                            HStack{
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
                    // .padding(Constants.spacingSpacingM)
                    .padding(.horizontal, Constants.iconSizeM)
                }
                
                .frame(width: 430, alignment: .leading)
                
                inforView()
                Spacer()
            }
            
        }
        .navigationBarItems(
            leading:
                    Button(action: {
            // 添加返回按钮点击的操作
            print("按钮点击!!")
//            presentationMode.wrappedValue.dismiss()
//            appState.isShowingSearchView = true
//            appState.isShowMyView = false
                        navigationCoordinator.path.removeLast()
        }) {
            Image("icon-back")
        }.buttonStyle(ButtonStyle_m()),
            
            trailing:
                Button(action: {
        // 添加按钮点击的操作
//                appState.isShowSettingView = true
                    navigationCoordinator.path.append(Route.settingView)
                    print(navigationCoordinator.path)
//                    appState.isShowingSearchView = false
        }) {
            Image(systemName: "gear") // 设置图标
        }
//                .navigationDestination(isPresented: $appState.isShowSettingView) {
//            SettingView()
//            
//        }
        )
        
//        .frame(height: 30)
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
//        .navigationBarItems(
//        )
//        .onDisappear{
//            isSheetPresented = true
//        }
        
    }
}

struct MyView_Previews: PreviewProvider {
    static var previews: some View {
        MyView()
            .environment(AppStateModel())
    }
}
