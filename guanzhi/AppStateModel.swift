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
    
    
//    func fetchNearbyShareList(latitude: Double, longitude: Double, radius: Double?) {
//        let userId = 11
//
//        Task {
//            guard let responseData = try? await OTONetwork.request(.fetchNearbyShareList(latitude: latitude, userId: userId, longitude: longitude, radius: radius)) else { return }
//            print("Response data received: \(responseData)")
//            
//            do {
//                let decoder = JSONDecoder()
//                if let jsonData = try? JSONSerialization.data(withJSONObject: responseData, options: []) {
//                    let response = try decoder.decode(OTOResponseModel.self, from: jsonData)
//                    print("Response decoded successfully: \(response)")
//                    
//                    // 判断 datas 类型
//                    if let datasDict = response.datas?.value as? [String: Any],
//                       let records = datasDict["records"] as? [[String: Any]] {
//                        responsedNearbyShareListDict = records
//                    } else if let datasString = response.datas?.value as? String {
//                        print("Datas as string: \(datasString)")
//                    }
//                }
//            } catch {
//                print("Error decoding response: \(error)")
//            }
//        }
//    }
    
    
}


//服务器返回的Share模型
struct ResponsedShare: Codable {
    let id: Int
    let createDate: Int
    let userId: Int
    let data: String
    let longitude: Double      // 修改为 Double 类型
    let latitude: Double       // 修改为 Double 类型
    let provinceCode: String?  // 可选类型
    let cityCode: String?      // 可选类型
    let districtCode: String?  // 可选类型
    let address: String
    let imagePath: String
    let title: String
    let deleted: Int
}

//服务器返回的附近Share列表模型
struct ResponsedNearbyShareList: Codable {
    let records: [ResponsedShare]
    let total: Int
    let size: Int
    let current: Int
    let orders: [String]
    let optimizeCountSql: Bool
    let searchCount: Bool
    let countId: String?      // 修改为可选类型
    let maxLimit: Int?        // 修改为可选类型
    let pages: Int
}
