//  首页
//  ContentView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/13.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = true
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
    }
}


struct FrontView: View {
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    @State private var isPresented = false
    
    
    var body: some View {
        ZStack {
            //地图
            MapView(region: $region)
                .edgesIgnoringSafeArea(.all)
            //按钮
            VStack{
                Spacer()
                Button {
                    getUserLocation()
                } label: {
                    Image("location")
                        .frame(width: Constants.iconSizeM, height: Constants.iconSizeM)
                        .padding(.trailing,Constants.spacingSpacingXs)
                }
                
                VStack(spacing: 0){
                    VStack(alignment: .center, spacing: Constants.spacingSpacingS) {
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(width: 36, height: 6)
                            .background(Constants.mainPrimaryGery)
                            .cornerRadius(3)
                    }
                    .padding(.horizontal, Constants.spacingSpacingM)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .background(.white)
                    
                    HStack(alignment: .top, spacing: Constants.spacingSpacingXs) {
                        Button(action:{
                            isPresented = true
                        }) {
                            TextFieldView()
                        }
                        .padding(.leading,Constants.spacingSpacingM)
                        // 通过修饰符弹出页面
                        .fullScreenCover(isPresented: $isPresented, content: FullScreenView.init)
                        
                        //相机按钮
                        Button{
                            
                        }label: {
                            Image("camera")
                            .frame(width: 40, height: 40)
                            .padding(.trailing,Constants.spacingSpacingM)
                        }
                    }
                    .padding(.horizontal, Constants.spacingSpacingM)
                    .padding(.top, Constants.spacingSpacing0)
                    .padding(.bottom, 0)
                    .frame(width: 430, alignment: .top)
                    .background(.white)
                    
                    
                    
                }
               
            }
            
            
        }
        .onAppear {
            getUserLocation()
        }
    }
    
    func getUserLocation() {
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
        
        DispatchQueue.global().async {
            if CLLocationManager.locationServicesEnabled() {
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
                locationManager.startUpdatingLocation()
                
                if let location = locationManager.location?.coordinate {
                    region = MKCoordinateRegion(center: location, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                    print("经纬度",location.latitude,location.longitude)
                }
            }
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        FrontView()
    }
}
