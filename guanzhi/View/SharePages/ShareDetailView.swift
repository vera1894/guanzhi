//
//  ShareDetailView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/10/28.
//
//ZStack (最外层)
//  └── GeometryReader
//      └── ZStack
//          ├── Color.clear (容器层)
//          │   └── .overlay
//          │       └── TabView (媒体展示)
//          │           └── .overlayPreferenceValue
//          │               └── VideoPlayerView (全局播放器)
//          ├── 点击手势 (.onTapGesture 切换 isShowShareDetailsCard)
//          └── HStack (左边缘滑动退出区域)
//
//  .overlay (顶部操作栏)
//      └── 返回按钮、用户信息胶囊、更多按钮
//      └── opacity/allowsHitTesting 受 isShowShareDetailsCard 控制
//
//  .overlay (底部详情卡片)
//      └── ShareDetailsCardView
//      └── opacity/allowsHitTesting 受 isShowShareDetailsCard 控制
//
//  .overlay (自定义对话框遮罩)
//      └── DialogOverlay

//1. 主要结构：
//    - 最外层是一个ZStack
//    - 包含一个GeometryReader
//    - GeometryReader内部还有一个ZStack
//    - 在ZStack内部有一个Color.clear作为容器，然后用.overlay添加TabView（显示媒体
//  内容）
//    - TabView上还有.overlayPreferenceValue用于视频播放器的全局显示
//    - 退出手势和点击手势直接加在Color.clear上
//    - 左边缘滑动手势是一个单独的HStack层
//  2. Overlay层级：
//    - 顶部操作栏（返回按钮、用户信息、更多按钮）使用.overlay添加，通过isShowShar
//  eDetailsCard控制显隐
//    - 底部ShareDetailsCardView也用.overlay添加，同样受isShowShareDetailsCard控制
//    - DialogOverlay（自定义遮罩）也是用.overlay添加
//    - Alert是SwiftUI原生的，不算在ZStack/overlay体系里
//  3. 点击交互逻辑：
//    -
//  点击图片区域会切换isShowShareDetailsCard，从而控制顶部导航栏和底部sheet的显隐



import SwiftUI
import PhotosUI
import _AVKit_SwiftUI
import Combine
import SwiftData

// MARK: - PreferenceKey for Player Frame Anchoring

/// PreferenceKey 用于传递当前选中页的播放矩形
struct PlayerFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        // ✅ 只保留非 .zero 的值（因为多个 MediaItemView 会报告，只有选中的那个是非 .zero）
        if next != .zero {
            value = next
        }
    }
}

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
    
    // Sheet 控制状态
    @State private var currentDetent: PresentationDetent = .height(Constants.sheetCollapsedHeight)
    
    @State private var viewOpacity: Double = 1.0
    @State var cardDragIsActive = true
    @State private var isDeleting: Bool = false // 是否正在删除
    
    // ✅ 方案B：单实例播放器 Overlay
    @State private var currentEngine: VideoEngine? = nil // 当前选中页的 VideoEngine
    @State private var currentCoverVisible: Bool = true // 当前选中页的封面可见性
    @State private var currentIsPlaying: Bool = false // 当前选中页的播放状态

    // ✅ 双门机制状态
    @State private var isReadyLayer: Bool = false // 图层是否可显示（isReadyForDisplay）
    @State private var hasFirstPixel: Bool = false // 是否已渲染首帧像素

    // ✅ 可播监听
    @State private var mediaItemCancellable: AnyCancellable? = nil // 监听 wrapper 可播状态

    // ✅ 稳定的播放器矩形（防抖，只在滑动结束时更新）
    @State private var stablePlayerFrame: CGRect = .zero

    // ✅ 贴纸互动 ViewModel（统一管理点赞/无感状态和贴纸统计）
    @StateObject private var interactionViewModel = ShareInteractionViewModel()

    // 判断是否是自己的分享
    private var isMyShare: Bool {
        guard let share = searchViewModel.selectedShare else { return false }
        #if DEBUG
        let currentUserId = OTOLoginStatusManager.shared.__effectiveUserIdForPreview()
        #else
        let currentUserId = OTOLoginStatusManager.shared.getUserID()
        #endif
        return Int64(currentUserId) == share.userId
    }

    // 统一的弹窗状态：仅需要自定义遮罩的弹窗
    // 注意：iOS 18/26 中，alert、UIAlertController 都自带系统 dimming
    private var anyModalOn: Bool {
        searchViewModel.shareDeletedMessage != nil
        // ❌ 不包含更多操作弹窗（UIAlertController 自带系统 dimming）
        // ❌ 不包含删除确认弹窗（UIAlertController 自带系统 dimming）
        // ❌ 不包含查看路线弹窗（UIAlertController 自带系统 dimming）
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
                                        MediaItemView(
                                            mediaItemWrapper: itemWrapper,
                                            thumbnailImage: searchViewModel.selectedAnnotationImage,
                                            currentIndex: index,
                                            selectedIndex: selectedIndex
                                        )
                                        .tag(index)
                                    }
                                }
                                .tabViewStyle(PageTabViewStyle())
                                .coordinateSpace(name: "PlayerSpace") // ✅ 将坐标空间定义在 TabView 上
                                .ignoresSafeArea()
    //                            .matchedGeometryEffect(id: "sharedElement\(annotationID)", in: animationNamespace, isSource: false)
                                // ✅ 将 overlayPreferenceValue 应用在 TabView 上，确保坐标空间一致
                                .overlayPreferenceValue(PlayerFrameKey.self) { playerFrame in
                                    Group {
                                        if let engine = currentEngine,
                                           let player = engine.player,
                                           playerFrame != .zero {
                                            let displayFrame = stablePlayerFrame != .zero ? stablePlayerFrame : playerFrame

                                            VideoPlayerView(
                                                player: player,
                                                shouldPlay: true,
                                                isSelected: true,
                                                onReadyForDisplay: {
                                                    #if DEBUG
                                                    print("📺 [Overlay] 条件1满足：图层可显示")
                                                    #endif
                                                    isReadyLayer = true
                                                    tryHideCoverForCurrentVideo()
                                                }
                                            )
                                            .id("global-video-player")
                                            .frame(width: displayFrame.width, height: displayFrame.height)
                                            .position(x: displayFrame.midX, y: displayFrame.midY)
                                            .animation(nil, value: displayFrame)
                                            .transition(.identity)
                                            .allowsHitTesting(false)
                                            .onChange(of: playerFrame) { oldValue, newValue in
                                                if newValue != .zero && abs(newValue.origin.x) < 10 {
                                                    #if DEBUG
                                                    print("📐 [Overlay] 更新 stablePlayerFrame: \(newValue)")
                                                    #endif
                                                    stablePlayerFrame = newValue
                                                }
                                            }
                                            .onAppear {
                                                #if DEBUG
                                                print("📐 [Overlay] 锚定到显示矩形: \(displayFrame)")
                                                #endif
                                            }
                                        }
                                    }
                                }
                                .onChange(of: selectedIndex) { oldValue, newValue in
                                    #if DEBUG
                                    print("📑 ShareDetailView - selectedIndex 变化: \(oldValue) -> \(newValue)")
                                    #endif

                                    // ✅ 方案B：切换全局播放器（会自动启动监听如果需要）
                                    switchToVideo(at: newValue)
                                }
                                .onChange(of: searchViewModel.downloadMedia.count) { oldCount, newCount in
                                    #if DEBUG
                                    print("📊 ShareDetailView - downloadMedia.count 变化: \(oldCount) -> \(newCount)")
                                    #endif
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
                    .onAppear {
                        #if DEBUG
                        print("🏠 ShareDetailView.onAppear - 初始化，selectedIndex: \(selectedIndex), 数据数量: \(searchViewModel.downloadMedia.count)")
                        #endif
                        
                        // ✅ 方案B：初始化第一个视频（延迟确保数据就绪）
                        DispatchQueue.main.async {
                            if !searchViewModel.downloadMedia.isEmpty {
                                #if DEBUG
                                print("🏠 ShareDetailView.onAppear - 延迟触发 switchToVideo(\(selectedIndex))")
                                #endif
                                switchToVideo(at: selectedIndex)
                            }
                        }
                    }
                    .onChange(of: searchViewModel.downloadMedia.count) { oldCount, newCount in
                        #if DEBUG
                        print("🔄 [Overlay] downloadMedia.count 变化: \(oldCount) -> \(newCount)")
                        #endif
                        
                        // ✅ 当第一次加载数据完成时，触发首张视频播放
                        if oldCount == 0, newCount > 0, currentEngine == nil {
                            #if DEBUG
                            print("🔄 [Overlay] 数据首次加载完成，触发 switchToVideo(0)")
                            #endif
                            DispatchQueue.main.async {
                                switchToVideo(at: selectedIndex)
                            }
                        }
                    }
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

                        // 用户信息胶囊
                        if let share = searchViewModel.selectedShare {
                            UserInfoCapsule(
                                userId: share.userId,
                                searchViewModel: searchViewModel
                            )
                            .environmentObject(navigationCoordinator)
                        }

                        Spacer()

                        Button {
                            showMoreActionsSheet()
                        } label: {
                            Image("icon-more")
                        }
                        .buttonStyle(ButtonStyle_m())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // 贴纸统计展示条
                    StickerSummaryBar(
                        items: interactionViewModel.stickerSummaries,
                        maxVisibleItems: 4,
                        onTap: {
                            interactionViewModel.isShowingStickerSummaryOverlay = true
                        }
                    )
                    .padding(.top, 12)

                    Spacer()
                }
            }
            .opacity(isShowShareDetailsCard ? 1 : 0)
            .allowsHitTesting(isShowShareDetailsCard),
            alignment: .top
        )
        // 贴纸交互层（全屏覆盖，但只在底部区域响应触摸）
        .overlay {
            GeometryReader { geo in
                // 计算使用区域：屏幕中心偏上位置（SwiftUI 坐标系）
                // 注意：这里使用 SwiftUI 坐标系，StickerFieldView 内部会自动转换为 SpriteKit 坐标
                let useZoneSize = CGSize(width: geo.size.width - 80, height: 120)
                let customFrame = CGRect(
                    x: 40,
                    y: geo.size.height * 0.25,  // 屏幕上方 1/4 位置（SwiftUI Y 轴向下）
                    width: useZoneSize.width,
                    height: useZoneSize.height
                )

                StickerFieldView(
                    stickers: StickerDefinition.mockAll,
                    onUseSticker: { sticker in
                        #if DEBUG
                        print("🎯 [ShareDetailView] 使用贴纸: \(sticker.displayName) (\(sticker.kind))")
                        #endif

                        // 根据贴纸种类处理投票逻辑
                        if let voteState = sticker.kind.voteState {
                            // 可持久化贴纸：调用统一投票入口
                            interactionViewModel.setVote(voteState)
                        }
                        // 其他本地贴纸：只做动画效果，不上报服务器
                    },
                    showBackground: false,
                    showUseZoneHint: false,
                    customUseZoneFrame: customFrame,  // 传入自定义使用区域（SwiftUI 坐标）
                    queueBottomY: 180,       // 贴纸队列位置（避开底部卡片）
                    touchAreaHeight: 250,    // 只在底部 250pt 区域响应触摸，上方区域穿透
                    enableAutoScroll: false  // 关闭自动轮播，节省性能
                )
            }
            .opacity(isShowShareDetailsCard ? 1 : 0)
            .allowsHitTesting(isShowShareDetailsCard)
        }
//        .sheet(isPresented: $isShowShareDetailsCard)
//        {
//                        ShareDetailsCardView(
//                            isFullScreen: $isFullScreen,
//                            isAtTop: $isAtTop,
//                            dragOffset: $dragOffset,
//                            cardDragIsActive: $cardDragIsActive
//                        )
//                        .environmentObject(searchViewModel)
//            //            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//            //            .offset(y: isFullScreen ? 0 + dragOffset : UIScreen.main.bounds.height * 0.86 + dragOffset)
//            //            .opacity(isShowShareDetailsCard ? 1 : 0)
//            //            .allowsHitTesting(isShowShareDetailsCard)
//            //            .gesture(
//            //                DragGesture()
//            //                    .onChanged { value in
//            //                        let translation = value.translation.height
//            //                        if !isFullScreen {
//            //                            // 只处理「上拉」
//            //                            if translation < 0 {
//            //                                dragOffset = translation
//            //                            }
//            //                        }
//            //                    }
//            //                    .onEnded { value in
//            //                        let translation = value.translation.height
//            //                        withAnimation(.easeInOut) {
//            //                            if !isFullScreen {
//            //                                // 上拉阈值
//            //                                if translation < -150 {
//            //                                    isFullScreen = true
//            //                                }
//            //                            }
//            //                            dragOffset = 0
//            //                        }
//            //                    },
//            //                isEnabled: !isFullScreen && isShowShareDetailsCard
//            //            )
//            //            .simultaneousGesture (
//            //                DragGesture()
//            //                    .onChanged { value in
//            //                        let translation = value.translation.height
//            //                        if (isFullScreen && isAtTop) {
//            //                            if translation > 0 {
//            //                                cardDragIsActive = false
//            //                                dragOffset = translation
//            //                            }
//            //                        }
//            //                    }
//            //                    .onEnded { value in
//            //                        let translation = value.translation.height
//            //                        withAnimation(.easeInOut) {
//            //                            if (isFullScreen && isAtTop) {
//            //                                if translation > 150 {
//            //                                    isFullScreen = false
//            //                                }
//            //                            }
//            //                            dragOffset = 0
//            //                            cardDragIsActive = true
//            //                        }
//            //                    },
//            //                isEnabled: (isFullScreen && isAtTop) && isShowShareDetailsCard
//            //            )
//                        // --- 新增 Sheet 样式配置 ---
//                        .presentationDetents([.height(Constants.sheetCollapsedHeight), .fraction(Constants.sheetExpandedFraction)], selection: $currentDetent)
//                        .presentationDragIndicator(.hidden)
//                        .presentationCornerRadius(Constants.sheetCornerRadius)
//                        .presentationBackground(.regularMaterial)
//                        .presentationBackgroundInteraction(.enabled)
//                        .interactiveDismissDisabled()
//        }
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
            .offset(y: isFullScreen ? 0 + dragOffset : UIScreen.main.bounds.height * 0.86 + dragOffset)
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
        .overlay(
            // 点赞打卡交互层（使用共享的 interactionViewModel）
            Group {
                if let share = searchViewModel.selectedShare {
                    InteractionOverlayView(
                        share: share,
                        viewModel: interactionViewModel
                    )
                    .opacity(isShowShareDetailsCard ? 1 : 0)
                    .allowsHitTesting(isShowShareDetailsCard)
                    .animation(.easeInOut(duration: 0.25), value: isShowShareDetailsCard)
                }
            }
        )
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            if PreviewHarness.enabled {
                print("🔌 [PreviewHarness] Overriding login status for preview")
                OTOLoginStatusManager.shared.__overrideForPreview(userId: 11)
            }

            #if DEBUG
            print("🏠 ShareDetailView.onAppear - 开始加载分享详情")
            #endif
            selectedIndex = 0
            if let shareId = Int64(annotationID) {
                searchViewModel.loadShareDetail(for: shareId)
            }

            // 初始化贴纸互动 ViewModel
            // 注意：loadShareDetail 是异步的，selectedShare 此时可能为 nil
            // 真正的初始化依赖 .onChange(of: selectedShare?.id) 监听器
            if let share = searchViewModel.selectedShare {
                interactionViewModel.initialize(share: share, onStateChanged: makeStateChangedCallback())
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
            DialogOverlay(isPresented: anyModalOn)
                .zIndex(9999)  // 确保遮罩在最上层，避免层级冲突
                .animation(.easeInOut(duration: 0.25), value: anyModalOn)
        )
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
        // 贴纸统计详细覆层
        .sheet(isPresented: $interactionViewModel.isShowingStickerSummaryOverlay) {
            StickerSummaryOverlay(
                items: interactionViewModel.stickerSummaries,
                onClose: {
                    interactionViewModel.isShowingStickerSummaryOverlay = false
                }
            )
            .presentationDetents([.medium, .large])
        }
        // ✅ 监听 selectedShare?.id 变化，重新初始化 interactionViewModel
        // 注意：监听整个对象在 SwiftData @Model 中可能不会触发，改为监听 id
        .onChange(of: searchViewModel.selectedShare?.id) { oldValue, newValue in
            handleShareIdChange(oldValue: oldValue, newValue: newValue)
        }
    }

    // MARK: - Share ID 变化处理

    /// 处理 selectedShare.id 变化，重新初始化 interactionViewModel
    private func handleShareIdChange(oldValue: Int64?, newValue: Int64?) {
        #if DEBUG
        print("🔄 [ShareDetailView] selectedShare.id 变化: \(oldValue?.description ?? "nil") -> \(newValue?.description ?? "nil")")
        #endif
        guard let share = searchViewModel.selectedShare else { return }
        interactionViewModel.initialize(
            share: share,
            onStateChanged: makeStateChangedCallback()
        )
    }

    /// 创建状态变化回调（同步到 SwiftData）
    private func makeStateChangedCallback() -> (Int64, VoteState, Int, Int) -> Void {
        return { [weak searchViewModel] shareId, voteState, agreeCount, neutralCount in
            Task { @MainActor in
                guard let vm = searchViewModel,
                      let currentShare = vm.selectedShare,
                      currentShare.id == shareId else { return }
                currentShare.agreeCount = agreeCount
                currentShare.currentUserVoteType = voteState.rawValue
                currentShare.neutralCount = neutralCount
                try? vm.context.save()
            }
        }
    }

    func resetCardState() {
        isFullScreen = false
        dragOffset = 0
        isAtTop = true
    }

    func showMoreActionsSheet() {
        // 捕获需要的上下文
        let viewModel = searchViewModel
        let appState = appState
        let navigationCoordinator = navigationCoordinator

        let alert = UIAlertController(title: "更多操作", message: nil, preferredStyle: .actionSheet)

        // 分享按钮
        alert.addAction(UIAlertAction(title: "分享", style: .default) { _ in
            // TODO: 实现分享功能
        })

        // 删除或举报按钮
        if isMyShare {
            alert.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in
                // 延迟显示确认弹窗，等待 actionSheet dismiss 完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    Self.showDeleteConfirmation(
                        viewModel: viewModel,
                        appState: appState,
                        navigationCoordinator: navigationCoordinator
                    )
                }
            })
        } else {
            alert.addAction(UIAlertAction(title: "举报", style: .destructive) { _ in
                // TODO: 实现举报功能
            })
        }

        // 取消按钮
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in })

        // 展示弹窗
        DispatchQueue.main.async {
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }

    // 显示删除确认弹窗的静态函数
    private static func showDeleteConfirmation(
        viewModel: SearchViewModel,
        appState: AppStateModel,
        navigationCoordinator: NavigationCoordinator
    ) {
        let alert = UIAlertController(
            title: "确认删除",
            message: "确定要删除这条分享吗？删除后将无法恢复。",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in })

        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in
            Task {
                await Self.performDelete(
                    viewModel: viewModel,
                    appState: appState,
                    navigationCoordinator: navigationCoordinator
                )
            }
        })

        DispatchQueue.main.async {
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }

    // 执行删除操作的静态函数
    private static func performDelete(
        viewModel: SearchViewModel,
        appState: AppStateModel,
        navigationCoordinator: NavigationCoordinator
    ) async {
        guard let share = viewModel.selectedShare else { return }

        // 立即清空正在加载的媒体数据
        viewModel.cleandownloadMedia()

        do {
            // 调用删除 API
            try await ShareService.shared.deleteShare(shareId: Int(share.id))

            // 删除成功后，在主线程执行 UI 操作
            await MainActor.run {
                let shareId = share.id

                // 1. 从本地 SwiftData 删除分享和相关媒体文件
                viewModel.deleteShare(shareId: shareId)

                // 2. 从地图标注列表中移除该分享
                if let index = viewModel.annotations.firstIndex(where: { $0.id == "\(shareId)" }) {
                    viewModel.annotations.remove(at: index)
                }

                // 3. 清理选中的分享
                viewModel.selectedAnnotation = nil
                viewModel.selectedAnnotationID = nil
                viewModel.selectedShare = nil

                // 4. 退出详情页面
                if appState.useOverlayMode {
                    viewModel.isShareDetailOverlayShown = false
                } else {
                    navigationCoordinator.path.removeLast()
                }
            }
        } catch {
            // 删除失败，显示错误
            await MainActor.run {
                print("删除分享失败: \(error.localizedDescription)")
                // TODO: 可以在这里显示一个错误提示
            }
        }
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
    
    // MARK: - 方案B：全局播放器切换逻辑

    /// 监听当前 wrapper 的可播状态，当它变为 Movie 时自动播放
    private func watchPlayableState(of index: Int) {
        // 取消旧的监听
        mediaItemCancellable?.cancel()
        mediaItemCancellable = nil

        guard index >= 0, index < searchViewModel.downloadMedia.count else { return }

        let wrapper = searchViewModel.downloadMedia[index]

        #if DEBUG
        print("👀 [Overlay] 开始监听 wrapper[\(index)] 的可播状态")
        #endif

        // ✅ 监听 wrapper.mediaItem 的变化
        mediaItemCancellable = wrapper.$mediaItem
            .sink { [self] mediaItem in
                // 如果变成了 Movie 类型，且还没有播放过，则触发播放
                if mediaItem is Movie, !wrapper.hasAutoPlayedForSelection {
                    #if DEBUG
                    print("🔄 [Overlay] wrapper[\(index)] 可播就绪（变为 Movie），二次触发 switchToVideo")
                    #endif

                    // 延迟一帧确保状态已同步
                    DispatchQueue.main.async {
                        self.switchToVideo(at: index)
                    }
                }
            }
    }

    /// 切换到指定索引的视频
    private func switchToVideo(at index: Int) {
        guard index >= 0, index < searchViewModel.downloadMedia.count else {
            #if DEBUG
            print("⚠️ [Overlay] switchToVideo - 索引越界: \(index)")
            #endif
            return
        }

        let wrapper = searchViewModel.downloadMedia[index]

        #if DEBUG
        print("🔄 [Overlay] switchToVideo - 切换到索引: \(index), wrapper: \(wrapper.id)")
        #endif

        // ✅ 停止之前的播放器（如果有）
        currentEngine?.stop()

        // ✅ 重置状态
        currentCoverVisible = true
        currentIsPlaying = false
        isReadyLayer = false // ✅ 重置双门状态
        hasFirstPixel = false // ✅ 重置双门状态
        stablePlayerFrame = .zero // ✅ 重置稳定矩形，让新视频重新初始化位置

        // ✅ 检查是否是 Movie 类型
        guard let movie = wrapper.mediaItem as? Movie else {
            #if DEBUG
            print("⚠️ [Overlay] switchToVideo - 不是 Movie 类型，启动监听等待可播")
            #endif
            currentEngine = nil

            // ✅ 关键：启动监听，等待 wrapper 变为可播状态
            watchPlayableState(of: index)
            return
        }
        
        // ✅ 修复关键：如果 VideoEngine 不存在，现在创建！
        if wrapper.videoEngine == nil {
            #if DEBUG
            print("🎬 [Overlay] switchToVideo - 为选中页创建 VideoEngine")
            #endif
            wrapper.videoEngine = VideoEngine()
        }
        
        guard let engine = wrapper.videoEngine else {
            #if DEBUG
            print("⚠️ [Overlay] switchToVideo - VideoEngine 创建失败")
            #endif
            currentEngine = nil
            return
        }
        
        // ✅ 设置当前 Engine
        currentEngine = engine
        
        // ✅ 设置首帧渲染回调
        engine.onFirstFrameRendered = {
            #if DEBUG
            print("🎞️ [Overlay] 条件2满足：首帧已渲染")
            #endif
            hasFirstPixel = true
            tryHideCoverForCurrentVideo()
        }
        
        // ✅ 设置播放完成回调
        engine.onPlaybackFinished = {
            #if DEBUG
            print("✅ [Overlay] 视频播放完成，回到静止")
            #endif
            currentIsPlaying = false
            currentCoverVisible = true
            currentEngine?.stop()
            
            // ✅ 通知 MediaItemView 显示封面
            wrapper.coverShouldShow = true
        }
        
        // ✅ 如果已经播放过，跳过自动播放
        guard !wrapper.hasAutoPlayedForSelection else {
            #if DEBUG
            print("⏭️ [Overlay] switchToVideo - 已经播放过，跳过")
            #endif
            return
        }

        // ✅ 开始播放
        #if DEBUG
        print("🎬 [Overlay] switchToVideo - 开始预加载并播放")
        #endif

        // ✅ 不要提前隐藏封面！等待双门通过后再隐藏
        // wrapper.coverShouldShow 将在 tryHideCoverForCurrentVideo 中设置

        engine.prepare(url: movie.url) {
            #if DEBUG
            print("▶️ [Overlay] 视频准备完成，开始播放（等待两个条件）")
            #endif
            engine.playImmediately()
            wrapper.hasAutoPlayedForSelection = true
        }
    }
    
    /// 尝试隐藏当前视频的封面（需要两个条件都满足）
    private func tryHideCoverForCurrentVideo() {
        guard let engine = currentEngine else { return }

        // ✅ 双门机制：只有两个条件都满足时才隐藏封面
        guard isReadyLayer && hasFirstPixel else {
            #if DEBUG
            print("⏳ [Overlay] 门控未通过 = readyLayer:\(isReadyLayer) pixel:\(hasFirstPixel)")
            #endif
            return
        }

        // ✅ 获取当前选中的 wrapper
        guard selectedIndex >= 0, selectedIndex < searchViewModel.downloadMedia.count else { return }
        let wrapper = searchViewModel.downloadMedia[selectedIndex]

        // ✅ 两个条件都满足，隐藏封面
        withAnimation(.easeOut(duration: 0.12)) {
            currentCoverVisible = false
            currentIsPlaying = true
            // ✅ 关键：在双门通过后才隐藏 MediaItemView 的封面
            wrapper.coverShouldShow = false
        }

        #if DEBUG
        print("✨ [Overlay] 🎯 封面已隐藏（双门通过）")
        #endif
    }

}

// MARK: - 用户信息胶囊组件
struct UserInfoCapsule: View {
    let userId: Int64
    @ObservedObject var searchViewModel: SearchViewModel
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator

    private var isMyself: Bool {
        return OTOLoginStatusManager.shared.getUserID() == userId
    }

    var body: some View {
        Group {
            if isMyself {
                // 显示本机用户
                if let localUser = userProfileManager.localUserProfile {
                    capsuleContent(
                        nickname: localUser.nickname,
                        oneCode: localUser.name,
                        phone: localUser.phone,
                        iconName: nil,
                        onTap: {
                            navigationCoordinator.path.append(Route.myView)
                        }
                    )
                } else {
                    capsuleContent(nickname: "我", iconName: nil, onTap: {})
                }
            } else {
                // 显示他人用户 - 根据加载状态显示不同 UI
                renderOtherUserCapsule()
            }
        }
        .onAppear {
            loadUserIfNeeded()
        }
    }

    @ViewBuilder
    private func renderOtherUserCapsule() -> some View {
        if PreviewHarness.enabled {
            capsuleContent(
                nickname: "测试用户",
                oneCode: "TEST001",
                iconName: "person.crop.circle.fill",
                onTap: {}
            )
        } else {
            renderOtherUserCapsuleReal()
        }
    }

    @ViewBuilder
    private func renderOtherUserCapsuleReal() -> some View {
        let state = userProfileManager.userLoadingStates[Int(userId)] ?? .idle

        switch state {
        case .idle, .loading:
            capsuleContent(nickname: "加载中...", iconName: nil, onTap: {})

        case .loaded:
            if let otherUser = userProfileManager.otherUserProfile, otherUser.id == userId {
                capsuleContent(
                    nickname: otherUser.nickname ?? "陌生人",
                    oneCode: otherUser.name,
                    phone: otherUser.phone,
                    iconName: nil,
                    onTap: {
                        navigationCoordinator.path.append(Route.othersView(userId: Int(userId)))
                    }
                )
            } else {
                capsuleContent(nickname: "陌生人", iconName: "person.fill.questionmark", onTap: {})
            }

        case .error:
            capsuleContent(
                nickname: "加载失败",
                iconName: "exclamationmark.triangle.fill",
                onTap: {
                    retryLoadUser()
                }
            )
        }
    }

    @ViewBuilder
    private func capsuleContent(nickname: String, oneCode: String? = nil, phone: String? = nil, iconName: String?, onTap: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            // 如果有错误图标，显示图标；否则显示头像
            if let iconName = iconName {
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
            } else {
                AvatarView_s(
                    isEnabled: true,
                    profileImage: Image("例子"),
                    borderThickness: 2
                )
            }

            // 用户昵称和 OneCode（使用 VStack）
            VStack(alignment: .leading, spacing: 2) {
                Text(nickname)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // OneCode 显示逻辑：如果 oneCode == phone，隐私保护显示占位符
                let displayCode: String = {
                    guard let code = oneCode else { return "⬛️⬛️⬛️⬛️" }
                    if let phone = phone, code == phone {
                        return "⬛️⬛️⬛️⬛️"  // 隐私保护：与手机号相同时隐藏
                    }
                    return code
                }()

                Text("OneCode: \(displayCode)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .onTapGesture {
            onTap()
        }
    }

    private func loadUserIfNeeded() {
        guard !isMyself else { return }

        // 检查当前状态，如果已加载或正在加载，则不重复加载
        let currentState = userProfileManager.userLoadingStates[Int(userId)] ?? .idle
        if case .loaded = currentState {
            return
        }
        if case .loading = currentState {
            return
        }

        Task {
            do {
                try await userProfileManager.fetchUserFullInfo(userId: Int(userId))
            } catch {
                // 错误已经在 UserProfileManager 中处理和记录
            }
        }
    }

    private func retryLoadUser() {
        Task {
            do {
                try await userProfileManager.fetchUserFullInfo(userId: Int(userId))
            } catch {
                // 错误已经在 UserProfileManager 中处理和记录
            }
        }
    }
}

// MARK: - 小尺寸头像组件
struct AvatarView_s: View {
    var isEnabled: Bool
    var profileImage: Image
    var borderThickness: CGFloat

    var body: some View {
        ZStack(alignment: .center) {
            // 边框层（使用底层头像图形）
            Image("avatar")
                .resizable()
                .scaledToFit()
                .frame(width: 28 - 2, height: 28 - 2)
                .foregroundColor(.black)
            // 头像图像层，使用遮罩将其切成相同的形状
            profileImage
                .resizable()
                .scaledToFit()
                .frame(width: 28 - borderThickness - 2, height: 28 - borderThickness - 2)
                .mask(
                    Image("avatar")
                        .resizable()
                        .scaledToFit()
                )
        }
        .brightness(0)
        .grayscale(isEnabled ? 0 : 1)
        .scaleEffect(1.0)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

// MARK: - Preview Support

// 为预览创建必要的环境和数据
@MainActor
class PreviewDependencies {
    let searchViewModel: SearchViewModel
    let navigationCoordinator: NavigationCoordinator
    let userProfileManager: UserProfileManager
    let appState: AppStateModel

    init(modelContext: ModelContext) {
        // 创建 AppStateModel
        self.appState = AppStateModel()

        // 创建 NavigationCoordinator
        self.navigationCoordinator = NavigationCoordinator()

        // 创建 UserProfileManager
        self.userProfileManager = UserProfileManager()
        self.userProfileManager.localUserProfile = LocalUserProfile(
            id: 1,
            name: "testuser",
            nickname: "测试用户",
            phone: "13800138000",
            photo: nil,
            code: "TEST001",
            createDate: nil,
            jpushId: nil,
            titleDOS: nil
        )

        // 创建 SearchViewModel 并设置 context
        self.searchViewModel = SearchViewModel()
        self.searchViewModel.context = modelContext
    }
}

// 预览包装器视图
@available(iOS 17.0, *)
struct ShareDetailViewPreview: View {
    @Environment(\.modelContext) private var modelContext
    @State private var deps: PreviewDependencies?
    @Namespace private var namespace

    var body: some View {
        if let deps = deps {
            ShareDetailView(
                searchViewModel: deps.searchViewModel,
                animationNamespace: namespace,
                annotationID: "12345"
            )
            .environment(\.appState, deps.appState)
            .environmentObject(deps.navigationCoordinator)
            .environmentObject(deps.userProfileManager)
        } else {
            Color.clear
                .onAppear {
                    setupPreview()
                }
        }
    }

    private func setupPreview() {
        // 创建测试分享数据并插入到 context 中
        let testShare = Share(
            id: 12345,
            createDate: Date(),
            userId: 1,
            data: "这是一个测试分享，用于预览页面布局和样式效果",
            longitude: 121.5,
            latitude: 31.2,
            provinceCode: "31",
            cityCode: "3101",
            districtCode: "310115",
            address: "上海市 浦东新区 张江高科技园区",
            imagePaths: [],
            title: "测试分享",
            deleted: false
        )
        modelContext.insert(testShare)

        // 创建依赖项
        let newDeps = PreviewDependencies(modelContext: modelContext)

        // 设置 selectedShare
        newDeps.searchViewModel.selectedShare = testShare

        // 设置一个测试图片
        newDeps.searchViewModel.selectedAnnotationImage = UIImage(named: "例子")

        deps = newDeps
    }
}

@available(iOS 17.0, *)
#Preview("ShareDetailView") {
    ShareDetailViewPreview()
        .modelContainer(for: [Share.self, MediaFile.self, LocalUserProfile.self, OtherUserProfile.self], inMemory: true)
}


#if DEBUG
/// 统一判断：Xcode 预览 或 手动开关（方便真机 DEBUG 测试）
enum __PreviewGate {
    static var enabled: Bool {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return true }
        return UserDefaults.standard.bool(forKey: "__PreviewMocksEnabled")
    }
}

/// 便捷开关（你也可以在控制台执行：UserDefaults.standard.set(true, forKey: "__PreviewMocksEnabled")）
func __enablePreviewMocks() { UserDefaults.standard.set(true, forKey: "__PreviewMocksEnabled") }
func __disablePreviewMocks() { UserDefaults.standard.set(false, forKey: "__PreviewMocksEnabled") }
#endif

