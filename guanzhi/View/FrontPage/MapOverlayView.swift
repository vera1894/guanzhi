//
//  MapOverlayView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/10/9.
//
import SwiftUI
import MapKit

struct MapOverlayView: View {
    @Namespace var mapScope
    @Environment(\.appState) var appState
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var searchViewModel: SearchViewModel
    @Binding var position: MapCameraPosition
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
        
        VStack(spacing: 32) {
            VStack {
                MapPitchToggle(scope: mapScope)
            }
            .mapControlVisibility(.visible)
            .buttonBorderShape(.circle)
            .padding(.top, 60)
            
            Spacer()
            
//            ZoomSliderView(position: $position)
            
            VStack(spacing: 16) {
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
                
//                Button{ //暂时隐藏
//                    //提醒按钮-圆形 //测试登录页面导航问题
//                }label: {
//                    Image("icon-notification")
//                }
//                .buttonStyle(ButtonStyle_m())
//                .navigationDestination(isPresented: $appState.isShowLogInView) {
//                    LogInView(userlogin: UserLoginModel())
//                }
                
                Button{
                    //定位按钮-圆形
                    print("定位按钮被点击")
                    if let location = locationManager.currentLocation {
                        let newRegion = MKCoordinateRegion(
                            center: location,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                        withAnimation(.spring()) {
                            position = .region(newRegion)
                        }
                        searchViewModel.region = newRegion
//                        searchViewModel.fetchNearbyShareList(latitude: location.latitude, longitude: location.longitude, radius: 20)
                    } else {
                        print("尚未获取到定位")
                    }
                }label: {
                    Image("icon-location")
                }
                .buttonStyle(ButtonStyle_m())
            }
        }
        .padding(.horizontal, 5)
        .padding(.bottom, 120)
        .onAppear {
            // 尝试加载缓存的头像
            userProfileManager.loadCachedAvatar()
        }
    }
}


#Preview {
    MapOverlayView(
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
