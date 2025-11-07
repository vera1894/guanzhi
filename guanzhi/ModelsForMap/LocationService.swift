//
//  LocationService.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/9/23.
//


import CoreLocation
import Observation

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var locationSet = false // 添加标志位
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var locationError: Error?
    @Published var locationErrorDescription: String?



    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // 请求定位权限，并立即开始更新位置
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func requestLocation() {
//        locationManager.requestWhenInUseAuthorization()
//        locationManager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            print("Received location updates: \(locations)")
            if let location = locations.last?.coordinate {
                DispatchQueue.main.async {
                    if !self.locationSet {
                        self.currentLocation = location
                        self.locationSet = true // 标记已设置位置
                        // 如果不需要持续更新位置，可以在这里停止位置更新
                        self.locationManager.stopUpdatingLocation()
                    }
                }
            }
        }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get user location: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.locationError = error
            self.locationErrorDescription = error.localizedDescription
            print("获取用户位置失败：\(error.localizedDescription)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("Authorization status changed: \(status.rawValue)")
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            print("定位权限被拒绝或受限")
            DispatchQueue.main.async {
                self.locationErrorDescription = "定位权限被拒绝或受限，请在设置中启用定位权限。"
            }
        default:
            break
        }
    }
    
    // MARK: - 坐标转换方法
    
    func getCurrentWGS84Location() -> CLLocationCoordinate2D? {
            if let currentLocation = self.currentLocation {
                return CoordinateConverter.shared.gcj02ToWgs84(currentLocation)
            }
            return nil
        }
    
}


struct LocationMarker: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String?
}
