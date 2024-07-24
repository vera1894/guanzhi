//
//  TestView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/14.
//

import SwiftUI
import MapKit

struct SearchView: View {
    
    @Namespace var mapScope
    
    @AppStorage("isFirstLaunch") private var isFirstLaunch: Bool = true
    
    @State private var position :MapCameraPosition = .region(.defaultRegion)
    @State private var isShowSearchView: Bool = true
    @State private var searchResults = [SearchResult]()
    //    @State private var searchResults = [SearchResult(location: CLLocationCoordinate2D.testLocation1),SearchResult(location: CLLocationCoordinate2D.testLocation2)]
    @State private var selectedLocation: SearchResult?
    
    @State private var isShowMyView: Bool = false
    @State private var isShowLogInView: Bool = false  //临时测试
    @State private var scene: MKLookAroundScene?
    @State private var isShowResultCard: Bool = false
    @State private var resultCardName = "" //详情卡片地名
    @State var locatedPosition : CLLocationCoordinate2D?
    
    @State private var detents: Set<PresentationDetent> = [.height(60), .large]
    @State private var currentDetent: PresentationDetent = .height(60) // 用于跟踪当前 SheetView 的高度
    
    
    func getUserLocation() {
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
        
        DispatchQueue.global().async {
            if CLLocationManager.locationServicesEnabled() {
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
                locationManager.startUpdatingLocation()
                
                if let location = locationManager.location?.coordinate {
                    getAddressFromLocation(for: location) { String in
                        if let address = String{
                            resultCardName = address
                            print("cardname:",resultCardName)
                        }
                    }
                    let region = MKCoordinateRegion(center: location, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                    withAnimation {
                        position = .region(region)
                                        }
                    locatedPosition = location
                   // searchResults.append(SearchResult(location: location))
                    print("经纬度",location.latitude,location.longitude)
                }
            }
        }
        
    }
    
    //根据地址翻译地名
    private func getAddressFromLocation(for location:CLLocationCoordinate2D?,completion:@escaping(String?)->Void){
        if let location = location{
            let location = CLLocation(latitude: location.latitude, longitude: location.longitude)
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                if let error = error{
                    print("定位错误：\(error.localizedDescription)")
                    
                }else if let placemark = placemarks?.first{
                    let address = "\(placemark.name ?? "")\(placemark.locality ?? "")\(placemark.administrativeArea ?? "")\(placemark.country ?? "")"
                    print("地址：",address)
                    completion(address)
                }
            }
        }
    }
    
    var body: some View {
        
        ToastRootView {
            NavigationStack{
                ZStack{
                    
                    Map(position: $position, interactionModes: [.all], selection: $selectedLocation, scope: mapScope){
                        ForEach(searchResults) { result in
                            Marker(coordinate: result.location) {
                                Image(systemName: "mappin")
                            }
                            .tag(result)
                        }
                        Annotation("", coordinate: .testLocation1, anchor: .bottom) {
                            ZStack {
                                
                                Button{
                                    //Seee位置，需要添加是否已经定位的状态 isLocated
                                }label: { }
                            .buttonStyle(SeeePositionStyle(isEnabled: true))
                                
                            }
                        }
                        UserAnnotation()
                    }
//                    .overlay(alignment: .bottom) {
//                        if selectedLocation != nil {
//                            //弹出卡片
//                            
//                        }
//                    }
                    .onChange(of: selectedLocation) {
                        if selectedLocation != nil {
                            getAddressFromLocation(for: selectedLocation?.location){
                                address in
                                if let address = address{
                                    resultCardName = address
                                }
                            }
                        }
                        
                        print("cardname",resultCardName)
//                        isShowSearchView = selectedLocation == nil //未选中地址的时候弹出搜索卡片
//                        isShowResultCard = selectedLocation != nil //选中地址的时候弹出详情卡片
                        print("已选择地址",selectedLocation as Any)
                        
                    }
                    .onChange(of: searchResults) {
                        if let firstResult = searchResults.first, searchResults.count == 1 {
                            selectedLocation = firstResult
                        }
                    }
                    .overlay(alignment:.bottomTrailing) {
                        if isShowSearchView == true {
                            VStack(spacing: 32) {
                                
                                VStack {
                                    MapPitchToggle(scope: mapScope)
                                }
                                .mapControlVisibility(.visible)
                                .buttonBorderShape(.circle)
                                .padding(.top, 60)
                                
                                Spacer()
                                
                                VStack(spacing: 16) {
                                    Button(action: {
                                        // 头像-s
                                        print(searchResults)
                                        isShowMyView = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                                    isShowSearchView = false
                                                }
                                    }) {
                                        
                                    }
                                    .buttonStyle(AvatarStyle_s(isEnabled: true, profileImage: Image("例子"), borderThickness: 4))
                                    .navigationDestination(isPresented: $isShowMyView) {
                                        MyView(isSheetPresented: $isShowSearchView)
                                    }
                                    
                                    Button{
                                        //提醒按钮-圆形 //测试登录页面导航问题
                                        isShowLogInView = true
                                        
                                    }label: {
                                        Image("icon-notification")
                                    }
                                    .buttonStyle(ButtonStyle_m())
                                    .navigationDestination(isPresented: $isShowLogInView) {
                                        LogInView(userlogin: UserLoginModel())
                                    }
                                    
                                    Button{
                                        //定位按钮-圆形
                                        getUserLocation()
                                    }label: {
                                        Image("icon-location")
                                    }
                                    .buttonStyle(ButtonStyle_m())
                                }
                            }
                            .padding(.horizontal, 5)
                            .padding(.bottom, 80)
                        }
                    }
                    .mapScope(mapScope)
                   
                    
                    .onAppear{
                        
                        if isFirstLaunch {
                            isFirstLaunch = false
                            getUserLocation()
                            
                            if let location = locatedPosition { selectedLocation = SearchResult(location: location)
                                print("进入界面",selectedLocation as Any)}
                            
                            getAddressFromLocation(for: selectedLocation?.location){
                                address in
                                if let address = address{
                                    resultCardName = address
                                }
                            }
                            print(searchResults)
                        }
                    }
                    
                    .sheet(isPresented: $isShowSearchView) {
                        SheetView(
                            searchResults: $searchResults,
                            cardName: $resultCardName,
                            currentDetent: $currentDetent,
                            selectedLocation: $selectedLocation,
                            position: $position
                        )
                    }
                    
                    .sheet(isPresented: $isShowResultCard) {
                        ResultCardView(
                            name: $resultCardName,
                            isShowResultCard: $isShowResultCard,
                            isShowSearchView: $isShowSearchView, 
                            sesrchViewHight: $currentDetent,
                            searchResults: $searchResults,
                            selectedLocation: $selectedLocation)
                    }
                       
                }
            }.navigationBarBackButtonHidden(true)
                .onAppear{
                    Toast.shared.present(style: .notificationOfWelcome(
                        title: "🌍世界虽大 吾可观之👀",
                        symbol: "",
                        tint: Color("color-primary"),
                        isUserInteractionEnabled: true,
                        timing: .medium,
                        isAutoClose: true)
                    )
                }
        }
    }
    
    
}

struct TextFieldGrayBackgroundColor: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(.gray.opacity(0.1))
            .cornerRadius(8)
            .foregroundColor(.primary)
    }
}

//===================================

struct Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}
//===================================

struct SearchCompletions: Identifiable {
    let id = UUID()
    let title: String
    let subTitle: String
    var url: URL?
}

@Observable
class LocationService: NSObject, MKLocalSearchCompleterDelegate {
    private let completer: MKLocalSearchCompleter
    
    var completions = [SearchCompletions]()
    
    init(completer: MKLocalSearchCompleter) {
        self.completer = completer
        super.init()
        self.completer.delegate = self
    }
    
    func update(queryFragment: String) {
        completer.resultTypes = .pointOfInterest
        completer.queryFragment = queryFragment
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results.map { completion in
            // Get the private _mapItem property
            let mapItem = completion.value(forKey: "_mapItem") as? MKMapItem
            
            return .init(
                title: completion.title,
                subTitle: completion.subtitle,
                url: mapItem?.url
            )}
    }
    
    func search(with query: String, coordinate: CLLocationCoordinate2D? = nil) async throws -> [SearchResult] {
        let mapKitRequest = MKLocalSearch.Request()
        mapKitRequest.naturalLanguageQuery = query
        mapKitRequest.resultTypes = .pointOfInterest
        if let coordinate {
            mapKitRequest.region = .init(.init(origin: .init(coordinate), size: .init(width: 1, height: 1)))
        }
        let search = MKLocalSearch(request: mapKitRequest)
        
        let response = try await search.start()
        
        return response.mapItems.compactMap { mapItem in
            guard let location = mapItem.placemark.location?.coordinate else { return nil }
            
            return .init(location: location)
        }
    }
}

//===================================
struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let location: CLLocationCoordinate2D
    
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension CLLocationCoordinate2D {
    static var defaultLocation: CLLocationCoordinate2D{
        return .init(latitude: 39.9042, longitude: 116.4074)
    }
    static var testLocation1: CLLocationCoordinate2D{
        return .init(latitude: 39.92, longitude: 116.39)
    }
    static var testLocation2: CLLocationCoordinate2D{
        return .init(latitude: 39.93, longitude: 116.40)
    }
}

extension MKCoordinateRegion{
    static var defaultRegion:MKCoordinateRegion{
        return .init(center: .defaultLocation, latitudinalMeters: 1000, longitudinalMeters: 1000)
    }
}

//右滑返回
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}


