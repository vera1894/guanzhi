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
    @Binding var isShowMyView: Bool
    @Binding var isShowLogInView: Bool
    @Bindable var appState: AppStateModel
    @Bindable var locationManager: LocationManager
    @ObservedObject var searchViewModel: SearchViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            VStack {
                MapPitchToggle(scope: mapScope)
            }
            .mapControlVisibility(.visible)
            .buttonBorderShape(.circle)
            .padding(.top, 60)
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: {
                    // 头像-s
                    print(searchViewModel.searchResults)
                    isShowMyView = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        appState.isShowingSearchView = false
                    }
                }) {
                    
                }
                .buttonStyle(AvatarStyle_s(isEnabled: true, profileImage: Image("例子"), borderThickness: 4))
                .navigationDestination(isPresented: $isShowMyView) {
                    MyView(appState: appState)
                }
                
                Button{
                    //提醒按钮-圆形 //测试登录页面导航问题
                    //isShowSearchView = false
                    //isShowLogInView = true
                    //isShowCameraView = true
                    //appState.isShowingCameraView = true
                    //appState.isShowingSearchView = false
                    //print("appState.isShowingCameraView")
                    
                    //logout()
                    //OTOLoginStatusManager.shared.logout()
                    
                    searchViewModel.fetchNearbyShareList(
                        latitude: searchViewModel.locatedPosition?.latitude ?? 0.0,
                        longitude: searchViewModel.locatedPosition?.longitude ?? 0.0,
                        radius: 20)
                    print(appState.responsedNearbyShareList?.records ?? "获取Annotation数据失败") // 检查是否成功获取数据
                    
                }label: {
                    Image("icon-notification")
                }
                .buttonStyle(ButtonStyle_m())
                .navigationDestination(isPresented: $isShowLogInView) {
                    LogInView(userlogin: UserLoginModel())
                }
                
                Button{
                    //定位按钮-圆形
                    print("定位按钮被点击")
                    if let location = locationManager.currentLocation {
                        let newRegion = MKCoordinateRegion(
                            center: location,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                        withAnimation(.spring()) {
                            searchViewModel.region = newRegion
                        }
                        searchViewModel.fetchNearbyShareList(latitude: location.latitude, longitude: location.longitude, radius: 20)
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
        .padding(.bottom, 80)
    }
}
