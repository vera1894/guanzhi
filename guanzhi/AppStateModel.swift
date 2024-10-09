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
    func showingCameraToggle()
    func updateNearbyShareList(from newData: ResponsedNearbyShareList)
    func fetchNearbyShareList(latitude: Double, longitude: Double, radius: Double?)
    
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
    func showingCameraToggle() {
        isShowingCameraView.toggle()
    }
    
    // 存储数据的方法
    func updateNearbyShareList(from newData: ResponsedNearbyShareList) {
        print("Updating with data: \(newData)")
        self.responsedNearbyShareList = newData
    }
    
    /*OTOLoginStatusManager.shared.getUserID()*/
    
    func fetchNearbyShareList(latitude: Double, longitude: Double, radius: Double?) {
        let userId = 11

        Task {
            do {
                let data = try await OTONetwork.request(.fetchNearbyShareList(latitude: latitude, userId: userId, longitude: longitude, radius: radius))
                print("收到响应数据")

                let decoder = JSONDecoder()
                // 使用新的模型类型进行解码
                let response = try decoder.decode(OTOResponseModel<ResponsedNearbyShareList>.self, from: data)
                print("成功解码响应：\(response)")

                if let nearbyShareList = response.datas {
                    self.responsedNearbyShareList = nearbyShareList
                    print("解码后的数据：\(nearbyShareList)")
                }else {
                    print("未能解码 datas 字段")
                }
            } catch {
                print("获取或解码数据时出错：\(error)")
            }
        }
    }
    
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
    let records: [ResponsedShare]
    let total: Int
    let size: Int
    let current: Int
    let orders: [String]
    let optimizeCountSql: Bool
    let searchCount: Bool
    let countId: StringOrInt?      // 修改为 StringOrInt?
    let maxLimit: Int?             // 修改为 Int?
    let pages: Int
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
