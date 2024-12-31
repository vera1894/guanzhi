//
//  ShareDetailView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/10/28.
//

import SwiftUI
import PhotosUI
import _AVKit_SwiftUI

struct ShareDetailView: View {
    @Environment(\.appState) var appState
    @ObservedObject var searchViewModel: SearchViewModel
    var animationNamespace: Namespace.ID
    @State private var isShowShareDetailsCard: Bool = true //显示描述和操作控件
    @State private var isFullScreen: Bool = false // 控制卡片的当前状态（部分或全屏）
    @State private var dragOffset: CGFloat = 0 // 记录底部卡片拖动偏移量
    @State private var isAtTop: Bool = true
    @State private var isTieTieEnabled: Bool = false
    @State private var selectedIndex: Int = 0 //跟踪当前选中的索引
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    var annotationID: String
    @State private var viewOpacity: Double = 1.0
    @State var cardDragIsActive = true

    var body: some View {
        @Bindable var appState = appState
        ZStack {
            // 主内容区域：媒体展示（TabView或ProcessingView）
            Group {
                if !searchViewModel.downloadMedia.isEmpty {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(searchViewModel.downloadMedia.enumerated()), id: \.element.id) { index, itemWrapper in
                            MediaItemView(mediaItemWrapper: itemWrapper, thumbnailImage: searchViewModel.selectedAnnotationImage)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle())
                    .matchedGeometryEffect(id: "sharedElement\(annotationID)", in: animationNamespace, isSource: false)
                    .ignoresSafeArea(.all)
                    .onChange(of: searchViewModel.downloadMedia.count) { oldCount, newCount in
                        if selectedIndex >= newCount {
                            selectedIndex = max(0, newCount - 1)
                        }
                    }
                } else {
                    // 显示加载指示器
                    ProcessingView()
                        .ignoresSafeArea(.all)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .ignoresSafeArea(.all)
            .opacity(viewOpacity)
            // 下拉退出手势
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let dragDistance = value.translation.height
                        let threshold: CGFloat = 120
                        if dragDistance >= 50 {
                            viewOpacity = max(0.15, 1.0 - min(1.0, (dragDistance - 50) / threshold))
                        }
                    }
                    .onEnded { value in
                        let dragDistance = value.translation.height
                        let threshold: CGFloat = 120
                        if dragDistance > threshold {
                            // 根据模式决定退出方式
                            if appState.useOverlayMode {
                                appState.isShareImageExpanded = false
                            } else {
                                navigationCoordinator.path.removeLast()
                            }
                        } else {
                            withAnimation(.easeOut(duration: 0.2)) {
                                viewOpacity = 1.0
                            }
                        }
                    }
            )
            // 点击切换顶部和底部内容显隐
            .onTapGesture {
                withAnimation {
                    isShowShareDetailsCard.toggle()
                }
            }

            // 左边缘滑动退出区域
            HStack {
                Color.clear
                    .frame(width: 40)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let dragDistance = value.translation.width
                                let threshold: CGFloat = 120
                                if dragDistance > 0 {
                                    viewOpacity = max(0.15, 1.0 - min(1.0, dragDistance / threshold))
                                }
                            }
                            .onEnded { value in
                                let dragDistance = value.translation.width
                                let threshold: CGFloat = 120
                                if dragDistance > threshold {
                                    if appState.useOverlayMode {
                                        appState.isShareImageExpanded = false
                                    } else {
                                        navigationCoordinator.path.removeLast()
                                    }
                                } else {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        viewOpacity = 1.0
                                    }
                                }
                            }
                    )
                Spacer()
            }
            .ignoresSafeArea()
            .zIndex(3)
        }
        .overlay(// 顶部操作栏（仅当isShowShareDetailsCard为true时显示）
            Group {
                if isShowShareDetailsCard {
                    VStack {
                        HStack {
                            Button {
                                if appState.useOverlayMode {
                                    appState.isShareImageExpanded = false
                                } else {
                                    navigationCoordinator.path.removeLast()
                                }
                            } label: {
                                Image("icon-back")
                            }
                            .buttonStyle(ButtonStyle_m())

                            Spacer()

                            Button {
                                // 更多按钮逻辑
                            } label: {
                                Image("icon-more")
                            }
                            .buttonStyle(ButtonStyle_m())
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)

                        Spacer()
                    }
                    .ignoresSafeArea()
                    .transition(.move(edge: .top))
                }
            },
            alignment: .top
        )
        .overlay(// 底部详情卡片和评论输入区
            ZStack {
                if isShowShareDetailsCard {
                    ShareDetailsCardView(
                        isFullScreen: $isFullScreen,
                        isAtTop: $isAtTop,
                        dragOffset: $dragOffset,
                        cardDragIsActive: $cardDragIsActive
                    )
                    .environmentObject(searchViewModel)
                    .transition(.move(edge: .bottom)) // 从底部移动过渡
                    .zIndex(1)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .offset(y: isFullScreen ? 0 + dragOffset : UIScreen.main.bounds.height * 4 / 5 + dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let translation = value.translation.height
                                if !isFullScreen {
                                    // 只处理「上拉」
                                    if translation < 0 {
                                        dragOffset = translation
                                    }
                                }
                            }
                            .onEnded { value in
                                let translation = value.translation.height
                                withAnimation(.easeInOut) {
                                    if !isFullScreen {
                                        // 上拉阈值
                                        if translation < -150 {
                                            isFullScreen = true
                                        }
                                    }
                                    dragOffset = 0
                                }
                            },
                        isEnabled: !isFullScreen/* || (isFullScreen && isAtTop)*/
                    )
                    .simultaneousGesture (
                        DragGesture()
                            .onChanged { value in
                                let translation = value.translation.height
                                if (isFullScreen && isAtTop) {
                                    if translation > 0 {
                                        cardDragIsActive = false
                                        dragOffset = translation
                                    }
                                }
                            }
                            .onEnded { value in
                                let translation = value.translation.height
                                withAnimation(.easeInOut) {
                                    if (isFullScreen && isAtTop) {
                                        if translation > 150 {
                                            isFullScreen = false
                                        }
                                    }
                                    dragOffset = 0
                                    cardDragIsActive = true
                                }
                            },
                        isEnabled: (isFullScreen && isAtTop)
                    )
                    .ignoresSafeArea()

                    CommentContentView(isTieTieEnabled: $isTieTieEnabled)
                        .zIndex(2)
                        .ignoresSafeArea()
                }

            }
        )
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            selectedIndex = 0
            if let shareId = Int64(annotationID) {
                searchViewModel.loadShareDetail(for: shareId)
            }
        }
        .onDisappear {
            searchViewModel.isUpdatingAnnotations = false
            searchViewModel.selectedAnnotation = nil
            searchViewModel.selectedAnnotationID = nil
            searchViewModel.selectedAnnotationImage = nil
            appState.isShowingSearchView = true
            appState.isShowingShowMarker = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                searchViewModel.cleandownloadMedia()
            }
        }
    }

    func resetCardState() {
        isFullScreen = false
        dragOffset = 0
        isAtTop = true
    }

}

