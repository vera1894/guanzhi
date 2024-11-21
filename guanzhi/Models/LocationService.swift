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

//    // 判断坐标是否在中国境内
//    func isLocationOutOfChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
//        let lat = coordinate.latitude
//        let lon = coordinate.longitude
//        if lon < 72.004 || lon > 137.8347 {
//            return true
//        }
//        if lat < 0.8293 || lat > 55.8271 {
//            return true
//        }
//        return false
//    }
//
//    // 纬度转换
//    func transformLat(x: Double, y: Double) -> Double {
//        var ret = -100.0 + 2.0 * x + 3.0 * y
//        ret += 0.2 * y * y + 0.1 * x * y
//        ret += 0.2 * sqrt(abs(x))
//        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
//        ret += (20.0 * sin(y * Double.pi) + 40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0
//        ret += (160.0 * sin(y / 12.0 * Double.pi) + 320.0 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0
//        return ret
//    }
//
//    // 经度转换
//    func transformLon(x: Double, y: Double) -> Double {
//        var ret = 300.0 + x + 2.0 * y
//        ret += 0.1 * x * x + 0.1 * x * y
//        ret += 0.1 * sqrt(abs(x))
//        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
//        ret += (20.0 * sin(x * Double.pi) + 40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0
//        ret += (150.0 * sin(x / 12.0 * Double.pi) + 300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0
//        return ret
//    }
//
//    // 将 WGS-84 坐标转换为 GCJ-02 坐标
//    func wgs84ToGcj02(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
//        if isLocationOutOfChina(coordinate) {
//            return coordinate
//        }
//        var dLat = transformLat(x: coordinate.longitude - 105.0, y: coordinate.latitude - 35.0)
//        var dLon = transformLon(x: coordinate.longitude - 105.0, y: coordinate.latitude - 35.0)
//        let radLat = coordinate.latitude / 180.0 * Double.pi
//        var magic = sin(radLat)
//        magic = 1 - 0.00669342162296594323 * magic * magic
//        let sqrtMagic = sqrt(magic)
//        dLat = (dLat * 180.0) / ((6378245.0 * (1 - 0.00669342162296594323)) / (magic * sqrtMagic) * Double.pi)
//        dLon = (dLon * 180.0) / (6378245.0 / sqrtMagic * cos(radLat) * Double.pi)
//        let mgLat = coordinate.latitude + dLat
//        let mgLon = coordinate.longitude + dLon
//        return CLLocationCoordinate2D(latitude: mgLat, longitude: mgLon)
//    }
//    
//    // 获取当前的 WGS-84 坐标
//    func getCurrentWGS84Location() -> CLLocationCoordinate2D? {
//        if let currentLocation = self.currentLocation {
//            return gcj02ToWgs84(currentLocation)
//        }
//        return nil
//    }
//
//    // 将 GCJ-02 坐标转换为 WGS-84 坐标
//    func gcj02ToWgs84(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
//        let gcjLat = coordinate.latitude
//        let gcjLon = coordinate.longitude
//        let wgsLoc = wgs84ToGcj02(coordinate)
//        let dLat = gcjLat - wgsLoc.latitude
//        let dLon = gcjLon - wgsLoc.longitude
//        return CLLocationCoordinate2D(latitude: coordinate.latitude - dLat, longitude: coordinate.longitude - dLon)
//    }
}
