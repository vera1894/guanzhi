//
//  CustomAnnotation.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/9/24.
//


import Foundation
import MapKit
import SwiftUI

class CustomAnnotation: NSObject, Identifiable, MKAnnotation {
    let id: String // 将 id 的类型修改为 String
    @objc dynamic var coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let imageUrl: URL?
    var annotationData: Share?
    let annotationType: AnnotationType

    init(
        id: String, // id 类型为 String
        coordinate: CLLocationCoordinate2D,
        title: String?,
        subtitle: String?,
        imageUrl: URL?,
        annotationData: Share?,
        annotationType: AnnotationType
    ) {
        self.id = id
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.imageUrl = imageUrl
        self.annotationData = annotationData
        self.annotationType = annotationType
    }

    // MARK: - Hashable (Stage 1: 用于 MKMapView 标注 diff 算法)
    override var hash: Int {
        return id.hashValue
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? CustomAnnotation else { return false }
        return self.id == other.id
    }
}

enum AnnotationType {
//    case searchResult
    case nearbyShare
}

/// 图片加载状态
private enum ImageLoadState {
    case loading
    case loaded(UIImage)
    case failed
}

struct MapAnnotationView: View {
    @Environment(\.appState) var appState
    @EnvironmentObject var searchViewModel: SearchViewModel
    var animationNamespace: Namespace.ID
    let annotation: CustomAnnotation
    @State private var loadState: ImageLoadState = .loading
    @State private var isPressed: Bool = false
    var isExpanded: Bool {
            (annotation.id == searchViewModel.selectedAnnotationID) && /*appState.isShareImageExpanded*/searchViewModel.isShareDetailOverlayShown
        }
//    @StateObject private var viewModel: MapAnnotationViewModel
    var onTap: (UIImage?) -> Void
    init(animationNamespace: Namespace.ID, annotation: CustomAnnotation, onTap: @escaping (UIImage?) -> Void) {
        self.animationNamespace = animationNamespace
        self.annotation = annotation
        self.onTap = onTap
//        _viewModel = StateObject(wrappedValue: MapAnnotationViewModel(annotation: annotation))
        }

    /// 获取已加载的图片（用于 onTap）
    private var loadedImage: UIImage? {
        if case .loaded(let image) = loadState {
            return image
        }
        return nil
    }

    var body: some View {
        ZStack(alignment: .center) {
            if !searchViewModel.isShareDetailOverlayShown/*appState.isShareImageExpanded*/ {
                Image("icon-position")
                    .frame(width: 24, height: 33)
                    .offset(y: 32)
            }

            switch loadState {
            case .loaded(let uiImage):
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(Circle())
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(Color.black, lineWidth: 4))

            case .loading:
                // 加载中状态
                CircularImagePlaceholderView(state: .loading, size: 64)
                    .onAppear {
                        loadImage()
                    }

            case .failed:
                // 加载失败状态
                CircularImagePlaceholderView(state: .failed, size: 64)
            }

        }
        .onTapGesture {
                    onTap(loadedImage)
                }
//        .coordinateSpace(name: "shared")
        .compositingGroup()
        .shadow(color: Color("color-primary").opacity(isExpanded ? 0 : 1),
                radius: 0, x: isExpanded ? 0 : 2, y: isExpanded ? 0 : 4)
        // 添加按钮按下效果
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .brightness(isPressed ? -0.2 : 0)
        .animation(.easeInOut(duration: 0.2), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation {
                        self.isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation {
                        self.isPressed = false
                    }
                }
        )
    }

    private func loadImage() {
            guard let imageUrl = annotation.imageUrl else {
                loadState = .failed
                return
            }
            ImageCache.shared.loadImage(from: imageUrl) { loadedImage in
                if let image = loadedImage {
                    self.loadState = .loaded(image)
                } else {
                    self.loadState = .failed
                }
            }
        }

}

extension MKCoordinateRegion: Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        return lhs.center.latitude == rhs.center.latitude &&
               lhs.center.longitude == rhs.center.longitude &&
               lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
               lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
}


class MapAnnotationViewModel: ObservableObject {
    @Published var image: UIImage?
    let annotation: CustomAnnotation

    init(annotation: CustomAnnotation) {
        self.annotation = annotation
        loadImage()
    }

    private func loadImage() {
        guard let imageUrl = annotation.imageUrl else {
            print("Annotation \(annotation.id) 没有有效的图片 URL")
            return
        }

        ImageCache.shared.loadImage(from: imageUrl) { [weak self] loadedImage in
            self?.image = loadedImage
            if let _ = loadedImage {
                print("Annotation \(self?.annotation.id ?? "") 成功加载图片")
            } else {
                print("Annotation \(self?.annotation.id ?? "") 图片加载失败")
            }
        }
    }
}


struct OffsetKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    
    static func reduce(value: inout [String : Anchor<CGRect>], nextValue: () -> [String : Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}







//struct SharedImageView: View {
//    let image: UIImage
//    let isExpanded: Bool
//    let animationNamespace: Namespace.ID
//    let id: String
//
//    var body: some View {
//        
//        Image(uiImage: image)
//            .resizable()
//            .aspectRatio(contentMode: isExpanded ? .fit : .fill)
//            .clipShape(isExpanded ? AnyShape(Rectangle()) : AnyShape(Circle()))
//            .ignoresSafeArea(.all)
//            .frame(width: isExpanded ? UIScreen.main.bounds.width : 64,
//                   height: isExpanded ? UIScreen.main.bounds.height : 64)
//            .overlay(
//                Circle().stroke(Color.black.opacity(isExpanded ? 0 : 1), lineWidth: isExpanded ? 0 : 4)
//            )
////            .matchedGeometryEffect(id: "image-\(id)", in: animationNamespace, anchor: .center, isSource: true)
//            .onAppear {
//                print("SharedImageView matchedGeometryEffect id: image-\(id), namespace: \(animationNamespace)")
//            }
//    }
//}
