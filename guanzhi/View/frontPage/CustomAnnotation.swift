//
//  CustomAnnotation.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/9/24.
//


import Foundation
import MapKit
import SwiftUI

class CustomAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    // 添加其他属性
    var imageUrl: URL?
    var annotationData: ResponsedShare?
    var annotationType: AnnotationType // 新增属性

    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, imageUrl: URL?, annotationData: ResponsedShare?, annotationType: AnnotationType) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.imageUrl = imageUrl
        self.annotationData = annotationData
        self.annotationType = annotationType
    }
}

enum AnnotationType {
    case searchResult
    case nearbyShare
}


struct MapAnnotationView: View {
    let annotation: ResponsedShare
    let imageUrl: URL?
    @Environment(\.appState) var appState

    var body: some View {
        ZStack {
            Button {
                // 处理点击事件，例如展示详情或执行其他操作
                appState.isShowingSearchView = false
                appState.isShowingResultCardView = false
            } label: {
                // 自定义按钮样式和显示内容
            }
            .buttonStyle(SeeePositionStyle(isEnabled: true, imageUrl: imageUrl))
        }
    }
}
