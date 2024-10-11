//
//  LocationService.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/9/23.
//


import CoreLocation
import Observation

@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    var currentLocation: CLLocationCoordinate2D?
    var locationError: Error?
    var locationErrorDescription: String?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("Received location updates: \(locations)")
        if let location = locations.last?.coordinate {
            DispatchQueue.main.async {
                self.currentLocation = location
                self.locationManager.stopUpdatingLocation()
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
}


extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

