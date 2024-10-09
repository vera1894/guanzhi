//
//  SearchViewModel.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/9/29.
//

import Foundation
import Observation
import MapKit
import SwiftUI

@Observable
class SearchViewModel {
//    @Environment(AppStateModel.self) var appState
    var appState: AppStateModel?
    
//    var appState: AppStateModel
//    // 构造函数，接收 appState
//    init(appState: AppStateModel) {
//        self.appState = appState
//    }
    
    
    var region: MKCoordinateRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    var fetchWorkItem: DispatchWorkItem?
    var selectedAnnotation: CustomAnnotation?
    var annotations: [CustomAnnotation] = []
    var position: CustomMapCameraPosition = .automatic
    var searchResults = [SearchResult]()
    var selectedLocation: SearchResult? = nil
    var locationAnimating: Bool = false  //结果位置标记动画暂时无用
    var scene: MKLookAroundScene? //
    var locatedPosition : CLLocationCoordinate2D?
    
    
    
    // MARK: - Functions
    // 获取标注列表
    func getAnnotations() -> [CustomAnnotation] {
        var annotations: [CustomAnnotation] = []

        // 添加搜索结果的标注
        if ((self.appState?.isShowingShowMarker) != nil), let selectedLocation = selectedLocation {
            let annotation = CustomAnnotation(
                coordinate: selectedLocation.location,
                title: "搜索结果",
                subtitle: nil,
                imageUrl: nil,
                annotationData: nil,
                annotationType: .searchResult
            )
            annotations.append(annotation)
            print("Added searchResult annotation at \(selectedLocation.location)")
        } else {
            print("Did not add searchResult annotation. isShowingShowMarker: \(String(describing: self.appState?.isShowingShowMarker)), selectedLocation: \(String(describing: selectedLocation))")
        }

        // 添加附近分享的标注
        if let records = self.appState?.responsedNearbyShareList?.records {
            print("Found \(records.count) nearby shares")
            for record in records {
                let coordinate = CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude)
                let imageUrl = getImageUrl(from: record)
                let annotation = CustomAnnotation(
                    coordinate: coordinate,
                    title: record.title,
                    subtitle: record.address,
                    imageUrl: imageUrl,
                    annotationData: record,
                    annotationType: .nearbyShare
                )
                annotations.append(annotation)
                print("Added nearbyShare annotation at \(coordinate), title: \(record.title)")
            }
        } else {
            print("No nearby shares found")
        }

        print("Total annotations: \(annotations.count)")
        return annotations
    }
    
    // 处理地图区域变化
    func handleMapRegionChange(_ region: MKCoordinateRegion) {
        fetchWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            let center = region.center
            let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
            
            // 计算四个角的坐标
            let topLeft = CLLocationCoordinate2D(
                latitude: region.center.latitude + (region.span.latitudeDelta / 2.0),
                longitude: region.center.longitude - (region.span.longitudeDelta / 2.0)
            )
            let topRight = CLLocationCoordinate2D(
                latitude: region.center.latitude + (region.span.latitudeDelta / 2.0),
                longitude: region.center.longitude + (region.span.longitudeDelta / 2.0)
            )
            let bottomLeft = CLLocationCoordinate2D(
                latitude: region.center.latitude - (region.span.latitudeDelta / 2.0),
                longitude: region.center.longitude - (region.span.longitudeDelta / 2.0)
            )
            let bottomRight = CLLocationCoordinate2D(
                latitude: region.center.latitude - (region.span.latitudeDelta / 2.0),
                longitude: region.center.longitude + (region.span.longitudeDelta / 2.0)
            )
            
            // 计算中心到各角的距离
            let distances = [
                centerLocation.distance(from: CLLocation(latitude: topLeft.latitude, longitude: topLeft.longitude)),
                centerLocation.distance(from: CLLocation(latitude: topRight.latitude, longitude: topRight.longitude)),
                centerLocation.distance(from: CLLocation(latitude: bottomLeft.latitude, longitude: bottomLeft.longitude)),
                centerLocation.distance(from: CLLocation(latitude: bottomRight.latitude, longitude: bottomRight.longitude))
            ]
            
            let radius = distances.max() ?? 0.0
            
            print("Fetching shares with radius: \(radius) meters")
            
            // 获取附近的分享
            self.appState?.fetchNearbyShareList(latitude: center.latitude, longitude: center.longitude, radius: radius)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
        
        fetchWorkItem = workItem
    }
    
    // 处理地图位置变化
    func handlePositionChange(_ newPosition: CustomMapCameraPosition) {
        // 根据需要更新位置
        // 例如，防止循环更新
    }
    
    // 获取标注的图片 URL
    func getImageUrl(from annotation: ResponsedShare) -> URL? {
        let imagePaths = annotation.imagePath.components(separatedBy: ",")
        let baseURL = "https://onettoo.com/" // 请替换为您的实际服务器地址
        if let firstImagePath = imagePaths.first {
            let imageUrlString = baseURL + firstImagePath
            if let encodedUrlString = imageUrlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: encodedUrlString) {
                return url
            }
        }
        return nil
    }
    
    
    // 获取用户位置
    func getUserLocation() {
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
        
        DispatchQueue.global().async {
            if CLLocationManager.locationServicesEnabled() {
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
                locationManager.startUpdatingLocation()
                
                if let location = locationManager.location?.coordinate {
                    self.getAddressFromLocation(for: location) { address in
                        if let address = address {
                            DispatchQueue.main.async {
                                self.appState?.resultLocationName = address
                                print("cardname:", self.appState?.resultLocationName)
                            }
                        }
                    }
                    let newRegion = MKCoordinateRegion(center: location, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                    DispatchQueue.main.async {
                        withAnimation(Animation.spring()) {
                            self.position = .region(newRegion)
                            self.region = newRegion // 更新 region
                            self.locatedPosition = location
                            self.appState?.fetchNearbyShareList(latitude: location.latitude, longitude: location.longitude, radius: 20)
                        }
                        print("经纬度", location.latitude, location.longitude)
                    }
                }
            }
        }
    }
    
    // 根据坐标获取地址
    func getAddressFromLocation(for location: CLLocationCoordinate2D?, completion: @escaping (String?) -> Void) {
        if let location = location {
            let location = CLLocation(latitude: location.latitude, longitude: location.longitude)
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    print("定位错误：\(error.localizedDescription)")
                } else if let placemark = placemarks?.first {
                    let address = "\(placemark.name ?? "")\(placemark.locality ?? "")\(placemark.administrativeArea ?? "")\(placemark.country ?? "")"
                    print("地址：", address)
                    completion(address)
                }
            }
        }
    }
    
}
