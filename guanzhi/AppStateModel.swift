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
    var errorMessage: String { get set }
    var showErrorAlert: Bool { get set }
    var uploadProgress: Double { get set }
    var useOverlayMode: Bool { get set }
    var didShowWelcomeToast: Bool { get set }
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
    var uploadProgress: Double = 0.0
    var errorMessage: String = ""
    var showErrorAlert: Bool = false
    var useOverlayMode: Bool = false
    var didShowWelcomeToast: Bool = false
}


enum Route: Hashable, Codable { //用于页面导航
    case myView
    case othersView(userId: Int)
    case settingView
    case shareDetailView(annotationID: String)
    case editProfileView
    case accountManagementView
    /// 从推送通知跳转到分享详情并定位评论
    case shareComment(shareId: Int64, commentId: Int64)
    /// 消息中心页面
    case messagesView
    /// 通知设置页面
    case notificationSettingsView

    // 定义用于编码和解码的键
    enum CodingKeys: String, CodingKey {
        case type
        case annotationID
        case userId
        case shareId
        case commentId
    }

    // 定义一个类型枚举，用于区分不同的 case
    enum RouteType: String, Codable {
        case myView
        case othersView
        case settingView
        case shareDetailView
        case editProfileView
        case accountManagementView
        case shareComment
        case messagesView
        case notificationSettingsView
    }
    
    // 实现 Encodable 协议
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .myView:
            try container.encode(RouteType.myView, forKey: .type)
        case .othersView(let userId):
            try container.encode(RouteType.othersView, forKey: .type)
            try container.encode(userId, forKey: .userId)
        case .settingView:
            try container.encode(RouteType.settingView, forKey: .type)
        case .shareDetailView(let annotationID):
            try container.encode(RouteType.shareDetailView, forKey: .type)
            try container.encode(annotationID, forKey: .annotationID)
        case .editProfileView:
            try container.encode(RouteType.editProfileView, forKey: .type)
        case .accountManagementView:
            try container.encode(RouteType.accountManagementView, forKey: .type)
        case .shareComment(let shareId, let commentId):
            try container.encode(RouteType.shareComment, forKey: .type)
            try container.encode(shareId, forKey: .shareId)
            try container.encode(commentId, forKey: .commentId)
        case .messagesView:
            try container.encode(RouteType.messagesView, forKey: .type)
        case .notificationSettingsView:
            try container.encode(RouteType.notificationSettingsView, forKey: .type)
        }
    }

    // 实现 Decodable 协议
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(RouteType.self, forKey: .type)
        switch type {
        case .myView:
            self = .myView
        case .othersView:
            let userId = try container.decode(Int.self, forKey: .userId)
            self = .othersView(userId: userId)
        case .settingView:
            self = .settingView
        case .shareDetailView:
            let annotationID = try container.decode(String.self, forKey: .annotationID)
            self = .shareDetailView(annotationID: annotationID)
        case .editProfileView:
            self = .editProfileView
        case .accountManagementView:
            self = .accountManagementView
        case .shareComment:
            let shareId = try container.decode(Int64.self, forKey: .shareId)
            let commentId = try container.decode(Int64.self, forKey: .commentId)
            self = .shareComment(shareId: shareId, commentId: commentId)
        case .messagesView:
            self = .messagesView
        case .notificationSettingsView:
            self = .notificationSettingsView
        }
    }
}

class NavigationCoordinator: ObservableObject {
    @Published var path = NavigationPath()
}


