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
    @ObservedObject var userlogin : UserLoginModel
    @Environment(\.appState) var appState
    @State var locationManager = LocationManager()
    @ObservedObject var searchViewModel: SearchViewModel
    @State private var hasVisitedPage: Bool = UserDefaults.standard.bool(forKey: "HasVisitedPage") //用于检测是否打开app后第一次到此页面
    
    @State private var isShowMyView: Bool = false
    @State private var isShowLogInView: Bool = false  //临时测试登录页面
    @State private var detents: Set<PresentationDetent> = [.height(60), .large]
    @State private var currentDetent: PresentationDetent = .height(60) // 用于跟踪当前 SheetView 的高度
    @State private var currentSearchTask: Task<Void, Never>? = nil // 添加任务管理
    @State private var image: UIImage?
    
    var body: some View {
        @Bindable var appState = appState
        ToastRootView {
            NavigationStack{
                ZStack{
                    CustomMapView(
                        appState: appState,
                        region: $searchViewModel.region,
                        selectedAnnotation: $searchViewModel.selectedAnnotation,
                        locationAnimating: $searchViewModel.locationAnimating,
                        annotations: $searchViewModel.annotations,
                        onRegionChange: searchViewModel.handleMapRegionChange
                    )
                    .edgesIgnoringSafeArea(.all)
                    .mapScope(mapScope)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .mapStyle(.standard(elevation: .realistic))
                    .animation(.spring(), value: searchViewModel.selectedLocation)
//                    .onChange(of: searchViewModel.selectedAnnotation) { _ , newAnnotation in
//                        if let newAnnotation = newAnnotation {
//                            if newAnnotation.annotationType == .searchResult {
//                                // 点击了搜索结果的标注，已经在 Coordinator 中处理
//                            } else if newAnnotation.annotationType == .nearbyShare {
//                                // 点击了附近分享的标注，可以在这里处理，例如展示详情
//
//                            }
//                        }
//                    }
//                    .onChange(of: appState.responsedNearbyShareList) { _ , newValue in
//                        print("Nearby share list updated")
//                        searchViewModel.annotations = searchViewModel.getAnnotations()
//                    }
//                    .onChange(of: searchViewModel.searchResults) {
//                        print("Search Results Changed: \(searchViewModel.searchResults)")
//                        if let firstResult = searchViewModel.searchResults.first {
//                            DispatchQueue.main.async {
//                                print("First Search Result Selected: \(firstResult)")
//                                searchViewModel.selectedLocation = firstResult
//                                appState.isShowingShowMarker = true
//                            }
//                        }
//                    }
//                    .onChange(of: appState.isShowingResultCardView) { _ , isShowing in
//                        print("Is Show Result Card Changed: \(appState.isShowingResultCardView)")
//                        if !isShowing {
//                            searchViewModel.selectedLocation = nil
//                            searchViewModel.searchResults.removeAll()
//                            appState.isShowingShowMarker = true
//                            searchViewModel.annotations = searchViewModel.getAnnotations()
//                            }
//                    }
//                    .onChange(of: appState.isShowingShowMarker) { _, _ in
//                        DispatchQueue.main.async {
//                            searchViewModel.annotations = searchViewModel.getAnnotations()
//                            print("Annotations updated due to isShowingShowMarker change")
//                        }
//                    }
                    .overlay(alignment:.bottomTrailing) {
                        if appState.isShowingSearchView {
                            MapOverlayView(
                                isShowMyView: $isShowMyView,
                                isShowLogInView: $isShowLogInView,
                                appState: appState,
                                locationManager: locationManager,
                                searchViewModel: searchViewModel
                            )
                        }
                    }
                    
                    .onAppear{
                        if hasVisitedPage {
                            hasVisitedPage = false
                            UserDefaults.standard.set(false, forKey: "HasVisitedPage")
                            
//                            searchViewModel.getUserLocation()
                            if let location = searchViewModel.locatedPosition { searchViewModel.selectedLocation = SearchResult(location: location)
                                print("进入界面",searchViewModel.selectedLocation as Any)}
                            
                            searchViewModel.getAddressFromLocation(for: searchViewModel.selectedLocation?.location){
                                address in
                                if let address = address{
                                    DispatchQueue.main.async {
                                        appState.resultLocationName = address
                                    }
                                }
                            }
                            print(searchViewModel.searchResults)
                            
                        }
                    }
//                    .sheet(isPresented: $appState.isShowingSearchView) {
//                        // 显示 SheetView
//                        SheetView(
//                            appState: appState,
//                            searchResults: $searchViewModel.searchResults,
//                            currentDetent: $currentDetent,
//                            selectedLocation: $searchViewModel.selectedLocation,
//                            position: $searchViewModel.position,
//                            currentSearchTask: $currentSearchTask
//                        )
//                        .environment(appState)
//                        .animation(.spring(), value: appState.isShowingSearchView)
//                    }
//                    .sheet(isPresented: $appState.isShowingResultCardView) {
//                        // 显示 ResultCardView
//                        ResultCardView(
//                            appState: appState,
//                            sesrchViewHight: $currentDetent,
//                            searchResults: $searchViewModel.searchResults,
//                            selectedLocation: $searchViewModel.selectedLocation
//                        )
//                        .animation(.spring(), value: appState.isShowingResultCardView)
//                        .presentationDragIndicator(.hidden)
//                        .interactiveDismissDisabled(true)
//                    }
//                    .navigationDestination(isPresented: $appState.isShowingCameraView) {
//                        CameraViewWrapper(appState: appState)
//                    }
                    
//                    根据登录状态决定是否显示登录页面
//                    if !OTOLoginStatusManager.shared.isLoggedIn {
//                        LogInView(userlogin: userlogin)
//                    }
                    
                    //显示分享详情
                    if let selectedAnnotation = searchViewModel.selectedAnnotation {
                        ShareDetailView(searchViewModel: searchViewModel)
                                        }
                    
                } //ZStack
                
            }
            .onChange(of: appState.isPushedGuanzhi) { oldValue, newValue in
                showNotification()
            }
            .onChange(of: locationManager.currentLocation) { _ , newLocation in
                if let location = newLocation {
                    let region = MKCoordinateRegion(center: location, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                    withAnimation(.spring()) {
                        searchViewModel.region = region
                    }
                    searchViewModel.fetchNearbyShareList(latitude: location.latitude, longitude: location.longitude, radius: 20)
                }
            }
            .onChange(of: locationManager.locationErrorDescription) { _ , errorDescription in
                if let errorDescription = errorDescription {
                    print("位置错误：\(errorDescription)")
                    // 可以在这里显示一个错误提示给用户
                }
            }
            
        }
        .task{
            locationManager.requestLocation()
            searchViewModel.appState = appState
            initializePage()
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
        if hasVisitedPage {
            hasVisitedPage = false
            UserDefaults.standard.set(false, forKey: "HasVisitedPage")
//            searchViewModel.initializeLocation()
        }
    }
    
}

//===================================

struct Previews: PreviewProvider {
    static var previews: some View {
        SearchView(userlogin: UserLoginModel()/*, appState: AppStateModel()*/, locationManager: LocationManager(), searchViewModel: SearchViewModel(/*appState: AppStateModel()*/))
            .environment(\.appState, AppStateModel())
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

