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
    var isShowingShareDetailView: Bool { get set }
    var isShowingShowMarker: Bool { get set }
    var isShowMyView: Bool { get set }
    var isShowSettingView: Bool { get set }
    var isShowLogInView: Bool { get set }
    var isReadyToPost: Bool { get set }
    var isLoading: Bool { get set }
    var isShareImageExpanded: Bool { get set }
    var captureboxIsLoading: Bool { get set }
    var isPlayingLivePhoto: Bool { get set }
    var livePhotoTemporarily: PHLivePhoto? { get set }
    var postText: String { get set }
    var isPushingGuanzhi: Bool { get set }
    var isPushedGuanzhi: Bool { get set }
    var resultLocationName: String { get set }
    var resultLocation: CLLocationCoordinate2D { get set }
    var responsedNearbyShareList: ResponsedNearbyShareList?  { get set }
    var hasSetInitialRegion: Bool { get set }
    
}

@Observable 
class AppStateModel: AppState {
    // 定义所有窗口的显示开关变量
    var isShowingCameraView: Bool = false
    var isShowingSearchView: Bool = true
    var isShowingResultCardView: Bool = false
    var isShowingShareDetailView: Bool = false
    var isShowingShowMarker: Bool = false
    var isShowMyView: Bool = false
    var isShowSettingView: Bool = false
    var isShowLogInView: Bool = false
    var isReadyToPost: Bool = false
    var isLoading: Bool = false
    var isShareImageExpanded: Bool = false
    var captureboxIsLoading: Bool = false
    var isPlayingLivePhoto: Bool = false
    var livePhotoTemporarily: PHLivePhoto? = nil
    var postText: String = ""
    var isPushingGuanzhi: Bool = false
    var isPushedGuanzhi: Bool = false
    var resultLocationName: String = ""
    var resultLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
    var responsedNearbyShareList: ResponsedNearbyShareList? = nil
    var hasSetInitialRegion: Bool = false
    
}

enum Route: Hashable { //用于页面导航
    case myView
    case settingView
}


