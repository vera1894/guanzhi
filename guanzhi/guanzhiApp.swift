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

//    @State private var camera: CameraModel?
    
    var body: some Scene {
        WindowGroup {
//            if let camera = camera {
//                SearchView(camera: camera, userlogin: UserLoginModel())
////                CameraView(camera: camera)
////                    .statusBarHidden(true)
//                    .task {
//                        // Start the capture pipeline.
//                        await camera.start()
//                    }
//            } else {
//                Text("Loading camera...")
//                    .task {
//                        self.camera = await CameraModel.create()
//                    }
//            }
//            LogInView(userlogin: OTOLoginStatusManager.shared.userLogin)
//            MessageView(userlogin: UserLoginModel())
//            nameView(userlogin: UserLoginModel())
//            if let appState = appState {
            SearchView(userlogin: UserLoginModel(), /*appState: appState,*/ searchViewModel: SearchViewModel(/*appState: AppStateModel()*/))
                .environment(\.appState, AppStateModel())
//            MainToolbar(camera: PreviewCameraModel(), appState: AppStateModel())
//                    .task {
//                        await appState.create()
//                    }
//            } else {
//                Text("Loading")
//                    .task {
//                        self.appState = await appState?.create()
//                    }
//            }
            
//                .environment(appState)
//            GlobalTest()
//            MapTestView()
//            CaptureView()
//                .preferredColorScheme(.dark) // 设置为夜间模式
        }
    }
}

/// A global logger for the app.  为应用程序定义一个全局的 logger 实例，用于日志记录
let logger = Logger()
