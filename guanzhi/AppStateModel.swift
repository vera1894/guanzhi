//
//  AppStateModel.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/8/26.
//

import Observation
import SwiftUI
import Combine
import MapKit
import Photos

private struct AppStateKey: EnvironmentKey {
    static var defaultValue = AppStateModel()
}

extension EnvironmentValues {
    var appState: AppStateModel {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}

//@MainActor
protocol AppState: AnyObject {
    
    var isShowingCameraView: Bool { get set }
    var isShowingSearchView: Bool { get set }
    var isShowingResultCardView: Bool { get set }
    var isShowingShowMarker: Bool { get set }
    var isReadyToPost: Bool { get set }
    var isLoading: Bool { get set }
    var captureboxIsLoading: Bool { get set }
    var isPlayingLivePhoto: Bool { get set }
    var livePhotoTemporarily: PHLivePhoto? { get set }
    var postText: String { get set }
    var isPushingGuanzhi: Bool { get set }
    var isPushedGuanzhi: Bool { get set }
    var resultLocationName: String { get set }
    var resultLocation: CLLocationCoordinate2D { get set }
    var responsedNearbyShareList: ResponsedNearbyShareList?  { get set }
    
}

@Observable
class AppStateModel: AppState {
    // 定义所有窗口的显示开关变量
    var isShowingCameraView: Bool = false
    var isShowingSearchView: Bool = true
    var isShowingResultCardView: Bool = false
    var isShowingShowMarker: Bool = false
    var isReadyToPost: Bool = false
    var isLoading: Bool = false
    var captureboxIsLoading: Bool = false
    var isPlayingLivePhoto: Bool = false
    var livePhotoTemporarily: PHLivePhoto? = nil
    var postText: String = ""
    var isPushingGuanzhi: Bool = false
    var isPushedGuanzhi: Bool = false
    var resultLocationName: String = ""
    var resultLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
    var responsedNearbyShareList: ResponsedNearbyShareList? = nil
    
}


//服务器返回的Share模型
struct ResponsedShare: Codable, Equatable {
    let id: Int
    let createDate: Int
    let userId: Int
    let data: String
    let longitude: Double
    let latitude: Double
    let provinceCode: StringOrInt?  // 修改为 StringOrInt?
    let cityCode: StringOrInt?      // 修改为 StringOrInt?
    let districtCode: StringOrInt?  // 修改为 StringOrInt?
    let address: String
    let imagePath: String
    let title: String
    let deleted: Int
}

//服务器返回的附近Share列表模型
struct ResponsedNearbyShareList: Codable, Equatable {
    var records: [ResponsedShare]
    var total: Int
    let size: Int
    let current: Int
    let orders: [String]
    let optimizeCountSql: Bool
    let searchCount: Bool
    let countId: StringOrInt?      // 修改为 StringOrInt?
    let maxLimit: Int?             // 修改为 Int?
    let pages: Int
    mutating func merge(with newData: ResponsedNearbyShareList) {
        // 创建一个 Set 来存储已有的分享 ID，避免重复
        let existingIds = Set(self.records.map { $0.id })
        
        // 过滤掉重复的分享
        let newRecords = newData.records.filter { !existingIds.contains($0.id) }
        
        // 将新的分享添加到已有的记录中
        self.records.append(contentsOf: newRecords)
        
        // 更新其他属性（如需要）
        self.total += newRecords.count
        // 根据需要更新其他属性，如 size、pages 等
    }
}


enum StringOrInt: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
            return
        }
        if let int = try? container.decode(Int.self) {
            self = .int(int)
            return
        }
        if let double = try? container.decode(Double.self) {
            self = .double(double)
            return
        }
        throw DecodingError.typeMismatch(StringOrInt.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String, Int, or Double"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str):
            try container.encode(str)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let str):
            return str
        case .int(let int):
            return String(int)
        case .double(let double):
            return String(double)
        }
    }
}

////获取附近的分享
//func fetchNearbyShareList(latitude: Double, longitude: Double, radius: Double?) {
//    let userId = 11 // 示例 /*OTOLoginStatusManager.shared.getUserID()*/
//
//    Task {
//        do {
//            let data = try await OTONetwork.request(.fetchNearbyShareList(latitude: latitude, userId: userId, longitude: longitude, radius: radius))
//            let decoder = JSONDecoder()
//            let response = try decoder.decode(OTOResponseModel<ResponsedNearbyShareList>.self, from: data)
//
//            if let nearbyShareList = response.datas {
//                self.appState?.responsedNearbyShareList = nearbyShareList
//            }
//        } catch {
//            print("获取或解码数据时出错：\(error)")
//        }
//    }
//}
