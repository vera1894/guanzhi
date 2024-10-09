//
//  CameraViewWrapper.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/9/30.
//

import SwiftUI

struct CameraViewWrapper/*<AppStateModel: AppState>*/: View {
    @State private var camera: CameraModel?
//    @State var appState: AppStateModel
    @Bindable var appState: AppStateModel
    
    var body: some View {
        NavigationView {
            if let camera = camera {
                CameraView(camera: camera, appState: appState)
                    .task {
                        await camera.start()
                    }
            } else {
                Rectangle()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(Color.gray)
                    .task {
                        self.camera = await CameraModel.create()
                    }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .onDisappear {
            appState.isShowingSearchView = true // 在滑动关闭视图时也能更新变量
            appState.isShowingCameraView = false
                    }
    }
}
