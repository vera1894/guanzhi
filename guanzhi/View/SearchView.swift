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
    @State private var selectedLocation: SearchResult?
    @State private var isShowMyView: Bool = false
    
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
                .ignoresSafeArea()
                
                HStack{
                    Spacer()
                    VStack(alignment: .center, spacing: Constants.spacingSpacingM){
                        Button {
                            isSheetPresented = false
                            isShowMyView = true
                        } label: {
                            Image("骷髅头")
                                .resizable()
                                .frame(width: Constants.iconSizeM, height: Constants.iconSizeM)
                        }.buttonStyle(ButtonStyle_s())
                            .navigationDestination(isPresented: $isShowMyView) {
                                MyView()
                            }
                        
                        Button {
                            getUserLocation()
                        } label: {
                            Image("icon-location")
                                .frame(width: Constants.iconSizeM, height: Constants.iconSizeM)
                        }.buttonStyle(ButtonStyle_s())
                    }.padding(Constants.spacingSpacingM)
                }
                
                
                
            }
        }
        
        
        .onAppear{
            getUserLocation()
        }
        .onChange(of: selectedLocation) {
            isSheetPresented = selectedLocation == nil
        }
        .onChange(of: searchResults) {
            if let firstResult = searchResults.first, searchResults.count == 1 {
                selectedLocation = firstResult
            }
        }
        .sheet(isPresented: $isSheetPresented) {
            SheetView(searchResults: $searchResults)
        }
    }
}

//===================================

struct SheetView: View {
    @State private var search: String = ""
    @State private var locationService = LocationService(completer: .init())
    @Binding var searchResults: [SearchResult]
    @State private var isShowingImagePicker = false
    @State private var image: UIImage?
    
    var body: some View {
        VStack {
            // 1 搜索栏
            HStack {
                // Image(systemName: "magnifyingglass")
                HStack{
                    Text(" 🔍")
                    TextField("想瞧瞧哪里？", text: $search)
                        .autocorrectionDisabled()
                        .onSubmit {
                            Task {
                                searchResults = (try? await locationService.search(with: search)) ?? []
                            }
                        }
                }.modifier(TextFieldGrayBackgroundColor())
                
                //相机按钮
                Button{
                    isShowingImagePicker = true
                }label: {
                    Image("icon-camera")
                        .frame(width: 40, height: 40)
                        .padding(.trailing,Constants.spacingSpacingM)
                }
            }
            .sheet(isPresented: $isShowingImagePicker) {
                CameraView(image: $image)
            }
            
            
            Spacer()
            
            // 2
            List {
                ForEach(locationService.completions) { completion in
                    Button(action: {didTapOnCompletion(completion) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(completion.title)
                                .font(.headline)
                                .fontDesign(.rounded)
                            Text(completion.subTitle)
                            // Show the URL if it's present
                            if let url = completion.url {
                                Link(url.absoluteString, destination: url)
                                    .lineLimit(1)
                            }
                        }
                    }
                    // 3
                    .listRowBackground(Color.clear)
                }
            }
            // 4
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        // 5
        .onChange(of: search) {
            locationService.update(queryFragment: search)
        }
        
        
        .padding()
        // 2 用户无法通过向下滑动来关闭工作表视图
        .interactiveDismissDisabled()//
        // 3 工作表视图有两种可能的尺寸：小尺寸（200 点高）和大尺寸（默认尺寸）
        .presentationDetents([.height(120), .large])
        // 4 模糊效果
        .presentationBackground(.regularMaterial)
        // 5 用户可以与其后面的地图视图进行交互
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
    }
    
    private func didTapOnCompletion(_ completion: SearchCompletions) {
        Task {
            if let singleLocation = try? await locationService.search(with: "\(completion.title) \(completion.subTitle)").first {
                searchResults = [singleLocation]
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
}

extension MKCoordinateRegion{
    static var defaultRegion:MKCoordinateRegion{
        return .init(center: .defaultLocation, latitudinalMeters: 1000, longitudinalMeters: 1000)
    }
}
