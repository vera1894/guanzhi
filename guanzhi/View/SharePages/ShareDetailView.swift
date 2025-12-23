//
//  ShareDetailView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/10/28.
//

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   📐 视图层级结构图
// MARK: - ═══════════════════════════════════════════════════════════════════
//
//  ZStack (最外层容器)
//  │
//  ├── GeometryReader (获取全屏尺寸)
//  │   └── ZStack
//  │       ├── Color.clear (透明容器层)
//  │       │   └── .overlay
//  │       │       └── TabView (媒体分页展示 - 图片/视频)
//  │       │           └── .overlayPreferenceValue(PlayerFrameKey)
//  │       │               └── VideoPlayerView (全局单实例视频播放器)
//  │       │
//  │       ├── 下拉退出手势 (.gesture DragGesture 垂直)
//  │       ├── 点击切换UI手势 (.onTapGesture → isShowShareDetailsCard)
//  │       │
//  │       └── HStack (左边缘滑动退出区域 - 40pt宽)
//  │           └── 左滑退出手势 (.gesture DragGesture 水平)
//  │
//  ├── .overlay (顶部导航栏) ← zIndex 默认
//  │   └── VStack
//  │       ├── HStack (返回按钮 | 用户信息胶囊 | 更多按钮)
//  │       └── StickerSummaryBar (贴纸统计展示条)
//  │
//  ├── .overlay (贴纸交互层 - SpriteKit) ← 底部 250pt 响应触摸
//  │   └── StickerFieldView (贴纸队列 + 使用区域)
//  │
//  ├── .overlay (底部详情卡片)
//  │   └── ShareDetailsCardView (分享描述 + 评论)
//  │       └── 上拉/下拉手势控制全屏/收起
//  │
//  ├── .overlay (右侧互动按钮)
//  │   └── InteractionOverlayView (点赞/无感按钮)
//  │
//  └── .overlay (弹窗遮罩层) ← zIndex: 9999
//      └── DialogOverlay (半透明黑色背景)
//
// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   🔗 关键状态变量说明
// MARK: - ═══════════════════════════════════════════════════════════════════
//
//  isShowShareDetailsCard: Bool
//      - 控制顶部导航栏、底部卡片、贴纸层、互动按钮的显隐
//      - 点击媒体区域切换此状态
//
//  isFullScreen: Bool
//      - 控制底部卡片是收起状态还是全屏状态
//      - 上拉超过 150pt 展开，下拉超过 150pt 收起
//
//  selectedIndex: Int
//      - 当前选中的媒体索引（TabView 的 selection）
//      - 变化时触发 switchToVideo() 切换视频播放器
//
//  currentEngine: VideoEngine?
//      - 当前全局视频播放器的引擎实例
//      - 单实例模式：所有视频共用一个播放器，滑动时切换
//
//  interactionViewModel: ShareInteractionViewModel
//      - 管理点赞/无感状态、贴纸统计、API 调用
//      - 提供 visibleStickerDefinitions（应用互斥逻辑后的可用贴纸）
//
// MARK: - ═══════════════════════════════════════════════════════════════════

import SwiftUI
import PhotosUI
import _AVKit_SwiftUI
import Combine
import SwiftData

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   🎬 视频播放器定位 PreferenceKey
// MARK: - ═══════════════════════════════════════════════════════════════════

/// PreferenceKey：用于从 MediaItemView 传递视频播放区域的 frame
/// 全局视频播放器 (VideoPlayerView) 使用此 frame 定位自己的位置
/// 只有当前选中页的 frame 会被保留（非 .zero 的值）
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

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   🌫️ 弹窗遮罩组件
// MARK: - ═══════════════════════════════════════════════════════════════════

// TODO: 将文件 DialogStyles.swift 添加到 Xcode 项目后，删除此段代码

/// 弹窗遮罩配置（半透明黑色背景）
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

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   📱 ShareDetailView 主视图
// MARK: - ═══════════════════════════════════════════════════════════════════

// MARK: - ⚙️ 可调节的布局配置（方便手动调整）

/// 贴纸队列距离底部卡片顶部的间距（像素）
/// 计算方式：贴纸队列最底部 = 底部卡片顶部 - 此间距
private let kStickerQueueToCardSpacing: CGFloat = 32

/// 底部卡片收起时距离屏幕底部的比例（0.1 = 10%）
/// 卡片收起时的 Y 偏移 = screenHeight * (1 - kBottomCardCollapsedRatio)
private let kBottomCardCollapsedRatio: CGFloat = 0.08

/// 已使用贴纸状态条距离屏幕底部的距离（像素）
/// 调整此值可以改变状态条的垂直位置
private let kUsedStickerStatusBarBottomPadding: CGFloat = 60

struct ShareDetailView: View {

    // MARK: - 环境与依赖

    @Environment(\.appState) var appState
    @ObservedObject var searchViewModel: SearchViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    var animationNamespace: Namespace.ID
    var annotationID: String                        // 当前分享的 ID（从导航传入）

    // MARK: - UI 显隐控制状态

    @State private var isShowShareDetailsCard: Bool = true  // 控制顶部栏+底部卡片+贴纸层的显隐
    @State private var isFullScreen: Bool = false           // 底部卡片是否全屏展开
    @State private var dragOffset: CGFloat = 0              // 底部卡片拖动偏移量
    @State private var isAtTop: Bool = true                 // 底部卡片滚动是否在顶部
    @State private var viewOpacity: Double = 1.0            // 退出手势时的整体透明度
    @State var cardDragIsActive = true                      // 底部卡片拖拽是否激活

    // MARK: - 媒体展示状态

    @State private var selectedIndex: Int = 0               // 当前选中的媒体索引（TabView selection）
    @State private var isTieTieEnabled: Bool = false        // 贴贴功能开关（暂未使用）

    // MARK: - Sheet 控制（已废弃，改用 overlay）

    @State private var currentDetent: PresentationDetent = .height(Constants.sheetCollapsedHeight)

    // MARK: - 删除操作状态

    @State private var isDeleting: Bool = false             // 是否正在执行删除

    // MARK: - 🎬 视频播放器状态（单实例 Overlay 方案）

    @State private var currentEngine: VideoEngine? = nil    // 当前绑定的 VideoEngine
    @State private var currentCoverVisible: Bool = true     // 封面是否可见
    @State private var currentIsPlaying: Bool = false       // 是否正在播放

    // MARK: - 🚪 视频封面双门机制（两个条件都满足才隐藏封面）

    @State private var isReadyLayer: Bool = false           // 条件1: AVPlayerLayer.isReadyForDisplay
    @State private var hasFirstPixel: Bool = false          // 条件2: 首帧已渲染到屏幕

    // MARK: - 视频可播状态监听

    @State private var mediaItemCancellable: AnyCancellable? = nil  // 监听 wrapper.mediaItem 变化
    @State private var stablePlayerFrame: CGRect = .zero            // 稳定的播放器 frame（防抖）

    // MARK: - 🎯 贴纸交互 ViewModel

    /// 统一管理：点赞/无感状态、贴纸统计、API 调用
    /// 提供 visibleStickerDefinitions（应用互斥逻辑后的可用贴纸列表）
    @StateObject private var interactionViewModel = ShareInteractionViewModel()

    // MARK: - 📊 浏览统计（用于褪色度计算）

    /// 是否已记录本次浏览（防止重复上报）
    @State private var hasRecordedView: Bool = false

    // MARK: - 计算属性

    /// 判断当前分享是否是自己发布的（用于决定显示"删除"还是"举报"）
    private var isMyShare: Bool {
        guard let share = searchViewModel.selectedShare else { return false }
        #if DEBUG
        let currentUserId = OTOLoginStatusManager.shared.__effectiveUserIdForPreview()
        #else
        let currentUserId = OTOLoginStatusManager.shared.getUserID()
        #endif
        return Int64(currentUserId) == share.userId
    }

    /// 是否需要显示自定义弹窗遮罩
    /// 注意：iOS 18+ 的 alert/UIAlertController 自带系统 dimming，不需要额外遮罩
    private var anyModalOn: Bool {
        searchViewModel.shareDeletedMessage != nil
    }

    // MARK: - ═══════════════════════════════════════════════════════════════════
    // MARK:   🏗️ Body - 主视图构建
    // MARK: - ═══════════════════════════════════════════════════════════════════

    var body: some View {
        @Bindable var appState = appState
        ZStack {
            GeometryReader { fullScreenGeometry in
                ZStack {

                // ┌─────────────────────────────────────────────────────────────┐
                // │  📸 媒体展示区域（TabView 或 加载中指示器）                    │
                // │  - 全屏铺满，忽略安全区域                                     │
                // │  - 包含全局视频播放器 Overlay                                 │
                // └─────────────────────────────────────────────────────────────┘
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
                                            selectedIndex: selectedIndex,
                                            totalMediaCount: searchViewModel.downloadMedia.count  // 传入总数用于页数指示器
                                        )
                                        .tag(index)
                                    }
                                }
                                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))  // 隐藏页数指示点
                                .coordinateSpace(name: "PlayerSpace")
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

            // MARK: - 整个页面的手势控制
            // ┌─────────────────────────────────────────────────────────────┐
            // │  👇 下拉退出手势                                             │
            // │  - 下拉超过 120pt 退出详情页                                  │
            // │  - 拖动过程中调整透明度提供反馈                               │
            // └─────────────────────────────────────────────────────────────┘
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

            // ┌─────────────────────────────────────────────────────────────┐
            // │  👆 点击切换 UI 显隐                                          │
            // │  - 点击媒体区域切换 isShowShareDetailsCard                    │
            // │  - 控制顶部栏、底部卡片、贴纸层、互动按钮的显隐                │
            // └─────────────────────────────────────────────────────────────┘
            .onTapGesture {
                isShowShareDetailsCard.toggle()
            }

            // ┌─────────────────────────────────────────────────────────────┐
            // │  👈 左边缘滑动退出区域（40pt 宽）                              │
            // │  - 右滑超过 120pt 退出详情页                                  │
            // │  - 与 NavigationStack 的返回手势兼容                          │
            // └─────────────────────────────────────────────────────────────┘
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

        // MARK: - 顶部导航栏
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │  🔝 顶部导航栏 Overlay                                               │
        // │  - 返回按钮 | 用户信息胶囊 | 更多按钮                                 │
        // │  - 贴纸统计展示条 (StickerSummaryBar)                                │
        // │  - 通过 isShowShareDetailsCard 控制显隐                              │
        // └─────────────────────────────────────────────────────────────────────┘
        .overlay(
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

                        // MARK: - 用户信息胶囊💊
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

                    // 分享次级信息 + 褪色度显示行
                    if let share = searchViewModel.selectedShare {
                        HStack {
                            // 左边：分享ID和日期
                            Text("#\(share.id) · \(searchViewModel.formattedDate(from: share.createDate))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
//                                .background(
//                                    Capsule()
//                                        .fill(Color.white.opacity(0.35))
//                                )

//                            Spacer()

                            // 右边：褪色度
                            Text("褪色度：\(share.fadeScore)%")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
//                                .background(
//                                    Capsule()
//                                        .fill(Color.white.opacity(0.35))
//                                )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    // 贴纸统计展示条
                    StickerSummaryBar(
                        items: interactionViewModel.stickerSummaries,
                        maxVisibleItems: 4,
                        onTap: {
                            interactionViewModel.isShowingStickerSummaryOverlay = true
                        }
                    )
//                    .padding(.top, 8)

                    Spacer()
                }
            }
            .opacity(isShowShareDetailsCard ? 1 : 0)
            .allowsHitTesting(isShowShareDetailsCard),
            alignment: .top
        )

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │  🎨 贴纸交互层 Overlay (SpriteKit)                                   │
        // │  - 底部贴纸队列（可拖动使用）                                         │
        // │  - 使用区域在屏幕正中心                                               │
        // │  - 只有底部区域响应触摸，上方区域穿透                                  │
        // │  - 通过 isShowShareDetailsCard 控制显隐                              │
        // │  - 如果已使用贴纸，显示状态条替代贴纸队列                             │
        // └─────────────────────────────────────────────────────────────────────┘
        .overlay {
            stickerOverlayContent
        }

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │  📝 底部详情卡片 Overlay (已废弃的 Sheet 代码保留作参考)              │
        // └─────────────────────────────────────────────────────────────────────┘
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

        // MARK: - 底部详情卡片 Overlay
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │  📋 底部详情卡片 Overlay                                             │
        // │  - 显示分享描述、评论等内容                                          │
        // │  - 收起状态：距底部 10%，背景透明，点击展开（禁用拖拽）               │
        // │  - 展开状态：顶部安全区下方，背景模糊，可拖拽收起                     │
        // │  - 通过 isShowShareDetailsCard 控制显隐                              │
        // └─────────────────────────────────────────────────────────────────────┘
        .overlay(
            GeometryReader { _ in
                // ✅ 修复：直接从 UIApplication 获取安全区，避免 ignoresSafeArea 影响
                let topSafeArea = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?.windows.first?.safeAreaInsets.top ?? 0
                let screenHeight = UIScreen.main.bounds.height
                let screenWidth = UIScreen.main.bounds.width
                // 展开时的卡片高度：屏幕高度减去顶部安全区
                let expandedHeight = screenHeight - topSafeArea

                ShareDetailsCardView(
                    isFullScreen: $isFullScreen,
                    isAtTop: $isAtTop,
                    dragOffset: $dragOffset,
                    cardDragIsActive: $cardDragIsActive
                )
                .environmentObject(searchViewModel)
                .zIndex(1)
                // 展开时高度限制在安全区下方；收起时使用全屏高度
                .frame(width: screenWidth, height: isFullScreen ? expandedHeight : screenHeight)
                // 展开时：顶部安全区下方；收起时：距底部 10%
                .offset(y: isFullScreen ? topSafeArea + dragOffset : screenHeight * 0.9 + dragOffset)
                .opacity(isShowShareDetailsCard ? 1 : 0)
                .allowsHitTesting(isShowShareDetailsCard)
                // 点击展开（仅收起状态）
                .onTapGesture {
                    if !isFullScreen {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isFullScreen = true
                        }
                    }
                }
                // 下拉收起手势（仅展开状态 + 滚动在顶部时）
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.height
                            if isFullScreen && isAtTop {
                                if translation > 0 {
                                    cardDragIsActive = false
                                    dragOffset = translation
                                }
                            }
                        }
                        .onEnded { value in
                            let translation = value.translation.height
                            withAnimation(.easeInOut) {
                                if isFullScreen && isAtTop {
                                    if translation > 150 {
                                        isFullScreen = false
                                    }
                                }
                                dragOffset = 0
                                cardDragIsActive = true
                            }
                        },
                    including: (isFullScreen && isAtTop && isShowShareDetailsCard) ? .all : .none
                )
            }
            .ignoresSafeArea()
        )

        // MARK: - 👍 右侧互动按钮 Overlay
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │  👍 右侧互动按钮 Overlay                                             │
        // │  - 点赞/无感按钮                                                     │
        // │  - 使用共享的 interactionViewModel                                   │
        // │  - 通过 isShowShareDetailsCard 控制显隐                              │
        // └─────────────────────────────────────────────────────────────────────┘
        .overlay(
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

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │  🔄 生命周期：onAppear                                               │
        // │  - 加载分享详情                                                      │
        // │  - 初始化 interactionViewModel                                       │
        // │  - 加载贴纸可用性                                                    │
        // └─────────────────────────────────────────────────────────────────────┘
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

            // ✅ 修复：每次 onAppear 都强制重新初始化 interactionViewModel
            // 因为 loadFromLocal 是同步的，此时 selectedShare 应该已经有值
            // 延迟执行确保 loadFromLocal 完成
            DispatchQueue.main.async {
                if let share = searchViewModel.selectedShare {
                    #if DEBUG
                    print("🔄 [ShareDetailView] onAppear 初始化 interactionViewModel")
                    print("   - shareId: \(share.id)")
                    print("   - share.currentUserVoteType: \(share.currentUserVoteType?.description ?? "nil")")
                    print("   - 初始化前 loadingState: \(interactionViewModel.stickerLoadingState)")
                    print("   - 初始化前 visibleStickers: \(interactionViewModel.visibleStickerDefinitions.count)")
                    #endif
                    interactionViewModel.initialize(share: share, onStateChanged: makeStateChangedCallback())

                    #if DEBUG
                    print("   - 初始化后 loadingState: \(interactionViewModel.stickerLoadingState)")
                    print("   - 初始化后 visibleStickers: \(interactionViewModel.visibleStickerDefinitions.count)")
                    print("   - 初始化后 availableKinds: \(interactionViewModel.availableStickerKinds.map { $0.rawValue })")
                    #endif

                    // ✅ 从服务器加载贴纸可用性（异步，如果失败会自动降级）
                    #if DEBUG
                    print("📡 [ShareDetailView] 开始加载贴纸可用性...")
                    #endif
                    Task {
                        await interactionViewModel.loadStickerAvailability(shareId: share.id)
                        #if DEBUG
                        await MainActor.run {
                            print("📡 [ShareDetailView] 贴纸可用性加载完成")
                            print("   - loadingState: \(interactionViewModel.stickerLoadingState)")
                            print("   - visibleStickers: \(interactionViewModel.visibleStickerDefinitions.count)")
                            print("   - availableKinds: \(interactionViewModel.availableStickerKinds.map { $0.rawValue })")
                        }
                        #endif
                    }

                    // ✅ 记录浏览行为（用于褪色度计算）
                    recordShareViewIfNeeded(shareId: share.id)
                } else {
                    #if DEBUG
                    print("⚠️ [ShareDetailView] onAppear - selectedShare 为空，无法初始化")
                    #endif
                }
            }
        }

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │  🔄 生命周期：onDisappear                                            │
        // │  - 恢复地图视图状态                                                  │
        // │  - 清理媒体下载数据                                                  │
        // └─────────────────────────────────────────────────────────────────────┘
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

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │  🌫️ 弹窗遮罩 Overlay                                                │
        // │  - 半透明黑色背景                                                    │
        // │  - zIndex: 9999 确保在最上层                                         │
        // └─────────────────────────────────────────────────────────────────────┘
        .overlay(
            DialogOverlay(isPresented: anyModalOn)
                .zIndex(9999)
                .animation(.easeInOut(duration: 0.25), value: anyModalOn)
        )

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │  ⚠️ 分享已删除提示弹窗                                               │
        // │  - 当分享被其他用户删除时显示                                         │
        // │  - 点击确定后退出详情页                                              │
        // └─────────────────────────────────────────────────────────────────────┘
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

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │  📊 贴纸统计详情 Sheet                                               │
        // │  - 点击 StickerSummaryBar 时弹出                                     │
        // │  - 显示所有贴纸的详细统计                                            │
        // └─────────────────────────────────────────────────────────────────────┘
        .sheet(isPresented: $interactionViewModel.isShowingStickerSummaryOverlay) {
            StickerSummaryOverlay(
                items: interactionViewModel.stickerSummaries,
                onClose: {
                    interactionViewModel.isShowingStickerSummaryOverlay = false
                }
            )
            .presentationDetents([.medium, .large])
        }

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │  🔄 状态监听：selectedShare 变化                                      │
        // │  - 当 share 数据变化时重新初始化 interactionViewModel                │
        // │  - 使用组合键监听多个属性变化                                         │
        // └─────────────────────────────────────────────────────────────────────┘
        .onChange(of: shareStateKey) { oldKey, newKey in
            #if DEBUG
            print("⚠️ [ShareDetailView] shareStateKey 变化: \(oldKey) -> \(newKey)")
            print("   - 当前 loadingState: \(interactionViewModel.stickerLoadingState)")
            print("   - 当前 visibleStickers: \(interactionViewModel.visibleStickerDefinitions.count)")
            #endif
            reinitializeInteractionViewModel()
        }
    }

    // MARK: - ═══════════════════════════════════════════════════════════════════
    // MARK:   🔧 辅助计算属性
    // MARK: - ═══════════════════════════════════════════════════════════════════

    /// 组合键：用于监听 share ID 变化（切换到不同分享时）
    /// ⚠️ 不再监听 voteType/agreeCount 变化，因为这些已被 ViewModel 内部处理
    /// 如果监听这些属性，会导致投票成功后触发 reinitialize，打断互斥动画
    private var shareStateKey: String {
        guard let share = searchViewModel.selectedShare else { return "nil" }
        return "\(share.id)"
    }

    /// 贴纸层内容（抽取为独立属性以简化 body 表达式）
    @ViewBuilder
    private var stickerOverlayContent: some View {
        GeometryReader { geo in
            if let usedSticker = interactionViewModel.currentUserSticker {
                // 已使用贴纸：显示状态条
                usedStickerStatusView(usedSticker: usedSticker, geo: geo)
            } else {
                // 未使用贴纸：显示贴纸队列
                stickerFieldContent(geo: geo)
            }
        }
        .opacity(isShowShareDetailsCard ? 1 : 0)
        .allowsHitTesting(isShowShareDetailsCard && interactionViewModel.currentUserSticker == nil)
    }

    /// 已使用贴纸状态条视图
    @ViewBuilder
    private func usedStickerStatusView(usedSticker: UsedStickerInfo, geo: GeometryProxy) -> some View {
        VStack {
            Spacer()
            UsedStickerStatusBar(usedSticker: usedSticker)
                .padding(.bottom, kUsedStickerStatusBarBottomPadding)
        }
        .frame(maxWidth: .infinity)
    }

    /// 贴纸队列视图
    @ViewBuilder
    private func stickerFieldContent(geo: GeometryProxy) -> some View {
        let useZoneSize = CGSize(width: geo.size.width - 80, height: 120)
        let customFrame = CGRect(
            x: 40,
            y: (geo.size.height - useZoneSize.height) / 2,
            width: useZoneSize.width,
            height: useZoneSize.height
        )
        let bottomCardTopY = geo.size.height * kBottomCardCollapsedRatio
        let stickerQueueBottomY = bottomCardTopY + kStickerQueueToCardSpacing

        StickerFieldView(
            stickers: interactionViewModel.visibleStickerDefinitions,
            onUseSticker: { sticker in
                handleStickerUse(sticker)
            },
            stickerLoadingState: interactionViewModel.stickerLoadingState,
            onRetryLoad: {
                retryStickerLoad()
            },
            showBackground: false,
            showUseZoneHint: false,
            customUseZoneFrame: customFrame,
            queueBottomY: stickerQueueBottomY,
            touchAreaHeight: 250,
            enableAutoScroll: false
        )
    }

    // MARK: - ═══════════════════════════════════════════════════════════════════
    // MARK:   🎯 贴纸与互动处理方法
    // MARK: - ═══════════════════════════════════════════════════════════════════

    /// 重新初始化 interactionViewModel（当 share 数据变化时调用）
    private func reinitializeInteractionViewModel() {
        guard let share = searchViewModel.selectedShare else { return }
        #if DEBUG
        print("🔄 [ShareDetailView] reinitializeInteractionViewModel")
        print("   - currentUserVoteType: \(share.currentUserVoteType?.description ?? "nil")")
        print("   - agreeCount: \(share.agreeCount)")
        #endif
        interactionViewModel.initialize(share: share, onStateChanged: makeStateChangedCallback())

        // ✅ 重新加载贴纸可用性（异步）
        Task {
            await interactionViewModel.loadStickerAvailability(shareId: share.id)
        }
    }

    /// 记录分享浏览行为（用于褪色度计算）
    /// 条件：用户已登录 + 非 PreviewHarness 模式 + 本次打开尚未上报
    private func recordShareViewIfNeeded(shareId: Int64) {
        guard !PreviewHarness.enabled else { return }
        guard OTOLoginStatusManager.shared.isLoggedIn else { return }
        guard !hasRecordedView else { return }

        hasRecordedView = true
        Task {
            do {
                try await ShareService.shared.recordShareView(shareId: shareId)
                #if DEBUG
                print("📊 [ShareDetailView] 已上报浏览: shareId=\(shareId)")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ [ShareDetailView] 上报浏览失败（静默忽略）: \(error)")
                #endif
                // 上报失败静默忽略，不影响用户操作
            }
        }
    }

    /// 处理贴纸使用动作
    /// - Parameter sticker: 被使用的贴纸定义
    private func handleStickerUse(_ sticker: StickerDefinition) {
        #if DEBUG
        print("🎯 [ShareDetailView] 使用贴纸: \(sticker.displayName) (\(sticker.kind))")
        #endif

        // ✅ 使用 ViewModel 的统一方法处理所有贴纸类型
        // - 投票类贴纸：走 vote API
        // - 标签类贴纸：走 sticker use API
        interactionViewModel.useSticker(sticker.kind)
    }

    /// 重试加载贴纸可用性（用户点击重试按钮时调用）
    private func retryStickerLoad() {
        guard let share = searchViewModel.selectedShare else { return }

        #if DEBUG
        print("🔁 [ShareDetailView] 用户点击重试，重新加载贴纸可用性: shareId=\(share.id)")
        #endif

        Task {
            await interactionViewModel.retryStickerAvailability(shareId: share.id)
        }
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

    // MARK: - ═══════════════════════════════════════════════════════════════════
    // MARK:   📋 底部卡片控制方法
    // MARK: - ═══════════════════════════════════════════════════════════════════

    /// 重置底部卡片状态到收起状态
    func resetCardState() {
        isFullScreen = false
        dragOffset = 0
        isAtTop = true
    }

    // MARK: - ═══════════════════════════════════════════════════════════════════
    // MARK:   ⚙️ 更多操作菜单
    // MARK: - ═══════════════════════════════════════════════════════════════════

    /// 显示更多操作 ActionSheet（分享/删除/举报）
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

    // MARK: - ═══════════════════════════════════════════════════════════════════
    // MARK:   🗑️ 删除分享操作
    // MARK: - ═══════════════════════════════════════════════════════════════════

    /// 显示删除确认弹窗
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

    // MARK: - ═══════════════════════════════════════════════════════════════════
    // MARK:   🎬 视频播放器控制（单实例 Overlay 方案）
    // MARK: - ═══════════════════════════════════════════════════════════════════
    //
    //  核心流程：
    //  1. switchToVideo(at:) - 切换到指定索引的视频
    //  2. watchPlayableState(of:) - 监听 wrapper 变为可播状态
    //  3. tryHideCoverForCurrentVideo() - 双门机制通过后隐藏封面
    //
    //  双门机制说明：
    //  - 条件1: isReadyLayer = true (AVPlayerLayer.isReadyForDisplay)
    //  - 条件2: hasFirstPixel = true (首帧已渲染)
    //  - 两个条件都满足时才隐藏封面，避免闪烁
    //
    // ═══════════════════════════════════════════════════════════════════════════

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

// MARK: - ═══════════════════════════════════════════════════════════════════════
// MARK:   👤 用户信息胶囊组件
// MARK: - ═══════════════════════════════════════════════════════════════════════
//
//  显示在顶部导航栏中间位置
//  - 自己的分享：显示本机用户信息，点击跳转个人中心
//  - 他人的分享：加载并显示发布者信息，点击跳转他人主页
//
// ═══════════════════════════════════════════════════════════════════════════════

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
                    capsuleContentForMyself(localUser: localUser)
                } else {
                    capsuleContentSimple(nickname: "我", iconName: nil, onTap: {})
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

    // MARK: - 本机用户胶囊（使用真实头像）

    @ViewBuilder
    private func capsuleContentForMyself(localUser: LocalUserProfile) -> some View {
        // 获取本机用户头像
        let avatarImage: Image = {
            if let uiImage = userProfileManager.avatarImage {
                return Image(uiImage: uiImage)
            } else {
                return Image("例子")
            }
        }()

        HStack(spacing: 8) {
            AvatarView_s(
                isEnabled: true,
                profileImage: avatarImage,
                borderThickness: 2
            )

            // 只显示用户名
            Text(localUser.nickname)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .onTapGesture {
            navigationCoordinator.path.append(Route.myView)
        }
    }

    // MARK: - 他人用户胶囊渲染

    @ViewBuilder
    private func renderOtherUserCapsule() -> some View {
        if PreviewHarness.enabled {
            capsuleContentSimple(
                nickname: "测试用户",
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
            capsuleContentSimple(nickname: "加载中...", iconName: nil, onTap: {})

        case .loaded:
            if let otherUser = userProfileManager.otherUserProfile, otherUser.id == userId {
                capsuleContentForOther(otherUser: otherUser)
            } else {
                capsuleContentSimple(nickname: "陌生人", iconName: "person.fill.questionmark", onTap: {})
            }

        case .error:
            capsuleContentSimple(
                nickname: "加载失败",
                iconName: "exclamationmark.triangle.fill",
                onTap: {
                    retryLoadUser()
                }
            )
        }
    }

    // MARK: - 他人用户胶囊（从网络加载头像）

    @ViewBuilder
    private func capsuleContentForOther(otherUser: UserFullInfoModel) -> some View {
        HStack(spacing: 8) {
            // 从网络加载头像
            if let photoPath = otherUser.photo,
               let photoURL = URL(string: photoPath) {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        AvatarView_s(
                            isEnabled: true,
                            profileImage: image,
                            borderThickness: 2
                        )
                    case .failure, .empty:
                        AvatarView_s(
                            isEnabled: true,
                            profileImage: Image("例子"),
                            borderThickness: 2
                        )
                    @unknown default:
                        AvatarView_s(
                            isEnabled: true,
                            profileImage: Image("例子"),
                            borderThickness: 2
                        )
                    }
                }
            } else {
                AvatarView_s(
                    isEnabled: true,
                    profileImage: Image("例子"),
                    borderThickness: 2
                )
            }

            // 只显示用户名
            Text(otherUser.nickname ?? "陌生人")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .onTapGesture {
            navigationCoordinator.path.append(Route.othersView(userId: Int(userId)))
        }
    }

    // MARK: - 简化版胶囊（用于加载中、错误状态）

    @ViewBuilder
    private func capsuleContentSimple(nickname: String, iconName: String?, onTap: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
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

            Text(nickname)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .onTapGesture {
            onTap()
        }
    }

    // MARK: - 辅助方法

    private func loadUserIfNeeded() {
        guard !isMyself else { return }

        let currentState = userProfileManager.userLoadingStates[Int(userId)] ?? .idle
        if case .loaded = currentState { return }
        if case .loading = currentState { return }

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

// MARK: - ═══════════════════════════════════════════════════════════════════════
// MARK:   🖼️ 小尺寸头像组件
// MARK: - ═══════════════════════════════════════════════════════════════════════

/// 28pt 尺寸的头像组件（用于用户信息胶囊）
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

// MARK: - ═══════════════════════════════════════════════════════════════════════
// MARK:   🔬 Preview Support（Xcode 预览支持）
// MARK: - ═══════════════════════════════════════════════════════════════════════
//
//  提供 Xcode 预览所需的模拟环境和测试数据
//  - PreviewDependencies: 创建所有必要的依赖项
//  - ShareDetailViewPreview: 预览包装器视图
//
// ═══════════════════════════════════════════════════════════════════════════════

/// 为预览创建必要的环境和数据
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

// MARK: - ═══════════════════════════════════════════════════════════════════════
// MARK:   🐛 Debug 工具
// MARK: - ═══════════════════════════════════════════════════════════════════════

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

