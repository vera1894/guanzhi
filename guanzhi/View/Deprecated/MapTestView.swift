//
//  MapTestView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/6/8.
//

import SwiftUI
import MapKit
import CoreLocation

extension CLLocationCoordinate2D {
    static let bigBen = CLLocationCoordinate2D(latitude: 51.500685, longitude: -0.124570)
    
    static let towerBridge = CLLocationCoordinate2D(latitude: 51.505507, longitude: -0.075402)
    
    static let pickupLocation = CLLocationCoordinate2D(latitude: 51.500926, longitude: -0.125977)
}

struct MapTestView: View {
    
    @Namespace var mapScope
    
    @State private var position: MapCameraPosition = .automatic
    @State private var searchResults: [MKMapItem] = []
    @StateObject var mapData = MapViewModel()
    @State var locationManager = CLLocationManager()
    
    let placeholder = "🔍想瞧瞧哪里？"
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    @State private var showBottomSheet: Bool = false
    @State private var detents: Set<PresentationDetent> = [.height(60), .large]
    @State private var currentDetent: PresentationDetent = .height(60) // 用于跟踪当前 BottomSheet 的状态
    @State private var showLocationsBottomSheet: Bool = false
    @State private var locationSheetDetents: Set<PresentationDetent> = [.height(140)]
    @State private var locationSheetCurrentDetent: PresentationDetent = .height(140)
    @State private var locationSheetText: String = ""
    
    
    var body: some View {
        ZStack {
            
            //initialPosition: .userLocation(fallback: .automatic)
            Map(position: $mapData.cameraPosition, interactionModes: [.all], scope: mapScope) {
                Annotation("", coordinate: .pickupLocation, anchor: .bottom) {
                    ZStack {
                        
                        Button{
                            //Seee位置，需要添加是否已经定位的状态 isLocated
                        }label: { }
                    .buttonStyle(SeeePositionStyle(isEnabled: true))
                        
                    }
                }
                UserAnnotation()
                
                ForEach(searchResults, id: \.self) { result in
                    Marker(item: result)
                }
                
            }
            .environmentObject(mapData)
            .mapStyle(.imagery(elevation: .realistic))
            .onChange(of: mapData.cameraPosition) { _, _ in
                mapData.shouldUpdateCamera = false
            }
            .gesture(
                DragGesture().onEnded { _ in
                    mapData.shouldUpdateCamera = false
                }
            )
            
            .overlay(alignment:.bottomTrailing) {
                if showLocationsBottomSheet == false {
                    VStack(spacing: 32) {
                        
                        VStack(spacing: 16) {
                            Button(action: {
                                // 头像-s
                            }) { }
                            .buttonStyle(AvatarStyle_s(isEnabled: true, profileImage: Image("例子"), borderThickness: 4))
                            
                            Button{
                                //提醒按钮-圆形
                            }label: {
                                Image("icon-notification")
                            }
                            .buttonStyle(ButtonStyle_m())
                            
                            Button{
                                //定位按钮-圆形
                            }label: {
                                Image("icon-location")
                            }
                            .buttonStyle(ButtonStyle_m())
                        }
                        
                        Spacer()
                        
                        VStack {
                            MapCompass(scope: mapScope)
                            MapPitchToggle(scope: mapScope)
                            MapUserLocationButton(scope: mapScope)
                        }
                        .mapControlVisibility(.visible)
                        .buttonBorderShape(.circle)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 72)
                }
            }
            .mapScope(mapScope)
            
        }
        .task {
            showBottomSheet = true  //显示搜索底栏
            showLocationsBottomSheet = false  //显示地点底栏
            print("开始测试")
        }
        .sheet(isPresented: $showBottomSheet) {  //搜索框底栏
            ScrollView(.vertical, content: {
                VStack(alignment: .leading, spacing: 15, content: {
//
                    HStack(spacing: 8) {
                        
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.shadow(.inner(color: Color("color-primary").opacity(1), radius: 0, x: 4, y: 6)))
                            .stroke(.black, lineWidth: 4)
                            .foregroundStyle(Color("color-white").opacity(1))
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .overlay {
                                TextField(placeholder, text: $mapData.searchTxt)
                                    .font(.system(size: 18, weight: .regular, design: .default))
                                    .padding(.horizontal, 16)
                                    .frame(height: 40)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0))
                                    .cornerRadius(20)
                                    .multilineTextAlignment(.leading)
                                    .focused($isFocused)
                                    .onChange(of: mapData.searchTxt) {_, newValue in
                                        if newValue.count >= 400 {
                                            mapData.searchTxt = String(newValue.prefix(400))
                                            isFocused = false
                                        }
                                        let delay = 0.3
                                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                            if newValue == mapData.searchTxt {
                                                mapData.searchQuery()
                                            }
                                        }
                                    }
                                    .onSubmit {
                                        mapData.searchQuery()
                                    }
                            }
                        
                        if currentDetent != .large { // 根据 BottomSheet 的状态隐藏或显示  目前无法实现！！！！
                            Button(action: {
                                // 分享地点-胶囊按钮hug
                            }) {
                                Text("📷 分享地点")
                            }
                            .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: true))
                        } else {
                            Button{
                                //关闭按钮-圆形
                                
                            }label: {
                                Image("icon-close")
                            }
                            .buttonStyle(ButtonStyle_m())
                        }
                     
                        
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if !mapData.places.isEmpty && mapData.searchTxt != "" {
                        ScrollView {
                            VStack(spacing: 15) {
                                ForEach(mapData.places) { place in
                                    Text(place.placemark.name ?? "")
                                        .foregroundColor(Color("text-black"))
                                        .frame(maxWidth: .infinity)
                                        .background(.clear)
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            print("开始测试搜索")
                                            mapData.selectPlace(place: place)
                                            isFocused = false
                                            locationSheetText = place.placemark.name ?? ""
                                            withAnimation { //*高度调整仍然不起作用
                                                currentDetent = .height(60)
                                                                                    }
                                            
                                            if let coordinate = place.placemark.location?.coordinate {
                                                position = .camera(MapCamera(centerCoordinate: coordinate, distance: 500, heading: 0, pitch: 0))
                                                                                    }
                                            //点击结果后隐藏搜索框，显示地点信息栏
                                            showBottomSheet = false
                                            showLocationsBottomSheet = true
                                  
                                        }
                                    Divider()
                                }
                            }
                            .background(.clear)
                        }
                    }
                })
                .padding(.top, 20)
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .presentationDetents(detents, selection: $currentDetent) // 绑定 BottomSheet 的状态
            .presentationCornerRadius(20)
            .presentationBackground(.regularMaterial)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))  //用于对下层的可操控
            .interactiveDismissDisabled()  //用于限制无法下滑关闭
        }
        .sheet(isPresented: $showLocationsBottomSheet) {
                VStack(alignment: .leading, spacing: 15, content: {
                    HStack(spacing: 8) {
                        Text(locationSheetText)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(Color("text-black"))
                        
                        Spacer()
                        
                        Button{
                            //关闭按钮-圆形
                            //点击后关闭地点信息栏，显示搜索底栏
                            showBottomSheet = true
                            showLocationsBottomSheet = false
                        }label: {
                            Image("icon-close")
                        }
                        .buttonStyle(ButtonStyle_m())
                        
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    VStack {
                        Text("没有瞧到有用的信息？去试试求助👇")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(Color("text-gray"))
                        
                        Button(action: {
                                    // 求助（紫色）-胶囊按钮fill
                                }) {
                                    Text("🥺 求一下这里最新的照片或视频")
                                }
                            .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    
                })
                .padding(.top, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .presentationDetents(locationSheetDetents, selection: $locationSheetCurrentDetent) // 绑定 BottomSheet 的状态
                .presentationCornerRadius(20)
                .presentationBackground(.regularMaterial)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(140)))  //用于对下层的可操控
                .interactiveDismissDisabled()  //用于限制无法下滑关闭
        }
        
        //ZStack
    }
    
    private func search(location: CLLocationCoordinate2D, query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
                            center: location,
                            latitudinalMeters: 100,
                            longitudinalMeters: 100)
        
        Task {
            let search = MKLocalSearch(request: request)
            let response = try? await search.start()
            searchResults = response?.mapItems ?? []
        }
    }
}

#Preview {
    MapTestView()
}
