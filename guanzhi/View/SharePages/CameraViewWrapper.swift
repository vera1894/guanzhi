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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // 主内容
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

            // 左边缘滑动拦截区域（仅在输入模式时激活）
            if appState.isReadyToPost {
                EdgeSwipeInterceptor {
                    // 左滑返回拍照模式
                    withAnimation(.easeOut(duration: 0.2)) {
                        appState.isReadyToPost = false
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .onDisappear {
            // 停止相机并释放资源
            if let camera = camera {
                Task {
                    await camera.stop()
                }
            }
            // 重置发布状态，确保下次进入时从拍照模式开始
            appState.isReadyToPost = false
            appState.isShowingSearchView = true // 在滑动关闭视图时也能更新变量
            appState.isShowingCameraView = false
        }
    }
}

// MARK: - 左边缘滑动拦截器
/// 在左边缘放置一个透明的拦截区域，捕获滑动手势
private struct EdgeSwipeInterceptor: View {
    let onSwipeBack: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack {
            // 左边缘拦截区域
            Color.clear
                .frame(width: 25)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width > 0 {
                                dragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if value.translation.width > 80 {
                                onSwipeBack()
                            }
                            dragOffset = 0
                        }
                )

            Spacer()
        }
        .allowsHitTesting(true)
    }
}
