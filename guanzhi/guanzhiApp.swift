//
//  guanzhiApp.swift
//  guanzhi
//
//  Created by Vera on 2024/1/13.
//

import SwiftUI

@main
struct guanzhiApp: App {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some Scene {
        WindowGroup {
            LogInView(userlogin: OTOLoginStatusManager.shared.userLogin)
//            MessageView(userlogin: UserLoginModel())
//            nameView(userlogin: UserLoginModel())
//            SearchView()
//            GlobalTest()
                .preferredColorScheme(.dark) // 设置为夜间模式
        }
    }
}
