//
//  SheetView.swift
//  guanzhi
//
//  Created by Vera on 2024/2/29.
//

import SwiftUI
import MapKit

struct SheetView: View {
    @Environment(\.appState) var appState
    @EnvironmentObject var searchViewModel: SearchViewModel
    @EnvironmentObject var onboardingCoordinator: OnboardingCoordinator
    @State private var search: String = ""
    @State private var locationService = LocationService(completer: .init())
//    @Binding var searchResults: [SearchResult]
    @State private var image: UIImage?
    let placeholder = String(localized: "🔍想瞧瞧哪里？")
    @Binding var currentDetent: PresentationDetent // 绑定sheetview高度
//    @Binding var selectedLocation: SearchResult?
//    @Binding var position: CustomMapCameraPosition
//    @Binding var currentSearchTask: Task<Void, Never>?  // 添加任务管理
    @State private var currentSearchTask: Task<Void, Never>? = nil // 添加任务管理
    var onLocationSelected: ((CLLocationCoordinate2D, String) -> Void)?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var shouldShowResults: Bool = false // iOS 26: 追踪是否应该显示结果
    
    var body: some View {
        @Bindable var appState = appState
        VStack(spacing: 0) {
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
                                .focused($isSearchFieldFocused)
                                .autocorrectionDisabled()
//                                .onTapGesture {
//                                    currentDetent = .large
//                                    searchViewModel.selectedLocation = nil
//                                    searchViewModel.searchResults.removeAll()
//                                }
                                .onSubmit {
                                    // iOS 26 修复：点击回车时保持 sheet 展开，只收起键盘
                                    shouldShowResults = true // 标记要显示结果
                                    isSearchFieldFocused = false // 收起键盘
                                    // 确保 sheet 保持展开状态
                                    if currentDetent == .height(Constants.sheetCollapsedHeight) {
                                        currentDetent = .fraction(Constants.sheetExpandedFraction)
                                    }
                                }
                        }
                
                if currentDetent == .height(Constants.sheetCollapsedHeight) && !isSearchFieldFocused { // 根据 BottomSheet 的状态隐藏或显示
                    Button(action: {
                        // 【Onboarding】点击发布按钮，完成提示 D
                        onboardingCoordinator.handleEvent(.publishButtonTapped)
                        // 分享地点-胶囊按钮hug
                        appState.isShowingCameraView = true
                        appState.isShowingSearchView = false
                    }) {
                        Text("📷 发布观之")
                    }
                    .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: true))
                    .onboardingHighlight(onboardingCoordinator.currentStep == .publishReminder)
                    
                } else {
                    Button{
                        //关闭按钮-圆形
                        // iOS 26 修复：确保一次点击就能完全关闭，无论键盘是否开启
                        
                        // 先清理数据和状态
                        search = ""
                        shouldShowResults = false
                        searchViewModel.selectedLocation = nil
                        searchViewModel.searchResults.removeAll()
                        
                        // 同时收起键盘和折叠 sheet
                        isSearchFieldFocused = false
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentDetent = .height(Constants.sheetCollapsedHeight)
                        }
                    }label: {
                        Image("icon-close")
                    }
                    .buttonStyle(ButtonStyle_m())
                }
                
            }
            .padding(.top, 20)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // iOS 26 修复：当 sheet 展开、输入框聚焦或需要显示搜索结果时，显示列表
            if currentDetent != .height(Constants.sheetCollapsedHeight) || isSearchFieldFocused || shouldShowResults {
                List {
                    ForEach(locationService.completions) { completion in
                        Button(action: {didTapOnCompletion(completion) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(completion.title)
                                        .font(.headline)
                                        .fontDesign(.rounded)
                                    Text(completion.subTitle)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    if let url = completion.url {
                                        Link(url.absoluteString, destination: url)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                if let coord = completion.coordinate {
                                    Text(distanceText(to: coord))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: search) {
            locationService.update(queryFragment: search, region: searchViewModel.region)
            // iOS 26 修复：输入改变时重置显示结果标记，显示自动完成
            if !search.isEmpty {
                shouldShowResults = false
            }
        }
        .disabled(!appState.isShowingSearchView)
        .onChange(of: isSearchFieldFocused) { oldValue, newValue in
            // iOS 26 修复：获得焦点时展开 sheet
            if newValue == true {
                // 使用 DispatchQueue 确保在下一个渲染周期执行，避免首次点击不生效
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentDetent = .fraction(Constants.sheetExpandedFraction)
                    }
                }
            }
        }
        // iOS 26 修复：移除内部的 presentationDetents，应该在调用 sheet 的地方设置
    }
    
    /// 计算从地图中心到目标坐标的距离文本
    private func distanceText(to coordinate: CLLocationCoordinate2D) -> String {
        let from = CLLocation(latitude: searchViewModel.region.center.latitude,
                              longitude: searchViewModel.region.center.longitude)
        let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let meters = from.distance(from: to)
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }

    private func didTapOnCompletion(_ completion: SearchCompletions) {
        Task {
            // 取消当前任务
            currentSearchTask?.cancel()
            // 启动新任务
            currentSearchTask = Task {
                if let singleLocation = try? await locationService.search(with: "\(completion.title) \(completion.subTitle)").first {
                    await MainActor.run {
                        // 调用 onLocationSelected 闭包，将地点坐标和名称传递回 SearchView
                        onLocationSelected?(singleLocation.location, completion.title)
                        // 更新 appState 和其他属性
                        appState.resultLocationName = completion.title
                        appState.isShowingShowMarker = true
                        appState.isShowingSearchView = false
                        currentDetent = .height(Constants.sheetCollapsedHeight)
                        shouldShowResults = false // 重置显示结果标记
                        appState.isShowingResultCardView = true
                    }
                }
            }
        }
    }
}


struct SearchCompletions: Identifiable {
    let id = UUID()
    let title: String
    let subTitle: String
    var url: URL?
    var coordinate: CLLocationCoordinate2D?
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
    
    func update(queryFragment: String, region: MKCoordinateRegion? = nil) {
        completer.resultTypes = [.pointOfInterest, .address]
        if let region {
            completer.region = region
            // iOS 18+: 强制区域优先，优先返回本地结果
            if #available(iOS 18.0, *) {
                completer.regionPriority = .required
            }
        }
        completer.queryFragment = queryFragment
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results.map { completion in
            let mapItem = completion.value(forKey: "_mapItem") as? MKMapItem

            return .init(
                title: completion.title,
                subTitle: completion.subtitle,
                url: mapItem?.url,
                coordinate: mapItem?.placemark.coordinate
            )
        }
    }
    
    func search(with query: String, coordinate: CLLocationCoordinate2D? = nil) async throws -> [SearchResult] {
        completions.removeAll()
        let mapKitRequest = MKLocalSearch.Request()
        mapKitRequest.naturalLanguageQuery = query
        mapKitRequest.resultTypes = [.pointOfInterest, .address]
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
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
            return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
        }
    
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
