//
//  MapOverlayView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/10/9.
//
import SwiftUI
import MapKit

struct MapOverlayView: View {
    let mapScope: Namespace.ID  // ✅ 接收与 Map 相同的 scope，用于绑定 MapKit 控件
    @Binding var position: MapCameraPosition
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
                return Image("例子")
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
            
            Button{
                // 消息按钮 - 跳转到消息中心
                navigationCoordinator.path.append(Route.messagesView)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    appState.isShowingSearchView = false
                }
            }label: {
                ZStack(alignment: .topTrailing) {
                    Image("icon-notification")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 46, height: 46)

                    // 未读红点（由 NotificationBadgeManager 驱动）
                    NotificationBadge()
                        .offset(x: 4, y: -4)
                }
            }
            .buttonStyle(ButtonStyle_l())
            
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
            
            // ✅ 官方 MapKit 控件（绑定到同一个 mapScope，会与地图联动）
            
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
//                .foregroundColor(Color.black)
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
//                .foregroundColor(Color.black)
                .controlSize(.small)
                .tint(Color("color-black"))
                .background(.regularMaterial, in: Circle())
                .shadow(color: Color("color-primary"), radius: 0, x: 2, y: 4)
                .font(.system(size: 8))
                .scaleEffect(0.9)
            

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
            )
        )
        .environment(\.appState, AppStateModel())
        .environmentObject(LocationManager())
        .environmentObject(SearchViewModel())
        .environmentObject(NavigationCoordinator())
        .environmentObject(UserProfileManager())
    }
}
