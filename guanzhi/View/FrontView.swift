//
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
    

    var body: some View {
        ZStack {

            MapView(region: $region)
                .edgesIgnoringSafeArea(.all)
            HStack{
                Spacer()
                Button {
                    getUserLocation()
                } label: {
                    Image("location")
                    .frame(width: Constants.iconSizeM, height: Constants.iconSizeM)
                    .padding(.trailing,Constants.spacingSpacingXs)
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
