//
//  SearchView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/14.
//

import SwiftUI
import MapKit

struct SearchView: View {
    
    @Namespace var mapScope
    @Namespace private var animationNamespace
    @ObservedObject var userlogin : UserLoginModel
    @Environment(\.appState) var appState
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.modelContext) private var context
    @EnvironmentObject var searchViewModel: SearchViewModel
//    @StateObject var searchViewModel = SearchViewModel()
    @StateObject var navigationCoordinator = NavigationCoordinator()
    
    @State private var detents: Set<PresentationDetent> = [.height(60), .large]
    @State private var currentDetent: PresentationDetent = .height(60) // 用于跟踪当前 SheetView 的高度
    @State private var image: UIImage?

    @State private var annotations: [MKAnnotation] = []
    @State private var position: MapCameraPosition = .automatic
    @State private var locationMarkers: [LocationMarker] = []
    @State private var mapSize: CGSize = .zero
    @State private var isAnimating: Bool = false
    
    var body: some View {
        @Bindable var appState = appState
        
        ToastRootView {
            if !OTOLoginStatusManager.shared.isLoggedIn {
                // 显示登录页面
                LogInView(userlogin: userlogin)
            } else {
                NavigationStack(path: $navigationCoordinator.path) {
                    ZStack{
                        Map(position: $position,interactionModes: .all) {
                            
                            if !appState.isShareImageExpanded {
                                ForEach(searchViewModel.annotations, id: \.id) { annotation in
                                    Annotation(annotation.title ?? "", coordinate: annotation.coordinate) {
                                        
                                        MapAnnotationView(
                                            animationNamespace: animationNamespace,
                                            annotation: annotation,
                                            onTap: { uiImage in
                                                print("点击标注")
                                                searchViewModel.selectAnnotation(annotation, thumbnailImage: uiImage)
    //                                            if let uiImage = uiImage {
    //                                                searchViewModel.selectedAnnotationImage = uiImage
    //                                            }
    //                                            searchViewModel.isUpdatingAnnotations = true
    //                                            searchViewModel.selectedAnnotation = annotation
    //                                            searchViewModel.selectedAnnotationID = annotation.id
    //                                            if let shareId = Int64(annotation.id) {
    //                                                searchViewModel.loadSourceImage(for: shareId)
    //                                            }
                                                withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.4)) {
                                                    appState.isShowingSearchView = false
                                                    appState.isShareImageExpanded.toggle()
                                                }
                                            }
                                        )
                                //        .matchedGeometryEffect(id: "image-\(annotation.id)", in: animationNamespace)
                                        .environment(appState)
                                        .environmentObject(searchViewModel)
                                        .id(annotation.id)
                                    }
                                }
                            }
                            
                            ForEach(locationMarkers) { marker in
                                    Marker(marker.title ?? "", coordinate: marker.coordinate)
    //                                    .tag(marker)
                                }
                            
                            UserAnnotation()
                        }
                        .mapScope(mapScope)
                        .coordinateSpace(name: "shared")
                        .disabled(appState.isShareImageExpanded)
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
                            .environment(appState)
                            .environmentObject(searchViewModel)
                            .animation(.spring(), value: appState.isShowingSearchView)
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
                                    currentDetent = .height(60)
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
                        
                        //显示分享详情
                        if appState.isShareImageExpanded {
                            SimpleCarouselView(searchViewModel: searchViewModel, animationNamespace: animationNamespace)
    //                            .matchedGeometryEffect(id: "image-\(searchViewModel.selectedAnnotationID ?? "")", in: animationNamespace)
                                .environment(appState)
                                .environmentObject(searchViewModel)
                            
                        }
                        
                    } //ZStack
                    .navigationDestination(for: Route.self) { route in
                                            switch route {
                                            case .myView:
                                                MyView()
                                                    .environment(appState)
                                                    .environmentObject(navigationCoordinator)
                                            case .settingView:
                                                SettingView()
                                                    .environment(appState)
                                                    .environmentObject(navigationCoordinator)
                                            }
                                        }
                    .toolbar(appState.isShareImageExpanded ? .visible : .hidden, for: .navigationBar)
                } //NavStack
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
            }
        }
        .onAppear {
            if searchViewModel.context == nil {
                searchViewModel.context = context
                searchViewModel.appState = appState
                searchViewModel.locationManager = locationManager
                searchViewModel.initializeData()
            }
        }
//        .disabled(!OTOLoginStatusManager.shared.isLoggedIn)
        .task{
            locationManager.requestLocation()
            Toast.shared.present(style: .notificationOfWelcome(
                title: "🌍世界虽大 吾可观之👀",
                symbol: " ",
                tint: Color("color-primary"),
                isUserInteractionEnabled: true,
                timing: .medium,
                isAutoClose: true)
            )
        }
        
    }
    
    
    // MARK: - Functions
    
    private func showNotification() {
            if appState.isPushedGuanzhi {
                Toast.shared.present(style: .notificationOnly(
                    title: "🌍 发布成功",
                    symbol: "",
                    tint: Color("color-primary"),
                    isUserInteractionEnabled: true,
                    timing: .short,
                    isAutoClose: true))
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

struct Previews: PreviewProvider {
    static var previews: some View {
        SearchView(userlogin: UserLoginModel())
            .environment(\.appState, AppStateModel())
            .environmentObject(LocationManager())
            .environmentObject(SearchViewModel())
    }
}
//===================================


//右滑返回
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

extension UserDefaults {
    func contains(key: String) -> Bool {
        return self.object(forKey: key) != nil
    }
}

struct LocationMarker: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String?
}

