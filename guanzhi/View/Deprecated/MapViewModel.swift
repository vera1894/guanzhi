//
//  MapViewModel.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/6/8.
//

import SwiftUI
import MapKit
import CoreLocation

// All Map Data Goes Here....

struct Place: Identifiable {
    
    var id = UUID().uuidString
    var placemark: CLPlacemark
}

class MapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // 创建一个 CLLocationManager 实例，用于管理和获取设备的地理位置
    private var locationManager = CLLocationManager()
    
    // 创建一个 MKMapView 实例，用于显示地图
    @Published var mapView = MKMapView()
    
    // 地图显示的区域
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // 用户权限被拒绝时的警告标志
    @Published var permissionDenied = false
    
    // 地图类型，默认为标准地图
    @Published var mapType: MKMapType = .standard
    
    // 搜索文本
    @Published var searchTxt = ""
    
    // 搜索到的位置列表
    @Published var places: [Place] = []
    
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
    
    
    // 更新地图类型的方法
//    func updateMapType() {
//        if mapType == .standard {
//            mapType = .hybrid
//            mapView.mapType = mapType
//        } else {
//            mapType = .standard
//            mapView.mapType = mapType
//        }
//    }
    
    // 聚焦当前位置的方法
    func focusLocation() {
//        guard let _ = region else { return }
        mapView.setRegion(region, animated: true)
        mapView.setVisibleMapRect(mapView.visibleMapRect, animated: true)
    }
    
    // 搜索位置的方法
    func searchQuery() {
        places.removeAll()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchTxt
        
        // 执行搜索
        MKLocalSearch(request: request).start { (response, _) in
            guard let result = response else { return }
            self.places = result.mapItems.compactMap { (item) -> Place? in
                return Place(placemark: item.placemark)
            }
        }
    }
    
    // 选择搜索结果的位置并显示在地图上的方法
    func selectPlace(place: Place) {
        // 清空搜索文本
        searchTxt = ""
        
        guard let coordinate = place.placemark.location?.coordinate else { return }
        
        let pointAnnotation = MKPointAnnotation()
        pointAnnotation.coordinate = coordinate
        pointAnnotation.title = place.placemark.name ?? "No Name"
        
        // 移除旧的标注
        mapView.removeAnnotations(mapView.annotations)
        
        // 添加新的标注
        mapView.addAnnotation(pointAnnotation)
        
        // 移动地图到选择的位置
        let coordinateRegion = MKCoordinateRegion(center: coordinate, latitudinalMeters: 10000, longitudinalMeters: 10000)
        mapView.setRegion(coordinateRegion, animated: true)
        mapView.setVisibleMapRect(mapView.visibleMapRect, animated: true)
        
        // 更新 cameraPosition 以跳转到选择的位置
        cameraPosition = .region(coordinateRegion)
    }
    
    // 处理权限变化的方法
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied:
            // 更新权限被拒绝标志
            permissionDenied.toggle()
        case .notDetermined:
            // 请求权限
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // 请求位置更新
            manager.requestLocation()
        default:
            ()
        }
    }
    
    // 处理位置更新失败的方法
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 打印错误信息
        print(error.localizedDescription)
    }
    
    // 获取并更新用户位置的方法
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // 更新用户位置
        userLocation = Location(coordinate: location.coordinate)
        region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        
        // 如果 shouldUpdateCamera 为 true，更新摄像头位置
        if shouldUpdateCamera {
            cameraPosition = .region(region)
        }
        
         //更新地图显示区域
        self.mapView.setRegion(self.region, animated: true)
        
        // 平滑动画效果
//        self.mapView.setVisibleMapRect(self.mapView.visibleMapRect, animated: true)
    }
}
