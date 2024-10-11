//
//  SheetView.swift
//  guanzhi
//
//  Created by Vera on 2024/2/29.
//

import SwiftUI
import MapKit

struct SheetView: View {

    @Bindable var appState: AppStateModel
    @State private var search: String = ""
    @State private var locationService = LocationService(completer: .init())
    @Binding var searchResults: [SearchResult]
    @State private var image: UIImage?
    let placeholder = "🔍想瞧瞧哪里？"
    @Binding var currentDetent: PresentationDetent // 绑定sheetview高度
    @Binding var selectedLocation: SearchResult?
    @Binding var position: CustomMapCameraPosition
    @Binding var currentSearchTask: Task<Void, Never>?  // 添加任务管理
    
    var body: some View {
//        @Bindable var appState = appState
        VStack {
            HStack(spacing: 8) {
                    
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.shadow(.inner(color: Color("color-primary").opacity(1), radius: 0, x: 4, y: 6)))
                        .stroke(.black, lineWidth: 4)
                        .foregroundStyle(Color("color-white").opacity(1))
                        .frame(height: 32)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            TextField(placeholder, text: $search)
                                .font(.system(size: 16, weight: .regular, design: .default))
                                .padding(.horizontal, 16)
                                .frame(height: 32)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0))
                                .cornerRadius(20)
                                .multilineTextAlignment(.leading)
                                .autocorrectionDisabled()
                                .onTapGesture {
                                    currentDetent = .large
                                    selectedLocation = nil
                                    searchResults.removeAll()
                                }
                                .onSubmit {
                                    currentSearchTask?.cancel() // 取消当前任务
                                    currentSearchTask = Task {
                                        searchResults = (try? await locationService.search(with: search)) ?? []
                                    }
                                }
                        }
                
                if currentDetent != .large { // 根据 BottomSheet 的状态隐藏或显示
                    Button(action: {
                        // 分享地点-胶囊按钮hug
                        appState.isShowingCameraView = true
                        appState.isShowingSearchView = false
                    }) {
                        Text("📷 分享地点")
                    }
                    .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: true))
                    
                } else {
                    Button{
                        //关闭按钮-圆形
                        search = ""
                        UIApplication.shared.endEditing()
                        currentDetent = .height(60)
                        selectedLocation = nil
                        searchResults.removeAll()
                        
                    }label: {
                        Image("icon-close")
                    }
                    .buttonStyle(ButtonStyle_m())
                }
                
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.3), value: currentDetent)
            .padding(.top, 32)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .disabled(!appState.isShowingSearchView)
        .presentationCornerRadius(20)
        // 2 用户无法通过向下滑动来关闭工作表视图
        .interactiveDismissDisabled()//
        // 3 工作表视图有两种可能的尺寸：小尺寸（200 点高）和大尺寸（默认尺寸）
        .presentationDetents([.height(60), .large], selection: $currentDetent)
        // 4 模糊效果
        .presentationBackground(.regularMaterial)
        // 5 用户可以与其后面的地图视图进行交互
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
    }
    
    private func didTapOnCompletion(_ completion: SearchCompletions) {
        Task {
            // 取消当前任务
            currentSearchTask?.cancel()
                // 启动新任务
            currentSearchTask = Task {
                if let singleLocation = try? await locationService.search(with: "\(completion.title) \(completion.subTitle)").first {
                    searchResults = [singleLocation]
                    selectedLocation = singleLocation
                    print("Selected Location in SheetView: \(String(describing: selectedLocation))")
                    withAnimation(Animation.spring()) {
                        position = .region(MKCoordinateRegion(center: singleLocation.location, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
                        appState.isShowingShowMarker = true
                        appState.isShowingSearchView = false
                        currentDetent = .height(60)
                        appState.isShowingResultCardView = true
                    }
                }
            }
        }
    }
}



//#Preview {
//    SheetView()
//}


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
        completions.removeAll()
        let mapKitRequest = MKLocalSearch.Request()
        mapKitRequest.naturalLanguageQuery = query
        mapKitRequest.resultTypes = .pointOfInterest
        if let coordinate {
            mapKitRequest.region = .init(.init(origin: .init(coordinate), size: .init(width: 1, height: 1)))
        }
        
        let search = MKLocalSearch(request: mapKitRequest)
        
        let response = try await search.start()
        print([SearchResult].self)  //测试
        
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
