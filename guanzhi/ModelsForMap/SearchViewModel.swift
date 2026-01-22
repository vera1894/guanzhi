//
//  SearchViewModel.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/9/29.
//

import Foundation
import Observation
import MapKit
import SwiftUI
import Combine
import SwiftData
import AVFoundation
import Photos

// ✅ 方案切换开关（true = 方案B短视频，false = 方案A LivePhoto）
fileprivate let USE_VIDEO_PLAYBACK = true

@MainActor
class SearchViewModel: ObservableObject {
    
    @Published var appState: AppStateModel?
    var locationManager: LocationManager?
    var context: ModelContext!
    func initializeData() {
        guard context != nil else {
            print("Context is nil in initializeData")
            return
        }
        if let location = locationManager?.currentLocation {
            fetchAllShares(latitude: location.latitude, longitude: location.longitude)
            getAnnotations()
        }
    }
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    var fetchWorkItem: DispatchWorkItem?
    
    @Published var annotations: [CustomAnnotation] = []
    @Published var searchResults = [SearchResult]() //用于存储搜索结果
    @Published var selectedLocation: SearchResult? = nil //用于存储选中的搜索结果
//    var locationAnimating: Bool = false
//    private var lastRegionChangeTime: Date = Date()
//    private var cancellables = Set<AnyCancellable>()
    /// 缓存服务器返回的原始 ResponsedShare 数据（key: shareId）
    /// 用于聚合列表等需要完整数据（如 fadeScore）的场景
    @Published var cachedResponsedShares: [Int: ResponsedShare] = [:]
    @Published var selectedAnnotation: CustomAnnotation? = nil //用于存储选中的分享
    @Published var selectedAnnotationID: String? = nil //用于存储选中分享的id，用于match动画，但目前不可用
    @Published var selectedAnnotationImage: UIImage? //用于存储选中分享的图像，快速传递缩略图，后加载为原文件
    @Published var downloadMedia: [MediaItemWrapper] = []
    @Published var isUpdatingAnnotations: Bool = false
    @Published var selectedShare: Share?
    @Published var selectedShareMediaFiles: [MediaFile] = []
    @Published var annotationSortOption: AnnotationSortOption = .createDateDescending
    @Published var isShareDetailOverlayShown: Bool = false
    private var currentLoadingShareId: Int64? = nil  // 正在加载的分享 ID，防止重复加载
    @Published var shareDeletedMessage: String? = nil // 分享已删除的提示消息
    @Published var showNavigationSheet: Bool = false // 导航应用选择弹窗状态

    // MARK: - 网络重试机制
    /// 附近分享加载状态
    @Published var nearbySharesState: DataLoadingState<[Share]> = .idle
    /// 分享详情加载状态
    @Published var shareDetailState: DataLoadingState<Share> = .idle
    /// 当前正在执行的获取任务（用于取消）
    private var currentFetchTask: Task<Void, Never>?
    private var currentDetailTask: Task<Void, Never>?
    /// 网络恢复监听
    private var networkRestoredCancellable: AnyCancellable?
    private var networkChangedCancellable: AnyCancellable?

    // ✅ MediaItemWrapper 缓存，key 为 "shareId-prefix"，用于复用已有的 wrapper，避免重复创建导致视图重建
    private var mediaItemWrapperCache: [String: MediaItemWrapper] = [:]

    // MARK: - Lifecycle

    deinit {
        // 显式取消 Combine 订阅
        networkRestoredCancellable?.cancel()
        networkRestoredCancellable = nil
        networkChangedCancellable?.cancel()
        networkChangedCancellable = nil
        // 取消进行中的任务
        currentFetchTask?.cancel()
        currentDetailTask?.cancel()
        #if DEBUG
        print("🧹 SearchViewModel deinit - 资源已清理")
        #endif
    }

    // MARK: - 媒体下载重试机制
    /// 失败的下载任务队列（用于网络恢复时重试）
    private var failedDownloads: [(mediaFile: MediaFile, wrapper: MediaItemWrapper)] = []
    /// 媒体下载的 URLSession（带超时配置）
    private lazy var mediaDownloadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30   // 请求超时 30 秒
        config.timeoutIntervalForResource = 120 // 资源超时 120 秒
        config.waitsForConnectivity = true      // 等待网络连接
        return URLSession(configuration: config)
    }()

    // MARK: - Functions - 分享标注列表与标注用于地图

    // 根据坐标获取地址（备用，目前未使用）
    func getAddressFromLocation(for location: CLLocationCoordinate2D?, completion: @escaping (String?) -> Void) {
        // 使用反地理编码将坐标转换为地址字符串
        if let location = location {
            let location = CLLocation(latitude: location.latitude, longitude: location.longitude)
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    print("定位错误：\(error.localizedDescription)")
                } else if let placemark = placemarks?.first {
                    let address = "\(placemark.name ?? "")\(placemark.locality ?? "")\(placemark.administrativeArea ?? "")\(placemark.country ?? "")"
                    print("地址：", address)
                    completion(address)
                }
            }
        }
    }
    
    // 地图操作防抖，延迟更新地图上的标注，避免频繁刷新
    func scheduleAnnotationUpdate() {
        fetchWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.getAnnotations()
        }
        fetchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }
    
    // MARK: - 网络重试机制方法

    /// 设置网络恢复监听
    func setupNetworkMonitoring() {
        // 监听网络恢复
        networkRestoredCancellable = NotificationCenter.default
            .publisher(for: .networkRestored)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // 附近分享：只在错误状态时自动重试
                if self.nearbySharesState.hasError {
                    print("📶 [SearchViewModel] 网络恢复，自动重试获取分享列表")
                    self.refreshNearbyShares(reason: .networkRestored)
                }
                // 分享详情：只在错误状态时自动重试
                if self.shareDetailState.hasError, let shareId = self.selectedShare?.id {
                    print("📶 [SearchViewModel] 网络恢复，自动重试获取分享详情")
                    self.fetchShareDetailFromServer(shareId: shareId, isBackground: false)
                }
                // 媒体下载：重试失败的下载
                self.retryFailedMediaDownloads()
            }

        // 监听网络类型切换
        networkChangedCancellable = NotificationCenter.default
            .publisher(for: .networkChanged)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // 附近分享：只在错误状态时自动重试
                if self.nearbySharesState.hasError {
                    print("📶 [SearchViewModel] 网络切换，自动重试获取分享列表")
                    self.refreshNearbyShares(reason: .networkRestored)
                }
                // 分享详情：只在错误状态时自动重试
                if self.shareDetailState.hasError, let shareId = self.selectedShare?.id {
                    print("📶 [SearchViewModel] 网络切换，自动重试获取分享详情")
                    self.fetchShareDetailFromServer(shareId: shareId, isBackground: false)
                }
                // 媒体下载：重试失败的下载
                self.retryFailedMediaDownloads()
            }
    }

    /// 重试失败的媒体下载
    private func retryFailedMediaDownloads() {
        guard !failedDownloads.isEmpty else { return }

        let downloadsToRetry = failedDownloads
        failedDownloads.removeAll()

        print("📶 [SearchViewModel] 网络恢复，重试 \(downloadsToRetry.count) 个失败的媒体下载")

        Task {
            for item in downloadsToRetry {
                do {
                    try await downloadMediaFile(mediaFile: item.mediaFile)
                    // 下载成功后创建媒体项
                    await MainActor.run {
                        if let mediaItem = createMediaItem(from: item.wrapper) {
                            item.wrapper.mediaItem = mediaItem
                            print("✅ [SearchViewModel] 媒体重试下载成功")
                        }
                    }
                } catch {
                    // 仍然失败，重新加入队列
                    print("❌ [SearchViewModel] 媒体重试下载仍然失败: \(error.localizedDescription)")
                    await MainActor.run {
                        self.failedDownloads.append(item)
                    }
                }
            }
        }
    }

    /// 刷新附近分享（带重试机制）
    /// - Parameters:
    ///   - reason: 刷新原因
    ///   - overrideLocation: 可选的覆盖坐标，如果提供则使用它，否则从 locationManager 获取
    func refreshNearbyShares(reason: RefreshReason, overrideLocation: CLLocationCoordinate2D? = nil) {
        // 优先使用传入的坐标，其次使用 locationManager，最后使用地图中心点
        let location: CLLocationCoordinate2D
        if let override = overrideLocation {
            location = override
            print("📍 [SearchViewModel] 使用传入坐标: \(override.latitude), \(override.longitude)")
        } else if let current = locationManager?.currentLocation {
            location = current
            print("📍 [SearchViewModel] 使用定位坐标: \(current.latitude), \(current.longitude)")
        } else {
            // 备用：使用地图中心点
            location = region.center
            print("📍 [SearchViewModel] 使用地图中心点: \(region.center.latitude), \(region.center.longitude)")
        }

        // 规范 2：如果已在加载中，直接返回
        if case .loading = nearbySharesState { return }

        // 取消旧任务
        currentFetchTask?.cancel()

        // P0 修复：Task 必须明确 @MainActor
        currentFetchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            let key = RetryCoordinator.key(for: .nearbyShares(lat: location.latitude, lng: location.longitude))
            let bypassCooldown = reason.shouldBypassCooldown

            // 原子操作：检查并标记开始
            guard await RetryCoordinator.shared.beginIfAllowed(
                key: key,
                bypassCooldown: bypassCooldown
            ) else { return }

            // P0 修复：使用 Task.detached 避免取消传播到 finish 调用
            defer {
                Task.detached { await RetryCoordinator.shared.finish(key: key) }
            }

            // P0 修复：保存前置状态，取消时可恢复
            let prevState = self.nearbySharesState
            self.nearbySharesState = .loading

            do {
                print("🌍 [SearchViewModel] 开始获取附近分享数据...")
                print("📍 坐标: latitude=\(location.latitude), longitude=\(location.longitude)")

                let shareList = try await ShareService.shared.fetchNearbyShares(
                    latitude: location.latitude,
                    longitude: location.longitude,
                    radius: 1000,
                    size: -1
                )

                // P0 修复：取消时恢复状态
                if Task.isCancelled {
                    self.nearbySharesState = prevState
                    return
                }

                print("✅ [SearchViewModel] 成功获取 \(shareList.count) 条分享数据")

                // 🔍 调试日志：检查服务器返回的 fadeScore
                print("🔍 [DEBUG] nearby first 5 fadeScore:", shareList.prefix(5).map { ($0.id, $0.fadeScore as Any) })

                // 缓存原始 ResponsedShare 数据（用于聚合列表等场景）
                for share in shareList {
                    self.cachedResponsedShares[share.id] = share
                }

                // 保存到 SwiftData
                await self.saveSharesToDatabase(shares: shareList)
                self.getAnnotations()

                // 获取保存后的 Share 列表
                let shares = self.getAllSharesFromDatabase()
                self.nearbySharesState = .loaded(shares)

            } catch {
                // P0 修复：取消时恢复状态
                if Task.isCancelled {
                    self.nearbySharesState = prevState
                    return
                }

                print("❌ [SearchViewModel] 获取分享数据失败: \(error.localizedDescription)")
                self.nearbySharesState = .error(error)
            }
        }
    }

    /// 从数据库获取所有分享
    private func getAllSharesFromDatabase() -> [Share] {
        guard context != nil else { return [] }
        let fetchDescriptor = FetchDescriptor<Share>(sortBy: [SortDescriptor<Share>(\.createDate, order: .reverse)])
        return (try? context.fetch(fetchDescriptor)) ?? []
    }

    //获取所有分享数据列表（保留原方法，内部调用新方法）
    func fetchAllShares(latitude: Double, longitude: Double) {
        // 设置网络监听（首次调用时）
        if networkRestoredCancellable == nil {
            setupNetworkMonitoring()
        }
        // 使用新的刷新方法，传入坐标
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        refreshNearbyShares(reason: .onAppear, overrideLocation: coordinate)
    }
    
    //保存分享数据到数据库
    func saveSharesToDatabase(shares: [ResponsedShare]) async {
        print("开始保存分享数据，数量: \(shares.count)")

        // 安全检查：确保 context 已初始化
        guard context != nil else {
            print("⚠️ SearchViewModel.saveSharesToDatabase: context 为 nil，跳过保存")
            return
        }

        for share in shares {
            // 创建 FetchDescriptor，用于查找数据库中是否已存在该分享
            let shareId = Int64(share.id)
            let fetchDescriptor = FetchDescriptor<Share>(
                predicate: #Predicate { $0.id == shareId },
                sortBy: []
            )
            // 执行 Fetch
            let existingShares = try? context.fetch(fetchDescriptor)
            if let existingShare = existingShares?.first {
                if share.deleted == 1 {
                    // 如果分享已被删除，从数据库中删除
                    context.delete(existingShare)
//                    print("删除已删除的分享，ID: \(share.id)")
                } else {
                    // 更新已有分享
                    updateShare(existingShare, with: share)
//                    print("更新已有的分享，ID: \(share.id)")
                }
            } else {
                if share.deleted == 1 {
                    // 已删除的分享，不需要处理
//                    print("分享已被删除，ID: \(share.id)，跳过")
                } else {
                    // 创建新分享，插入数据库
                    // 使用 TimeKit 统一处理时间（后端已统一 UTC）
                    let correctedDate = ServerTime.parse(milliseconds: share.createDate)
                    let newShare = Share(
                        id: Int64(share.id),
                        createDate: correctedDate,
                        userId: Int64(share.userId),
                        data: share.data,
                        longitude: share.longitude,
                        latitude: share.latitude,
                        provinceCode: share.provinceCode?.stringValue,
                        cityCode: share.cityCode?.stringValue,
                        districtCode: share.districtCode?.stringValue,
                        address: share.address,
                        imagePaths: share.imagePath.components(separatedBy: ","),
                        title: share.title,
                        deleted: share.deleted == 1
                    )
                    // 设置互动统计字段
                    newShare.agreeCount = share.agreeCount ?? 0
                    newShare.neutralCount = share.neutralCount ?? 0
                    newShare.checkinCount = share.checkinCount ?? 0
                    newShare.commentCount = share.commentCount ?? 0
                    newShare.fadeScore = share.fadeScore ?? 0
                    if let voteType = share.currentUserVoteType {
                        newShare.currentUserVoteType = voteType
                    }
                    context.insert(newShare)
//                    print("插入新的分享，ID: \(share.id)")
                    // 解析并存储该分享的媒体文件
                    await saveMediaFiles(for: newShare)
                }
            }
        }
        // 保存上下文，提交更改到数据库
        do {
            try context.save()
            print("成功保存上下文")
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    // 更新已有分享的数据
    func updateShare(_ share: Share, with responsedShare: ResponsedShare) {
        // 更新分享的各个属性
        // 使用 TimeKit 统一处理时间（后端已统一 UTC）
        share.createDate = ServerTime.parse(milliseconds: responsedShare.createDate)
        share.data = responsedShare.data
        share.longitude = responsedShare.longitude
        share.latitude = responsedShare.latitude
        share.provinceCode = responsedShare.provinceCode?.stringValue
        share.cityCode = responsedShare.cityCode?.stringValue
        share.districtCode = responsedShare.districtCode?.stringValue
        share.address = responsedShare.address
        share.imagePaths = responsedShare.imagePath.components(separatedBy: ",").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        share.title = responsedShare.title
        share.deleted = responsedShare.deleted == 1

        // ✅ 新增：同步互动统计字段
        share.agreeCount = responsedShare.agreeCount ?? 0
        share.neutralCount = responsedShare.neutralCount ?? 0
        share.checkinCount = responsedShare.checkinCount ?? 0
        share.commentCount = responsedShare.commentCount ?? 0

        // ✅ 新增：同步褪色度字段
        share.fadeScore = responsedShare.fadeScore ?? 0

        // ✅ 关键修复：只在后端返回非 nil 时更新 currentUserVoteType
        // 避免后端不返回该字段时，用 nil 覆盖本地已保存的状态
        if let voteType = responsedShare.currentUserVoteType {
            share.currentUserVoteType = voteType
            #if DEBUG
            print("🔄 [SearchViewModel] 从后端更新 currentUserVoteType: \(voteType)")
            #endif
        } else {
            #if DEBUG
            print("⚠️ [SearchViewModel] 后端未返回 currentUserVoteType，保持本地值: \(share.currentUserVoteType?.description ?? "nil")")
            #endif
        }

        #if DEBUG
        print("🔄 [SearchViewModel] updateShare - 同步互动数据:")
        print("   - shareId: \(share.id)")
        print("   - agreeCount: \(share.agreeCount)")
        print("   - currentUserVoteType (最终): \(share.currentUserVoteType?.description ?? "nil")")
        #endif

        // 异步更新媒体文件
        Task {
            await updateMediaFiles(for: share)
        }
    }
    
    // 更新分享的媒体文件
    func updateMediaFiles(for share: Share) async {
        // 安全检查：确保 context 已初始化
        guard context != nil else {
            print("⚠️ SearchViewModel.updateMediaFiles: context 为 nil，跳过")
            return
        }
        // 获取现有的媒体文件
        let shareId = share.id
        let fetchDescriptor = FetchDescriptor<MediaFile>(
            predicate: #Predicate { $0.shareId == shareId },
            sortBy: []
        )
        let existingMediaFiles = (try? context.fetch(fetchDescriptor)) ?? []
        // 解析新的媒体路径
        let newMediaPathsSet = Set(share.imagePaths)
        // 现有的媒体文件路径
        let existingMediaPathsSet = Set(existingMediaFiles.map { $0.fullPath })
        // 找出需要添加和删除的媒体文件
        let mediaPathsToAdd = newMediaPathsSet.subtracting(existingMediaPathsSet)
        let mediaFilesToDelete = existingMediaFiles.filter { !newMediaPathsSet.contains($0.fullPath) }
        // 删除已不存在的媒体文件
        for mediaFile in mediaFilesToDelete { context.delete(mediaFile) }
        // 添加新的媒体文件
        for path in mediaPathsToAdd {
            if !path.trimmingCharacters(in: .whitespaces).isEmpty {
                if let mediaFile = parseMediaFile(from: path, shareId: share.id) {
                    context.insert(mediaFile)
                } else {
                    print("无法解析媒体文件路径：'\(path)'")
                }
            }
        }
        // 保存上下文
        do {
            try context.save()
//            print("成功更新媒体文件") // 更新媒体文件日志
        } catch {
            print("更新媒体文件时发生错误：\(error)")
        }
    }
    
    //解析并存储媒体文件
    func saveMediaFiles(for share: Share) async {
        // 安全检查：确保 context 已初始化
        guard context != nil else {
            print("⚠️ SearchViewModel.saveMediaFiles: context 为 nil，跳过")
            return
        }
        let mediaPaths = share.imagePaths
        var mediaFilesDict: [String: (photo: MediaFile?, video: MediaFile?, thumbnail: MediaFile?)] = [:]

        for path in mediaPaths {
            guard !path.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            guard let mediaFile = parseMediaFile(from: path, shareId: share.id) else {
                print("无法解析媒体文件路径：'\(path)'")
                continue
            }
            let prefix = mediaFile.prefix
            // 检查数据库中是否已存在该媒体文件
            let fullPath = mediaFile.fullPath
            let fetchDescriptor = FetchDescriptor<MediaFile>(
                predicate: #Predicate { $0.fullPath == fullPath },
                sortBy: []
            )
            if let existingMedia = try? context.fetch(fetchDescriptor).first {
                // 已存在，跳过或更新
                continue
            } else {
                // 新的媒体文件，暂时存储在字典中
                if mediaFilesDict[prefix] != nil {
                    switch mediaFile.type {
                    case .photo:
                        mediaFilesDict[prefix]?.photo = mediaFile
                    case .video, .livePhoto:
                        mediaFilesDict[prefix]?.video = mediaFile
                    case .thumbnail:
                        mediaFilesDict[prefix]?.thumbnail = mediaFile
                    default:
                        break
                    }
                } else {
                    mediaFilesDict[prefix] = (photo: nil, video: nil, thumbnail: nil)
                    switch mediaFile.type {
                    case .photo:
                        mediaFilesDict[prefix]?.photo = mediaFile
                    case .video, .livePhoto:
                        mediaFilesDict[prefix]?.video = mediaFile
                    case .thumbnail:
                        mediaFilesDict[prefix]?.thumbnail = mediaFile
                    default:
                        break
                    }
                }
            }
            do {
                try context.save()
                print("成功保存媒体文件，数量：\(mediaFilesDict.count)")
            } catch {
                print("保存媒体文件时发生错误：\(error)")
            }
        }

        // 将关联的媒体文件保存到数据库
        for (_, mediaTriple) in mediaFilesDict {
            if let thumbnailMedia = mediaTriple.thumbnail {
                // 存在服务器提供的缩略图（新逻辑）
                context.insert(thumbnailMedia)
            } else {
                // 不存在缩略图（旧逻辑），从第一张媒体生成缩略图
                if let photoMedia = mediaTriple.photo {
                    if let generatedThumbnail = await generateThumbnailMediaFile(from: photoMedia) {
                        context.insert(generatedThumbnail)
                    }
                } else if let videoMedia = mediaTriple.video {
                    if let generatedThumbnail = await generateThumbnailMediaFile(from: videoMedia) {
                        context.insert(generatedThumbnail)
                    }
                }
            }
            // 插入其他媒体文件
            if let photoMedia = mediaTriple.photo {
                context.insert(photoMedia)
            }
            if let videoMedia = mediaTriple.video {
                context.insert(videoMedia)
            }
        }
        // 保存上下文
        do {
            try context.save()
            print("成功保存媒体文件")
        } catch {
            print("保存媒体文件时发生错误：\(error)")
        }
    }
    
    // 生成缩略图的媒体文件
    func generateThumbnailMediaFile(from mediaFile: MediaFile) async -> MediaFile? {
        // 下载媒体文件（如果尚未下载）
        if mediaFile.localURL == nil {
            do {
                let (data, _) = try await URLSession.shared.data(from: mediaFile.url!)
                // 保存到本地
                guard let localURL = getLocalURL(for: mediaFile) else {
                    print("无法获取本地存储路径")
                    return nil
                }
                try data.write(to: localURL)
                mediaFile.localURL = localURL
                mediaFile.fileSize = Int64(data.count)
                try context.save()
            } catch {
                print("下载媒体文件时发生错误：\(error)")
                return nil
            }
        }
        guard let localURL = mediaFile.localURL else {
            return nil
        }
        // 生成缩略图
        var thumbnailImage: UIImage?
        switch mediaFile.type {
        case .photo, .livePhoto:
            if let imageData = try? Data(contentsOf: localURL),
               let image = UIImage(data: imageData) {
                thumbnailImage = image
            }
        case .video:
            let asset = AVAsset(url: localURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 1, preferredTimescale: 60)
            do {
                let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                thumbnailImage = UIImage(cgImage: imageRef)
            } catch {
                print("从视频生成缩略图失败：\(error)")
                return nil
            }
        default:
            return nil
        }
        guard let thumbnailImage = thumbnailImage else {
            return nil
        }
        // 保存缩略图到本地文件
        guard let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.5) else {
            return nil
        }
        // 生成缩略图的本地文件 URL
        let thumbnailFileName = "\(mediaFile.prefix)_thumbnail.jpg"
        guard let thumbnailLocalURL = getLocalThumbnailURL(for: thumbnailFileName) else {
            print("无法获取缩略图存储路径")
            return nil
        }

        do {
            try thumbnailData.write(to: thumbnailLocalURL)
        } catch {
            print("保存缩略图时发生错误：\(error)")
            return nil
        }
        // 创建缩略图的 MediaFile 实例
        let thumbnailMediaFile = MediaFile(
            shareId: mediaFile.shareId,
            type: .thumbnail,
            timestamp: mediaFile.timestamp,
            fileExtension: "jpg",
            fullPath: thumbnailLocalURL.path,
            url: nil,  // 本地生成的缩略图没有服务器 URL
            prefix: mediaFile.prefix
        )
        thumbnailMediaFile.localURL = thumbnailLocalURL

        return thumbnailMediaFile
    }

    // 获取本地缩略图的存储路径
    func getLocalThumbnailURL(for fileName: String) -> URL? {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let thumbnailDirectory = cachesDirectory.appendingPathComponent("Thumbnails")
        if !FileManager.default.fileExists(atPath: thumbnailDirectory.path) {
            try? FileManager.default.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        return thumbnailDirectory.appendingPathComponent(fileName)
    }
    
    // 解析单个媒体文件的路径，生成 MediaFile 实例
    func parseMediaFile(from path: String, shareId: Int64) -> MediaFile? {
        let baseURL = "https://onettoo.com/"
        let fullPath = baseURL + path
        guard let encodedUrlString = fullPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedUrlString) else {
            print("无法生成有效的 URL，fullPath: \(fullPath)")
            return nil
        }
//        print("生成的图片 URL: \(url.absoluteString)")
        let fileName = (path as NSString).lastPathComponent
        // 尝试解析第一种格式：-1_1725872756089_24297_video-20240909090557844.mov
        var components = fileName.components(separatedBy: "_")
        if components.count >= 4 {
                let prefix = components[0...2].joined(separator: "_") // 提取前缀
                let typeAndTimestamp = components[3]
                let typeTimestampComponents = typeAndTimestamp.components(separatedBy: "-")
                guard typeTimestampComponents.count >= 2 else {
                    print("无法解析媒体文件：格式不符 (缺少 -): \(typeAndTimestamp)")
                    return nil
                }
                let typeString = typeTimestampComponents[0]
                
                // 时间戳通常是第二部分
                let timestampPart = typeTimestampComponents[1]
                let timestampString = timestampPart.components(separatedBy: ".").first ?? ""
                
                // 使用 NSString 方法提取扩展名，更加可靠
                let fileExtension = (fileName as NSString).pathExtension
                guard !fileExtension.isEmpty else {
                    print("无法解析媒体文件：无法提取扩展名: \(fileName)")
                    return nil
                }

                guard let timestamp = Double(timestampString) else {
                    print("无法解析媒体文件：无效的时间戳: \(timestampString)")
                    return nil
                }

                let mediaType: MediaType
                switch typeString.lowercased() {
                case "photo":
                    mediaType = .photo
                case "video":
                    mediaType = .video
                case "livephoto":
                    mediaType = .livePhoto
                case "thumbnail":
                    mediaType = .thumbnail
                default:
                    print("无法解析媒体文件：未知类型: \(typeString)")
                    return nil
                }

                return MediaFile(
                    shareId: shareId,
                    type: mediaType,
                    timestamp: Date(timeIntervalSince1970: timestamp / 1000),
                    fileExtension: fileExtension,
                    fullPath: fullPath,
                    url: url,
                    prefix: prefix
                )
        } else {
            // 尝试解析第二种格式：image-20240904080557516.jpg
            components = fileName.components(separatedBy: "-")
            if components.count == 2 {
                let prefix = components[0]  // 提取前缀
                let timestampAndExtension = components[1].components(separatedBy: ".")
                guard timestampAndExtension.count == 2 else {
                    print("无法解析媒体文件(格式2)：扩展名格式不符: \(fileName)")
                    return nil
                }
                let timestampString = timestampAndExtension[0]
                let fileExtension = timestampAndExtension[1]
                guard let timestamp = Double(timestampString) else {
                    print("无法解析媒体文件(格式2)：无效的时间戳: \(timestampString)")
                    return nil
                }

                let mediaType: MediaType
                switch fileExtension.lowercased() {
                case "jpg", "jpeg", "png", "heic", "heif":
                    mediaType = .photo
                case "mov", "mp4":
                    mediaType = .video
                default:
                    print("无法解析媒体文件(格式2)：未知扩展名: \(fileExtension)")
                    return nil
                }

                return MediaFile(
                    shareId: shareId,
                    type: mediaType,
                    timestamp: Date(timeIntervalSince1970: timestamp / 1000),
                    fileExtension: fileExtension,
                    fullPath: fullPath,
                    url: url,
                    prefix: prefix  // 添加前缀属性
                )
            } else {
                // 无法解析的文件名格式
                print("⚠️ 无法解析媒体文件：文件名格式不匹配任何已知模式")
                print("   - 原始路径: '\(path)'")
                print("   - 文件名: '\(fileName)'")
                print("   - 按 '-' 分割后组件数: \(components.count) (期望: 2)")
                return nil
            }
        }
    }
    
    // 实现清理机制，清理过多的分享记录  **暂未设定使用
    func cleanUpSharesIfNeeded() {
        let fetchDescriptor = FetchDescriptor<Share>(
            sortBy: [SortDescriptor(\Share.createDate, order: .forward)]
        )
        let shares = try? context.fetch(fetchDescriptor)

        if let shares = shares, shares.count > 1000 {
            let sharesToDelete = shares.prefix(shares.count - 1000)
            for share in sharesToDelete {
                context.delete(share)
            }
            try? context.save()
        }
    }

    // 实现清理机制，清理过多的媒体文件，控制存储空间  **暂未设定使用
    func cleanUpMediaFilesIfNeeded() {
        // 计算媒体文件总大小
        let fetchDescriptor = FetchDescriptor<MediaFile>()
        let mediaFiles = try? context.fetch(fetchDescriptor)
        var totalSize: Int64 = 0

        for mediaFile in mediaFiles ?? [] {
            if let fileURL = mediaFile.localURL,
               let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        if totalSize > 500 * 1024 * 1024 { // 500MB
            // 清理较早的媒体文件
            let sortedMediaFiles = (mediaFiles ?? []).sorted { $0.timestamp < $1.timestamp }
            for mediaFile in sortedMediaFiles {
                // 删除本地文件
                if let fileURL = mediaFile.localURL {
                    try? FileManager.default.removeItem(at: fileURL)
                }
                // 删除数据库记录
                context.delete(mediaFile)
                totalSize -= mediaFile.fileSize ?? 0
                if totalSize <= 500 * 1024 * 1024 {
                    break
                }
            }
            try? context.save()
        }
    }
    
    // 数据更新，更新本地的分享数据 **暂未设定使用
    func updateLocalShares(with newShares: [ResponsedShare]) async {
        // 获取本地所有分享的 ID
        let fetchDescriptor = FetchDescriptor<Share>(sortBy: [])
        let localShares = try? context.fetch(fetchDescriptor)
        let localShareIDs = Set(localShares?.map { $0.id } ?? [])
        let newShareIDs = Set(newShares.map { Int64($0.id) })
        // 找出需要删除的分享
        let sharesToDeleteIDs = localShareIDs.subtracting(newShareIDs)
        for shareID in sharesToDeleteIDs {
            if let share = localShares?.first(where: { $0.id == shareID }) {
                context.delete(share)
            }
        }
        // 更新或添加新的分享
        for shareData in newShares {
            if let existingShare = localShares?.first(where: { $0.id == Int64(shareData.id) }) {
                // 更新已有分享
                updateShare(existingShare, with: shareData)
            } else {
                // 添加新分享
                // 使用 TimeKit 统一处理时间（后端已统一 UTC）
                let newShare = Share(
                    id: Int64(shareData.id),
                    createDate: ServerTime.parse(milliseconds: shareData.createDate),
                    userId: Int64(shareData.userId),
                    data: shareData.data,
                    longitude: shareData.longitude,
                    latitude: shareData.latitude,
                    provinceCode: shareData.provinceCode?.stringValue,
                    cityCode: shareData.cityCode?.stringValue,
                    districtCode: shareData.districtCode?.stringValue,
                    address: shareData.address,
                    imagePaths: shareData.imagePath.components(separatedBy: ","),
                    title: shareData.title,
                    deleted: shareData.deleted == 1
                )
                context.insert(newShare)
                await saveMediaFiles(for: newShare)
            }
        }
        // 保存上下文
        try? context.save()
    }
    
    //获取地图显示区域对应的分享标注
    func getSharesInRegion(_ region: MKCoordinateRegion) -> [Share] {
        // 安全检查：确保 context 已初始化
        guard context != nil else {
            print("⚠️ SearchViewModel.getSharesInRegion: context 为 nil，跳过")
            return []
        }
        // 获取 GCJ-02 坐标系的区域边界
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        // 定义区域的四个角的坐标
        let topLeftGCJ = CLLocationCoordinate2D(latitude: maxLat, longitude: minLon)
        let topRightGCJ = CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon)
        let bottomLeftGCJ = CLLocationCoordinate2D(latitude: minLat, longitude: minLon)
        let bottomRightGCJ = CLLocationCoordinate2D(latitude: minLat, longitude: maxLon)
        // 将 GCJ-02 坐标转换为 WGS-84 坐标
        let topLeftWGS = CoordinateConverter.shared.gcj02ToWgs84(topLeftGCJ)
        let topRightWGS = CoordinateConverter.shared.gcj02ToWgs84(topRightGCJ)
        let bottomLeftWGS = CoordinateConverter.shared.gcj02ToWgs84(bottomLeftGCJ)
        let bottomRightWGS = CoordinateConverter.shared.gcj02ToWgs84(bottomRightGCJ)
        // 获取所有转换后的纬度和经度
        let latitudesWGS = [topLeftWGS.latitude, topRightWGS.latitude, bottomLeftWGS.latitude, bottomRightWGS.latitude]
        let longitudesWGS = [topLeftWGS.longitude, topRightWGS.longitude, bottomLeftWGS.longitude, bottomRightWGS.longitude]
        // 计算最小和最大纬度、经度
        let minLatWGS = latitudesWGS.min() ?? -90
        let maxLatWGS = latitudesWGS.max() ?? 90
        let minLonWGS = longitudesWGS.min() ?? -180
        let maxLonWGS = longitudesWGS.max() ?? 180
        // 创建 FetchDescriptor，添加对 deleted 字段的过滤
        let fetchDescriptor = FetchDescriptor<Share>(
            predicate: #Predicate {
                $0.latitude >= minLatWGS && $0.latitude <= maxLatWGS &&
                $0.longitude >= minLonWGS && $0.longitude <= maxLonWGS &&
                $0.deleted == false  // 只获取未被删除的分享
            },
            sortBy: []
        )
        // 执行 Fetch
        let sharesInRegion = try? context.fetch(fetchDescriptor)
        print("从数据库中检索到的分享数量: \(sharesInRegion?.count ?? 0)")
        return sharesInRegion ?? []
    }
    
    //在地图上显示标注
    func getAnnotations() {
        // 注意：不要使用 removeAll()！
        // 直接构建新数组后赋值，避免触发两次 SwiftUI 更新，保护聚合状态

        // 获取当前地图区域
        let currentRegion = self.region
        // 获取可视区域内的分享
        var sharesInRegion = getSharesInRegion(currentRegion)
        print("Number of shares in region: \(sharesInRegion.count)")

        // 对 sharesInRegion 进行排序
        sortShares(&sharesInRegion)
        var newAnnotations: [CustomAnnotation] = []

        // 【关键修改】判断用户当前位置是否在中国，决定坐标转换策略
        // 目的：让标注坐标系与 MapKit 底图坐标系保持一致，避免跨境查看时的偏移
        let userInChina: Bool
        if let userLocation = locationManager?.currentLocation {
            // 如果用户位置可用，判断用户是否在中国
            userInChina = !CoordinateConverter.shared.isOutOfChina(userLocation)
        } else {
            // 如果用户位置不可用，使用地图中心点判断
            // 这样当用户浏览地图时，坐标系会根据地图中心动态切换
            let mapCenter = CLLocationCoordinate2D(
                latitude: currentRegion.center.latitude,
                longitude: currentRegion.center.longitude
            )
            userInChina = !CoordinateConverter.shared.isOutOfChina(mapCenter)
        }

        for share in sharesInRegion {
            // SSOT：取 max(cached, local) 确保不低估褪色度
            // fadeScore 单调递增，取 max 更保守，>=100 的隐藏更可靠
            let cachedFadeScore = cachedResponsedShares[Int(share.id)]?.fadeScore ?? 0
            let effectiveFadeScore = max(cachedFadeScore, share.fadeScore)

            // 跳过已完全褪色的分享（Home Map 不可见）
            guard effectiveFadeScore < 100 else { continue }

            let wgsCoordinate = CLLocationCoordinate2D(latitude: share.latitude, longitude: share.longitude)
            var displayCoordinate = wgsCoordinate

            // 【新逻辑】根据用户所在位置决定是否转换坐标
            // - 用户在中国：所有坐标转换为 GCJ-02（匹配高德地图底图）
            // - 用户在境外：所有坐标保持 WGS-84（匹配 Apple Maps 底图）
            if userInChina {
                // 用户在中国，转换所有坐标为 GCJ-02
                displayCoordinate = CoordinateConverter.shared.wgs84ToGcj02(wgsCoordinate)
            } else {
                // 用户在境外，保持所有坐标为 WGS-84
                displayCoordinate = wgsCoordinate
            }

            let thumbnailURL = getThumbnailURL(for: share)
            let annotation = CustomAnnotation(
                id: "\(share.id)",
                coordinate: displayCoordinate,
                title: share.title,
                subtitle: share.address,
                imageUrl: thumbnailURL,
                annotationData: share,
                annotationType: .nearbyShare
            )
            newAnnotations.append(annotation)
            print("Added annotation for share ID: \(share.id) at coordinates: (\(share.latitude), \(share.longitude))")
        }
        annotations = newAnnotations
    }
    
    
    private func sortShares(_ shares: inout [Share]) {
        switch annotationSortOption {
        case .createDateDescending:
            shares.sort { $0.createDate > $1.createDate }
        case .createDateAscending:
            shares.sort { $0.createDate < $1.createDate }
//        case .likesDescending:
//            shares.sort { ($0.likes ?? 0) > ($1.likes ?? 0) }  // 假设将来有 likes 属性
        case .custom(let comparison):
            shares.sort(by: comparison)
        }
    }
    
    //获取分享的缩略图 URL
    func getThumbnailURL(for share: Share) -> URL? {
        // 安全检查：确保 context 已初始化
        guard context != nil else {
            print("⚠️ SearchViewModel.getThumbnailURL: context 为 nil")
            return nil
        }
        let shareId = share.id
        let thumbnailTypeString = MediaType.thumbnail.rawValue
        // 首先查找缩略图媒体文件
        let thumbnailFetchDescriptor = FetchDescriptor<MediaFile>(
            predicate: #Predicate { mediaFile in
                mediaFile.shareId == shareId &&
                mediaFile.typeString == thumbnailTypeString
            },
            sortBy: [SortDescriptor(\MediaFile.timestamp, order: .forward)]
        )
        if let thumbnailMediaFile = try? context.fetch(thumbnailFetchDescriptor).first {
            if let localURL = thumbnailMediaFile.localURL {
                // 检查本地文件是否真实存在（iOS 可能已清理 Caches 目录）
                if FileManager.default.fileExists(atPath: localURL.path) {
//                    print("找到分享 ID \(shareId) 的本地缩略图")
                    return localURL
                } else {
                    // 文件不存在，清除 localURL 并使用远程 URL
                    print("⚠️ 缩略图缓存已失效，使用远程 URL: shareId=\(shareId)")
                    thumbnailMediaFile.localURL = nil
                    if let url = thumbnailMediaFile.url {
                        return url
                    }
                }
            } else if let url = thumbnailMediaFile.url {
//                print("找到分享 ID \(shareId) 的远程缩略图 URL")
                return url
            } else {
//                print("缩略图媒体文件没有 URL，分享 ID \(shareId)")
            }
        }
        // 如果没有缩略图，使用第一张照片或 Live Photo
        let photoTypeString = MediaType.photo.rawValue
        let livePhotoTypeString = MediaType.livePhoto.rawValue

        let photoFetchDescriptor = FetchDescriptor<MediaFile>(
            predicate: #Predicate { mediaFile in
                mediaFile.shareId == shareId &&
                (mediaFile.typeString == photoTypeString || mediaFile.typeString == livePhotoTypeString)
            },
            sortBy: [SortDescriptor(\MediaFile.timestamp, order: .forward)]
        )

        if let firstPhotoMediaFile = try? context.fetch(photoFetchDescriptor).first {
            if let localURL = firstPhotoMediaFile.localURL {
                // 检查本地文件是否真实存在（iOS 可能已清理 Caches 目录）
                if FileManager.default.fileExists(atPath: localURL.path) {
                    print("使用分享 ID \(shareId) 的第一张照片的本地 URL")
                    return localURL
                } else {
                    // 文件不存在，清除 localURL 并使用远程 URL
                    print("⚠️ 照片缓存已失效，使用远程 URL: shareId=\(shareId)")
                    firstPhotoMediaFile.localURL = nil
                    if let url = firstPhotoMediaFile.url {
                        return url
                    }
                }
            } else if let url = firstPhotoMediaFile.url {
                print("使用分享 ID \(shareId) 的第一张照片的远程 URL")
                return url
            } else {
                print("第一张照片媒体文件没有 URL，分享 ID \(shareId)")
            }
        }
        // 如果没有照片或 Live Photo，返回 nil
        print("未找到分享 ID \(shareId) 的缩略图或照片")
        return nil
    }
    
    
    
    
    // MARK: - Functions - 分享标注详情页
    
    // 选择一个标注（分享），显示其详情
    func selectAnnotation(_ annotation: CustomAnnotation, thumbnailImage: UIImage?) {
        self.selectedAnnotation = annotation
        self.selectedAnnotationID = annotation.id
        self.selectedAnnotationImage = thumbnailImage  // 设置为缩略图
        // 加载分享的所有媒体文件
        if let shareId = Int64(annotation.id) {
            print("选中的分享 ID：\(shareId)")
            loadShareDetail(for: shareId)
        } else {
            print("无法将 annotation.id 转换为 Int64：\(annotation.id)")
        }
    }
    
    // 在点击标注后，加载缩略图的源文件（原始图片或视频）
    func loadSourceImage(for shareId: Int64) {
        // 安全检查：确保 context 已初始化
        guard context != nil else {
            print("⚠️ SearchViewModel.loadSourceImage: context 为 nil，跳过")
            return
        }
        // 获取源文件的媒体类型
        let photoTypeString = MediaType.photo.rawValue
        let livePhotoTypeString = MediaType.livePhoto.rawValue

        let mediaFetchDescriptor = FetchDescriptor<MediaFile>(
            predicate: #Predicate { mediaFile in
                mediaFile.shareId == shareId &&
                (mediaFile.typeString == photoTypeString || mediaFile.typeString == livePhotoTypeString)
            },
            sortBy: [SortDescriptor(\MediaFile.timestamp, order: .forward)]
        )
        Task {
            if let mediaFile = try? context.fetch(mediaFetchDescriptor).first {
                if let localURL = mediaFile.localURL {
                    if let imageData = try? Data(contentsOf: localURL),
                       let image = UIImage(data: imageData) {
                        // 更新为源文件图片
                        DispatchQueue.main.async {
                            self.selectedAnnotationImage = image
                        }
                    }
                } else if let url = mediaFile.url {
                    // 下载源文件
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        // 保存到本地
                        guard let localURL = getLocalURL(for: mediaFile) else {
                            print("无法获取本地存储路径")
                            return
                        }
                        try data.write(to: localURL)
                        // 更新数据库
                        mediaFile.localURL = localURL
                        mediaFile.fileSize = Int64(data.count)
                        try context.save()
                        if let image = UIImage(data: data) {
                            // 更新为源文件图片
                            DispatchQueue.main.async {
                                self.selectedAnnotationImage = image
                            }
                        }
                    } catch {
                        print("加载源文件时发生错误：\(error)")
                    }
                }
            } else {
                print("未找到分享 ID \(shareId) 的媒体文件")
            }
        }
    }
    
    //加载分享详情
    func loadShareDetail(for shareId: Int64) {
        if PreviewHarness.enabled {
            print("🔌 [PreviewHarness] ShareDetail mocked for shareId: \(shareId)")
            let mockShare = Share(
                id: shareId,
                createDate: Date(),
                userId: 11,
                data: "这是一个测试分享，用于预览页面布局和样式效果",
                longitude: 121.60,
                latitude: 31.20,
                provinceCode: "310000",
                cityCode: "310100",
                districtCode: "310115",
                address: "上海市 浦东新区 张江高科技园区",
                imagePaths: [],
                title: "测试分享",
                deleted: false
            )
            let wrapper = MediaItemWrapper(nil)
            wrapper.mediaItem = Photo(data: Data(), isProxy: true, livePhotoMovieURL: nil)

            DispatchQueue.main.async {
                self.selectedShare = mockShare
                self.downloadMedia = [wrapper]
            }
            return
        }

        // 尝试加载本地数据
        let hasLocalData = loadFromLocal(shareId: shareId)
        
        if currentLoadingShareId == shareId && !hasLocalData {
            #if DEBUG
            print("⏭️ 分享 \(shareId) 正在加载中，跳过重复请求")
            #endif
            return
        }

        // 如果没有本地数据，标记为加载中（显示 Loading）
        if !hasLocalData {
            currentLoadingShareId = shareId
        }
        print("加载分享详情，分享 ID：\(shareId) (hasLocalData: \(hasLocalData))")
        
        // 无论本地有没有数据，都从服务器拉取最新详情
        fetchShareDetailFromServer(shareId: shareId, isBackground: hasLocalData)
    }
    
    // 新增：从本地数据库加载数据并更新 UI
    private func loadFromLocal(shareId: Int64) -> Bool {
        // 安全检查：确保 context 已初始化
        guard context != nil else {
            print("⚠️ SearchViewModel.loadFromLocal: context 为 nil")
            return false
        }
        let fetchDescriptor = FetchDescriptor<Share>(
            predicate: #Predicate { $0.id == shareId },
            sortBy: []
        )
        guard let share = try? context.fetch(fetchDescriptor).first else {
            return false
        }
        
        // 检查分享是否已被删除
        if share.deleted {
            // 分享已被删除，显示提示
            self.shareDeletedMessage = "这条观之已被删除，看看其他的吧～"
            
            // 从本地删除该分享
            self.deleteShare(shareId: shareId)
            
            // 从地图标注列表中移除
            if let index = self.annotations.firstIndex(where: { $0.id == "\(shareId)" }) {
                self.annotations.remove(at: index)
            }
            
            // 清除加载状态
            currentLoadingShareId = nil
            return true // 视为已处理
        }
        
        self.selectedShare = share
        self.selectedAnnotation = annotations.first { $0.id == "\(shareId)" }

        #if DEBUG
        print("📂 [loadFromLocal] 加载分享 \(shareId)")
        print("   - imagePaths: \(share.imagePaths)")
        #endif

        // 获取媒体文件
        let mediaFetchDescriptor = FetchDescriptor<MediaFile>(
            predicate: #Predicate { $0.shareId == shareId },
            sortBy: [SortDescriptor(\MediaFile.timestamp, order: .forward)]
        )

        if let mediaFiles = try? context.fetch(mediaFetchDescriptor) {
            #if DEBUG
            print("   - 数据库中找到 \(mediaFiles.count) 个 MediaFile 记录")
            for mf in mediaFiles {
                print("     • type=\(mf.type), prefix=\(mf.prefix), fullPath=\(mf.fullPath)")
            }
            #endif

            // 解析媒体文件，创建 MediaItemWrapper 数组
            let mediaItems = parseMediaFiles(mediaFiles)

            #if DEBUG
            print("   - 解析后得到 \(mediaItems.count) 个 MediaItemWrapper")
            if mediaItems.isEmpty && !share.imagePaths.isEmpty {
                print("   ⚠️ 警告：imagePaths 非空但 MediaItemWrapper 为空，可能是解析问题！")
            }
            #endif

            // 更新 self.downloadMedia
            DispatchQueue.main.async {
                self.downloadMedia = mediaItems
            }

            // 下载媒体文件并更新对应的 MediaItemWrapper
            downloadMediaFiles(mediaItems: mediaItems)
            return true
        }

        #if DEBUG
        print("   - ⚠️ 无法从数据库获取 MediaFile 记录")
        #endif

        return true
    }
    
    //从服务器获取分享详情（带重试机制）
    func fetchShareDetailFromServer(shareId: Int64, isBackground: Bool = false) {
        // 取消旧任务
        currentDetailTask?.cancel()

        currentDetailTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            let key = RetryCoordinator.key(for: .shareDetail(id: shareId))

            // 原子操作：检查并标记开始
            guard await RetryCoordinator.shared.beginIfAllowed(
                key: key,
                bypassCooldown: false
            ) else { return }

            // P0 修复：使用 Task.detached 避免取消传播
            defer {
                Task.detached { await RetryCoordinator.shared.finish(key: key) }
            }

            // 保存前置状态
            let prevState = self.shareDetailState
            if !isBackground {
                self.shareDetailState = .loading
            }

            do {
                let detail = try await ShareService.shared.fetchShareDetail(shareId: shareId)

                // 取消时恢复状态
                if Task.isCancelled {
                    self.shareDetailState = prevState
                    return
                }

                // 检查分享是否已被删除
                if detail.deleted == 1 {
                    // 分享已被删除
                    // 从本地删除该分享
                    self.deleteShare(shareId: shareId)

                    // 从地图标注列表中移除
                    if let index = self.annotations.firstIndex(where: { $0.id == "\(shareId)" }) {
                        self.annotations.remove(at: index)
                    }

                    // 设置标志，通知 UI 显示提示
                    self.shareDeletedMessage = "这条观之已被删除，看看其他的吧～"

                    // 清除加载状态
                    self.currentLoadingShareId = nil
                    self.shareDetailState = .idle
                    return
                }

                // 把这个 detail 做 SwiftData 持久化
                await self.saveSharesToDatabase(shares: [detail])

                // 重新从本地加载（刷新 UI）
                _ = self.loadFromLocal(shareId: shareId)
                if !isBackground {
                    self.currentLoadingShareId = nil
                }

                // 更新状态为成功
                if let share = self.selectedShare {
                    self.shareDetailState = .loaded(share)
                } else {
                    self.shareDetailState = .idle
                }

            } catch {
                // 取消时恢复状态
                if Task.isCancelled {
                    self.shareDetailState = prevState
                    return
                }

                print("❌ [SearchViewModel] 获取分享详情失败: \(error)")

                // 出错时设置错误状态
                if !isBackground {
                    self.currentLoadingShareId = nil
                    self.shareDetailState = .error(error)
                }
            }
        }
    }

    /// 重试获取分享详情
    func retryShareDetail(shareId: Int64) {
        // 清除错误状态
        shareDetailState = .idle
        // 使用 manual 原因绕过 cooldown
        currentDetailTask?.cancel()

        currentDetailTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            let key = RetryCoordinator.key(for: .shareDetail(id: shareId))

            // bypassCooldown = true 因为是手动重试
            guard await RetryCoordinator.shared.beginIfAllowed(
                key: key,
                bypassCooldown: true
            ) else { return }

            defer {
                Task.detached { await RetryCoordinator.shared.finish(key: key) }
            }

            self.shareDetailState = .loading

            do {
                let detail = try await ShareService.shared.fetchShareDetail(shareId: shareId)

                if Task.isCancelled { return }

                if detail.deleted == 1 {
                    self.deleteShare(shareId: shareId)
                    if let index = self.annotations.firstIndex(where: { $0.id == "\(shareId)" }) {
                        self.annotations.remove(at: index)
                    }
                    self.shareDeletedMessage = "这条观之已被删除，看看其他的吧～"
                    self.shareDetailState = .idle
                    return
                }

                await self.saveSharesToDatabase(shares: [detail])
                _ = self.loadFromLocal(shareId: shareId)

                if let share = self.selectedShare {
                    self.shareDetailState = .loaded(share)
                } else {
                    self.shareDetailState = .idle
                }
            } catch {
                if Task.isCancelled { return }
                print("❌ [SearchViewModel] 重试获取分享详情失败: \(error)")
                self.shareDetailState = .error(error)
            }
        }
    }
    
    func downloadMediaFiles(mediaItems: [MediaItemWrapper]) {
        Task {
            for mediaItemWrapper in mediaItems {
                var photoDownloadFailed = false
                var videoDownloadFailed = false

                // 使用 TaskGroup 并发下载
                await withTaskGroup(of: (Bool, Bool).self) { group in
                    // 下载照片文件
                    if let photoFile = mediaItemWrapper.photoFile, photoFile.localURL == nil {
                        group.addTask {
                            do {
                                try await self.downloadMediaFile(mediaFile: photoFile)
                                return (false, false) // photo success
                            } catch {
                                print("❌ 照片下载失败，已加入重试队列: \(error.localizedDescription)")
                                await MainActor.run {
                                    self.failedDownloads.append((mediaFile: photoFile, wrapper: mediaItemWrapper))
                                }
                                return (true, false) // photo failed
                            }
                        }
                    }
                    // 下载视频文件
                    if let videoFile = mediaItemWrapper.videoFile, videoFile.localURL == nil {
                        group.addTask {
                            do {
                                try await self.downloadMediaFile(mediaFile: videoFile)
                                return (false, false) // video success
                            } catch {
                                print("❌ 视频下载失败，已加入重试队列: \(error.localizedDescription)")
                                await MainActor.run {
                                    self.failedDownloads.append((mediaFile: videoFile, wrapper: mediaItemWrapper))
                                }
                                return (false, true) // video failed
                            }
                        }
                    }
                    // 收集结果
                    for await result in group {
                        if result.0 { photoDownloadFailed = true }
                        if result.1 { videoDownloadFailed = true }
                    }
                }

                // 只有在没有失败时才创建媒体项
                if !photoDownloadFailed && !videoDownloadFailed {
                    // 在主线程上创建媒体项并更新 UI
                    await MainActor.run {
                        // 检查 mediaFile 是否还存在（可能已被删除）
                        let isDeleted = (mediaItemWrapper.photoFile?.isDeleted ?? false) ||
                                       (mediaItemWrapper.videoFile?.isDeleted ?? false)
                        guard !isDeleted else {
                            print("媒体文件已被删除，跳过创建媒体项")
                            return
                        }

                        if let mediaItem = createMediaItem(from: mediaItemWrapper) {
                            mediaItemWrapper.mediaItem = mediaItem
                        }
                    }
                }
            }
        }
    }

    //异步加载媒体文件（使用自定义超时配置的 URLSession）
    func downloadMediaFile(mediaFile: MediaFile) async throws {
        guard let url = mediaFile.url else {
            print("媒体文件没有有效的 URL")
            return
        }
        do {
            print("开始下载媒体文件：\(url.absoluteString)")
            // 使用自定义的 URLSession（带超时配置）
            let (data, _) = try await mediaDownloadSession.data(from: url)
            // 保存到本地
            guard let localURL = getLocalURL(for: mediaFile) else {
                print("无法获取本地存储路径")
                return
            }
            try data.write(to: localURL)

            // 检查文件尺寸（仅对图像和视频文件）
            if mediaFile.type == .photo || mediaFile.type == .livePhoto {
                if let image = UIImage(data: data) {
                    print("下载的图像尺寸：\(image.size)")
                }
            } else if mediaFile.type == .video {
                let asset = AVAsset(url: localURL)
                if let track = asset.tracks(withMediaType: .video).first {
                    let t = track.preferredTransform
                    let oriented = track.naturalSize.applying(t)
                    let width = abs(oriented.width)
                    let height = abs(oriented.height)
                    print("下载的视频尺寸：(\(width), \(height))")
                }
            }

            // 在主线程上更新 mediaFile 对象
            await MainActor.run {
                // 安全检查：确保 context 已初始化
                guard self.context != nil else {
                    print("⚠️ SearchViewModel.downloadMediaFile: context 为 nil，跳过保存")
                    return
                }
                // 检查 mediaFile 是否还在 context 中（可能已被删除）
                guard !mediaFile.isDeleted else {
                    print("媒体文件已被删除，跳过保存")
                    return
                }

                mediaFile.localURL = localURL
                mediaFile.fileSize = Int64(data.count)
                // 保存上下文
                do {
                    try self.context.save()
                    print("媒体文件下载并保存成功：\(localURL.path)")
                } catch {
                    print("保存媒体文件到数据库时发生错误：\(error)")
                }
            }
        } catch {
            print("下载媒体文件时发生错误：\(error)")
            throw error
        }
    }

    /// 重新下载损坏的媒体文件并更新 MediaItemWrapper
    /// - Parameters:
    ///   - mediaFile: 需要重新下载的 MediaFile
    ///   - wrapper: 对应的 MediaItemWrapper
    func redownloadMediaFile(mediaFile: MediaFile, wrapper: MediaItemWrapper) async {
        print("🔄 开始重新下载损坏的媒体文件：\(mediaFile.fullPath)")

        do {
            // 重新下载
            try await downloadMediaFile(mediaFile: mediaFile)

            // 如果是视频文件，也检查并重新下载
            if let videoFile = wrapper.videoFile, videoFile.localURL == nil {
                try await downloadMediaFile(mediaFile: videoFile)
            }

            // 在主线程上创建媒体项
            await MainActor.run {
                if let mediaItem = createMediaItem(from: wrapper) {
                    wrapper.mediaItem = mediaItem
                    print("✅ 重新下载成功，媒体项已创建")
                } else {
                    print("❌ 重新下载后仍无法创建媒体项")
                }
            }
        } catch {
            print("❌ 重新下载媒体文件失败：\(error)")
        }
    }

    // 解析媒体文件，创建 MediaItemWrapper 数组
    func parseMediaFiles(_ mediaFiles: [MediaFile]) -> [MediaItemWrapper] {
        // 按照客户端标记分组
        var mediaGroups: [String: [MediaFile]] = [:]
        for mediaFile in mediaFiles {
            let prefix = mediaFile.prefix
            mediaGroups[prefix, default: []].append(mediaFile)
        }
        var mediaItems: [MediaItemWrapper] = []
        // 按照时间戳排序
        let sortedKeys = mediaGroups.keys.sorted { key1, key2 in
            guard let timestamp1 = mediaGroups[key1]?.first?.timestamp,
                  let timestamp2 = mediaGroups[key2]?.first?.timestamp else {
                return false
            }
            return timestamp1 < timestamp2
        }
        for key in sortedKeys {
            if let group = mediaGroups[key] {
                // 判断媒体类型
                let hasPhoto = group.contains { $0.type == .photo }
                let hasThumbnail = group.contains { $0.type == .thumbnail }
                let hasVideo = group.contains { $0.type == .video }
                let hasLivePhotoVideo = group.contains { $0.type == .livePhoto }

                // ✅ 获取 shareId 和 prefix 用于缓存 key
                guard let firstFile = group.first else { continue }
                let shareId = firstFile.shareId
                let prefix = firstFile.prefix
                let cacheKey = "\(shareId)-\(prefix)"

                if hasPhoto && (hasVideo || hasLivePhotoVideo) {
                    // 动态照片（Live Photo）
                    if let photoFile = group.first(where: { $0.type == .photo }),
                       let videoFile = group.first(where: { $0.type == .video || $0.type == .livePhoto }) {

                        // ✅ 尝试从缓存中获取，如果不存在则创建新的
                        let mediaItemWrapper: MediaItemWrapper
                        if let cachedWrapper = mediaItemWrapperCache[cacheKey] {
                            mediaItemWrapper = cachedWrapper
                            #if DEBUG
                            print("♻️ 复用 MediaItemWrapper: \(cacheKey)")
                            #endif
                        } else {
                            mediaItemWrapper = MediaItemWrapper(nil)
                            mediaItemWrapperCache[cacheKey] = mediaItemWrapper
                            #if DEBUG
                            print("🆕 创建新 MediaItemWrapper: \(cacheKey)")
                            #endif
                        }

                        mediaItemWrapper.photoFile = photoFile
                        mediaItemWrapper.videoFile = videoFile
                        mediaItems.append(mediaItemWrapper)
                    }
                } else if hasPhoto {
                    // 静态照片
                    if let photoFile = group.first(where: { $0.type == .photo }) {

                        // ✅ 尝试从缓存中获取，如果不存在则创建新的
                        let mediaItemWrapper: MediaItemWrapper
                        if let cachedWrapper = mediaItemWrapperCache[cacheKey] {
                            mediaItemWrapper = cachedWrapper
                            #if DEBUG
                            print("♻️ 复用 MediaItemWrapper: \(cacheKey)")
                            #endif
                        } else {
                            mediaItemWrapper = MediaItemWrapper(nil)
                            mediaItemWrapperCache[cacheKey] = mediaItemWrapper
                            #if DEBUG
                            print("🆕 创建新 MediaItemWrapper: \(cacheKey)")
                            #endif
                        }

                        mediaItemWrapper.photoFile = photoFile
                        mediaItems.append(mediaItemWrapper)
                    }
                } else if hasVideo && !hasPhoto {
                    // 视频（排除 livePhoto 类型）
                    if let videoFile = group.first(where: { $0.type == .video }) {

                        // ✅ 尝试从缓存中获取，如果不存在则创建新的
                        let mediaItemWrapper: MediaItemWrapper
                        if let cachedWrapper = mediaItemWrapperCache[cacheKey] {
                            mediaItemWrapper = cachedWrapper
                            #if DEBUG
                            print("♻️ 复用 MediaItemWrapper: \(cacheKey)")
                            #endif
                        } else {
                            mediaItemWrapper = MediaItemWrapper(nil)
                            mediaItemWrapperCache[cacheKey] = mediaItemWrapper
                            #if DEBUG
                            print("🆕 创建新 MediaItemWrapper: \(cacheKey)")
                            #endif
                        }

                        mediaItemWrapper.videoFile = videoFile
                        mediaItems.append(mediaItemWrapper)
                    }
                }
                // 忽略没有匹配的 livePhoto 视频文件
            }
        }
        return mediaItems
    }

    // 创建媒体项，返回 MediaItemProtocol
    @MainActor
    func createMediaItem(from mediaItemWrapper: MediaItemWrapper) -> MediaItemProtocol? {
        // 安全检查：确保 context 已初始化（用于可能的 context.save 调用）
        guard context != nil else {
            print("⚠️ SearchViewModel.createMediaItem: context 为 nil，跳过")
            return nil
        }
        if let photoFile = mediaItemWrapper.photoFile, photoFile.type != .thumbnail, let photoLocalURL = photoFile.localURL {
            print("创建媒体项，照片文件已下载，本地 URL：\(photoLocalURL)")

            // ✅ 验证缓存文件是否存在且可读
            guard FileManager.default.fileExists(atPath: photoLocalURL.path) else {
                print("⚠️ 缓存文件不存在，清除 localURL 以触发重新下载：\(photoLocalURL.path)")
                photoFile.localURL = nil
                try? context.save()
                // 触发重新下载
                Task {
                    await redownloadMediaFile(mediaFile: photoFile, wrapper: mediaItemWrapper)
                }
                return nil
            }

            if let imageData = try? Data(contentsOf: photoLocalURL) {
                if let videoFile = mediaItemWrapper.videoFile {
                    if let videoLocalURL = videoFile.localURL {
                        // ✅ 验证视频缓存文件是否存在
                        guard FileManager.default.fileExists(atPath: videoLocalURL.path) else {
                            print("⚠️ LivePhoto 视频缓存文件不存在，清除 localURL 以触发重新下载：\(videoLocalURL.path)")
                            videoFile.localURL = nil
                            try? context.save()
                            Task {
                                await redownloadMediaFile(mediaFile: videoFile, wrapper: mediaItemWrapper)
                            }
                            return nil
                        }

                        print("创建媒体项，视频文件已下载，本地 URL：\(videoLocalURL)")

                        // ✅ 方案切换：根据开关决定创建类型
                        if USE_VIDEO_PLAYBACK {
                            // 方案B：创建 Movie（短视频播放）
                            print("📹 方案B：将 LivePhoto 作为短视频播放")
                            let movie = Movie(url: videoLocalURL)
                            mediaItemWrapper.mediaItem = movie
                            // 同时保存封面图
                            mediaItemWrapper.coverImageData = imageData
                            
                            // ✅ 修复：不要在这里创建 VideoEngine！
                            // VideoEngine 应该只在 ShareDetailView.switchToVideo 中为选中页创建
                            // 这样才能确保永远只有一个 VideoEngine 实例
                            
                            return movie
                        } else {
                            // 方案A：创建 Photo（LivePhoto 播放）
                            print("📸 方案A：使用 PHLivePhotoView 播放")
                            let photo = Photo(data: imageData, isProxy: false, livePhotoMovieURL: videoLocalURL)
                            mediaItemWrapper.mediaItem = photo
                            // 传入本地文件URL，避免重新写入临时文件
                            mediaItemWrapper.generateLivePhoto(localPhotoURL: photoLocalURL)
                            return photo
                        }
                    } else {
                        print("视频文件尚未下载完成，无法创建媒体项")
                        // 视频文件尚未下载完成，暂不创建 MediaItem
                        return nil
                    }
                } else {
                    print("没有视频文件，创建静态照片")
                    // 静态照片
                    let photo = Photo(data: imageData, isProxy: false, livePhotoMovieURL: nil)
                    mediaItemWrapper.mediaItem = photo
                    return photo
                }
            } else {
                print("⚠️ 无法读取照片数据（文件可能损坏），删除并重新下载：\(photoLocalURL)")
                // 删除损坏的缓存文件
                try? FileManager.default.removeItem(at: photoLocalURL)
                photoFile.localURL = nil
                try? context.save()
                // 触发重新下载
                Task {
                    await redownloadMediaFile(mediaFile: photoFile, wrapper: mediaItemWrapper)
                }
            }
        } else if let videoFile = mediaItemWrapper.videoFile, let videoLocalURL = videoFile.localURL {
            print("创建媒体项，视频文件已下载，本地 URL：\(videoLocalURL)")

            // ✅ 验证视频缓存文件是否存在
            guard FileManager.default.fileExists(atPath: videoLocalURL.path) else {
                print("⚠️ 视频缓存文件不存在，清除 localURL 以触发重新下载：\(videoLocalURL.path)")
                videoFile.localURL = nil
                try? context.save()
                Task {
                    await redownloadMediaFile(mediaFile: videoFile, wrapper: mediaItemWrapper)
                }
                return nil
            }

            // 视频
            let movie = Movie(url: videoLocalURL)
            mediaItemWrapper.mediaItem = movie
            return movie
        } else {
            print("无法创建媒体项，照片和视频文件均未下载")
        }
        // 无法创建媒体项，返回 nil
        return nil
    }
    
    //获取媒体文件的本地存储 URL
    func getLocalURL(for mediaFile: MediaFile) -> URL? {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let mediaDirectory = cachesDirectory.appendingPathComponent("MediaFiles")
        if !FileManager.default.fileExists(atPath: mediaDirectory.path) {
            try? FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        let fileName = "\(mediaFile.shareId)_\(mediaFile.timestamp.timeIntervalSince1970).\(mediaFile.fileExtension)"
        return mediaDirectory.appendingPathComponent(fileName)
    }
    
    // 删除分享及其关联的媒体文件
    func deleteShare(shareId: Int64) {
        // 安全检查：确保 context 已初始化
        guard context != nil else {
            print("⚠️ SearchViewModel.deleteShare: context 为 nil，跳过")
            return
        }
        let fetchDescriptor = FetchDescriptor<Share>(
            predicate: #Predicate { $0.id == shareId },
            sortBy: []
        )
        if let share = try? context.fetch(fetchDescriptor).first {
            context.delete(share)
            // 删除关联的媒体文件
            let mediaFetchDescriptor = FetchDescriptor<MediaFile>(
                predicate: #Predicate { $0.shareId == shareId },
                sortBy: []
            )
            let mediaFiles = try? context.fetch(mediaFetchDescriptor)
            for mediaFile in mediaFiles ?? [] {
                if let localURL = mediaFile.localURL {
                    try? FileManager.default.removeItem(at: localURL)
                }
                context.delete(mediaFile)
            }
            try? context.save()

            // ✅ 清理该分享对应的 MediaItemWrapper 缓存
            clearMediaItemWrapperCache(for: shareId)
        }
    }
    
    // 清理下载的媒体数据
    func cleandownloadMedia() {
        self.downloadMedia.removeAll()
        // ✅ 清理所有 MediaItemWrapper 缓存
        mediaItemWrapperCache.removeAll()
        // ✅ 清理失败下载队列
        failedDownloads.removeAll()
        #if DEBUG
        print("🧹 清理所有 MediaItemWrapper 缓存和失败下载队列")
        #endif
    }

    // ✅ 清理指定分享的 MediaItemWrapper 缓存
    private func clearMediaItemWrapperCache(for shareId: Int64) {
        let keysToRemove = mediaItemWrapperCache.keys.filter { $0.hasPrefix("\(shareId)-") }
        for key in keysToRemove {
            mediaItemWrapperCache.removeValue(forKey: key)
            #if DEBUG
            print("🧹 清理 MediaItemWrapper 缓存: \(key)")
            #endif
        }
    }
    
    // 将时间戳转换为实际时间
    // 使用 TimeKit 统一处理时间显示
    func formattedDate(from timestamp: Date) -> String {
        return TimeDisplay.shared.absoluteTime(from: timestamp, style: .medium)
    }
    
}

//不同地点标注排序方式的枚举
enum AnnotationSortOption {
    case createDateDescending  // 按创建时间降序排列（最新的在最顶层）
    case createDateAscending   // 按创建时间升序排列
//    case likesDescending       // 按点赞数量降序排列（未来扩展）
    case custom((Share, Share) -> Bool)  // 自定义排序闭包
}

// 扩展 MKCoordinateRegion，添加包含另一个区域的判断方法
extension MKCoordinateRegion {
    func contains(_ region: MKCoordinateRegion) -> Bool {
        let minLat = center.latitude - span.latitudeDelta / 2
        let maxLat = center.latitude + span.latitudeDelta / 2
        let minLon = center.longitude - span.longitudeDelta / 2
        let maxLon = center.longitude + span.longitudeDelta / 2

        let regionMinLat = region.center.latitude - region.span.latitudeDelta / 2
        let regionMaxLat = region.center.latitude + region.span.latitudeDelta / 2
        let regionMinLon = region.center.longitude - region.span.longitudeDelta / 2
        let regionMaxLon = region.center.longitude + region.span.longitudeDelta / 2

        return regionMinLat >= minLat && regionMaxLat <= maxLat &&
               regionMinLon >= minLon && regionMaxLon <= maxLon
    }
}

//服务器返回的Share模型
struct ResponsedShare: Codable, Equatable {
    let id: Int
    let createDate: Int
    let userId: Int
    let data: String
    let longitude: Double
    let latitude: Double
    let provinceCode: StringOrInt?
    let cityCode: StringOrInt?
    let districtCode: StringOrInt?
    let address: String
    let imagePath: String
    let title: String
    let deleted: Int

    // ✅ 新增：互动统计字段
    let agreeCount: Int?
    let neutralCount: Int?
    let checkinCount: Int?
    let commentCount: Int?
    let currentUserVoteType: Int?  // 当前用户的投票状态 (1=赞同, 0=无感, nil=未投票)

    // ✅ 新增：褪色度字段
    let fadeScore: Int?  // 褪色度 (0-100)
}

//服务器返回的附近Share列表模型
struct ResponsedNearbyShareList: Codable, Equatable {
    var records: [ResponsedShare]
    var total: Int
    let size: Int
    let current: Int
    let orders: [String]
    let optimizeCountSql: Bool
    let searchCount: Bool
    let countId: StringOrInt?
    let maxLimit: Int?
    let pages: Int
    mutating func merge(with newData: ResponsedNearbyShareList) {
        // 创建一个 Set 来存储已有的分享标识符，避免重复
        let existingShareIdentifiers = Set(self.records.compactMap { extractShareIdentifier(from: $0.imagePath) })
        
        // 过滤掉重复的分享
        let newRecords = newData.records.filter {
            guard let shareIdentifier = extractShareIdentifier(from: $0.imagePath) else { return true }
            return !existingShareIdentifiers.contains(shareIdentifier)
        }
        
        self.records.append(contentsOf: newRecords)
        
        // 更新其他属性（如需要）
        self.total += newRecords.count
        // 根据需要更新其他属性，如 size、pages 等
    }
}

/// 提取分享标识符的方法
/// - Parameter imagePath: 包含分享信息的图片路径字符串
/// - Returns: 分享标识符字符串或 `nil` 如果无法提取
func extractShareIdentifier(from imagePath: String) -> String? {
    guard let firstImagePath = imagePath.components(separatedBy: ",").first else { return nil }
    guard let range = firstImagePath.range(of: "image/") else { return nil }
    let pathAfterImage = firstImagePath[range.upperBound...]
    if let underscoreRange = pathAfterImage.range(of: "_", options: .backwards) {
        let shareIdentifier = pathAfterImage[..<underscoreRange.lowerBound]
        return String(shareIdentifier)
    }
    return nil
}

// 用于解析可能为 String 或 Int 的字段
enum StringOrInt: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
            return
        }
        if let int = try? container.decode(Int.self) {
            self = .int(int)
            return
        }
        if let double = try? container.decode(Double.self) {
            self = .double(double)
            return
        }
        throw DecodingError.typeMismatch(StringOrInt.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String, Int, or Double"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str):
            try container.encode(str)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let str):
            return str
        case .int(let int):
            return String(int)
        case .double(let double):
            return String(double)
        }
    }
}

// MARK: - 图片变体枚举（统一 API）

/// 图片变体类型
/// - original: 原图
/// - fadeVeil: 白化效果（fadeScore >= 90 时应用）
enum ImageVariant: Hashable {
    case original                      // 原图
    case fadeVeil(fadeScore: Int)      // 白化效果（内部判断 >= 90 才处理）

    /// 生成缓存 key 后缀
    var cacheKeySuffix: String {
        switch self {
        case .original:
            return ""
        case .fadeVeil(let fadeScore):
            if fadeScore >= FadeVeilProcessor.threshold {
                return "_\(FadeVeilProcessor.version)"  // 带版本号
            }
            return ""  // < 90 等价于原图
        }
    }

    /// 是否需要处理
    var needsProcessing: Bool {
        switch self {
        case .original:
            return false
        case .fadeVeil(let fadeScore):
            return fadeScore >= FadeVeilProcessor.threshold
        }
    }

    /// 提取 fadeScore（用于处理器）
    var fadeScore: Int {
        switch self {
        case .original: return 0
        case .fadeVeil(let score): return score
        }
    }
}

// MARK: - 图片缓存通知

extension Notification.Name {
    /// 图片加载成功通知（userInfo 包含 "url": URL）
    static let imageCacheDidLoadImage = Notification.Name("imageCacheDidLoadImage")
}

// MARK: - 图片缓存类

/// 图片缓存类，使用 NSCache 缓存图片
/// 支持原图和白化效果图片的加载与缓存
class ImageCache {
    static let shared = ImageCache()
    private init() {
        cache.countLimit = 100 // 设置最大缓存大小
    }

    private let cache = NSCache<NSString, UIImage>()

    // 并发去重：记录正在处理的请求
    private var inFlightRequests: [String: [(UIImage?) -> Void]] = [:]
    private let lock = NSLock()

    // 记录已通知的 URL（避免重复通知）
    private var notifiedUrls: Set<String> = []
    private let notifiedUrlsLock = NSLock()

    // MARK: - 基础方法

    func image(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    // MARK: - 统一图片加载 API

    /// 加载图片（统一 API）
    /// - Parameters:
    ///   - url: 图片 URL
    ///   - variant: 图片变体（原图 or 白化）
    ///   - completion: 回调（始终在主线程）
    func loadImage(from url: URL,
                   variant: ImageVariant = .original,
                   completion: @escaping (UIImage?) -> Void) {
        let cacheKey = url.absoluteString + variant.cacheKeySuffix

        // 1. 检查缓存（命中时也统一回主线程）
        if let cachedImage = image(forKey: cacheKey) {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }

        // 2. 并发去重：如果已有相同请求在处理，加入等待队列
        lock.lock()
        if var waiters = inFlightRequests[cacheKey] {
            waiters.append(completion)
            inFlightRequests[cacheKey] = waiters
            lock.unlock()
            return
        }
        inFlightRequests[cacheKey] = [completion]
        lock.unlock()

        // 3. 加载原图（单例不需要 weak self）
        loadOriginalImage(from: url) { originalImage in
            guard let originalImage = originalImage else {
                self.completeRequest(cacheKey: cacheKey, image: nil, originalUrl: url)
                return
            }

            // 4. 处理（异步）
            if variant.needsProcessing {
                DispatchQueue.global(qos: .userInitiated).async {
                    let processed = FadeVeilProcessor.shared.process(
                        originalImage,
                        fadeScore: variant.fadeScore
                    )
                    self.setImage(processed, forKey: cacheKey)
                    self.completeRequest(cacheKey: cacheKey, image: processed, originalUrl: url)
                }
            } else {
                self.completeRequest(cacheKey: cacheKey, image: originalImage, originalUrl: url)
            }
        }
    }

    /// 完成请求并通知所有等待者（统一回主线程）
    private func completeRequest(cacheKey: String, image: UIImage?, originalUrl: URL? = nil) {
        lock.lock()
        let waiters = inFlightRequests.removeValue(forKey: cacheKey) ?? []
        lock.unlock()

        // 统一在主线程回调，避免调用方线程不一致
        DispatchQueue.main.async {
            for completion in waiters {
                completion(image)
            }

            // 图片加载成功时，发送通知（用于更新显示占位图的标注）
            if let image = image, let url = originalUrl {
                self.notifyImageLoaded(url: url)
            }
        }
    }

    /// 发送图片加载成功通知（避免重复通知同一 URL）
    private func notifyImageLoaded(url: URL) {
        let urlString = url.absoluteString

        notifiedUrlsLock.lock()
        let alreadyNotified = notifiedUrls.contains(urlString)
        if !alreadyNotified {
            notifiedUrls.insert(urlString)
        }
        notifiedUrlsLock.unlock()

        // 只在首次加载成功时发送通知
        if !alreadyNotified {
            NotificationCenter.default.post(
                name: .imageCacheDidLoadImage,
                object: nil,
                userInfo: ["url": url]
            )
        }
    }

    // MARK: - 原图加载（内部方法）

    /// 加载原图（不带任何处理）
    private func loadOriginalImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = url.absoluteString

        // 检查原图缓存
        if let cachedImage = image(forKey: cacheKey) {
            completion(cachedImage)
            return
        }

        if url.isFileURL {
            // 处理本地文件 URL
            DispatchQueue.global(qos: .userInitiated).async {
                if let imageData = try? Data(contentsOf: url),
                   let loadedImage = UIImage(data: imageData) {
                    self.setImage(loadedImage, forKey: cacheKey)
                    completion(loadedImage)
                } else {
                    completion(nil)
                }
            }
        } else {
            // 处理远程 URL
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data, let downloadedImage = UIImage(data: data) {
                    self.setImage(downloadedImage, forKey: cacheKey)
                    completion(downloadedImage)
                } else {
                    completion(nil)
                }
            }.resume()
        }
    }
}

struct ShareKey: Hashable {
    let userId: Int
    let createDate: Int
}

// 媒体项的包装类，包含一个唯一标识符和媒体项
class MediaItemWrapper: Identifiable, ObservableObject {
    let id = UUID()
    @Published var mediaItem: MediaItemProtocol?
    var photoFile: MediaFile?
    var videoFile: MediaFile?
    
    // 方案A：LivePhoto 相关
    @Published var livePhoto: PHLivePhoto?
    @Published var imageSize: CGSize?
    @Published var currentPlayToken: UUID?
    @Published var handledPlayToken: UUID?
    private var hasAssignedFinalLivePhoto = false
    private var isGeneratingLivePhoto = false
    var hasAutoPlayedForSelection: Bool = false
    
    // 方案B：短视频播放相关
    @Published var coverImageData: Data?  // 封面图数据
    @Published var videoEngine: VideoEngine?  // 视频播放引擎
    @Published var coverShouldShow: Bool = true  // 封面是否应该显示（由 ShareDetailView 控制）

    init(_ mediaItem: MediaItemProtocol?) {
        self.mediaItem = mediaItem
    }

    @MainActor
    /// 生成LivePhoto对象
    /// - Parameter localPhotoURL: 本地照片文件URL（可选）。如果提供，直接使用；否则创建临时文件
    func generateLivePhoto(localPhotoURL: URL? = nil) {
        guard let photo = self.mediaItem as? Photo,
              let livePhotoMovieURL = photo.livePhotoMovieURL else {
            return
        }

        // 避免重复生成同一份 Live Photo
        guard !isGeneratingLivePhoto else {
            #if DEBUG
            print("⏭️ 已在生成 LivePhoto，跳过重复请求")
            #endif
            return
        }
        isGeneratingLivePhoto = true
        hasAssignedFinalLivePhoto = false

        if let image = UIImage(data: photo.data) {
                    self.imageSize = image.size
                }
        // 获取视频尺寸（应用旋转矩阵并取绝对值）
        let asset = AVAsset(url: livePhotoMovieURL)
        if let track = asset.tracks(withMediaType: .video).first {
            let t = track.preferredTransform
            let oriented = track.naturalSize.applying(t)
            let width = abs(oriented.width)
            let height = abs(oriented.height)
            print("视频尺寸: (\(width), \(height))")
        }
        
        // ✅ 方案A改进：优先使用本地文件URL，避免重新写入临时文件（可能丢失元数据）
        let photoURL: URL
        
        if let localURL = localPhotoURL {
            // 直接使用已下载的本地文件（保留元数据）
            photoURL = localURL
            #if DEBUG
            print("✅ generateLivePhoto: 使用本地文件，保留元数据 - \(localURL.path)")
            
            // 🔍 调试：检查下载的文件是否包含元数据
            if let imageData = try? Data(contentsOf: localURL),
               let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
               let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
                let makerAppleKey = "{MakerApple}"
                if let makerApple = metadata[makerAppleKey] as? [String: Any],
                   let assetId = makerApple["17"] as? String {
                    print("🎉 元数据检查：图片包含 AssetID = \(assetId)")
                } else {
                    print("⚠️ 元数据检查：图片缺少 MakerApple/17，可能被服务器处理")
                }
            }
            #endif
        } else {
            // 创建临时文件（兼容旧逻辑）
            let tempPhotoURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".jpg")
            do {
                try photo.data.write(to: tempPhotoURL)
                photoURL = tempPhotoURL
                #if DEBUG
                print("⚠️ generateLivePhoto: 使用临时文件 - \(tempPhotoURL.path)")
                #endif
            } catch {
                print("无法写入临时照片文件：\(error)")
                return
            }
        }

        // 生成 PHLivePhoto 对象
        PHLivePhoto.request(withResourceFileURLs: [photoURL, livePhotoMovieURL], placeholderImage: nil, targetSize: .zero, contentMode: .aspectFit) { livePhoto, info in
            let isDegraded = (info[PHLivePhotoInfoIsDegradedKey] as? Bool) ?? false

            #if DEBUG
            if let livePhoto = livePhoto {
                print("📸 PHLivePhoto.request 回调 - isDegraded: \(isDegraded), LivePhoto: \(Unmanaged.passUnretained(livePhoto).toOpaque())")
            } else {
                print("📸 PHLivePhoto.request 回调 - isDegraded: \(isDegraded), LivePhoto: nil")
            }
            #endif

            DispatchQueue.main.async {
                defer {
                    if !isDegraded {
                        self.isGeneratingLivePhoto = false
                    }
                }

                guard let livePhoto = livePhoto else {
                    if let error = info[PHLivePhotoInfoErrorKey] as? NSError {
                        print("生成 Live Photo 失败，错误：\(error)")
                    } else if (info[PHLivePhotoInfoCancelledKey] as? NSNumber)?.boolValue == true {
                        print("生成 Live Photo 被取消")
                    } else {
                        print("生成 Live Photo 失败，未知错误")
                    }
                    return
                }

                guard !isDegraded else {
                    #if DEBUG
                    print("⏭️ 跳过降级版本 LivePhoto")
                    #endif
                    return
                }

                guard !self.hasAssignedFinalLivePhoto else {
                    #if DEBUG
                    print("⏭️ 已有最终 LivePhoto，忽略多余回调")
                    #endif
                    return
                }

                self.hasAssignedFinalLivePhoto = true
                self.livePhoto = livePhoto
                #if DEBUG
                print("✅ 设置最终 LivePhoto: \(Unmanaged.passUnretained(livePhoto).toOpaque())")
                #endif
            }
        }
        
    }
}
