//
//  SimpleCarouselView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/10/28.
//


import SwiftUI
import PhotosUI
import _AVKit_SwiftUI

struct SimpleCarouselView: View {
    @Environment(\.appState) var appState
    @ObservedObject var searchViewModel: SearchViewModel
    var animationNamespace: Namespace.ID
    @State private var isShowShareDetailsCard: Bool = true // 控制卡片的显示与隐藏
    @State private var isFullScreen: Bool = false // 控制卡片的当前状态（部分或全屏）
    @State private var dragOffset: CGFloat = 0 // 记录拖动过程中的偏移量
    @State private var isAtTop: Bool = true
    @State private var isMoreOptionsShow: Bool = true
    @State private var isTieTieEnabled: Bool = false
    @State private var isShowCarousel: Bool = false
    @State private var image: UIImage?
    @State private var selectedIndex: Int = 0 //跟踪当前选中的索引
    
    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            ZStack {
////                    if let selectedAnnotation = searchViewModel.selectedAnnotation {
////                        if let firstMediaItem = searchViewModel.downloadMedia.first,
////                           let photo = firstMediaItem as? Photo {
////                            if let uiImage = UIImage(data: photo.data) {
//                    if let uiImage = searchViewModel.selectedAnnotationImage {
//                                Image(uiImage: uiImage) //"测试长图"
//                                    .resizable()
//                                    .aspectRatio(contentMode: .fit)
//                                    .clipShape(AnyShape(Rectangle()))
//                                    .ignoresSafeArea(.all)
//                                    .frame(width: UIScreen.main.bounds.width,height: UIScreen.main.bounds.height)
//                                    .overlay(Circle().stroke(Color.black.opacity(0), lineWidth: 0)
//                                    )
////                                    .matchedGeometryEffect(id: searchViewModel.selectedAnnotationID, in: animationNamespace, isSource: false /*, anchor: .center*/)
////                                    .matchedGeometryEffect(id: selectedAnnotation.id, in: animationNamespace/*, anchor: .center*/)
////                                    .onAppear {
////                                        print("SimpleCarouselView matchedGeometryEffect id: image-\(selectedAnnotation.id), namespace: \(animationNamespace)")
////                                    }
////                            }
////                        }
//                    } else {
//                        // 显示占位符或加载指示器
//                        ProgressView()
//                    }
                if !searchViewModel.downloadMedia.isEmpty {
                        // 显示完整的媒体内容
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(searchViewModel.downloadMedia.enumerated()), id: \.element.id) { index, itemWrapper in
                            MediaItemView(mediaItemWrapper: itemWrapper, thumbnailImage: searchViewModel.selectedAnnotationImage)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle())
                    .ignoresSafeArea()
                    .onChange(of: searchViewModel.downloadMedia.count) { oldCount, newCount in
                            if selectedIndex >= newCount {
                                selectedIndex = max(0, newCount - 1)
                            }
                        }
                }
//                    else if let thumbnailImage = searchViewModel.selectedAnnotationImage {
//                            // 显示缩略图
//                            Image(uiImage: thumbnailImage)
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .ignoresSafeArea()
//                                .overlay {
//                                    ProcessingView()
//                                }
//                        }
                else {
                        // 显示加载指示器
                    ProcessingView()
                        .ignoresSafeArea()
                }
                
            }
            .toolbar {
                if isShowShareDetailsCard {
                    ToolbarItem(placement: .topBarLeading) {
                        Button{
                            //返回按钮-圆形
                            print("关闭分享详情")
                            searchViewModel.isUpdatingAnnotations = false
                            appState.isShareImageExpanded = false
                            searchViewModel.selectedAnnotation = nil
                            searchViewModel.selectedAnnotationID = nil
                            searchViewModel.selectedAnnotationImage = nil
                            appState.isShowingSearchView = true
                            appState.isShowingShowMarker = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                searchViewModel.cleandownloadMedia()
                            }
                        }label: {
                            Image("icon-back")
                        }
                        .buttonStyle(ButtonStyle_m())
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button{
                            //更多按钮-圆形
                        }label: {
                            Image("icon-more")
                        }
                        .buttonStyle(ButtonStyle_m())
                    }
                }
            }
            .ignoresSafeArea(.all)
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .statusBar(hidden: isFullScreen)
//            .navigationBarHidden(true)
        } //Nav
        
        .onAppear {
            selectedIndex = 0
        }
//        .onAppear {
//            withAnimation(.spring()) {
//                appState.isShareImageExpanded = true
//            }
//        }
    }

}
