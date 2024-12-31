//
//  CustomMapView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/9/24.
//


//import SwiftUI
//import MapKit
//
//struct CustomMapView: UIViewRepresentable {
//    @Environment(\.appState) var appState
//    @Binding var region: MKCoordinateRegion
//    @Binding var selectedAnnotation: CustomAnnotation?
//    @Binding var locationAnimating: Bool
//    @Binding var annotations: [CustomAnnotation]
//    var onRegionChange: ((MKCoordinateRegion) -> Void)?
//
//    func makeCoordinator() -> Coordinator {
//            Coordinator(self)
//        }
//
//    func makeUIView(context: Context) -> MKMapView {
//        let mapView = MKMapView()
//        mapView.delegate = context.coordinator
//        mapView.showsUserLocation = true
//
//        // 设置初始区域
//        mapView.setRegion(region, animated: false)
//
//        // 添加手势识别器以检测用户交互
//        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapPanGesture(_:)))
//        panGesture.delegate = context.coordinator
//        mapView.addGestureRecognizer(panGesture)
//        // 添加捏合手势识别器，用于检测用户交互
//        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapPinchGesture(_:)))
//        pinchGesture.delegate = context.coordinator
//        mapView.addGestureRecognizer(pinchGesture)
//
//        return mapView
//    }
//
//    func updateUIView(_ mapView: MKMapView, context: Context) {
//        print("updateUIView called")
//        if !context.coordinator.isUserInteracting {
//            mapView.setRegion(region, animated: true)
//        }
//
//        // 更新标注
//        updateAnnotations(on: mapView, context: context)
//    }
//
//    func updateAnnotations(on mapView: MKMapView, context: Context) {
//        let currentAnnotations = context.coordinator.displayedAnnotations
//        let newAnnotationsSet = Set(annotations)
//
//        let annotationsToRemove = currentAnnotations.subtracting(newAnnotationsSet)
//        let annotationsToAdd = newAnnotationsSet.subtracting(currentAnnotations)
//
//        print("currentAnnotations count: \(currentAnnotations.count)")
//        print("newAnnotationsSet count: \(newAnnotationsSet.count)")
//        print("annotationsToRemove count: \(annotationsToRemove.count)")
//        print("annotationsToAdd count: \(annotationsToAdd.count)")
//
//        for annotation in annotationsToRemove {
//            print("Annotation to remove: \(annotation.coordinate.latitude), \(annotation.coordinate.longitude), type: \(annotation.annotationType)")
//        }
//
//        for annotation in annotationsToAdd {
//            print("Annotation to add: \(annotation.coordinate.latitude), \(annotation.coordinate.longitude), type: \(annotation.annotationType)")
//        }
//
//        mapView.removeAnnotations(Array(annotationsToRemove))
//        mapView.addAnnotations(Array(annotationsToAdd))
//
//        context.coordinator.displayedAnnotations = newAnnotationsSet
//    }
//
//    // MARK: - Coordinator
//    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
//        var parent: CustomMapView
//        var displayedAnnotations: Set<CustomAnnotation> = []
////        var isUpdatingRegion = false
//        var isUserInteracting = false
//
//        init(_ parent: CustomMapView) {
//            self.parent = parent
//        }
//
//        // 处理平移手势
//        @objc func handleMapPanGesture(_ gesture: UIPanGestureRecognizer) {
//            if gesture.state == .began {
//                isUserInteracting = true
//                print("User started panning")
//            } else if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
//                isUserInteracting = false
//                print("User ended panning")
//            }
//        }
//
//        // 处理捏合手势
//        @objc func handleMapPinchGesture(_ gesture: UIPinchGestureRecognizer) {
//            if gesture.state == .began {
//                isUserInteracting = true
//                print("User started pinching")
//            } else if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
//                isUserInteracting = false
//                print("User ended pinching")
//            }
//        }
//
//        // 监听地图区域变化
//        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
//                print("regionDidChangeAnimated called")
//                if !isUserInteracting {
//                    parent.region = mapView.region
//                    print("Updated region from map view")
//                } else {
//                    print("User is interacting; region change not propagated")
//                }
//            }
//
//        // 自定义标注视图
//        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
//            if annotation is MKUserLocation {
//                return nil
//            }
//
//            guard let customAnnotation = annotation as? CustomAnnotation else {
//                return nil
//            }
//
//            let identifier: String
//            let view: AnyView
//
//            switch customAnnotation.annotationType {
//            case .searchResult:
//                identifier = "SearchResultAnnotationView"
//                view = AnyView(
//                    Button {
//                        // 点击事件
//                    } label: { }
//                        .buttonStyle(IconStylePosition(isAnimating: self.parent.$locationAnimating))
//                )
//
//            case .nearbyShare:
//                identifier = "NearbyShareAnnotationView"
//                view = AnyView(
//                    MapAnnotationView(annotation: customAnnotation.annotationData!, imageUrl: customAnnotation.imageUrl)
//                )
//            }
//
//            var annotationView: MKAnnotationView
//            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
//                annotationView = dequeuedView
//                annotationView.annotation = customAnnotation
//                // 移除之前的子视图，防止视图混乱
//                annotationView.subviews.forEach { $0.removeFromSuperview() }
//            } else {
//                annotationView = MKAnnotationView(annotation: customAnnotation, reuseIdentifier: identifier)
//                annotationView.canShowCallout = false
//            }
//
//            // 使用 UIHostingController 将 SwiftUI 视图嵌入到 MKAnnotationView 中
//            let hostingController = UIHostingController(rootView: view)
//            hostingController.view.backgroundColor = .clear
//            hostingController.view.frame = CGRect(x: 0, y: 0, width: 50, height: 50) // 根据需要调整大小
//
//            annotationView.addSubview(hostingController.view)
//            annotationView.frame = hostingController.view.frame
//
//            return annotationView
//        }
//
//        // 处理标注点击事件
//        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
//            if let customAnnotation = view.annotation as? CustomAnnotation {
//                parent.selectedAnnotation = customAnnotation
//                if customAnnotation.annotationType == .searchResult {
//                    // 点击了搜索结果的标注，展示 ResultCardView
//                    DispatchQueue.main.async {
//                        self.parent.appState.isShowingResultCardView = true
//                        self.parent.appState.isShowingShowMarker = true
//                    }
//                }
//            }
//        }
//
//        // 允许多个手势识别器同时识别
//        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//            return true
//        }
//    }
//}
//
//// MARK: - MapCameraPosition
//enum CustomMapCameraPosition: Equatable {
//    case automatic
//    case region(MKCoordinateRegion)
//}
//
//extension MKCoordinateRegion: Equatable {
//    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
//        return lhs.center.latitude == rhs.center.latitude &&
//               lhs.center.longitude == rhs.center.longitude &&
//               lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
//               lhs.span.longitudeDelta == rhs.span.longitudeDelta
//    }
//}
//
//extension MKCoordinateRegion {
//    func isEqualToRegion(_ other: MKCoordinateRegion, tolerance: CLLocationDegrees = 0.0001) -> Bool {
//        let centerEqual = abs(self.center.latitude - other.center.latitude) < tolerance &&
//                          abs(self.center.longitude - other.center.longitude) < tolerance
//        let spanEqual = abs(self.span.latitudeDelta - other.span.latitudeDelta) < tolerance &&
//                        abs(self.span.longitudeDelta - other.span.longitudeDelta) < tolerance
//        return centerEqual && spanEqual
//    }
//}




//struct CustomMapView: UIViewRepresentable {
//    @Binding var region: MKCoordinateRegion
//    @Binding var annotations: [MKAnnotation]
//
//    func makeUIView(context: Context) -> MKMapView {
//        let mapView = MKMapView()
//        mapView.delegate = context.coordinator
//        mapView.showsUserLocation = true
//        // 设置初始区域
//        mapView.setRegion(region, animated: false)
//        return mapView
//    }
//
//    func updateUIView(_ mapView: MKMapView, context: Context) {
//        // 仅当区域确实发生变化时，才更新地图区域，避免不必要的更新
//        if !mapView.region.isEqualToRegion(region) {
//            mapView.setRegion(region, animated: true)
//        }
//
//        // 更新标注
//        mapView.removeAnnotations(mapView.annotations)
//        mapView.addAnnotations(annotations)
//    }
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator()
//    }
//
//    class Coordinator: NSObject, MKMapViewDelegate {
//        // 不再持有 parent 的引用
//
//        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
//            print("标注被点击：\(String(describing: view.annotation?.title ?? "未知"))")
//            // 处理标注点击事件，例如显示详情视图
//        }
//
//        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
//            if annotation is MKUserLocation {
//                return nil
//            }
//
//            let identifier = "CustomAnnotationView"
//            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
//
//            if annotationView == nil {
//                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
//                annotationView?.canShowCallout = true
//                annotationView?.image = UIImage(systemName: "mappin.circle.fill")
//            } else {
//                annotationView?.annotation = annotation
//            }
//
//            return annotationView
//        }
//    }
//}
//
//extension MKCoordinateRegion {
//    func isEqualToRegion(_ other: MKCoordinateRegion, tolerance: CLLocationDegrees = 0.0001) -> Bool {
//        let centerEqual = abs(self.center.latitude - other.center.latitude) < tolerance &&
//                          abs(self.center.longitude - other.center.longitude) < tolerance
//        let spanEqual = abs(self.span.latitudeDelta - other.span.latitudeDelta) < tolerance &&
//                        abs(self.span.longitudeDelta - other.span.longitudeDelta) < tolerance
//        return centerEqual && spanEqual
//    }
//}
