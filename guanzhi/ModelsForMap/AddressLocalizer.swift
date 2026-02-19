//
//  AddressLocalizer.swift
//  guanzhi
//
//  Created by Claude Code on 2026/2/19.
//

import Foundation
import CoreLocation

/// 查看端地址本地化服务：根据查看者设备 locale 动态反编码坐标获取本地化地址
@MainActor
class AddressLocalizer: ObservableObject {
    static let shared = AddressLocalizer()

    // 缓存：shareId → 本地化地址
    private var cache: [Int64: String] = [:]
    private let geocoder = CLGeocoder()
    // 防止对同一 shareId 并发请求
    private var inFlight: Set<Int64> = []

    private init() {}

    /// 获取本地化地址（有缓存直接返回，无缓存返回 nil）
    func localizedAddress(for shareId: Int64) -> String? {
        return cache[shareId]
    }

    /// 异步反编码并缓存，完成后通过 objectWillChange 通知 UI 刷新
    func resolveAddress(for share: Share) async {
        let shareId = share.id
        if cache[shareId] != nil { return }
        guard !inFlight.contains(shareId) else { return }
        guard share.latitude != 0, share.longitude != 0 else { return }

        inFlight.insert(shareId)
        defer { inFlight.remove(shareId) }

        // 中国境内：WGS-84 → GCJ-02 后反编码
        let converter = CoordinateConverter.shared
        var coord = CLLocationCoordinate2D(latitude: share.latitude, longitude: share.longitude)
        if !converter.isOutOfChina(coord) {
            coord = converter.wgs84ToGcj02(coord)
        }

        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let pm = placemarks.first {
                let address = [pm.name, pm.locality, pm.administrativeArea, pm.country]
                    .compactMap { $0 }
                    .joined(separator: " ")
                cache[shareId] = address
                objectWillChange.send()
            }
        } catch {
            // 反编码失败，不缓存，下次重试
            #if DEBUG
            print("🌐 AddressLocalizer: 反编码失败 shareId=\(shareId): \(error)")
            #endif
        }
    }
}
