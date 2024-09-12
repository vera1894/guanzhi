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
    func showingCameraToggle()
//    func create() async -> AppStateModel
    
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
//    var isShowingSettingsView: Bool = false
    
//    private var _isShowingCameraView: Bool = false
//    var isShowingCameraView: Bool {
//        get { return _isShowingCameraView }
//        set { _isShowingCameraView = newValue }
//    }
    
//    private var _isShowingSearchView: Bool = false
//    var isShowingSearchView: Bool {
//        get { return _isShowingSearchView }
//        set { _isShowingSearchView = newValue }
//    }

        func showingCameraToggle() {
            isShowingCameraView.toggle()
        }
    
    // 可以根据需求添加更多的显示开关变量
    
}
