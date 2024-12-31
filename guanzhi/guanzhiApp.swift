//
//  guanzhiApp.swift
//  guanzhi
//
//  Created by Vera on 2024/1/13.
//

import os
import SwiftUI

@main
struct guanzhiApp: App {
    @Environment(\.colorScheme) var colorScheme
    @State var appState = AppStateModel()
    @StateObject var locationManager = LocationManager()
    @StateObject var searchViewModel = SearchViewModel()
    @StateObject var toastManager = ToastManager()
    init() {
            _ = CoordinateConverter.shared
        }
    
    var body: some Scene {
        WindowGroup {
            ZStack{
                SearchView(userlogin: UserLoginModel())
    //                .environment(\.appState, AppStateModel())
                    .environment(appState)
                    .environmentObject(locationManager)
                    .environmentObject(searchViewModel)
                    .modelContainer(for: [Share.self, MediaFile.self])
    //                .preferredColorScheme(.dark) // 设置为夜间模式
                
                // 顶层：GlobalToastContainerView
                GlobalToastContainerView()
            }
            .environmentObject(toastManager)
            .ignoresSafeArea()
        }
    }
}

/// A global logger for the app.  为应用程序定义一个全局的 logger 实例，用于日志记录
let logger = Logger()
