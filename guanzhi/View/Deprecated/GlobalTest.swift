//
//  GlobalTest.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/6/13.
//


import SwiftUI
import MapKit
import CoreLocation

// 定义一个符合 Identifiable 协议的结构体
struct Location: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // 创建一个 CLLocationManager 实例，用于管理和获取设备的地理位置
    private var locationManager = CLLocationManager()
    
    // 用于 SwiftUI 数据绑定，定义地图显示的区域，初始值设置为旧金山的坐标和跨度
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // 用于 SwiftUI 数据绑定，定义地图摄像头的位置，初始值与 region 相同
    @Published var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    
    // 用于存储用户的当前位置
    @Published var userLocation: Location?
    // 指示是否应更新摄像头位置
    @Published var shouldUpdateCamera = true
    
    // 初始化方法
    override init() {
        super.init()
        // 设置 locationManager 的委托为当前类
        locationManager.delegate = self
        // 配置所需的定位精度
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // 请求用户的定位授权
        locationManager.requestWhenInUseAuthorization()
        // 开始更新位置
        locationManager.startUpdatingLocation()
    }
    
    // 位置更新回调方法，当位置更新时会被调用
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 获取最新的位置，如果不存在则返回
        guard let location = locations.last else { return }
        // 更新用户位置
        userLocation = Location(coordinate: location.coordinate)
        // 更新地图显示区域
        region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        // 如果 shouldUpdateCamera 为 true，更新摄像头位置
        if shouldUpdateCamera {
            cameraPosition = .region(region)
        }
    }
}

struct GlobalTest: View {
    @Namespace var mapScope
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        ZStack {
            Map(position: $locationManager.cameraPosition, interactionModes: [.all], scope: mapScope) {
                Annotation("", coordinate: .pickupLocation, anchor: .bottom) {
                    ZStack {
                        Button {
                            // 处理按钮点击事件
                        } label: { }
                        .buttonStyle(SeeePositionStyle(isEnabled: true))
                    }
                }
                UserAnnotation()
                
            }
            .mapStyle(.hybrid(elevation: .realistic,
                              pointsOfInterest: .including([.park]),
                              showsTraffic: false))
            .onChange(of: locationManager.cameraPosition) { _, _ in
                locationManager.shouldUpdateCamera = false
            }
            .gesture(
                DragGesture().onEnded { _ in
                    locationManager.shouldUpdateCamera = false
                }
            )
    //        .mapControls {
    //            MapUserLocationButton()
    //            MapCompass()
    //            MapPitchToggle()
    //            MapScaleView()
    //                }
            .overlay(alignment:.bottomTrailing) {
                VStack(spacing: 32) {
                    
                    VStack(spacing: 16) {
                        Button(action: {
                            // 头像-s
                        }) { }
                        .buttonStyle(AvatarStyle_s(isEnabled: true, profileImage: Image("例子"), borderThickness: 4))
                        
                        Button{
                            //提醒按钮-圆形
                        }label: {
                            Image("icon-notification")
                        }
                        .buttonStyle(ButtonStyle_m())
                        
        //                Spacer()
                        
        //                Button{
        //                    //定位按钮-圆形
        //                }label: {
        //                    Image("icon-location")
        //                }
        //                .buttonStyle(ButtonStyle_m())
                    }
                    
                    Spacer()
                    
                    VStack {
                        MapCompass(scope: mapScope)
                        MapPitchToggle(scope: mapScope)
                        MapUserLocationButton(scope: mapScope)
                    }
                    .mapControlVisibility(.visible)
                    .buttonBorderShape(.circle)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 60)
            }
            .mapScope(mapScope)
            
            
        }  //ZStack
        
    }
}

#Preview {
    GlobalTest()
}
