//
//  MapView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/10/14.
//


import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var locationManager: LocationManager
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        Map(coordinateRegion: $region, showsUserLocation: true)
            .onReceive(locationManager.$currentLocation) { location in
                if let location = location {
                    region.center = location
                }
            }
    }
}