//
//  LocationPickerService.swift
//  guanzhi
//
//  Created by Claude Code on 2026/2/19.
//

import Foundation
import CoreLocation
import MapKit

/// 发布端位置选择的集中式服务
/// 负责：GPS 定位、反编码、最近 POI 查找、附近 POI 加载、搜索
@Observable
@MainActor
class LocationPickerService {

    // MARK: - 当前定位状态
    var currentCoordinate: CLLocationCoordinate2D?  // WGS-84
    var currentAddress: String = ""                 // CLGeocoder 行政地址（fallback）
    var currentPOIName: String?                     // 最近 POI 名称（优先显示）
    var isLocationReady: Bool = false

    /// 显示名称：优先 POI 名称，其次行政地址
    var displayName: String { currentPOIName ?? currentAddress }

    // MARK: - 附近 POI
    var nearbyPOIs: [POIItem] = []
    var isLoadingNearby: Bool = false

    // MARK: - 搜索结果
    var searchResults: [POIItem] = []
    var isSearching: Bool = false

    // MARK: - Private
    private let converter = CoordinateConverter.shared
    private let geocoder = CLGeocoder()

    // MARK: - 坐标转换

    /// WGS-84 → GCJ-02（MKLocalSearch / CLGeocoder 在中国需要 GCJ-02）
    func toGCJ02(_ coord: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        converter.isOutOfChina(coord) ? coord : converter.wgs84ToGcj02(coord)
    }

    /// GCJ-02 → WGS-84（MKLocalSearch 结果转回存储坐标系）
    func toWGS84(_ coord: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        converter.isOutOfChina(coord) ? coord : converter.gcj02ToWgs84(coord)
    }

    // MARK: - 获取当前定位

    /// GPS 定位 + 反编码行政地址 + 查找最近 POI 名称
    func resolveCurrentLocation() {
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()

        DispatchQueue.global().async { [weak self] in
            guard CLLocationManager.locationServicesEnabled(),
                  let coordinate = locationManager.location?.coordinate else { return }

            DispatchQueue.main.async {
                self?.currentCoordinate = coordinate
            }

            self?.reverseGeocode(coordinate)
            self?.findNearestPOI(wgs84: coordinate)
        }
    }

    /// CLGeocoder 反编码行政地址（作为 fallback）
    private func reverseGeocode(_ wgs84: CLLocationCoordinate2D) {
        let gcj02 = toGCJ02(wgs84)
        let location = CLLocation(latitude: gcj02.latitude, longitude: gcj02.longitude)

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let pm = placemarks?.first else { return }
            let address = [pm.name, pm.locality, pm.administrativeArea, pm.country]
                .compactMap { $0 }
                .joined(separator: " ")

            DispatchQueue.main.async {
                self?.currentAddress = address
                self?.isLocationReady = true
            }
        }
    }

    /// MKLocalSearch 多分类搜索，查找 300m 内最近的 POI 名称
    private func findNearestPOI(wgs84: CLLocationCoordinate2D) {
        let gcj02 = toGCJ02(wgs84)
        let queries = ["小区", "商铺", "写字楼"]

        multiQuerySearch(queries: queries, center: gcj02, radius: 300) { [weak self] items in
            guard let self else { return }

            let userLoc = CLLocation(latitude: gcj02.latitude, longitude: gcj02.longitude)
            let nearest = items
                .compactMap { item -> (name: String, distance: Double)? in
                    guard let name = item.name else { return nil }
                    let poiLoc = CLLocation(latitude: item.placemark.coordinate.latitude,
                                            longitude: item.placemark.coordinate.longitude)
                    return (name, userLoc.distance(from: poiLoc))
                }
                .min { $0.distance < $1.distance }

            if let nearest, nearest.distance < 300 {
                DispatchQueue.main.async {
                    self.currentPOIName = nearest.name
                    self.isLocationReady = true
                }
            }
        }
    }

    // MARK: - 加载附近 POI

    func loadNearbyPOIs() {
        guard let wgs84 = currentCoordinate else { return }
        isLoadingNearby = true

        let gcj02 = toGCJ02(wgs84)
        let queries = ["小区", "商铺", "餐饮", "学校", "公园", "医院"]

        multiQuerySearch(queries: queries, center: gcj02, radius: 1000) { [weak self] items in
            guard let self else { return }

            let userLoc = CLLocation(latitude: gcj02.latitude, longitude: gcj02.longitude)

            // 去重（按名称）+ 计算距离 + 按距离排序
            var seen = Set<String>()
            let pois: [POIItem] = items
                .compactMap { item -> POIItem? in
                    guard let name = item.name, !seen.contains(name) else { return nil }
                    seen.insert(name)
                    let poiCoord = item.placemark.coordinate
                    let dist = userLoc.distance(from: CLLocation(latitude: poiCoord.latitude,
                                                                  longitude: poiCoord.longitude))
                    return POIItem(name: name, subtitle: item.placemark.title ?? "",
                                   coordinate: poiCoord, distance: dist)
                }
                .sorted { ($0.distance ?? 0) < ($1.distance ?? 0) }

            DispatchQueue.main.async {
                self.nearbyPOIs = Array(pois.prefix(20))
                self.isLoadingNearby = false
            }
        }
    }

    // MARK: - 搜索地点

    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        if let wgs84 = currentCoordinate {
            let gcj02 = toGCJ02(wgs84)
            request.region = MKCoordinateRegion(center: gcj02,
                                                 latitudinalMeters: 5000, longitudinalMeters: 5000)
        }

        do {
            let response = try await MKLocalSearch(request: request).start()
            let userLoc: CLLocation? = currentCoordinate.map {
                let gcj02 = toGCJ02($0)
                return CLLocation(latitude: gcj02.latitude, longitude: gcj02.longitude)
            }

            searchResults = response.mapItems.prefix(20).compactMap { item in
                guard let name = item.name else { return nil }
                let poiCoord = item.placemark.coordinate
                var dist: CLLocationDistance? = nil
                if let userLoc {
                    dist = userLoc.distance(from: CLLocation(latitude: poiCoord.latitude,
                                                              longitude: poiCoord.longitude))
                }
                return POIItem(name: name, subtitle: item.placemark.title ?? "",
                               coordinate: poiCoord, distance: dist)
            }
        } catch {
            #if DEBUG
            print("📍 LocationPickerService search error: \(error)")
            #endif
        }
    }

    // MARK: - 选择位置

    /// 用户从 Picker 选择 POI 后调用（坐标为 GCJ-02，自动转 WGS-84 存储）
    func selectPOI(_ poi: POIItem) {
        currentCoordinate = toWGS84(poi.coordinate)
        currentPOIName = poi.name
    }

    /// 选择"当前位置"（不需要坐标转换，已是 WGS-84）
    func selectCurrentLocation() {
        // currentCoordinate 不变，POI 名称清空（使用行政地址）
        currentPOIName = nil
    }

    // MARK: - 距离格式化

    func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters < 100 {
            return "<100m"
        } else if meters < 1000 {
            return "\(Int(meters / 50) * 50)m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }

    // MARK: - 多分类并行搜索（内部工具）

    /// 对多个查询词并行执行 MKLocalSearch，合并结果后回调
    private func multiQuerySearch(
        queries: [String],
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        completion: @escaping ([MKMapItem]) -> Void
    ) {
        let group = DispatchGroup()
        var allItems: [MKMapItem] = []
        let lock = NSLock()

        for query in queries {
            group.enter()
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = [.pointOfInterest, .address]
            request.region = MKCoordinateRegion(center: center,
                                                 latitudinalMeters: radius * 2,
                                                 longitudinalMeters: radius * 2)

            MKLocalSearch(request: request).start { response, _ in
                if let items = response?.mapItems {
                    lock.lock()
                    allItems.append(contentsOf: items)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .global()) {
            completion(allItems)
        }
    }
}

// MARK: - POI 数据模型

struct POIItem: Identifiable {
    let id = UUID().uuidString
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    var distance: CLLocationDistance? = nil
}
