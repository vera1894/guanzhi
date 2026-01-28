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
    let mapScope: Namespace.ID  // ✅ 接收与 Map 相同的 scope，用于绑定 MapKit 控件
    @Binding var position: MapCameraPosition

    // MARK: - MKMapView 支持
    var useMKMapView: Bool = false  // 是否使用 MKMapView 模式
    var mkMapView: MKMapView?  // MKMapView 引用（用于 MKCompassButton）
    @Binding var shouldCenterOnUser: Bool  // MKMapView 模式：定位按钮触发
    @Binding var shouldResetHeading: Bool  // MKMapView 模式：指南针按钮触发
    @Binding var shouldToggle3D: Bool  // MKMapView 模式：3D 按钮触发
    @Binding var is3DMode: Bool  // MKMapView 模式：当前是否 3D

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
            
//            Button {
//                print("定位按钮被点击")
//
//                withAnimation(.spring()) {
//                    position = .userLocation(
//                        followsHeading: false,
//                        fallback: .automatic    // 定位不可用/未授权时的兜底
//                    )
//                }
//                // ✅ 不要在这里再手动写 searchViewModel.region
//            } label: {
//                Image("icon-location")
//            }
//            .buttonStyle(ButtonStyle_m())

//            Button{
//                //定位按钮-圆形
//                print("定位按钮被点击")
//                if let location = locationManager.currentLocation {
//                    let newRegion = MKCoordinateRegion(
//                        center: location,
//                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//                    )
//                    withAnimation(.spring()) {
//                        position = .region(newRegion)
//                    }
//                    searchViewModel.region = newRegion
//                } else {
//                    print("尚未获取到定位")
//                }
//            }label: {
//                Image("icon-location")
//            }
//            .buttonStyle(ButtonStyle_m())
            
            // MARK: - 地图控件（根据地图类型切换）
            if useMKMapView {
                // ===== MKMapView 模式：使用自定义按钮 =====
                // 🚨 不使用 MKUserTrackingButton，因为它会自动设置 userTrackingMode 导致地图锁定

                // 定位按钮（自定义实现，只触发一次定位，不使用跟踪模式）
                Button {
                    print("🗺️ MKMapView 定位按钮被点击")
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

                // 3D/2D 切换按钮（无官方控件，自定义实现，纯色背景与官方控件统一）
                Button {
                    print("MKMapView 3D 按钮被点击")
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

            } else {
                // ===== SwiftUI Map 模式：使用官方 MapKit 控件 =====

                MapUserLocationButton(scope: mapScope)  // 定位按钮：回到用户位置
                    .mapControlVisibility(.automatic)
                    .symbolVariant (.circle)
                    .labelStyle(.automatic)
                    .controlSize(.small)
                    .cornerRadius(24)
                    .tint(Color("color-black"))
                    .symbolRenderingMode(.hierarchical)
                    .labelStyle(.iconOnly)
                    .background(.regularMaterial, in: Circle())
                    .shadow(color: Color("color-primary"), radius: 0, x: 2, y: 4)
                    .font(. system(size: 12))
                    .scaleEffect(0.9)

                MapCompass(scope: mapScope)             // 指南针：随地图旋转，点击复位正北
                    .mapControlVisibility(.visible)
                    .symbolVariant (.fill)
                    .labelStyle(.iconOnly)
                    .foregroundColor(Color.black)
                    .controlSize(.small)
                    .tint(Color.black)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: Color("color-primary"), radius: 0, x: 2, y: 4)
                    .font(.system(size: 8))
                    .scaleEffect(0.9)

                MapPitchToggle(scope: mapScope)         // 3D 按钮：切换平面/3D 视角
                    .mapControlVisibility(.visible)
                    .symbolVariant (.fill)
                    .labelStyle(.iconOnly)
                    .controlSize(.small)
                    .tint(Color("color-black"))
                    .background(.regularMaterial, in: Circle())
                    .shadow(color: Color("color-primary"), radius: 0, x: 2, y: 4)
                    .font(.system(size: 8))
                    .scaleEffect(0.9)
            }
            

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
    @Namespace static var previewMapScope

    static var previews: some View {
        MapOverlayView(
            mapScope: previewMapScope,
            position: .constant(
                .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                )
            ),
            useMKMapView: false,
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
