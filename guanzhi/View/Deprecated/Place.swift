//
//  Place.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/6/8.
//

import SwiftUI
import MapKit

struct Place: Identifiable {
    
    var id = UUID().uuidString
    var placemark: CLPlacemark
}
