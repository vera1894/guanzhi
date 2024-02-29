//  我的
//  MyView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/13.
//

import SwiftUI
import Combine

struct MyView: View {
    @State private var isShowSettingView: Bool = false
    @Environment(\.presentationMode) var presentationMode
    @Binding var isSheetPresented: Bool
    
    var body: some View {
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
                                .foregroundColor(.black)
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
                
                testView()
                Spacer()
            }
            
        }.navigationBarItems(leading:
                                Button(action: {
            // 添加返回按钮点击的操作
            print("按钮点击!!")
            presentationMode.wrappedValue.dismiss()
        }) {
            Image("icon-back")
        }.buttonStyle(ButtonStyle_m()),trailing:
                                Button(action: {
            // 添加按钮点击的操作
            isShowSettingView = true
        }) {
            Image(systemName: "gear") // 设置图标
        }.navigationDestination(isPresented: $isShowSettingView) {
            SettingView()
        }
        )
        .navigationBarBackButtonHidden(true)
//        .navigationBarItems(
//        )
        .onDisappear{
            isSheetPresented = true
        }
        
    }
}

struct MyView_Previews: PreviewProvider {
    static var previews: some View {
        MyView(isSheetPresented: .constant(false))
    }
}
