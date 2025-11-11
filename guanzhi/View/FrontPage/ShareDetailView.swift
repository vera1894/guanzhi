//
//  ShareDetailView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/10/28.
//

import SwiftUI
import PhotosUI
import _AVKit_SwiftUI

// MARK: - 全局弹窗遮罩配置（临时放置）
// TODO: 将文件 DialogStyles.swift 添加到 Xcode 项目后，删除此段代码
struct DialogOverlayConfig {
    static let overlayColor: Color = .black
    static let overlayOpacity: Double = 0.4
    static let animationDuration: Double = 0.25
}

struct DialogOverlay: View {
    let isPresented: Bool

    var body: some View {
        if isPresented {
            DialogOverlayConfig.overlayColor
                .opacity(DialogOverlayConfig.overlayOpacity)
                .ignoresSafeArea()
                .transition(.opacity)
        }
    }
}

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
    @State private var showActionSheet: Bool = false // 控制底部弹窗显示
    @State private var showDeleteAlert: Bool = false // 控制删除确认弹窗显示
    @State private var isDeleting: Bool = false // 是否正在删除

    // 判断是否是自己的分享
    private var isMyShare: Bool {
        guard let share = searchViewModel.selectedShare else { return false }
        let currentUserId = OTOLoginStatusManager.shared.getUserID()
        return Int64(currentUserId) == share.userId
    }

    var body: some View {
        @Bindable var appState = appState
        ZStack {
            GeometryReader { fullScreenGeometry in
                ZStack {
                // 主内容区域：媒体展示（TabView或ProcessingView）
                // 使用固定布局，不受安全区域影响
                Color.clear
                    .frame(width: fullScreenGeometry.size.width, height: fullScreenGeometry.size.height)
                    .overlay(
                        Group {
                            if !searchViewModel.downloadMedia.isEmpty {
                                TabView(selection: $selectedIndex) {
                                    ForEach(Array(searchViewModel.downloadMedia.enumerated()), id: \.element.id) { index, itemWrapper in
                                        MediaItemView(mediaItemWrapper: itemWrapper, thumbnailImage: searchViewModel.selectedAnnotationImage)
                                            .tag(index)
                                    }
                                }
                                .tabViewStyle(PageTabViewStyle())
                                .ignoresSafeArea()
    //                            .matchedGeometryEffect(id: "sharedElement\(annotationID)", in: animationNamespace, isSource: false)
                                .onChange(of: searchViewModel.downloadMedia.count) { oldCount, newCount in
                                    if selectedIndex >= newCount {
                                        selectedIndex = max(0, newCount - 1)
                                    }
                                }
                            } else {
                                // 显示加载指示器
                                ProcessingView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .frame(width: fullScreenGeometry.size.width, height: fullScreenGeometry.size.height)
                    )
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
                                /*appState.isShareImageExpanded*/searchViewModel.isShareDetailOverlayShown = false
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
                isShowShareDetailsCard.toggle()
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
                                        /*appState.isShareImageExpanded*/searchViewModel.isShareDetailOverlayShown = false
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
        }
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .overlay(// 顶部操作栏（始终存在，通过 opacity 控制可见性）
            GeometryReader { geo in
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            if appState.useOverlayMode {
                                /*appState.isShareImageExpanded*/searchViewModel.isShareDetailOverlayShown = false
                            } else {
                                navigationCoordinator.path.removeLast()
                            }
                        } label: {
                            Image("icon-back")
                        }
                        .buttonStyle(ButtonStyle_m())

                        Spacer()

                        Button {
                            showActionSheet = true
                        } label: {
                            Image("icon-more")
                        }
                        .buttonStyle(ButtonStyle_m())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()
                }
            }
            .opacity(isShowShareDetailsCard ? 1 : 0)
            .allowsHitTesting(isShowShareDetailsCard),
            alignment: .top
        )
        .overlay(
            ShareDetailsCardView(
                isFullScreen: $isFullScreen,
                isAtTop: $isAtTop,
                dragOffset: $dragOffset,
                cardDragIsActive: $cardDragIsActive
            )
            .environmentObject(searchViewModel)
            .zIndex(1)
            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            .offset(y: isFullScreen ? 0 + dragOffset : UIScreen.main.bounds.height * 4 / 5 + dragOffset)
            .opacity(isShowShareDetailsCard ? 1 : 0)
            .allowsHitTesting(isShowShareDetailsCard)
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
                isEnabled: !isFullScreen && isShowShareDetailsCard
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
                isEnabled: (isFullScreen && isAtTop) && isShowShareDetailsCard
            )
            .ignoresSafeArea()
        ) // 底部详情卡片和评论输入区
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            selectedIndex = 0
            if let shareId = Int64(annotationID) {
                searchViewModel.loadShareDetail(for: shareId)
            }
        }
        .onDisappear {
            if navigationCoordinator.path.isEmpty {
                withAnimation(.easeInOut) {
                    appState.isShowingSearchView = true
                    appState.isShowingShowMarker = true
                }
                searchViewModel.isUpdatingAnnotations = false
                searchViewModel.selectedAnnotation = nil
                searchViewModel.selectedAnnotationID = nil
                searchViewModel.selectedAnnotationImage = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                searchViewModel.cleandownloadMedia()
            }
        }
        .overlay(
            DialogOverlay(isPresented: showActionSheet || showDeleteAlert || searchViewModel.shareDeletedMessage != nil || searchViewModel.showNavigationSheet)
                .animation(.easeInOut(duration: 0.4), value: showActionSheet)
                .animation(.easeInOut(duration: 0.4), value: showDeleteAlert)
                .animation(.easeInOut(duration: 0.4), value: searchViewModel.shareDeletedMessage != nil)
                .animation(.easeInOut(duration: 0.4), value: searchViewModel.showNavigationSheet)
        )
        .confirmationDialog("", isPresented: $showActionSheet, titleVisibility: .hidden) {
            Button("分享") {
                // TODO: 实现分享功能
            }

            if isMyShare {
                Button("删除", role: .destructive) {
                    showDeleteAlert = true
                }
            } else {
                Button("举报", role: .destructive) {
                    // TODO: 实现举报功能
                }
            }

            Button("取消", role: .cancel) { }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteShare()
            }
        } message: {
            Text("确定要删除这条分享吗？删除后将无法恢复。")
        }
        .alert("提示", isPresented: Binding(
            get: { searchViewModel.shareDeletedMessage != nil },
            set: { if !$0 { searchViewModel.shareDeletedMessage = nil } }
        )) {
            Button("确定") {
                // 退出详情页面
                if appState.useOverlayMode {
                    searchViewModel.isShareDetailOverlayShown = false
                } else {
                    navigationCoordinator.path.removeLast()
                }
                searchViewModel.shareDeletedMessage = nil
            }
        } message: {
            Text(searchViewModel.shareDeletedMessage ?? "")
        }
    }

    func resetCardState() {
        isFullScreen = false
        dragOffset = 0
        isAtTop = true
    }

    func deleteShare() {
        guard let share = searchViewModel.selectedShare else { return }

        isDeleting = true

        // 立即清空正在加载的媒体数据，防止下载任务完成后访问已释放的资源
        searchViewModel.cleandownloadMedia()

        Task {
            do {
                // 调用删除 API
                try await ShareService.shared.deleteShare(shareId: Int(share.id))

                // 删除成功后，在主线程执行 UI 操作
                await MainActor.run {
                    isDeleting = false

                    let shareId = share.id

                    // 1. 从本地 SwiftData 删除分享和相关媒体文件
                    searchViewModel.deleteShare(shareId: shareId)

                    // 2. 从地图标注列表中移除该分享
                    if let index = searchViewModel.annotations.firstIndex(where: { $0.id == "\(shareId)" }) {
                        searchViewModel.annotations.remove(at: index)
                    }

                    // 3. 清理选中的分享
                    searchViewModel.selectedAnnotation = nil
                    searchViewModel.selectedAnnotationID = nil
                    searchViewModel.selectedShare = nil

                    // 4. 退出详情页面
                    if appState.useOverlayMode {
                        searchViewModel.isShareDetailOverlayShown = false
                    } else {
                        navigationCoordinator.path.removeLast()
                    }
                }
            } catch {
                // 删除失败，显示错误
                await MainActor.run {
                    isDeleting = false
                    print("删除分享失败: \(error.localizedDescription)")
                    // TODO: 可以在这里显示一个错误提示
                }
            }
        }
    }

}

