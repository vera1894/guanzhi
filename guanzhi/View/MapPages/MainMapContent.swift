//
//  MainMapContent.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/2/6.
//


import SwiftUI
import MapKit

/// 把搜索视图需要的地图内容（标注、Marker、用户位置等）统一封装在这里
struct MainMapContent: DynamicMapContent {
    typealias Data = [CustomAnnotation]
    
    // 需要从外部传入的依赖
    var searchViewModel: SearchViewModel
    var locationMarkers: [LocationMarker]
    var animationNamespace: Namespace.ID
    
    var data: [CustomAnnotation] {
            searchViewModel.annotations
        }
    
    /// 你需要在点击标注时做一些切换逻辑：更新 appState / 跳转
    @Environment(\.appState) var appState
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    // 这是 DynamicMapContent 的核心：描述“要在地图上放什么”
    @MapContentBuilder
    var body: some MapContent {
        
        // 1) 地图上“分享”标注
        ForEach(searchViewModel.annotations, id: \.id) { annotation in
            Annotation("", coordinate: annotation.coordinate, anchor: .bottom) {
                // 标注视图
                MapAnnotationView(
                    animationNamespace: animationNamespace,
                    annotation: annotation,
                    onTap: { uiImage in
                        // 这里复制了你原先的点击逻辑
                        handleAnnotationTap(annotation, uiImage: uiImage)
                    }
                )
                .environmentObject(searchViewModel)
                .id(annotation.id)
            }
        }
        
        // 2) 其它 Marker
        ForEach(locationMarkers) { marker in
            Marker(marker.title ?? "", coordinate: marker.coordinate)
        }
        
        // 3) 用户自定义位置
        UserAnnotation()
    }
    
    // MARK: - 处理点击标注
    private func handleAnnotationTap(_ annotation: CustomAnnotation, uiImage: UIImage?) {
        searchViewModel.selectAnnotation(annotation, thumbnailImage: uiImage)
        
        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.4)) {
            // 关闭搜索 Sheet
            appState.isShowingSearchView = false
            
            // 根据 appState.useOverlayMode 判断是 Overlay 还是 NavigationStack
            if appState.useOverlayMode {
                searchViewModel.isShareDetailOverlayShown = true
                print("searchViewModel.isShareDetailOverlayShown = \(searchViewModel.isShareDetailOverlayShown)")
            } else {
                navigationCoordinator.path.append(Route.shareDetailView(annotationID: annotation.id))
            }
        }
    }
}
