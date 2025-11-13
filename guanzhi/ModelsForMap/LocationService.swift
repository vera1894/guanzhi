//
//  LocationService.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/9/23.
//

/*
 ============================================
 位置处理系统逻辑说明
 ============================================

 ## 1. 坐标系统概述

 本应用涉及三种坐标系统：

 - **WGS-84**：国际标准GPS坐标系，全球通用
   * GPS卫星、国际地图使用此坐标系
   * CLLocationManager 返回的是 WGS-84 坐标

 - **GCJ-02**：中国国家测绘局制定的坐标系（俗称"火星坐标"）
   * 中国大陆的地图服务（高德、腾讯、苹果中国地图）使用此坐标系
   * 相比 WGS-84 有随机偏移，偏移量约 50-500 米

 - **BD-09**：百度地图使用的坐标系
   * 在 GCJ-02 基础上再次加密
   * 本应用不直接处理，由百度地图 App 自动转换

 ## 2. 核心设计原则

 **存储策略**：所有位置信息以 WGS-84 格式存储
 - 服务器数据库：WGS-84
 - 本地 SwiftData：WGS-84
 - 优点：保证数据的国际通用性和一致性

 **显示策略**：根据位置动态转换
 - 中国大陆的坐标：转换为 GCJ-02 后显示在地图上
 - 境外的坐标：直接使用 WGS-84 显示
 - 判断依据：通过 CoordinateConverter.isOutOfChina() 判断

 ## 3. 位置信息的完整生命周期

 ### 3.1 获取位置（发送分享时）
 ```
 CLLocationManager
   ↓ (返回 WGS-84 坐标)
 设备 GPS 位置
   ↓
 判断是否在中国 (isOutOfChina)
   ↓
 如果在中国：转换为 GCJ-02 进行反地理编码 (获取地址名称)
 如果在境外：直接用 WGS-84 进行反地理编码
   ↓
 发送到服务器：WGS-84 坐标 + 地址字符串
   ↓
 服务器存储：WGS-84 格式
 ```

 ### 3.2 显示位置（查看分享时）
 ```
 从服务器/数据库获取：WGS-84 坐标
   ↓
 判断该坐标是否在中国 (isOutOfChina)
   ↓
 如果在中国：转换为 GCJ-02 后显示在 MapKit 上
 如果在境外：直接用 WGS-84 显示在 MapKit 上
   ↓
 MapKit 渲染地图标注
 ```

 ### 3.3 导航功能
 ```
 用户点击"查看路线"
   ↓
 获取目标坐标 (WGS-84)
   ↓
 根据不同导航应用需求转换：
   - 高德/百度：转换为 GCJ-02
   - Google/Apple：保持 WGS-84
   ↓
 打开对应导航应用
 ```

 ## 4. 已知的潜在风险和问题

 ### ✅ 风险 1：跨境查看的坐标系不匹配 [已修复]

 **问题描述**：
 MapKit 的底图坐标系会根据用户当前位置或地图中心点自动切换：
 - 在中国大陆：使用高德地图底图 (GCJ-02)
 - 在其他地区：使用 Apple Maps 底图 (WGS-84)

 原来的判断逻辑是基于**分享位置**是否在中国，而不是用户当前位置。

 **修复方案**：（已在 SearchViewModel.getAnnotations() 中实现）
 - 改为判断**用户当前位置**是否在中国
 - 如果用户在中国：所有标注转换为 GCJ-02
 - 如果用户在境外：所有标注保持 WGS-84
 - 如果用户位置不可用：使用地图中心点判断

 **修复效果**：
 ✅ 用户在美国查看中国的分享：标注和底图都是 WGS-84，无偏移
 ✅ 用户在中国查看美国的分享：标注和底图都是 GCJ-02，无偏移
 ✅ 标注坐标系始终与 MapKit 底图坐标系保持一致

 ### ⚠️ 风险 2：getCurrentWGS84Location() 方法存在逻辑错误

 **问题描述**：
 LocationService.swift 第 76-81 行的方法假设 currentLocation 是 GCJ-02 坐标，
 但实际上 CLLocationManager 返回的始终是 WGS-84 坐标。

 ```swift
 func getCurrentWGS84Location() -> CLLocationCoordinate2D? {
     if let currentLocation = self.currentLocation {
         // ❌ 错误：currentLocation 已经是 WGS-84，不应再次"转换"
         return CoordinateConverter.shared.gcj02ToWgs84(currentLocation)
     }
     return nil
 }
 ```

 **影响程度**：低
 - 此方法目前未被调用，但如果未来使用会导致坐标错误
 - 建议：删除此方法或修正逻辑

 ### ⚠️ 风险 3：边界判断的准确性

 **问题描述**：
 - isOutOfChina() 依赖 GCJ02.json 文件的边界数据
 - 如果边界数据不准确、不完整或过时，会导致误判
 - 边界附近的坐标（如边境地区）可能因浮点精度问题导致判断不稳定

 **影响程度**：低到中等
 - 大部分情况下边界判断是准确的
 - 极少数边境地区可能出现误判

 ### ⚠️ 风险 4：反地理编码的网络依赖

 **问题描述**：
 - CLGeocoder 需要网络连接才能获取地址
 - 在网络不佳或无网络时，无法获取地址字符串
 - 但坐标信息不受影响（已由 GPS 获取）

 **影响程度**：低
 - 只影响地址显示，不影响位置定位

 ### ✅ 确认正常的场景

 1. **用户在境外发送分享**
    - 设备获取：WGS-84 坐标
    - 存储：WGS-84
    - 境内用户查看：判断为境外，直接用 WGS-84 显示 ✅ 正确
    - 境外用户查看：判断为境外，直接用 WGS-84 显示 ✅ 正确

 2. **用户在境内发送分享，境内用户查看**
    - 设备获取：WGS-84 坐标
    - 存储：WGS-84
    - 显示：转换为 GCJ-02，与中国地图对齐 ✅ 正确

 3. **导航功能**
    - 高德/百度：使用 GCJ-02 坐标 ✅ 正确
    - Google/Apple Maps：使用 WGS-84 坐标 ✅ 正确

 ## 5. 改进建议

 1. **短期**：
    - 修复或删除 getCurrentWGS84Location() 方法
    - 添加坐标有效性检查（防止 0,0 或极端值）

 2. **中期**：
    - 考虑根据用户当前位置（而非分享位置）决定坐标转换策略
    - 在 UI 中提示用户跨境查看可能存在的偏移

 3. **长期**：
    - 实现动态检测 MapKit 底图类型，匹配坐标系
    - 考虑使用第三方地图 SDK 以获得更好的跨境支持

 ## 6. 相关文件

 - **CoordinateConverter.swift**: 坐标转换核心逻辑
 - **GCJ02.json**: 中国边界数据
 - **MainToolbar.swift**: 获取和发送位置信息
 - **SearchViewModel.swift**: 获取和显示分享位置
 - **ShareDetailsCardView.swift**: 导航功能实现

 ============================================
 */

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
