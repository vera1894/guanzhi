//
//  SettingView.swift
//  guanzhi
//
//  Created by Vera on 2024/2/24.
//

import SwiftUI

struct SettingView: View {
    var items = ["账号与绑定", "隐私政策", "清理缓存","退出登录","系统版本"]

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
                                               }) {
                                                   Image(systemName: "chevron.right")
                                                       .imageScale(.small)// 设置箭头图标
                                               }
                        }
                        
                        
                    }
                }.listStyle(PlainListStyle())
            }.navigationBarTitle(Text("设置"))
        }
}

#Preview {
    SettingView()
}
