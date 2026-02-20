//
//  MapOverlayView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/10/9.
//
import SwiftUI
import MapKit

// MARK: - 可调参数

/// 地图控件按钮直径（定位、指南针、3D/2D）
private let kMapControlButtonSize: CGFloat = 40

struct MapOverlayView: View {
    var mkMapView: MKMapView?  // MKMapView 引用（用于 MKCompassButton）
    @Binding var shouldCenterOnUser: Bool  // 定位按钮触发
    @Binding var shouldResetHeading: Bool  // 指南针按钮触发
    @Binding var shouldToggle3D: Bool  // 3D 按钮触发
    @Binding var is3DMode: Bool  // 当前是否 3D

    @Environment(\.appState) var appState
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var searchViewModel: SearchViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var userProfileManager: UserProfileManager

    var body: some View {
        @Bindable var appState = appState

        // 提前计算头像图片，避免在 ButtonStyle 中进行异步操作
        let avatarImage: Image = {
            if let uiImage = userProfileManager.avatarImage {
                return Image(uiImage: uiImage)
            } else {
                return Image("icon-defaultAvatar")
            }
        }()
        
        VStack(spacing: 12) {
            // 现有的自定义按钮
            Button(action: {
                navigationCoordinator.path.append(Route.myView)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    appState.isShowingSearchView = false
                }
            }) {
                // 使用与 MyView 相同的头像逻辑
            }
            .buttonStyle(AvatarStyle_s(
                isEnabled: true,
                profileImage: avatarImage,
                borderThickness: 4
            ))
            .padding(.bottom, 6)
            
            // 消息按钮 + 红点（红点在按钮外层，避免继承按钮阴影）
            ZStack(alignment: .topTrailing) {
                Button {
                    navigationCoordinator.path.append(Route.messagesView)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        appState.isShowingSearchView = false
                    }
                } label: {
                    Image("icon-notification")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(ButtonStyle_l())

                // 未读红点（在按钮外层，无阴影）
                NotificationBadge()
                    .offset(x: 8, y: -4)
            }
            
            // MARK: - 地图控件

                // 定位按钮（自定义实现，只触发一次定位，不使用跟踪模式）
                Button {
                    shouldCenterOnUser = true
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.primary)
                }
                .frame(width: kMapControlButtonSize, height: kMapControlButtonSize)
                .background(Color(.systemBackground), in: Circle())
                .compositingGroup()
                .shadow(color: Color("color-primary"), radius: 0, x: 2, y: 4)

                // MKCompassButton（官方指南针，圆形纯色背景）
                MKCompassButtonWrapper(mapView: mkMapView, size: kMapControlButtonSize)
                    .frame(width: kMapControlButtonSize, height: kMapControlButtonSize)
                    .shadow(color: Color("color-primary"), radius: 0, x: 2, y: 4)

                // 3D/2D 切换按钮
                Button {
                    shouldToggle3D = true
                } label: {
                    Image(systemName: is3DMode ? "view.2d" : "view.3d")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.primary)
                }
                .frame(width: kMapControlButtonSize, height: kMapControlButtonSize)
                .background(Color(.systemBackground), in: Circle())
                .compositingGroup()
                .shadow(color: Color("color-primary"), radius: 0, x: 2, y: 4)

        }
        .padding(.horizontal, 12)
        .padding(.bottom, 120)
        .onAppear {
            // 尝试加载缓存的头像
            userProfileManager.loadCachedAvatar()
        }
    }
}


struct MapOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        MapOverlayView(
            shouldCenterOnUser: .constant(false),
            shouldResetHeading: .constant(false),
            shouldToggle3D: .constant(false),
            is3DMode: .constant(false)
        )
        .environment(\.appState, AppStateModel())
        .environmentObject(LocationManager())
        .environmentObject(SearchViewModel())
        .environmentObject(NavigationCoordinator())
        .environmentObject(UserProfileManager())
    }
}
