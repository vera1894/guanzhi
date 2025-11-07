//
//  SearchView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/14.
//

import SwiftUI
import MapKit

struct SearchView: View {
    
    let useOverlay = false // true: 使用overlay, false: 使用navigationDestination 显示分享详情
    var animationNamespace: Namespace.ID
    @Namespace var mapScope
//    @Namespace private var animationNamespace
    @ObservedObject var userlogin : UserLoginModel
    @Environment(\.appState) var appState
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.modelContext) private var context
    @EnvironmentObject var searchViewModel: SearchViewModel
    @EnvironmentObject var toastManager: ToastManager
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
//    @StateObject var navigationCoordinator = NavigationCoordinator()
    
    @State private var detents: Set<PresentationDetent> = [.height(Constants.sheetCollapsedHeight), .fraction(Constants.sheetExpandedFraction)]
    @State private var currentDetent: PresentationDetent = .height(Constants.sheetCollapsedHeight) // 用于跟踪当前 SheetView 的高度
    @State private var image: UIImage?

    @State private var annotations: [MKAnnotation] = []
    @State private var position: MapCameraPosition = .automatic
    @State private var locationMarkers: [LocationMarker] = []
    @State private var mapSize: CGSize = .zero
    @State private var isAnimating: Bool = false
    
    var body: some View {
        @Bindable var appState = appState
        
        /*ToastRootView*/ ZStack {
            if !OTOLoginStatusManager.shared.isLoggedIn {
                // 显示登录页面
                LogInView(userlogin: userlogin)
            } else {
//                NavigationStack(path: $navigationCoordinator.path) {
                    ZStack{
                        Map(position: $position,interactionModes: .all) {
                            if !searchViewModel.isShareDetailOverlayShown/*appState.isShareImageExpanded*/ {
                                ForEach(searchViewModel.annotations, id: \.id) { annotation in
                                    Annotation("", coordinate: annotation.coordinate, anchor: .bottom) {
                                        MapAnnotationView(
                                            animationNamespace: animationNamespace,
                                            annotation: annotation,
                                            onTap: { uiImage in
                                                print("点击标注")
                                                searchViewModel.selectAnnotation(annotation, thumbnailImage: uiImage)
                                                withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.4)) {
                                                        appState.isShowingSearchView = false
                                                    if appState.useOverlayMode {
                                                        /*appState.isShareImageExpanded*/searchViewModel.isShareDetailOverlayShown = true  // 启用overlay模式
                                                        print("searchViewModel.isShareDetailOverlayShown 为 \(searchViewModel.isShareDetailOverlayShown)")
                                                    } else {
                                                        navigationCoordinator.path.append(Route.shareDetailView(annotationID: annotation.id)) // 导航模式
                                                    }
                                                    }
                                            }
                                        )
//                                        .matchedGeometryEffect(id: "sharedElement\(annotation.id)", in: animationNamespace)
                                        .environment(appState)
                                        .environmentObject(searchViewModel)
                                        .id(annotation.id)
                                    }
                                    
                                }
                            }
                            ForEach(locationMarkers) { marker in
                                    Marker(marker.title ?? "", coordinate: marker.coordinate)
                                }
                            UserAnnotation()
                            
//                            MainMapContent(
//                                    searchViewModel: searchViewModel,
//                                    locationMarkers: locationMarkers,
//                                    animationNamespace: animationNamespace
//                                )
                        }
                        .mapScope(mapScope)
                        .coordinateSpace(name: "shared")
                        .disabled(/*appState.isShareImageExpanded*/searchViewModel.isShareDetailOverlayShown)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .mapStyle(.standard(elevation: .realistic))
                        .ignoresSafeArea(.all)
                        .animation(.spring(), value: searchViewModel.selectedLocation)
                        .onAppear {
                            if !appState.hasSetInitialRegion {
                                    position = .automatic
                                } else {
                                    position = .region(searchViewModel.region)
                                }
                            locationManager.requestLocation()
                        }
                        .onMapCameraChange { context in
                            let region = context.region
                            searchViewModel.region = region
                            // 更新地图上的标注
                            searchViewModel.scheduleAnnotationUpdate()
                        }
                        .onReceive(locationManager.$currentLocation) { location in
                            if let location = location, !appState.hasSetInitialRegion {
                                // 使用用户当前位置初始化地图区域
                                let userRegion = MKCoordinateRegion(center: location, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                                searchViewModel.region = userRegion
                                position = .region(userRegion)
                                appState.hasSetInitialRegion = true
                                // 获取分享数据
                                searchViewModel.fetchAllShares(latitude: location.latitude, longitude: location.longitude)
                            }
                        }
                        .onChange(of: appState.responsedNearbyShareList) { _ , newValue in
                            print("Nearby share list updated")
                            searchViewModel.getAnnotations()
                        }
                        
                        .onChange(of: searchViewModel.searchResults) {
                            print("Search Results Changed: \(searchViewModel.searchResults)")
                            if let firstResult = searchViewModel.searchResults.first {
                                DispatchQueue.main.async {
                                    print("First Search Result Selected: \(firstResult)")
                                    searchViewModel.selectedLocation = firstResult
                                    appState.isShowingShowMarker = true
                                }
                            }
                        }
                        .onChange(of: appState.isShowingResultCardView) { _ , isShowing in
                            print("Is Show Result Card Changed: \(appState.isShowingResultCardView)")
                            if !isShowing {
                                searchViewModel.selectedLocation = nil
                                searchViewModel.searchResults.removeAll()
                                appState.isShowingShowMarker = false
                                searchViewModel.getAnnotations()
                                }
                        }
                        .onChange(of: appState.isShowingShowMarker) { _, _ in
                            DispatchQueue.main.async {
                                searchViewModel.getAnnotations()
                                print("Annotations updated due to isShowingShowMarker change")
                            }
                        }
                        .overlay(alignment:.bottomTrailing) {
                            if appState.isShowingSearchView{
                                MapOverlayView(position: $position)
                                .environment(appState)
                                .environmentObject(searchViewModel)
                                .environmentObject(locationManager)
                                .environmentObject(navigationCoordinator)
                                .transition(.move(edge: .trailing))
                            }

                        }
                        .sheet(isPresented: $appState.isShowingSearchView) { // 显示 SheetView
                            SheetView(
                                currentDetent: $currentDetent,
                                onLocationSelected: { coordinate, title in
    //                                // 创建新的 LocationMarker 并添加到 locationMarkers 数组中
                                    let marker = LocationMarker(coordinate: coordinate, title: title)
                                    locationMarkers.append(marker)
                                    // 更新地图位置
                                    position = .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
                                    // 关闭 SheetView
                                    appState.isShowingSearchView = false
                                    // 更新地图区域
                                    searchViewModel.region.center = coordinate
                                }
                            )
                            // iOS 26 修复：移除 .id(UUID()) 以保持视图状态和 presentationDetents
                            .environment(appState)
                            .environmentObject(searchViewModel)
                            .presentationDetents([.height(Constants.sheetCollapsedHeight), .fraction(Constants.sheetExpandedFraction)], selection: $currentDetent)
                            .presentationDragIndicator(.hidden)
                            .presentationCornerRadius(Constants.sheetCornerRadius)
                            .presentationBackground(.regularMaterial)
                            .presentationBackgroundInteraction(.enabled)
                            .presentationContentInteraction(.scrolls)
                            .interactiveDismissDisabled()
                            .presentationCompactAdaptation(.none)
                        }
                        .sheet(isPresented: $appState.isShowingResultCardView) {  // 显示 ResultCardView
                            ResultCardView(
                                sesrchViewHight: $currentDetent,
                                onClose: {
                                    // 移除地点标记
                                    locationMarkers.removeAll()
                                    // 更新状态
                                    appState.isShowingShowMarker = false
                                    appState.isShowingSearchView = true
                                    appState.isShowingResultCardView = false
                                    currentDetent = .height(Constants.sheetCollapsedHeight)
                                }
                            )
                            .environment(appState)
                            .environmentObject(searchViewModel)
                            .animation(.spring(), value: appState.isShowingResultCardView)
                            .presentationDragIndicator(.hidden)
                            .interactiveDismissDisabled(true)
                        }
                        .navigationDestination(isPresented: $appState.isShowingCameraView) {
                            CameraViewWrapper(appState: appState)
                        }
                        
//                        //显示分享详情
//                        if appState.isShareImageExpanded {
//                            ShareDetailView(searchViewModel: searchViewModel, animationNamespace: animationNamespace, annotationID: searchViewModel.selectedAnnotationID ?? "")
//                                .environment(appState)
//                                .environmentObject(searchViewModel)
//                                .transition(.move(edge: .bottom))
//                        }
                        
                    } //ZStack
//                    .navigationDestination(for: Route.self) { route in
//                        switch route {
//                        case .myView:
//                            MyView()
//                                .environment(appState)
//                                .environmentObject(navigationCoordinator)
//                                .environmentObject(userProfileManager)
//                                .environmentObject(searchViewModel)
//                        case .settingView:
//                            SettingView()
//                                .environment(appState)
//                                .environmentObject(navigationCoordinator)
//                        case .shareDetailView(let annotationID):
//                            ShareDetailView(searchViewModel: searchViewModel, animationNamespace: animationNamespace, annotationID: annotationID)
//                                .environment(appState)
//                                .environmentObject(searchViewModel)
//                                .environmentObject(navigationCoordinator)
//                                .matchedGeometryEffect(id: "sharedElement\(annotationID)", in: animationNamespace)
//                        }
//                    }
//                    .toolbar(appState.isShareImageExpanded ? .visible : .hidden, for: .navigationBar)
                    .toolbar(.hidden, for: .navigationBar)
//                } //NavStack
                .environmentObject(navigationCoordinator)
                .ignoresSafeArea(.all)
                .onChange(of: appState.isPushedGuanzhi) { oldValue, newValue in
                    showNotification()
                }
    //            .onChange(of: locationManager.locationErrorDescription) { _ , errorDescription in
    //                if let errorDescription = errorDescription {
    //                    print("位置错误：\(errorDescription)")
    //                    // 可以在这里显示一个错误提示给用户
    //                }
    //            }
            } //else
        } //ToastRootView
        .onAppear {
            if searchViewModel.context == nil {
                searchViewModel.context = context
                searchViewModel.appState = appState
                searchViewModel.locationManager = locationManager
                searchViewModel.initializeData()
            }
            if userProfileManager.context == nil {
                    userProfileManager.context = context
                }

            // 初始化用户信息和头像
            let myUserId = OTOLoginStatusManager.shared.getUserID()
            Task {
                do {
                    try await userProfileManager.fetchUserFullInfo(userId: myUserId)
                    // 确保在主线程初始化头像
                    await MainActor.run {
                        userProfileManager.initializeAvatar()
                    }
                } catch {
                    print("在 SearchView 里拉取本机用户信息报错：\(error)")
                }
            }
        }
//        .disabled(appState.isShareImageExpanded)
        .task{
            locationManager.requestLocation()
            if !appState.didShowWelcomeToast {
                appState.didShowWelcomeToast = true
                let newItem = ToastItem(style: .notificationOfWelcome(
                    title: "🌍世界虽大 吾可观之👀",
                    symbol: "",
                    tint: Color("color-primary"),
                    isUserInteractionEnabled: true,
                    timing: .medium,
                    isAutoClose: true
                ))
                toastManager.show(newItem)
            }
        }
        
    }
    
    
    // MARK: - Functions
    
    private func showNotification() {
        if appState.isPushedGuanzhi {
            let newItem = ToastItem(style: .notificationOnly(
                title: "🌍 发布成功",
                symbol: "",
                tint: Color("color-primary"),
                isUserInteractionEnabled: true,
                timing: .short,
                isAutoClose: true
            ))
            toastManager.show(newItem)
        }
    }
    
    func initializePage() {
        if !appState.hasSetInitialRegion {
            appState.hasSetInitialRegion = true
                locationManager.requestLocation()
            }
        }
    
    func loadImage(url: URL, completion: @escaping (UIImage?) -> Void) {  //检查是否需要
        let cacheKey = url.absoluteString
        if let cachedImage = ImageCache.shared.image(forKey: cacheKey) {
            completion(cachedImage)
        } else {
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data, let downloadedImage = UIImage(data: data) {
                    ImageCache.shared.setImage(downloadedImage, forKey: cacheKey)
                    completion(downloadedImage)
                } else {
                    completion(nil)
                }
            }.resume()
        }
    }
    
}

//===================================

struct SearchView_Previews: PreviewProvider {
    @Namespace static var animationNamespace
    
    static var previews: some View {
        // 通过调用 login(token:) 方法来模拟登录状态
        OTOLoginStatusManager.shared.login(token: "test_token")
        
        return SearchView(animationNamespace: animationNamespace, userlogin: UserLoginModel())
            .environment(\.appState, AppStateModel())
            .environmentObject(LocationManager())
            .environmentObject(SearchViewModel())
            .environmentObject(ToastManager())
            .environmentObject(UserProfileManager())
            .environmentObject(NavigationCoordinator())
    }
}

//===================================






