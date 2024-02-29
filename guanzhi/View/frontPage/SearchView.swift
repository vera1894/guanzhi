//
//  TestView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/14.
//

import SwiftUI
import MapKit

struct SearchView: View {
    @State private var position :MapCameraPosition = .region(.defaultRegion)
    @State private var isSheetPresented: Bool = true
     @State private var searchResults = [SearchResult]()
//    @State private var searchResults = [SearchResult(location: CLLocationCoordinate2D.testLocation1),SearchResult(location: CLLocationCoordinate2D.testLocation2)]
    @State private var selectedLocation: SearchResult?
    @State private var isShowMyView: Bool = false
    @State private var scene: MKLookAroundScene?
    @State private var isCardPresented: Bool = false
    
    
    func getUserLocation() {
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
        
        DispatchQueue.global().async {
            if CLLocationManager.locationServicesEnabled() {
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
                locationManager.startUpdatingLocation()
                
                if let location = locationManager.location?.coordinate {
                    let region = MKCoordinateRegion(center: location, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                    position = .region(region)
                    print("经纬度",location.latitude,location.longitude)
                }
            }
        }
        
    }
    
    var body: some View {
        NavigationStack{
            ZStack{
                Map(position: $position, selection: $selectedLocation){
                    ForEach(searchResults) { result in
                        Marker(coordinate: result.location) {
                            Image(systemName: "mappin")
                        }
                        .tag(result)
                    }
                }
                .overlay(alignment: .bottom) {
                           if selectedLocation != nil {
                               //弹出卡片
                               
                           }
                       }
                .ignoresSafeArea()
                .onChange(of: selectedLocation) {
                    if let selectedLocation {
                                    Task {
                                        scene = try? await fetchScene(for: selectedLocation.location)
                                    }
                                }
                    isSheetPresented = selectedLocation == nil
                    isCardPresented = selectedLocation != nil
                }
                .onChange(of: searchResults) {
                    if let firstResult = searchResults.first, searchResults.count == 1 {
                        selectedLocation = firstResult
                    }
                }
                
                HStack{
                    Spacer()
                    VStack(alignment: .center, spacing: Constants.spacingSpacingM){
                        Button {
                            isSheetPresented = false
                            isShowMyView = true
                        } label: {
                            Image("icon-avatar")
                                .resizable()
                                .frame(width: Constants.iconSizeM, height: Constants.iconSizeM)
                        }.buttonStyle(ButtonStyle_m())
                            .navigationDestination(isPresented: $isShowMyView) {
                                MyView(isSheetPresented: $isSheetPresented)
                            }
                        
                        Button {
                            getUserLocation()
                        } label: {
                            Image("icon-location")
                                .frame(width: Constants.iconSizeM, height: Constants.iconSizeM)
                        }.buttonStyle(ButtonStyle_m())
                    }.padding(Constants.spacingSpacingM)
                }
                
                
                
            }
        }
        
        
        .onAppear{
            getUserLocation()
        }

        .sheet(isPresented: $isSheetPresented) {
            SheetView(searchResults: $searchResults)
        }
        .sheet(isPresented: $isCardPresented) {
            CardView()
        }

    }
    //待注释
    private func fetchScene(for coordinate: CLLocationCoordinate2D) async throws -> MKLookAroundScene? {
            let lookAroundScene = MKLookAroundSceneRequest(coordinate: coordinate)
            return try await lookAroundScene.scene
        }
}

//===================================


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
