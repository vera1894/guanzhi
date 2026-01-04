//
//  SearchView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/14.
//

import SwiftUI
import MapKit
import UserNotifications

struct SearchView: View {
    
    let useOverlay = false // true: 使用overlay, false: 使用navigationDestination 显示分享详情

    // MARK: - Stage 1 临时开关：可一键切回旧 SwiftUI Map
    // 设为 true 使用新的 MKMapView，设为 false 使用旧的 SwiftUI Map
    // 地图模式切换开关
    let useMKMapView = true

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
    @State private var didPrime3D = false  // ✅ 追踪是否已激活 3D 按钮
    @State private var lastCamera: MapCamera?  // ✅ 保存最近的相机状态

    // MARK: - MKMapView 状态（Stage 1）
    @State private var shouldSetRegion = false  // 控制是否需要设置 region（搜索跳转）
    @State private var shouldCenterOnUser = false  // 控制是否定位到用户位置（点击定位按钮）
    @State private var shouldResetHeading = false  // 控制是否复位到正北（点击指南针按钮）
    @State private var shouldToggle3D = false  // 控制是否切换 3D 模式（点击 3D 按钮）
    @State private var is3DMode = false  // 当前是否为 3D 模式
    @State private var mkMapView: MKMapView?  // MKMapView 引用（用于 MKCompassButton）

    // MARK: - Stage 2: 聚合列表状态
    @State private var clusterAnnotations: [CustomAnnotation] = []  // 聚合内的标注
    @State private var isShowingClusterList = false  // 是否显示聚合列表

    // MARK: - 标注点击处理（Stage 1 提取，供 SwiftUI Map 和 MKMapView 共用）
    private func handleAnnotationTap(annotation: CustomAnnotation, thumbnailImage: UIImage?) {
        print("点击标注")
        searchViewModel.selectAnnotation(annotation, thumbnailImage: thumbnailImage)
        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.4)) {
            appState.isShowingSearchView = false
            if appState.useOverlayMode {
                searchViewModel.isShareDetailOverlayShown = true
                print("searchViewModel.isShareDetailOverlayShown 为 \(searchViewModel.isShareDetailOverlayShown)")
            } else {
                navigationCoordinator.path.append(Route.shareDetailView(annotationID: annotation.id))
            }
        }
    }

    /// 激活 3D 按钮：轻抬 pitch 到 1° 再回到 0°
    /// 等效于用户双指上托一次，但视觉上保持 2D
    private func prime3DButton() {
        // 取当前相机（没有就用当前区域中心）
        let base = lastCamera ?? MapCamera(
            centerCoordinate: searchViewModel.region.center,
            distance: 3000,
            heading: 0,
            pitch: 0
        )

        // 轻抬到 1°（触发 3D 能力）
        withAnimation(.easeInOut(duration: 0.2)) {
            position = .camera(
                MapCamera(
                    centerCoordinate: base.centerCoordinate,
                    distance: base.distance,
                    heading: base.heading,
                    pitch: max(1, base.pitch)
                )
            )
        }

        // 立刻回到 0°，保持 2D 外观（但按钮已激活）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.2)) {
                position = .camera(
                    MapCamera(
                        centerCoordinate: base.centerCoordinate,
                        distance: base.distance,
                        heading: base.heading,
                        pitch: 0
                    )
                )
            }
        }
    }

    var body: some View {
        @Bindable var appState = appState

        /*ToastRootView*/ ZStack {
            if !OTOLoginStatusManager.shared.isLoggedIn {
                // 显示登录页面
                LogInView(userlogin: userlogin)
            } else {
//                NavigationStack(path: $navigationCoordinator.path) {
                    ZStack{
                        // MARK: - 地图层（Stage 1: 支持 MKMapView 和 SwiftUI Map 切换）
                        Group {
                        if useMKMapView {
                            // ===== 新版：MKMapView (Stage 1) =====
                            MKMapViewWrapper(
                                region: $searchViewModel.region,
                                annotations: searchViewModel.annotations,
                                onAnnotationTap: { annotation, thumbnailImage in
                                    handleAnnotationTap(annotation: annotation, thumbnailImage: thumbnailImage)
                                },
                                onClusterTap: { annotations in
                                    // Stage 2: 聚合点击 -> 显示列表，同时隐藏搜索栏 sheet
                                    print("点击聚合，包含 \(annotations.count) 个标注")
                                    clusterAnnotations = annotations
                                    appState.isShowingSearchView = false
                                    isShowingClusterList = true
                                },
                                onRegionChange: { newRegion in
                                    // 只更新 ViewModel，不触发 updateUIView 重设 region
                                    searchViewModel.region = newRegion
                                    searchViewModel.scheduleAnnotationUpdate()
                                },
                                showsUserLocation: true,
                                shouldSetRegion: $shouldSetRegion,
                                shouldCenterOnUser: $shouldCenterOnUser,
                                shouldResetHeading: $shouldResetHeading,
                                shouldToggle3D: $shouldToggle3D,
                                is3DMode: $is3DMode,
                                onMapViewCreated: { mapView in
                                    self.mkMapView = mapView
                                }
                            )
                            .disabled(searchViewModel.isShareDetailOverlayShown)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .ignoresSafeArea(.all)
                            .onAppear {
                                // 首次加载，请求定位
                                locationManager.requestLocation()
                            }
                            .onReceive(locationManager.$currentLocation) { location in
                                if let location = location, !appState.hasSetInitialRegion {
                                    // 首次获取位置：触发精确定位（类似点击定位按钮）
                                    shouldCenterOnUser = true
                                    appState.hasSetInitialRegion = true
                                    searchViewModel.fetchAllShares(latitude: location.latitude, longitude: location.longitude)
                                }
                            }
                        } else {
                            // ===== 旧版：SwiftUI Map（回退开关） =====
                            Map(position: $position,
                                interactionModes: [.pan, .zoom, .rotate, .pitch],
                                scope: mapScope) {
                                if !searchViewModel.isShareDetailOverlayShown {
                                    ForEach(searchViewModel.annotations, id: \.id) { annotation in
                                        Annotation("", coordinate: annotation.coordinate, anchor: .bottom) {
                                            MapAnnotationView(
                                                animationNamespace: animationNamespace,
                                                annotation: annotation,
                                                onTap: { uiImage in
                                                    handleAnnotationTap(annotation: annotation, thumbnailImage: uiImage)
                                                }
                                            )
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
                            }
                            .coordinateSpace(name: "shared")
                            .disabled(searchViewModel.isShareDetailOverlayShown)
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
                            .onMapCameraChange(frequency: .continuous) { context in
                                lastCamera = context.camera
                                searchViewModel.region = context.region
                                searchViewModel.scheduleAnnotationUpdate()
                            }
                            .task {
                                guard !didPrime3D else { return }
                                didPrime3D = true
                                try? await Task.sleep(nanoseconds: 800_000_000)
                                prime3DButton()
                            }
                            .onReceive(locationManager.$currentLocation) { location in
                                if let location = location, !appState.hasSetInitialRegion {
                                    position = .userLocation(followsHeading: false, fallback: .automatic)
                                    appState.hasSetInitialRegion = true
                                    searchViewModel.fetchAllShares(latitude: location.latitude, longitude: location.longitude)
                                }
                            }
                        }
                        } // End Group
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
                                MapOverlayView(
                                    mapScope: mapScope,
                                    position: $position,
                                    useMKMapView: useMKMapView,
                                    mkMapView: mkMapView,
                                    shouldCenterOnUser: $shouldCenterOnUser,
                                    shouldResetHeading: $shouldResetHeading,
                                    shouldToggle3D: $shouldToggle3D,
                                    is3DMode: $is3DMode
                                )  // ✅ 传递 mapScope 和 MKMapView 状态
                                .environment(appState)
                                .environmentObject(searchViewModel)
                                .environmentObject(locationManager)
                                .environmentObject(navigationCoordinator)
                                .environmentObject(userProfileManager)
                                .transition(.move(edge: .trailing))
                            }

                        }
                        // MARK: - 网络错误提示
                        .overlay(alignment: .top) {
                            if searchViewModel.nearbySharesState.hasError {
                                NetworkErrorBanner(
                                    message: "加载失败",
                                    onRetry: {
                                        searchViewModel.refreshNearbyShares(reason: .manual)
                                    }
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .animation(.spring(response: 0.3), value: searchViewModel.nearbySharesState.hasError)
                            }
                        }
                        .sheet(isPresented: $appState.isShowingSearchView) { // 显示 SheetView
                            SheetView(
                                currentDetent: $currentDetent,
                                onLocationSelected: { coordinate, title in
                                    // 创建新的 LocationMarker 并添加到 locationMarkers 数组中
                                    let marker = LocationMarker(coordinate: coordinate, title: title)
                                    locationMarkers.append(marker)
                                    // 更新地图区域
                                    let newRegion = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                                    searchViewModel.region = newRegion
                                    // Stage 1: 同时支持两种地图
                                    if useMKMapView {
                                        shouldSetRegion = true  // 触发 MKMapView 更新
                                    } else {
                                        position = .region(newRegion)  // SwiftUI Map
                                    }
                                    // 关闭 SheetView
                                    appState.isShowingSearchView = false
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
                        // MARK: - Stage 2: 聚合列表 sheet（与主页搜索结果卡片风格一致）
                        .sheet(isPresented: $isShowingClusterList, onDismiss: {
                            // sheet 关闭时恢复搜索栏
                            clusterAnnotations = []
                            appState.isShowingSearchView = true
                        }) {
                            ClusterShareListView(
                                annotations: clusterAnnotations,
                                onDismiss: {
                                    isShowingClusterList = false
                                }
                            )
                            .environment(appState)
                            .environmentObject(searchViewModel)
                            .environmentObject(navigationCoordinator)
                            .presentationDetents([.medium, .large])
                            .presentationDragIndicator(.visible)
                            .presentationCornerRadius(Constants.sheetCornerRadius)
                            .presentationBackgroundInteraction(.enabled)
                        }

                    } //ZStack
                    .mapScope(mapScope)  // ✅ 添加环境注入，确保 overlay 中的控件也能访问 scope
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
                    if newValue {
                        showNotification()
                        // Refresh map data with a delay to ensure server indexing
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            if let location = locationManager.currentLocation {
                                print("🔄 SearchView: 刷新分享列表 (延迟1.5秒)")
                                searchViewModel.fetchAllShares(latitude: location.latitude, longitude: location.longitude)
                            }
                        }
                        // Reset the flag
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            appState.isPushedGuanzhi = false
                        }
                    }
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
            Task {
                do {
                    var myUserId = OTOLoginStatusManager.shared.getUserID()

                    // 如果已登录但 userId 为 0，先从后端获取用户信息并保存 userId
                    if myUserId == 0 && OTOLoginStatusManager.shared.isLoggedIn {
                        print("⚠️ SearchView: userId 为 0，尝试从后端获取...")
                        myUserId = try await fetchAndSaveCurrentUserId()
                    }

                    // 只有 userId 有效时才获取完整用户信息
                    if myUserId > 0 {
                        try await userProfileManager.fetchUserFullInfo(userId: myUserId)
                        // 确保在主线程初始化头像
                        await MainActor.run {
                            userProfileManager.initializeAvatar()
                        }
                    } else {
                        print("⚠️ SearchView: 无法获取有效的 userId")
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

            // 登录后请求通知权限并注册 APNs
            if OTOLoginStatusManager.shared.isLoggedIn {
                await requestNotificationPermission()
            }
        }
        
    }
    
    
    // MARK: - Functions

    /// 从后端获取当前用户 ID 并保存到本地
    /// 用于处理登录后 userId 未正确保存的情况
    private func fetchAndSaveCurrentUserId() async throws -> Int {
        let data = try await OTONetwork.request(.userInfo)
        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<dataModel>.self, from: data)

        guard response.respCode == 0, let datas = response.datas, let userId = datas.id, userId > 0 else {
            throw NSError(domain: "SearchView", code: -1, userInfo: [
                NSLocalizedDescriptionKey: response.respMsg ?? "获取用户信息失败"
            ])
        }

        // 保存 userId 到 OTOLoginStatusManager
        OTOLoginStatusManager.shared.setUserID(userId)
        print("✅ SearchView: 成功获取并保存 userId: \(userId)")
        return userId
    }

    /// 请求通知权限并注册 APNs
    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                print("✅ 通知权限已授权")
                // 在主线程注册 APNs
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("⚠️ 用户拒绝通知权限")
            }
        } catch {
            print("❌ 请求通知权限失败: \(error.localizedDescription)")
        }
    }

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






