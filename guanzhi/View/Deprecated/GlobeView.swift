//
//  GlobeView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/3/21.
//

import SwiftUI
import MapKit

struct Location {
    var title: String
    var latitude: Double
    var longitude: Double
}

struct GlobeView: View {
    // add locations here
    @State var locations = [
        Location(title: "San Francisco", latitude: 37.7749, longitude: -122.4194),
        Location(title: "New York", latitude: 40.7128, longitude: -74.0060)
    ]
    
    var body: some View {
        MapView(locations: locations)
    }
}


struct MapView: UIViewRepresentable {
    @State var locations: [Location]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        // change the map type here
        mapView.mapType = .hybridFlyover
        
        return mapView
    }
    
    func updateUIView(_ view: MKMapView, context: Context) {
        for location in locations {
            // make a pins
            let pin = MKPointAnnotation()
            
            // set the coordinates
            pin.coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            
            // set the title
            pin.title = location.title
            
            // add to map
            view.addAnnotation(pin)
        }
    }
}


#Preview {
    GlobeView()
}
