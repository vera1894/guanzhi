//
//  CoordinateConverter.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/11/14.
//


import Foundation
import CoreLocation

class CoordinateConverter {
    
    static let shared = CoordinateConverter()
    
    private var gcj02BoundaryPoints: [[Double]] = []
    
    private init() {
        // 私有化初始化方法，确保单例模式
        loadGCJ02BoundaryData()
    }
    
    private func loadGCJ02BoundaryData() {
        // 加载 GCJ02.json 文件的数据
        if let filePath = Bundle.main.path(forResource: "GCJ02", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
           let points = try? JSONSerialization.jsonObject(with: data, options: []) as? [[Double]] {
            self.gcj02BoundaryPoints = points
            print("成功加载 GCJ02 边界数据")
        } else {
            print("无法加载 GCJ02 边界数据")
        }
    }
    
    // 判断坐标是否在中国境内
    func isOutOfChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // 使用 gcj02BoundaryPoints 数据进行判断
        // 实现点是否在多边形内的算法，例如射线法
        var flag = false
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let points = gcj02BoundaryPoints
        let count = points.count
        for i in 0..<count {
            let p1Lat = points[i][0]
            let p1Lon = points[i][1]
            let p2Lat = points[(i + 1) % count][0]
            let p2Lon = points[(i + 1) % count][1]
            if ((p1Lat > lat) != (p2Lat > lat)) &&
                (lon < (p2Lon - p1Lon) * (lat - p1Lat) / (p2Lat - p1Lat) + p1Lon) {
                flag = !flag
            }
        }
        return !flag
    }
    
    // WGS-84 转 GCJ-02
    func wgs84ToGcj02(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        if isOutOfChina(coordinate) {
            return coordinate
        }
        var dLat = transformLat(x: coordinate.longitude - 105.0, y: coordinate.latitude - 35.0)
        var dLon = transformLon(x: coordinate.longitude - 105.0, y: coordinate.latitude - 35.0)
        let radLat = coordinate.latitude / 180.0 * Double.pi
        var magic = sin(radLat)
        magic = 1 - 0.00669342162296594323 * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((6378245.0 * (1 - 0.00669342162296594323)) / (magic * sqrtMagic) * Double.pi)
        dLon = (dLon * 180.0) / (6378245.0 / sqrtMagic * cos(radLat) * Double.pi)
        let mgLat = coordinate.latitude + dLat
        let mgLon = coordinate.longitude + dLon
        return CLLocationCoordinate2D(latitude: mgLat, longitude: mgLon)
    }
    
    // GCJ-02 转 WGS-84
    func gcj02ToWgs84(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        if isOutOfChina(coordinate) {
            return coordinate
        }
        let wgLoc = transform(coordinate)
        let longitude = coordinate.longitude * 2 - wgLoc.longitude
        let latitude = coordinate.latitude * 2 - wgLoc.latitude
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    private func transform(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        var dLat = transformLat(x: coordinate.longitude - 105.0, y: coordinate.latitude - 35.0)
        var dLon = transformLon(x: coordinate.longitude - 105.0, y: coordinate.latitude - 35.0)
        let radLat = coordinate.latitude / 180.0 * Double.pi
        var magic = sin(radLat)
        magic = 1 - 0.00669342162296594323 * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((6378245.0 * (1 - 0.00669342162296594323)) / (magic * sqrtMagic) * Double.pi)
        dLon = (dLon * 180.0) / (6378245.0 / sqrtMagic * cos(radLat) * Double.pi)
        let mgLat = coordinate.latitude + dLat
        let mgLon = coordinate.longitude + dLon
        return CLLocationCoordinate2D(latitude: mgLat, longitude: mgLon)
    }
    
    private func transformLat(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y
        ret += 0.2 * y * y + 0.1 * x * y
        ret += 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * Double.pi) + 40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * Double.pi) + 320.0 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0
        return ret
    }
    
    private func transformLon(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y
        ret += 0.1 * x * x + 0.1 * x * y
        ret += 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * Double.pi) + 40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * Double.pi) + 300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0
        return ret
    }
}