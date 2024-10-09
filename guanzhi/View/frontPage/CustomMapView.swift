//
//  CustomMapView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/9/24.
//


import SwiftUI
import MapKit

// MARK: - CustomMapView
struct CustomMapView/*<AppStateModel: AppState>*/: UIViewRepresentable {
//    @State var appState: AppStateModel
    @Bindable var appState: AppStateModel
    @Binding var position: CustomMapCameraPosition
    @Binding var region: MKCoordinateRegion
    @Binding var selectedAnnotation: CustomAnnotation?
    @Binding var locationAnimating: Bool
    @Binding var annotations: [CustomAnnotation]
    var onRegionChange: ((MKCoordinateRegion) -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        mapView.pointOfInterestFilter = .includingAll
        mapView.mapType = .standard
        
        // 设置初始位置
        updateMapCamera(mapView)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新地图相机位置
        updateMapCamera(mapView)

        // 更新标注
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotations(annotations)
    }
    
    func updateMapCamera(_ mapView: MKMapView) {
            switch position {
            case .automatic:
                break
            case .region(let region):
                mapView.setRegion(region, animated: true)
            }
        }
}

// MARK: - Coordinator
extension CustomMapView {
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CustomMapView
        
        init(_ parent: CustomMapView) {
            self.parent = parent
        }
        
        // 监听地图区域变化
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
            parent.position = .region(mapView.region)
            parent.onRegionChange?(mapView.region)
        }
        
        // 自定义标注视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 检查是否是用户位置
            if annotation is MKUserLocation {
                return nil
            }

            // 检查是否是 CustomAnnotation
            guard let customAnnotation = annotation as? CustomAnnotation else {
                return nil
            }

            let identifier: String
            let view: AnyView

            switch customAnnotation.annotationType {
            case .searchResult:
                identifier = "SearchResultAnnotationView"

                // 创建搜索结果的 SwiftUI 视图
                view = AnyView(
                    Button {
                        // 点击事件
                    } label: {  }
                    .buttonStyle(IconStylePosition(isAnimating: self.parent.$locationAnimating))
                )

            case .nearbyShare:
                identifier = "NearbyShareAnnotationView"

                // 创建附近分享的 SwiftUI 视图
                view = AnyView(
                    MapAnnotationView(annotation: customAnnotation.annotationData!, imageUrl: customAnnotation.imageUrl)
                )
            }

            var annotationView: MKAnnotationView
            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
                annotationView = dequeuedView
                annotationView.annotation = customAnnotation
                // 移除之前的子视图，防止视图混乱
                annotationView.subviews.forEach { $0.removeFromSuperview() }
            } else {
                annotationView = MKAnnotationView(annotation: customAnnotation, reuseIdentifier: identifier)
                annotationView.canShowCallout = false
            }

            // 使用 UIHostingController 将 SwiftUI 视图嵌入到 MKAnnotationView 中
            let hostingController = UIHostingController(rootView: view)
            hostingController.view.backgroundColor = .clear
            hostingController.view.frame = CGRect(x: 0, y: 0, width: 50, height: 50) // 根据需要调整大小

            annotationView.addSubview(hostingController.view)
            annotationView.frame = hostingController.view.frame

            return annotationView
        }
        
        // 处理标注点击事件
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let customAnnotation = view.annotation as? CustomAnnotation {
                parent.selectedAnnotation = customAnnotation
                if customAnnotation.annotationType == .searchResult {
                    // 点击了搜索结果的标注，展示 ResultCardView
                    DispatchQueue.main.async {
                        self.parent.appState.isShowingResultCardView = true
                        self.parent.appState.isShowingShowMarker = true
                    }
                }
            }
        }
        
        
        
    }
}

// MARK: - MapCameraPosition
enum CustomMapCameraPosition: Equatable {
    case automatic
    case region(MKCoordinateRegion)
}


extension MKCoordinateRegion: @retroactive Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        return lhs.center.latitude == rhs.center.latitude &&
               lhs.center.longitude == rhs.center.longitude &&
               lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
               lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
}
