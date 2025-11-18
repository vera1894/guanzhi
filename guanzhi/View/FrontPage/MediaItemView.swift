//
//  MediaItemView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/11/19.
//

/*
 ═══════════════════════════════════════════════════════════════════════════════
 LivePhoto/短视频 播放方案切换开关
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## 方案 A：PHLivePhotoView（系统原生 LivePhoto）
 - 使用 PHLivePhotoView 播放，需要元数据配对
 - 优势：系统级语义、震动、长按、保存相册支持完整
 - 劣势：首次播放有 0.5-0.8s 预热延迟（.hint → .full）
 - 适用场景：需要完整 LivePhoto 体验时
 
 ## 方案 B：AVPlayer（短视频播放）✅ 当前启用
 - 使用 AVPlayer 直接播放视频，无需配对元数据
 - 优势：秒播体验、可控性强、服务器无需改造
 - 劣势：失去系统 LivePhoto 语义，需手动实现震动
 - 适用场景：追求极致播放体验时
 
 ═══════════════════════════════════════════════════════════════════════════════
 */

// ✅ 方案切换开关（true = 方案B短视频，false = 方案A LivePhoto）
fileprivate let USE_VIDEO_PLAYBACK = true

import SwiftUI
import PhotosUI
import AVKit

struct MediaItemView: View {
    @ObservedObject var mediaItemWrapper: MediaItemWrapper
    var thumbnailImage: UIImage?
    var currentIndex: Int? = nil  // 当前项的索引
    var selectedIndex: Int? = nil  // 当前选中的索引
    @State private var isPlayingLivePhoto: Bool = false // 控制 Live Photo 的播放
    @State private var isLongPressActive: Bool = false // 长按手势是否正在进行
    @State private var longPressWorkItem: DispatchWorkItem? = nil
    @State private var didTriggerLongPressPlayback: Bool = false
    @State private var needsPrewarm: Bool = true // 是否需要预热（首次自动播放时）
    @State private var coverVisible: Bool = true // 方案B：控制封面图可见性
    @State private var isPlaying: Bool = false // 方案B：控制视频播放状态
    @State private var playbackSession = UUID() // 方案B：播放会话 ID，防止状态混乱
    @State private var isReadyLayer: Bool = false // 方案B：图层是否可显示（isReadyForDisplay）
    @State private var hasOneFrame: Bool = false // 方案B：是否已渲染至少一帧
    @State private var shouldShowPlayer: Bool = false // 方案B：是否应该显示播放器（防止 TabView 预创建时触发）

    // 判断当前项是否被选中
    private var isCurrentlySelected: Bool {
        guard let current = currentIndex, let selected = selectedIndex else {
            return false
        }
        return current == selected
    }

    var body: some View {
        #if DEBUG
        let _ = print("🔄 MediaItemView[\(currentIndex ?? -1)] body 重新渲染, isPlayingLivePhoto: \(isPlayingLivePhoto), isSelected: \(isCurrentlySelected)")
        #endif
        
        if let mediaItem = mediaItemWrapper.mediaItem {
            if let photo = mediaItem as? Photo {
                if photo.data.isEmpty {
                    // 数据为空，显示加载指示器
                    ProcessingView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let uiImage = UIImage(data: photo.data) {
                    // 动态照片或静态照片（统一处理）
                    ZStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .overlay(
                                VStack{
                                    HStack{
                                        // 只有 LivePhoto 才显示 badge
                                        if photo.livePhotoMovieURL != nil {
                                            LiveBadgeOnPhoto()
                                                .padding(.horizontal)
                                        }
                                        Spacer()
                                    }
                                    .padding(.top, 20)
                                    Spacer()
                                }
                            )
                            .onLongPressGesture(
                                minimumDuration: 0.8,
                                maximumDistance: 50,
                                pressing: { isPressing in
                                    guard photo.livePhotoMovieURL != nil else { return }

                                    if isPressing {
                                        // 已经在执行长按，避免重复调度
                                        guard !isLongPressActive else { return }
                                        isLongPressActive = true

                                        // 取消上一次的调度任务
                                        longPressWorkItem?.cancel()

                                        let workItem = DispatchWorkItem { [currentIndex] in
                                            guard isLongPressActive else { return }
                                            // ✅ 检查 LivePhoto 是否已准备好
                                            guard mediaItemWrapper.livePhoto != nil else {
                                                #if DEBUG
                                                print("⚠️ MediaItemView[\(currentIndex ?? -1)] - 长按触发但 LivePhoto 未准备好，取消播放")
                                                #endif
                                                return
                                            }
                                            #if DEBUG
                                            print("👆 MediaItemView[\(currentIndex ?? -1)] - 长按触发重新播放")
                                            #endif
                                            didTriggerLongPressPlayback = true
                                            mediaItemWrapper.currentPlayToken = UUID()
                                            isPlayingLivePhoto = true
                                        }

                                        longPressWorkItem = workItem
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
                                    } else {
                                        isLongPressActive = false
                                        longPressWorkItem?.cancel()
                                        longPressWorkItem = nil

                                        if didTriggerLongPressPlayback {
                                            // 松开手指后停止播放，下次可再次触发
                                            isPlayingLivePhoto = false
                                            mediaItemWrapper.currentPlayToken = nil
                                            mediaItemWrapper.handledPlayToken = nil
                                            didTriggerLongPressPlayback = false
                                        }
                                    }
                                },
                                perform: {}
                            )

                        // ✅ 终极方案：只在被选中时才创建 LivePhotoView，避免 TabView 预加载时的参数混乱
                        if isCurrentlySelected && photo.livePhotoMovieURL != nil {
                            LivePhotoView(
                                livePhoto: mediaItemWrapper.livePhoto,
                                shouldPlay: isPlayingLivePhoto,
                                isSelected: isCurrentlySelected,
                                needsPrewarm: needsPrewarm,
                                playToken: mediaItemWrapper.currentPlayToken,
                                handledPlayToken: mediaItemWrapper.handledPlayToken,
                                onPlaybackStarted: { token in
                                    // ✅ 使用 Task 避免在视图更新期间修改 @Published 属性
                                    Task { @MainActor in
                                        mediaItemWrapper.handledPlayToken = token
                                        needsPrewarm = false // 预热完成，后续不再需要
                                    }
                                },
                                onPlaybackFinished: {
                                    // ✅ 使用 Task 避免在视图更新期间修改 @Published 属性
                                    Task { @MainActor in
                                        isPlayingLivePhoto = false
                                        mediaItemWrapper.currentPlayToken = nil
                                        mediaItemWrapper.handledPlayToken = nil
                                    }
                                }
                            )
                            .id("LivePhotoView-index\(currentIndex ?? -1)-\(mediaItemWrapper.id)")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .opacity(isPlayingLivePhoto ? 1 : 0)
                            .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        #if DEBUG
                        print("▶️ MediaItemView[\(currentIndex ?? -1)] - ZStack.onAppear, isSelected: \(isCurrentlySelected), hasAutoPlayed: \(mediaItemWrapper.hasAutoPlayedForSelection), livePhoto: \(mediaItemWrapper.livePhoto != nil ? "已准备" : "未准备")")
                        #endif
                        // 只有在 LivePhoto 已经准备好的情况下才播放，使用短延迟给 PHLivePhotoView 准备资源的时间
                        if isCurrentlySelected,
                           photo.livePhotoMovieURL != nil,
                           mediaItemWrapper.livePhoto != nil,  // ✅ 检查 LivePhoto 是否已准备好
                           mediaItemWrapper.hasAutoPlayedForSelection == false {
                            #if DEBUG
                            print("▶️ MediaItemView[\(currentIndex ?? -1)] - LivePhoto 已准备，延迟 100ms 后自动播放（给视图时间准备资源）")
                            #endif
                            // ✅ 使用 100ms 短延迟，给 PHLivePhotoView 时间准备内部资源，但不会长到让 TabView 干扰
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak mediaItemWrapper] in
                                guard let mediaItemWrapper = mediaItemWrapper,
                                      !mediaItemWrapper.hasAutoPlayedForSelection else { return }
                                mediaItemWrapper.currentPlayToken = UUID()
                                isPlayingLivePhoto = true
                                mediaItemWrapper.hasAutoPlayedForSelection = true
                            }
                        } else if isCurrentlySelected,
                                  photo.livePhotoMovieURL != nil,
                                  mediaItemWrapper.livePhoto == nil {
                            #if DEBUG
                            print("⏳ MediaItemView[\(currentIndex ?? -1)] - LivePhoto 未准备好，等待生成完成")
                            #endif
                        }
                    }
                    .onChange(of: isCurrentlySelected) { oldValue, newValue in
                        #if DEBUG
                        print("🔀 MediaItemView[\(currentIndex ?? -1)] - isCurrentlySelected 变化: \(oldValue) -> \(newValue), livePhoto: \(mediaItemWrapper.livePhoto != nil ? "已准备" : "未准备")")
                        #endif
                        // 切换到当前照片：使用短延迟给 PHLivePhotoView 准备资源的时间
                        if newValue,
                           photo.livePhotoMovieURL != nil,
                           mediaItemWrapper.livePhoto != nil,  // ✅ 检查 LivePhoto 是否已准备好
                           mediaItemWrapper.hasAutoPlayedForSelection == false {
                            #if DEBUG
                            print("▶️ MediaItemView[\(currentIndex ?? -1)] - 切换到当前照片，LivePhoto 已准备，延迟 100ms 后播放")
                            #endif
                            // ✅ 使用 100ms 短延迟
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak mediaItemWrapper] in
                                guard let mediaItemWrapper = mediaItemWrapper,
                                      !mediaItemWrapper.hasAutoPlayedForSelection else { return }
                                mediaItemWrapper.currentPlayToken = UUID()
                                isPlayingLivePhoto = true
                                mediaItemWrapper.hasAutoPlayedForSelection = true
                            }
                        } else if newValue,
                                  photo.livePhotoMovieURL != nil,
                                  mediaItemWrapper.livePhoto == nil {
                            #if DEBUG
                            print("⏳ MediaItemView[\(currentIndex ?? -1)] - 切换到当前照片，LivePhoto 未准备好，等待生成完成")
                            #endif
                        }

                        // 切换走：停止播放并重置标志
                        if !newValue {
                            isPlayingLivePhoto = false
                            mediaItemWrapper.hasAutoPlayedForSelection = false
                            mediaItemWrapper.currentPlayToken = nil
                            mediaItemWrapper.handledPlayToken = nil
                        }
                    }
                    .onChange(of: mediaItemWrapper.livePhoto) { oldValue, newValue in
                        #if DEBUG
                        print("📸 MediaItemView[\(currentIndex ?? -1)] - livePhoto 变化: \(oldValue != nil ? "有" : "无") -> \(newValue != nil ? "有" : "无"), isSelected: \(isCurrentlySelected), hasAutoPlayed: \(mediaItemWrapper.hasAutoPlayedForSelection)")
                        #endif

                        // ✅ 核心逻辑：当 LivePhoto 从 nil 变为非 nil，且满足自动播放条件时，延迟触发播放
                        if oldValue == nil,
                           newValue != nil,
                           isCurrentlySelected,
                           photo.livePhotoMovieURL != nil,
                           !mediaItemWrapper.hasAutoPlayedForSelection,
                           !didTriggerLongPressPlayback {  // 不干扰长按播放
                            #if DEBUG
                            print("✅ MediaItemView[\(currentIndex ?? -1)] - LivePhoto 准备完成，延迟 100ms 后触发自动播放")
                            #endif
                            // ✅ 使用 100ms 短延迟，给 PHLivePhotoView 时间准备内部资源
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak mediaItemWrapper] in
                                guard let mediaItemWrapper = mediaItemWrapper,
                                      !mediaItemWrapper.hasAutoPlayedForSelection,
                                      !didTriggerLongPressPlayback else { return }
                                mediaItemWrapper.currentPlayToken = UUID()
                                isPlayingLivePhoto = true
                                mediaItemWrapper.hasAutoPlayedForSelection = true
                            }
                        }
                    }
                    .onChange(of: isPlayingLivePhoto) { oldValue, newValue in
                        #if DEBUG
                        print("🔀 MediaItemView[\(currentIndex ?? -1)] - isPlayingLivePhoto 状态变化: \(oldValue) -> \(newValue)")
                        #endif
                    }
                } else {
                    Text("无法加载图片")
                }
            } else if let movie = mediaItem as? Movie {
                // ✅ 方案B：短视频播放（全局 Overlay）
                // ✅ MediaItemView 只负责显示封面，播放器由 ShareDetailView 的全局 Overlay 管理
                if USE_VIDEO_PLAYBACK {
                    // ✅ 使用封面图尺寸作为统一的 aspectRatio
                    let posterSize: CGSize = {
                        if let coverData = mediaItemWrapper.coverImageData,
                           let coverImage = UIImage(data: coverData) {
                            return coverImage.size
                        }
                        return CGSize(width: 3, height: 4) // 默认 3:4
                    }()
                    
                    GeometryReader { geometry in
                        ZStack {
                            // ✅ 只显示封面图（不再创建 VideoPlayerView）
                            if let coverData = mediaItemWrapper.coverImageData,
                               let coverImage = UIImage(data: coverData) {
                                Image(uiImage: coverImage)
                                    .resizable()
                                    .scaledToFill()
                                    .opacity(mediaItemWrapper.coverShouldShow ? 1 : 0) // ✅ 由 ShareDetailView 控制
                                    .allowsHitTesting(false)
                                    .clipped()
                                    .overlay(
                                        // ✅ 实况图标（只在封面显示时显示）
                                        VStack {
                                            HStack {
                                                if mediaItemWrapper.coverShouldShow {
                                                    LiveBadgeOnPhoto()
                                                        .padding(.horizontal)
                                                }
                                                Spacer()
                                            }
                                            .padding(.top, 20)
                                            Spacer()
                                        }
                                    )
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        // ✅ 使用 preference 报告当前选中页的矩形到 PlayerSpace 坐标空间
                        .preference(key: PlayerFrameKey.self, value: {
                            let frame = isCurrentlySelected ? geometry.frame(in: .named("PlayerSpace")) : .zero
                            #if DEBUG
                            if isCurrentlySelected {
                                print("📐 MediaItemView[\(currentIndex ?? -1)] - 报告矩形: \(frame)")
                            }
                            #endif
                            return frame
                        }())
                    }
                    .aspectRatio(posterSize, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .onLongPressGesture(
                        minimumDuration: 0.8,
                        maximumDistance: 50,
                        pressing: { isPressing in
                            if isPressing {
                                // 长按开始：通知 ShareDetailView 播放视频
                                guard !isLongPressActive else { return }
                                isLongPressActive = true
                                
                                longPressWorkItem?.cancel()
                                let workItem = DispatchWorkItem { [currentIndex] in
                                    guard isLongPressActive else { return }
                                    
                                    #if DEBUG
                                    print("👆 MediaItemView[\(currentIndex ?? -1)] - 长按触发视频播放（将由全局 Overlay 处理）")
                                    #endif
                                    
                                    didTriggerLongPressPlayback = true
                                    
                                    // ✅ 重置封面状态
                                    mediaItemWrapper.coverShouldShow = false
                                    
                                    if let engine = mediaItemWrapper.videoEngine {
                                        engine.prepare(url: movie.url) {
                                            #if DEBUG
                                            print("▶️ MediaItemView[\(currentIndex ?? -1)] - 长按播放准备完成，开始播放")
                                            #endif
                                            engine.playImmediately()
                                        }
                                    }
                                }
                                
                                longPressWorkItem = workItem
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
                            } else {
                                // 长按结束：停止播放，回到静止
                                isLongPressActive = false
                                longPressWorkItem?.cancel()
                                longPressWorkItem = nil
                                
                                if didTriggerLongPressPlayback {
                                    mediaItemWrapper.coverShouldShow = true
                                    mediaItemWrapper.videoEngine?.stop()
                                    didTriggerLongPressPlayback = false
                                }
                            }
                        },
                        perform: {}
                    )
                    .onAppear {
                        #if DEBUG
                        print("▶️ MediaItemView[\(currentIndex ?? -1)] - Movie.onAppear, isSelected: \(isCurrentlySelected)")
                        #endif
                    }
                    .onChange(of: isCurrentlySelected) { oldValue, newValue in
                        #if DEBUG
                        print("🔀 MediaItemView[\(currentIndex ?? -1)] - Movie isSelected 变化: \(oldValue) -> \(newValue)")
                        #endif
                        
                        if !newValue {
                            // 切换走：重置状态
                            mediaItemWrapper.hasAutoPlayedForSelection = false
                            mediaItemWrapper.coverShouldShow = true
                        }
                    }
                } else {
                    // 原始方式（SwiftUI VideoPlayer）
                VideoPlayer(player: AVPlayer(url: movie.url))
                    .aspectRatio(contentMode: .fit)
                }
            } else {
                Text("Unsupported media type")
            }
            
        } else {
            // 显示 Loading 动画
            ZStack {
                // 封面图（如果有）
                if USE_VIDEO_PLAYBACK,
                   let coverData = mediaItemWrapper.coverImageData,
                   let coverImage = UIImage(data: coverData) {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .blur(radius: 10)
                        .opacity(0.5)
                }
                
                ProcessingView()
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                // ✅ 方案B：在 loading 期间开始预加载视频
                if USE_VIDEO_PLAYBACK,
                   isCurrentlySelected,
                   let videoFile = mediaItemWrapper.videoFile,
                   let videoURL = videoFile.localURL {
                    
                    #if DEBUG
                    print("🚀 MediaItemView[\(currentIndex ?? -1)] - Loading 期间检查预加载")
                    #endif
                    
                    // ✅ 如果 VideoEngine 已创建，开始预加载
                    if let engine = mediaItemWrapper.videoEngine {
                        engine.prepare(url: videoURL) {
                            #if DEBUG
                            print("✅ MediaItemView[\(currentIndex ?? -1)] - Loading 期间视频预加载完成")
                            #endif
                        }
                    } else {
                        #if DEBUG
                        print("⏳ MediaItemView[\(currentIndex ?? -1)] - Loading 期间 VideoEngine 尚未创建，等待 createMediaItem")
                        #endif
                    }
                }
            }
        }
    }
}

// MARK: - 架构说明与技术分析备注
/*
 ═══════════════════════════════════════════════════════════════════════════════
 LivePhoto 播放延迟问题的完整技术分析
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## 问题现象
 用户打开分享后，每张LivePhoto首次查看时需要等待约0.8秒静态图片，然后才开始播放。
 
 ## 根本原因
 
 ### 1. 服务器数据格式（当前状态）
 - **上传时**：`MainToolbar.swift` 第324-358行
   ```
   uniqueFileName_photo.jpg     // 普通JPEG，无LivePhoto元数据
   uniqueFileName_livephoto.mov // 普通MOV视频，无配对标识
   ```
 
 - **服务器存储**：这两个文件是**独立的普通文件**，不是Apple定义的"真·LivePhoto"
   - 缺少 `Content Identifier`（配对UUID）
   - 图片缺少 `MakerApple key 17`
   - 视频缺少 `QuickTime com.apple.quicktime.content.identifier`
   - 视频缺少 `Timed Metadata: com.apple.quicktime.still-image-time`
 
 ### 2. 客户端处理流程（SearchViewModel.swift 第1508-1513行）
 ```swift
 // 将普通JPG写入临时文件
 let tempPhotoURL = URL(fileURLWithPath: NSTemporaryDirectory())
     .appendingPathComponent(UUID().uuidString + ".jpg")
 try photo.data.write(to: tempPhotoURL)
 
 // 用两个普通文件生成LivePhoto
 PHLivePhoto.request(withResourceFileURLs: [tempPhotoURL, livePhotoMovieURL], ...)
 ```
 
 **关键问题**：
 - `PHLivePhoto.request` 接收的是**两个没有配对关系的普通文件**
 - 系统需要在客户端侧做"临时拼装"：
   1. 检测文件兼容性
   2. 构造LivePhoto内部结构
   3. 生成配对关系（耗时）
 - 首次播放**必须**执行 `.hint` 预热（约0.8秒），这是系统机制
 
 ### 3. PHLivePhotoView 的预热机制
 - **第一次播放**：必须 `.hint` 预热（~0.8秒）+ `.full` 播放
 - **第二次播放**：跳过预热，直接 `.full`（因为已预热）
 - **视图重建**：每次 `NEW VIEW CREATED`（SwiftUI重建）都需要重新预热
 
 日志证据：
 ```
 🎬 LivePhotoView makeUIView - NEW VIEW CREATED
 🎬 LivePhotoView - 准备播放，needsPrewarm: true
 🔥 LivePhotoView - 开始预热播放 .hint（不可见）  ← 0.8秒
 ✅ LivePhotoView - .hint 预热完成
 🎬 LivePhotoView - 预热后开始播放 .full
 ```
 
 ═══════════════════════════════════════════════════════════════════════════════
 解决方案对比
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## 方案A：真Live Photo（需改造服务器）❌ 当前不可行
 
 ### 要做什么
 1. **服务端改造**（必需）：
    - 生成配对UUID
    - 图片：写入 `MakerApple key 17 = UUID`（推荐HEIC格式）
    - 视频：写入 `QuickTime content.identifier = UUID`
    - 视频：添加 `mdta` 轨，写入 `still-image-time = -1`
 
 2. **技术难点**：
    - ffmpeg 无法可靠写入 `mdta still-image-time` 轨
    - 需要 macOS + AVFoundation 或 Bento4 工具
    - Linux转码集群需要增加macOS编码节点
 
 3. **客户端无需改动**：
    - 保持现有 `PHLivePhotoView` 逻辑
    - 系统会识别为"真Live Photo"
    - 预热时间显著缩短（但不会完全消失）
 
 ### 优势
 - ✅ 系统级LivePhoto语义（波纹、震动、相册集成）
 - ✅ 可保存到相册（`.photo` + `.pairedVideo`）
 - ✅ AirDrop、分享等完整支持
 - ✅ 首播等待时间缩短（从0.8秒降至极短，但不为0）
 
 ### 劣势
 - ❌ **必须改服务器**（工程量大）
 - ❌ 需要macOS编码节点或Bento4工具链
 - ❌ 历史数据需要重新处理
 - ❌ 仍然存在轻微预热（系统机制）
 
 ### 工程量评估
 - 服务端：★★★★★（需要macOS编码节点 + AVFoundation写mdta轨）
 - 客户端：★☆☆☆☆（几乎无需改动）
 - 总计：★★★★☆（中等偏大）
 
 ---
 
 ## 方案B：当短视频播放（推荐）✅ 可立即实施
 
 ### 核心思路
 既然服务器已经是"JPG + MOV短视频"，那就**把它当短视频播放**，用AVPlayer而非PHLivePhotoView。
 
 ### 要做什么
 1. **修改类型判断**（SearchViewModel.swift 第1147-1154行）：
    ```swift
    if let videoFile = mediaItemWrapper.videoFile {
        // ✅ 检测到LivePhoto，直接创建Movie而非Photo
        let movie = Movie(url: videoLocalURL)
        mediaItemWrapper.mediaItem = movie
        return movie
    }
    ```
 
 2. **新增 VideoEngine 类**：
    ```swift
    final class VideoEngine {
        private var player = AVPlayer()
        
        func prepare(url: URL, onReady: @escaping () -> Void) {
            let asset = AVURLAsset(url: url)
            asset.loadValuesAsynchronously(forKeys: ["playable"]) {
                let item = AVPlayerItem(asset: asset)
                item.preferredForwardBufferDuration = 2
                self.player.automaticallyWaitsToMinimizeStalling = false
                self.player.replaceCurrentItem(with: item)
                // 监听 readyToPlay
                if item.status == .readyToPlay { onReady() }
            }
        }
        
        func playNow() {
            player.playImmediately(atRate: 1.0)
        }
    }
    ```
 
 3. **修改 MediaItemView**：
    - `Movie` 类型用 `VideoPlayerView`（自封装AVPlayerLayer）
    - 不要用 SwiftUI 的 `VideoPlayer`（启动慢）
 
 4. **预加载策略**：
    - loading期间：预热首张 + 下一张
    - loading结束：立即 `playImmediately(atRate: 1.0)`
    - 切换时：复用AVPlayer，只换 `currentItem`
 
 5. **体验优化**：
    - 先显示封面JPG
    - `readyToPlay` 后淡出封面，淡入视频
    - 播放时触发 `UIImpactFeedbackGenerator`（模拟震动）
 
 ### 优势
 - ✅ **服务器无需改动**（最大优势）
 - ✅ 实现真正的"秒播"（loading完→直接播）
 - ✅ 避免 PHLivePhotoView 的构造开销
 - ✅ 避免 0.8秒预热
 - ✅ 可实现小红书同款体验
 - ✅ 更可控的播放逻辑
 
 ### 劣势
 - ⚠️ 失去系统级LivePhoto语义（波纹、长按动效）
 - ⚠️ 无法直接保存为LivePhoto到相册
 - ⚠️ 震动需要手动实现（UIImpactFeedbackGenerator）
 
 ### 工程量评估
 - 服务端：☆☆☆☆☆（无需改动）
 - 客户端：★★★☆☆（中等）
   - 新增VideoEngine
   - 修改类型判断
   - 封装VideoPlayerView
   - 调整预加载逻辑
 - 总计：★★☆☆☆（小到中等）
 
 ═══════════════════════════════════════════════════════════════════════════════
 当前服务器数据格式确认
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## 上传流程（MainToolbar.swift 第271-358行）
 
 ```swift
 // 1. 生成唯一文件名前缀
 let uniqueFileName = "\(userId)_\(timestamp)_\(randomNumber)"
 
 // 2. 上传静态图片（普通JPEG）
 uploadFile(data: photo.data, 
            fileName: "\(uniqueFileName)_photo.jpg",
            mimeType: "image/jpeg")
 
 // 3. 如果有LivePhoto视频，上传普通MOV
 if let livePhotoURL = photo.livePhotoMovieURL {
     let videoData = try Data(contentsOf: livePhotoURL)
     uploadFile(data: videoData,
                fileName: "\(uniqueFileName)_livephoto.mov",
                mimeType: "video/quicktime")
 }
 ```
 
 ## 服务器返回格式
 
 示例路径（逗号分隔）：
 ```
 11_1749277977147_15438_photo-20250607063258871.jpg,
 11_1749277977147_15438_livephoto-20250607063306679.mov,
 11_1749277986705_64961_photo-20250607063308721.jpg,
 11_1749277986705_64961_livephoto-20250607063309021.mov
 ```
 
 ## 解析逻辑（SearchViewModel.swift 第417-459行）
 
 ```swift
 // 按前缀分组：11_1749277977147_15438
 // 识别类型：photo / livephoto / thumbnail
 switch typeString.lowercased() {
 case "photo": mediaType = .photo
 case "livephoto": mediaType = .livePhoto  // ⚠️ 实际是普通MOV
 // ...
 }
 ```
 
 **关键结论**：
 - 服务器存储的是**两个独立的普通文件**
 - 没有Apple LivePhoto的配对元数据
 - 文件名通过前缀关联，不是通过元数据UUID关联
 
 ═══════════════════════════════════════════════════════════════════════════════
 最终建议
 ═══════════════════════════════════════════════════════════════════════════════
 
 ## ⭐️ 推荐方案B（短视频播放）
 
 **理由**：
 1. ✅ 服务器无需任何改动
 2. ✅ 可以立即实施，工程量可控
 3. ✅ 能够实现目标体验（loading完→立即播放）
 4. ✅ 技术上更可控，不依赖系统黑盒逻辑
 
 **不推荐方案A的原因**：
 1. ❌ **必须改服务器**（这是最大的阻碍）
 2. ❌ 需要macOS编码节点（Linux无法完成mdta轨写入）
 3. ❌ 工程量大，投入产出比低
 4. ❌ 历史数据需要重新处理
 
 ## 混合方案（可选）
 
 如果未来有"保存到相册"的需求：
 - App内播放：用方案B（短视频秒播）
 - 保存相册：在保存时，客户端临时生成LivePhoto（接受首次转换耗时）
 - 或者：保存时上传到新的"真LivePhoto"产线
 
 ═══════════════════════════════════════════════════════════════════════════════
 参考资料
 ═══════════════════════════════════════════════════════════════════════════════
 
 1. PHLivePhoto 配对机制：
    - MakerApple key 17（图片侧）
    - QuickTime content.identifier（视频侧）
    
 2. Timed Metadata 必要性：
    - com.apple.quicktime.still-image-time
    - ffmpeg 无法可靠写入，需要 AVFoundation 或 Bento4
    
 3. AVPlayer 快速起播：
    - preferredForwardBufferDuration
    - automaticallyWaitsToMinimizeStalling = false
    - playImmediately(atRate: 1.0)
    
 4. iOS 15.1+ 行为变更：
    - 系统相机优先使用 HEIC
    - JPG 的 MakerApple 行为有变动
 
 ═══════════════════════════════════════════════════════════════════════════════
 结论：不改服务器无法实现方案A，建议采用方案B
 ═══════════════════════════════════════════════════════════════════════════════
 */
