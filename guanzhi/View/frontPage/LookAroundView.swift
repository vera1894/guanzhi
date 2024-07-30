//
//  LookAroundView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/7/30.
//

import SwiftUI
import MapKit

struct LookAroundView: View {
    
    @State private var searchResults = [SearchResult]()
//    let itinerary: [ItineraryItem]
    
    var body: some View {
        ScrollView {
//            LazyVStack {
//                ForEach(searchResults) { item in
//                    LookAroundPreview(initialScene: item.lookAroundScene)
//                        .frame(height: 128)
//                        .overlay(alignment: .bottomTrailing) {
//                            Text(item.title)
//                                .font(.caption)
//                                .foregroundColor(.white)
//                                .padding()
//                        }
//                }
//            }
        }
    }
}

#Preview {
    LookAroundView()
}
