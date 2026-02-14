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

    // MARK: - 聚合列表显示模式开关
    // true: 使用 overlay（无 sheet 冲突，动画可控）
    // false: 使用 sheet（iOS 原生体验）
    let useOverlayForClusterList = true

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
    @EnvironmentObject var onboardingCoordinator: OnboardingCoordinator
    @EnvironmentObject var loginManager: OTOLoginStatusManager  // ✅ 登录状态管理
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
    @State private var clusterListDetent: PresentationDetent = .medium  // 当前 sheet 高度
    @State private var clusterListSession = UUID()  // 每次打开 sheet 的会话 ID，用于重置内部 @State
    // ✅ savedClusterAnnotations/savedClusterListDetent/savedScrollToShareId 已移到 SearchViewModel 中
    // 避免视图重建导致状态丢失（导航到用户主页再返回时的问题）
    // ✅ appState.shouldRestoreClusterList 已移到 AppStateModel 中，其他页面可访问

    // MARK: - 标注点击处理（Stage 1 提取，供 SwiftUI Map 和 MKMapView 共用）
    private func handleAnnotationTap(annotation: CustomAnnotation, thumbnailImage: UIImage?) {
        print("点击标注")
        // 【Onboarding】发送标注点击事件
        onboardingCoordinator.handleEvent(.annotationTapped)
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

    /// 将 CustomAnnotation 数组转换为 ResponsedShare 数组
    /// 优先从 SearchViewModel 的缓存获取原始数据（包含正确的 fadeScore）
    private func convertAnnotationsToShares(_ annotations: [CustomAnnotation]) -> [ResponsedShare] {
        return annotations.compactMap { annotation -> ResponsedShare? in
            guard let share = annotation.annotationData else { return nil }
            let shareId = Int(share.id)

            // 优先从缓存获取原始的 ResponsedShare（包含正确的 fadeScore 等字段）
            if let cached = searchViewModel.cachedResponsedShares[shareId] {
                return cached
            }

            // 回退：从本地 Share 对象转换
            return ResponsedShare(
                id: shareId,
                createDate: Int(share.createDate.timeIntervalSince1970) * 1000,
                userId: Int(share.userId),
                data: share.data,
                longitude: share.longitude,
                latitude: share.latitude,
                provinceCode: nil,
                cityCode: nil,
                districtCode: nil,
                address: share.address,
                imagePath: share.imagePathsString ?? "",
                title: share.title,
                deleted: 0,
                agreeCount: share.agreeCount,
                neutralCount: share.neutralCount,
                checkinCount: share.checkinCount,
                commentCount: share.commentCount,
                currentUserVoteType: nil,
                fadeScore: share.fadeScore
            )
        }
    }

    /// 聚合列表内容（供 sheet 和 overlay 两种模式共用）
    @ViewBuilder
    private var clusterListContent: some View {
        VStack(spacing: 0) {
            // 顶部标题栏（居中显示）
            Text("这里有 \(clusterAnnotations.count) 条观之")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color("text-gray"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Constants.spacingSpacingM)

            Divider()

            // UITableView 列表
            HostingTableView(
                items: convertAnnotationsToShares(clusterAnnotations),
                id: \.id,
                row: { share in
                    ShareSingleView(share: share, onTap: {
                        print("🔷 [ClusterList] 点击了 share.id=\(share.id)")
                        // 【Onboarding】触发标注点击事件（用于步骤 B）
                        onboardingCoordinator.handleEvent(.annotationTapped)
                        // 保存状态用于恢复（使用 SearchViewModel 存储，避免视图重建导致状态丢失）
                        searchViewModel.savedClusterAnnotations = clusterAnnotations
                        searchViewModel.savedClusterListDetent = clusterListDetent
                        searchViewModel.savedScrollToShareId = share.id
                        appState.shouldRestoreClusterList = true
                        print("🔷 [ClusterList] 保存了 \(clusterAnnotations.count) 条标注，detent=\(clusterListDetent)，scrollTo=\(share.id)，标记需要恢复")

                        // 关闭列表
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isShowingClusterList = false
                        }

                        // 延迟进入详情（overlay 模式可用更短延迟）
                        let delay = useOverlayForClusterList ? 0.05 : 0.1
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            if appState.useOverlayMode {
                                searchViewModel.selectedAnnotationID = "\(share.id)"
                                searchViewModel.loadShareDetail(for: Int64(share.id))
                                searchViewModel.isShareDetailOverlayShown = true
                            } else {
                                navigationCoordinator.path.append(Route.shareDetailView(annotationID: "\(share.id)"))
                            }
                        }
                    })
                        .environment(appState)
                        .environmentObject(searchViewModel)
                        .environmentObject(navigationCoordinator)
                },
                bouncesEnabled: true,
                endFooterStyle: .text("- 到底啦 -"),
                restoreToID: searchViewModel.savedScrollToShareId,
                estimatedRowHeight: 133
            )
        }
        .id(clusterListSession)
    }

    /// 恢复聚合列表（如果之前因进入详情而隐藏）
    private func restoreClusterListIfNeeded() {
        let pathCount = navigationCoordinator.path.count
        print("🔷 [ClusterList] restoreClusterListIfNeeded called, shouldRestore=\(appState.shouldRestoreClusterList), pathCount=\(pathCount), savedCount=\(searchViewModel.savedClusterAnnotations.count)")

        // ✅ 关键修复：只有当导航栈完全清空时才恢复聚合列表
        // 这样从嵌套的详情页（如 OthersView 的 ShareListView 进入的详情页）返回时不会触发恢复
        guard navigationCoordinator.path.isEmpty else {
            print("🔷 [ClusterList] 导航栈不为空（pathCount=\(pathCount)），跳过恢复")
            return
        }

        guard appState.shouldRestoreClusterList else {
            print("🔷 [ClusterList] shouldRestoreClusterList=false，跳过恢复")
            return
        }

        guard !searchViewModel.savedClusterAnnotations.isEmpty else {
            print("🔷 [ClusterList] savedClusterAnnotations 为空，跳过恢复")
            return
        }

        // 先关闭可能正在显示的搜索栏 sheet（避免 sheet 冲突）
        appState.isShowingSearchView = false

        // 恢复聚合列表（从 SearchViewModel 读取保存的状态）
        clusterAnnotations = searchViewModel.savedClusterAnnotations
        clusterListDetent = searchViewModel.savedClusterListDetent

        if useOverlayForClusterList {
            // Overlay 模式：无需延迟和动画，瞬间出现（skipAnimation 会处理）
            isShowingClusterList = true
            searchViewModel.savedClusterAnnotations = []
            print("🔷 [ClusterList] 已恢复聚合列表（overlay瞬间出现），共 \(clusterAnnotations.count) 条")

            // ✅ 关键修复：延迟重置 shouldRestoreClusterList
            // 让所有 onDisappear 回调（OthersView/MyView 等）先执行完毕
            // 否则这些回调会检测到 shouldRestoreClusterList=false，错误地设置 isShowingSearchView=true
            let appStateRef = appState
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appStateRef.shouldRestoreClusterList = false
                print("🔷 [ClusterList] 延迟重置 shouldRestoreClusterList = false")
            }
        } else {
            // Sheet 模式：需要短暂延迟避免 sheet 冲突
            let appStateRef = appState
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isShowingClusterList = true
                }
                searchViewModel.savedClusterAnnotations = []
                print("🔷 [ClusterList] 已恢复聚合列表（sheet），共 \(clusterAnnotations.count) 条，detent=\(clusterListDetent)，scrollTo=\(String(describing: searchViewModel.savedScrollToShareId))")

                // ✅ 关键修复：延迟重置 shouldRestoreClusterList
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    appStateRef.shouldRestoreClusterList = false
                    print("🔷 [ClusterList] 延迟重置 shouldRestoreClusterList = false")
                }
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
            if !loginManager.isLoggedIn {
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
                                    // 【Onboarding】点击聚合标注也视为完成步骤 B
                                    onboardingCoordinator.handleEvent(.annotationTapped)
                                    clusterAnnotations = annotations
                                    clusterListSession = UUID()  // 新会话，重置内部 @State

                                    // 快速隐藏搜索栏（0.15秒），同时立即显示聚合列表
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        appState.isShowingSearchView = false
                                    }
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
                            .disabled(searchViewModel.isShareDetailOverlayShown || isShowingClusterList)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .ignoresSafeArea(.all)
                            .onAppear {
                                // 首次加载，请求定位
                                locationManager.requestLocation()
                            }
                            .onReceive(locationManager.$currentLocation) { location in
                                if let location = location, !appState.hasSetInitialRegion {
                                    // 首次获取位置：触发精确定位
                                    appState.hasSetInitialRegion = true
                                    shouldCenterOnUser = true
                                    searchViewModel.fetchAllShares(latitude: location.latitude, longitude: location.longitude)
                                }
                            }
                            // 监听登出通知，重置地图初始化状态
                            .onReceive(NotificationCenter.default.publisher(for: .userDidLogout)) { _ in
                                appState.hasSetInitialRegion = false
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
                            .disabled(searchViewModel.isShareDetailOverlayShown || isShowingClusterList)
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
                                    // 同时更新 region 到用户位置
                                    searchViewModel.region = MKCoordinateRegion(
                                        center: location,
                                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                    )
                                    searchViewModel.fetchAllShares(latitude: location.latitude, longitude: location.longitude)
                                }
                            }
                            // 监听登出通知，重置地图初始化状态
                            .onReceive(NotificationCenter.default.publisher(for: .userDidLogout)) { _ in
                                appState.hasSetInitialRegion = false
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
                        // ✅ 确保 isShowingSearchView 变化时 MapOverlayView 的 transition 能正确触发
                        .animation(.easeInOut(duration: 0.2), value: appState.isShowingSearchView)
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
                        // 【Onboarding】底部 Sheet 控制：A-B 未完成时隐藏
                        .sheet(isPresented: Binding(
                            get: { appState.isShowingSearchView && !onboardingCoordinator.shouldBlockHomeSheet },
                            set: { newValue in
                                if !onboardingCoordinator.shouldBlockHomeSheet {
                                    appState.isShowingSearchView = newValue
                                }
                            }
                        )) { // 显示 SheetView
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
                        // MARK: - Stage 2: 聚合列表（支持 sheet 和 overlay 两种模式）
                        .modifier(ClusterListSheetModifier(
                            isEnabled: !useOverlayForClusterList,
                            isPresented: $isShowingClusterList,
                            clusterAnnotations: clusterAnnotations,
                            shouldRestoreClusterList: appState.shouldRestoreClusterList,
                            onDismiss: {
                                if !appState.shouldRestoreClusterList {
                                    clusterAnnotations = []
                                    appState.isShowingSearchView = true
                                }
                            },
                            content: { clusterListContent }
                        ))

                    } //ZStack
                    // MARK: - Overlay 模式的聚合列表（macOS 26 风格缩放动画）
                    // skipAnimation: 进入详情时无动画，从详情返回时瞬间出现
                    .overlay {
                        if useOverlayForClusterList {
                            AnimatedOverlaySheet(
                                isPresented: $isShowingClusterList,
                                cornerRadius: 0,  // 使用屏幕圆角
                                heightFraction: 0.75,
                                edgeInset: 12,
                                onDismiss: {
                                    print("🔷 [ClusterList] overlay onDismiss, appState.shouldRestoreClusterList=\(appState.shouldRestoreClusterList)")
                                    if !appState.shouldRestoreClusterList {
                                        clusterAnnotations = []
                                        // ✅ isShowingSearchView 的恢复移到 onChange(of: isShowingClusterList) 中处理
                                        // 避免 asyncAfter 导致动画不触发的问题
                                    }
                                },
                                content: { clusterListContent },
                                skipAnimation: appState.shouldRestoreClusterList  // 进入/返回详情时跳过动画
                            )
                            .zIndex(100)
                        }
                    }
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
                        // 【Onboarding】触发发布成功事件（用于步骤 D/E）
                        onboardingCoordinator.handleEvent(.sharePublished)
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
                // MARK: - 详情退出时恢复聚合列表
                .onReceive(NotificationCenter.default.publisher(for: .shareDetailDidDisappear)) { _ in
                    print("🔷 [ClusterList] 收到 shareDetailDidDisappear 通知")
                    restoreClusterListIfNeeded()
                }
                // MARK: - 删除观之后从聚合列表移除
                .onReceive(NotificationCenter.default.publisher(for: .shareDidDelete)) { notification in
                    guard let shareId = notification.userInfo?["shareId"] as? Int else { return }
                    let idStr = "\(shareId)"
                    clusterAnnotations.removeAll { $0.id == idStr }
                    searchViewModel.savedClusterAnnotations.removeAll { $0.id == idStr }
                    print("🔷 [ClusterList] 已从聚合列表移除已删除的观之 id=\(shareId)")
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
            // 【Onboarding】主页出现事件
            onboardingCoordinator.handleEvent(.homePageAppeared)

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
                    if myUserId == 0 && loginManager.isLoggedIn {
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
        // 【Onboarding】监听从详情页返回，触发 homePageFullyVisible
        // 注意：只有从详情页返回时才触发，关闭聚合列表不触发
        .onChange(of: navigationCoordinator.path.isEmpty) { oldValue, isEmpty in
            // 从详情页返回（导航模式）：path 从非空变成空
            if isEmpty && !oldValue && !searchViewModel.isShareDetailOverlayShown {
                // 延迟 1 秒检查聚合列表状态，等待 UI 完全稳定（详情页消失、聚合列表恢复）后再决定是否显示 D
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onboardingCoordinator.handleHomePageFullyVisible(isClusterListShowing: isShowingClusterList)
                }
            }
        }
        .onChange(of: searchViewModel.isShareDetailOverlayShown) { oldValue, isShowing in
            // 从详情页返回（overlay 模式）：isShowing 从 true 变成 false
            if !isShowing && oldValue && navigationCoordinator.path.isEmpty {
                // 延迟 1 秒检查聚合列表状态，等待 UI 完全稳定（详情页消失、聚合列表恢复）后再决定是否显示 D
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onboardingCoordinator.handleHomePageFullyVisible(isClusterListShowing: isShowingClusterList)
                }
            }
        }
        // 【Onboarding】监听聚合列表关闭，触发待显示的 D
        .onChange(of: isShowingClusterList) { oldValue, isShowing in
            // 聚合列表从显示变成隐藏
            if !isShowing && oldValue {
                onboardingCoordinator.handleEvent(.clusterListDismissed)

                // ✅ 修复：在 SwiftUI 的正常周期中恢复 UI
                // 注意：只在非恢复模式下才恢复（appState.shouldRestoreClusterList 为 false）
                // onDismiss 中的 asyncAfter 可能导致 animation 不触发
                if !appState.shouldRestoreClusterList {
                    withAnimation(.easeOut(duration: 0.2)) {
                        appState.isShowingSearchView = true
                    }
                }
            }
        }
//        .disabled(appState.isShareImageExpanded)
        // 【Onboarding】监听所有步骤完成后显示欢迎语
        .onChange(of: onboardingCoordinator.isAllStepsCompleted) { _, isCompleted in
            if isCompleted && !appState.didShowWelcomeToast {
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
        .task{
            locationManager.requestLocation()

            // 登录后请求通知权限并注册 APNs
            if loginManager.isLoggedIn {
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
        // ✅ 使用 setLoggedInForPreview，不写 Keychain
        #if DEBUG
        OTOLoginStatusManager.shared.setLoggedInForPreview(true)
        #endif

        return SearchView(animationNamespace: animationNamespace, userlogin: UserLoginModel())
            .environment(\.appState, AppStateModel())
            .environmentObject(OTOLoginStatusManager.shared)  // ✅ 必须添加
            .environmentObject(LocationManager())
            .environmentObject(SearchViewModel())
            .environmentObject(ToastManager())
            .environmentObject(UserProfileManager())
            .environmentObject(NavigationCoordinator())
            .environmentObject(OnboardingCoordinator())
    }
}

// MARK: - 聚合列表 Sheet 修饰器（条件性应用）

/// 条件性 sheet 修饰器，用于在开关关闭时保持 sheet 实现
struct ClusterListSheetModifier<SheetContent: View>: ViewModifier {
    let isEnabled: Bool
    @Binding var isPresented: Bool
    let clusterAnnotations: [CustomAnnotation]
    let shouldRestoreClusterList: Bool
    let onDismiss: () -> Void
    let content: () -> SheetContent

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .sheet(isPresented: $isPresented, onDismiss: {
                    print("🔷 [ClusterList] sheet onDismiss, shouldRestoreClusterList=\(shouldRestoreClusterList)")
                    onDismiss()
                }) {
                    self.content()
                        .presentationDetents([.medium, .large])
                        .presentationContentInteraction(.scrolls)
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(Constants.sheetCornerRadius)
                        .presentationBackgroundInteraction(.enabled)
                }
        } else {
            content
        }
    }
}

//===================================






