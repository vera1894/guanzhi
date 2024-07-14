//
//  GlobeView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/3/21.
//

import SwiftUI
import MapKit

struct GlobeView: View {
    @StateObject var mapData = GlobeViewModel()
    @State var locationManager = CLLocationManager()
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    @State private var showBottomSheet: Bool = false
    @State private var detents: Set<PresentationDetent> = [.height(60), .large]

    var body: some View {
        ZStack {
            MapView()
                .environmentObject(mapData)
                .ignoresSafeArea(.all)
//                .mapStyle(.imagery(elevation: .realistic))
        }
        .task {
            showBottomSheet = true
        }
        .sheet(isPresented: $showBottomSheet) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.shadow(.inner(color: Color("color-primary").opacity(1), radius: 0, x: 4, y: 6)))
                            .stroke(.black, lineWidth: 4)
                            .foregroundStyle(Color("color-white").opacity(1))
                            .frame(height: 40)
                            .frame(width: .infinity)
                            .overlay {
                                TextField("🔍想瞧瞧哪里？", text: $mapData.searchTxt)
                                    .font(.system(size: 18, weight: .regular, design: .default))
                                    .padding(.horizontal, 16)
                                    .frame(height: 40)
                                    .background(Color.gray.opacity(0))
                                    .cornerRadius(20)
                                    .multilineTextAlignment(.leading)
                                    .focused($isFocused)
                                    .onChange(of: mapData.searchTxt) { newValue in
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
                        
                        if !isFocused {
                            Button(action: {
                                // 分享地点-胶囊按钮hug
                            }) {
                                Text("📷 分享地点")
                            }
                            .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: true))
                        }
                        
                        
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    
                }
                .padding(.top, 20)
                
                if !mapData.places.isEmpty && mapData.searchTxt != "" {
                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(mapData.places) { place in
                                Text(place.placemark.name ?? "")
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .background(.clear)
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        mapData.selectPlace(place: place)
                                        isFocused = false
                                        //底栏高度变低
                                    }
                                Divider()
                            }
                        }
//                        .padding()
                        .background(.clear)
                    }
                }
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .presentationDetents(detents)
            .presentationCornerRadius(20)
            .presentationBackground(.regularMaterial)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
            .interactiveDismissDisabled()
        }
    }
}

struct MapView: UIViewRepresentable {
    @EnvironmentObject var mapData: GlobeViewModel
    
    func makeCoordinator() -> Coordinator {
        return MapView.Coordinator(mapData: mapData)
    }

    func makeUIView(context: Context) -> MKMapView {
        let view = mapData.mapView
                view.showsUserLocation = true
                view.mapType = .satelliteFlyover
                view.showsBuildings = true
                view.showsUserLocation = true
                view.delegate = context.coordinator
        
//        // 配置相机以显示地球样式
//        let camera = MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: 0, longitude: 0), fromDistance: 30000000, pitch: 0, heading: 0)
//        view.setCamera(camera, animated: false)
        
        return view
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
            // 重新设置相机
//            let camera = MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: 0, longitude: 0), fromDistance: 30000000, pitch: 0, heading: 0)
//            uiView.setCamera(camera, animated: false)
        }

    class Coordinator: NSObject, MKMapViewDelegate {
        var mapData: GlobeViewModel

        init(mapData: GlobeViewModel) {
            self.mapData = mapData
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation.isKind(of: MKUserLocation.self) {
                return nil
            } else {
                let pinAnnotation = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "PIN_VIEW")
                pinAnnotation.tintColor = .red
                pinAnnotation.animatesDrop = true
                pinAnnotation.canShowCallout = true
                return pinAnnotation
            }
        }
    }
}


#Preview {
    GlobeView()
}
