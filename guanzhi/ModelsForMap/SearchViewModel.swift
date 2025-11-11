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
//    @Published var cachedShares: [String: ResponsedShare] = [:] // 使用分享标识符作为键
    @Published var selectedAnnotation: CustomAnnotation? = nil //用于存储选中的分享
    @Published var selectedAnnotationID: String? = nil //用于存储选中分享的id，用于match动画，但目前不可用
    @Published var selectedAnnotationImage: UIImage? //用于存储选中分享的图像，快速传递缩略图，后加载为原文件
    @Published var downloadMedia: [MediaItemWrapper] = []
    @Published var isUpdatingAnnotations: Bool = false
    @Published var selectedShare: Share?
    @Published var selectedShareMediaFiles: [MediaFile] = []
    @Published var annotationSortOption: AnnotationSortOption = .createDateDescending
    @Published var isShareDetailOverlayShown: Bool = false
    @Published var shareDeletedMessage: String? = nil // 分享已删除的提示消息
    @Published var showNavigationSheet: Bool = false // 导航应用选择弹窗状态

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
    
    //获取所有分享数据列表
    func fetchAllShares(latitude: Double, longitude: Double) {
        Task {
            do {
                print("🌍 SearchViewModel: 开始获取附近分享数据...")
                print("📍 坐标: latitude=\(latitude), longitude=\(longitude)")
                
                let shareList = try await ShareService.shared.fetchNearbyShares(
                    latitude: latitude,
                    longitude: longitude,
                    radius: 1000, //获取范围
                    size: -1
                )
                
                print("✅ SearchViewModel: 成功获取 \(shareList.count) 条分享数据")
                
                // 跟原逻辑一样，把它存进 SwiftData
                await saveSharesToDatabase(shares: shareList)
                // 保存完再 getAnnotations() 或其他操作
                self.getAnnotations()
            } catch {
                print("❌ SearchViewModel: 获取分享数据失败")
                print("❌ 错误类型: \(type(of: error))")
                print("❌ 错误信息: \(error.localizedDescription)")
                print("❌ 错误详情: \(error)")
            }
        }
    }
    
    //保存分享数据到数据库
    func saveSharesToDatabase(shares: [ResponsedShare]) async {
        print("开始保存分享数据，数量: \(shares.count)")
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
                    let newShare = Share(
                        id: Int64(share.id),
                        createDate: Date(timeIntervalSince1970: TimeInterval(share.createDate / 1000)),
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
        share.createDate = Date(timeIntervalSince1970: TimeInterval(responsedShare.createDate / 1000))
        share.data = responsedShare.data
        share.longitude = responsedShare.longitude
        share.latitude = responsedShare.latitude
        share.provinceCode = responsedShare.provinceCode?.stringValue
        share.cityCode = responsedShare.cityCode?.stringValue
        share.districtCode = responsedShare.districtCode?.stringValue
        share.address = responsedShare.address
        share.imagePaths = responsedShare.imagePath.components(separatedBy: ",")
        share.title = responsedShare.title
        share.deleted = responsedShare.deleted == 1
        // 异步更新媒体文件
        Task {
            await updateMediaFiles(for: share)
        }
    }
    
    // 更新分享的媒体文件
    func updateMediaFiles(for share: Share) async {
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
            if let mediaFile = parseMediaFile(from: path, shareId: share.id) {
                context.insert(mediaFile)
            } else {
                print("无法解析媒体文件路径：\(path)")
            }
        }
        // 保存上下文
        do {
            try context.save()
            print("成功更新媒体文件")
        } catch {
            print("更新媒体文件时发生错误：\(error)")
        }
    }
    
    //解析并存储媒体文件
    func saveMediaFiles(for share: Share) async {
        let mediaPaths = share.imagePaths
        var mediaFilesDict: [String: (photo: MediaFile?, video: MediaFile?, thumbnail: MediaFile?)] = [:]

        for path in mediaPaths {
            guard let mediaFile = parseMediaFile(from: path, shareId: share.id) else { continue }
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
                    case .video:
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
                    case .video:
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
                let localURL = getLocalURL(for: mediaFile)
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
        let thumbnailLocalURL = getLocalThumbnailURL(for: thumbnailFileName)

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
    func getLocalThumbnailURL(for fileName: String) -> URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
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
                guard typeTimestampComponents.count == 2 else {
                    return nil
                }
                let typeString = typeTimestampComponents[0]
                let timestampAndExtension = typeTimestampComponents[1].components(separatedBy: ".")
                guard timestampAndExtension.count == 2 else {
                    return nil
                }
                let timestampString = timestampAndExtension[0]
                let fileExtension = timestampAndExtension[1]
                guard let timestamp = Double(timestampString) else {
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
                    return nil
                }
                let timestampString = timestampAndExtension[0]
                let fileExtension = timestampAndExtension[1]
                guard let timestamp = Double(timestampString) else {
                    return nil
                }

                let mediaType: MediaType
                switch fileExtension.lowercased() {
                case "jpg", "jpeg", "png":
                    mediaType = .photo
                case "mov", "mp4":
                    mediaType = .video
                default:
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
                let newShare = Share(
                    id: Int64(shareData.id),
                    createDate: Date(timeIntervalSince1970: TimeInterval(shareData.createDate / 1000)),
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
        annotations.removeAll()
        // 获取当前地图区域
        let currentRegion = self.region
        // 获取可视区域内的分享
        var sharesInRegion = getSharesInRegion(currentRegion)
        print("Number of shares in region: \(sharesInRegion.count)")
        
        // 对 sharesInRegion 进行排序
        sortShares(&sharesInRegion)
        var newAnnotations: [CustomAnnotation] = []

        for share in sharesInRegion {
            let wgsCoordinate = CLLocationCoordinate2D(latitude: share.latitude, longitude: share.longitude)
            var displayCoordinate = wgsCoordinate
            // 判断分享的位置是否在中国大陆境内
            if CoordinateConverter.shared.isOutOfChina(wgsCoordinate) {
                // 不在中国境内，直接使用 WGS-84 坐标
                displayCoordinate = wgsCoordinate
            } else {
                // 在中国境内，进行坐标系转换
                displayCoordinate = CoordinateConverter.shared.wgs84ToGcj02(wgsCoordinate)
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
//                print("找到分享 ID \(shareId) 的本地缩略图")
                return localURL
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
                print("使用分享 ID \(shareId) 的第一张照片的本地 URL")
                return localURL
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
                        let localURL = getLocalURL(for: mediaFile)
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
        print("加载分享详情，分享 ID：\(shareId)")
        // 从数据库中获取分享
        let fetchDescriptor = FetchDescriptor<Share>(
            predicate: #Predicate { $0.id == shareId },
            sortBy: []
        )
        if let share = try? context.fetch(fetchDescriptor).first {
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
                return
            }

            self.selectedShare = share
            self.selectedAnnotation = annotations.first { $0.id == "\(shareId)" }
            // 获取媒体文件
            let mediaFetchDescriptor = FetchDescriptor<MediaFile>(
                predicate: #Predicate { $0.shareId == shareId },
                sortBy: [SortDescriptor(\MediaFile.timestamp, order: .forward)]
            )

            if let mediaFiles = try? context.fetch(mediaFetchDescriptor) {
                // 解析媒体文件，创建 MediaItemWrapper 数组
                let mediaItems = parseMediaFiles(mediaFiles)

                // 更新 self.downloadMedia
                DispatchQueue.main.async {
                    self.downloadMedia = mediaItems
                }

                // 下载媒体文件并更新对应的 MediaItemWrapper
                downloadMediaFiles(mediaItems: mediaItems)
            }
        } else {
            // 如果本地没有，向服务器请求详情
            fetchShareDetailFromServer(shareId: shareId)
        }
    }
    
    //从服务器获取分享详情
    func fetchShareDetailFromServer(shareId: Int64) {
        Task {
            do {
                let detail = try await ShareService.shared.fetchShareDetail(shareId: shareId)

                // 检查分享是否已被删除
                if detail.deleted == 1 {
                    // 分享已被删除
                    await MainActor.run {
                        // 从本地删除该分享
                        self.deleteShare(shareId: shareId)

                        // 从地图标注列表中移除
                        if let index = self.annotations.firstIndex(where: { $0.id == "\(shareId)" }) {
                            self.annotations.remove(at: index)
                        }

                        // 设置标志，通知 UI 显示提示
                        self.shareDeletedMessage = "这条观之已被删除，看看其他的吧～"
                    }
                    return
                }

                // 把这个 detail 做 SwiftData 持久化
                await saveSharesToDatabase(shares: [detail])
                // 然后重新加载
                loadShareDetail(for: shareId)
            } catch {
                print("Error fetching share detail: \(error)")
            }
        }
    }
    
    func downloadMediaFiles(mediaItems: [MediaItemWrapper]) {
        Task {
            for mediaItemWrapper in mediaItems {
                // 使用 TaskGroup 并发下载
                try await withThrowingTaskGroup(of: Void.self) { group in
                    // 下载照片文件
                    if let photoFile = mediaItemWrapper.photoFile, photoFile.localURL == nil {
                        group.addTask {
                            try await self.downloadMediaFile(mediaFile: photoFile)
                        }
                    }
                    // 下载视频文件
                    if let videoFile = mediaItemWrapper.videoFile, videoFile.localURL == nil {
                        group.addTask {
                            try await self.downloadMediaFile(mediaFile: videoFile)
                        }
                    }
                    // 等待所有任务完成
                    try await group.waitForAll()
                }
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
    
    //异步加载媒体文件
    func downloadMediaFile(mediaFile: MediaFile) async throws {
        guard let url = mediaFile.url else {
            print("媒体文件没有有效的 URL")
            return
        }
        do {
            print("开始下载媒体文件：\(url.absoluteString)")
            let (data, _) = try await URLSession.shared.data(from: url)
            // 保存到本地
            let localURL = getLocalURL(for: mediaFile)
            try data.write(to: localURL)
            
            // 检查文件尺寸（仅对图像和视频文件）
            if mediaFile.type == .photo || mediaFile.type == .livePhoto {
                if let image = UIImage(data: data) {
                    print("下载的图像尺寸：\(image.size)")
                }
            } else if mediaFile.type == .video {
                let asset = AVAsset(url: localURL)
                if let track = asset.tracks(withMediaType: .video).first {
                    let size = track.naturalSize.applying(track.preferredTransform)
                    print("下载的视频尺寸：\(size)")
                }
            }
            
            // 在主线程上更新 mediaFile 对象
            await MainActor.run {
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

                if hasPhoto && (hasVideo || hasLivePhotoVideo) {
                    // 动态照片（Live Photo）
                    if let photoFile = group.first(where: { $0.type == .photo }),
                       let videoFile = group.first(where: { $0.type == .video || $0.type == .livePhoto }) {
                        let mediaItemWrapper = MediaItemWrapper(nil)
                        mediaItemWrapper.photoFile = photoFile
                        mediaItemWrapper.videoFile = videoFile
                        mediaItems.append(mediaItemWrapper)
                    }
                } else if hasPhoto {
                    // 静态照片
                    if let photoFile = group.first(where: { $0.type == .photo }) {
                        let mediaItemWrapper = MediaItemWrapper(nil)
                        mediaItemWrapper.photoFile = photoFile
                        mediaItems.append(mediaItemWrapper)
                    }
                } else if hasVideo && !hasPhoto {
                    // 视频（排除 livePhoto 类型）
                    if let videoFile = group.first(where: { $0.type == .video }) {
                        let mediaItemWrapper = MediaItemWrapper(nil)
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
        if let photoFile = mediaItemWrapper.photoFile, photoFile.type != .thumbnail, let photoLocalURL = photoFile.localURL {
            print("创建媒体项，照片文件已下载，本地 URL：\(photoLocalURL)")
            if let imageData = try? Data(contentsOf: photoLocalURL) {
                if let videoFile = mediaItemWrapper.videoFile {
                    if let videoLocalURL = videoFile.localURL {
                        print("创建媒体项，视频文件已下载，本地 URL：\(videoLocalURL)")
                        // 动态照片，确保视频文件已下载
                        let photo = Photo(data: imageData, isProxy: false, livePhotoMovieURL: videoLocalURL)
                        mediaItemWrapper.mediaItem = photo
                        mediaItemWrapper.generateLivePhoto()
                        return photo
                    } else {
                        print("视频文件尚未下载完成，无法创建 Live Photo")
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
                print("无法读取照片数据，路径：\(photoLocalURL)")
            }
        } else if let videoFile = mediaItemWrapper.videoFile, let videoLocalURL = videoFile.localURL {
            print("创建媒体项，视频文件已下载，本地 URL：\(videoLocalURL)")
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
    func getLocalURL(for mediaFile: MediaFile) -> URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let mediaDirectory = cachesDirectory.appendingPathComponent("MediaFiles")
        if !FileManager.default.fileExists(atPath: mediaDirectory.path) {
            try? FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        let fileName = "\(mediaFile.shareId)_\(mediaFile.timestamp.timeIntervalSince1970).\(mediaFile.fileExtension)"
        return mediaDirectory.appendingPathComponent(fileName)
    }
    
    // 删除分享及其关联的媒体文件
    func deleteShare(shareId: Int64) {
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
        }
    }
    
    // 清理下载的媒体数据
    func cleandownloadMedia() {
        self.downloadMedia.removeAll()
    }
    
    // 将时间戳转换为实际时间
    func formattedDate(from timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN") // 设置为中文格式
        formatter.timeZone = TimeZone.current // 显式指定当前设备时区
        
        // 转换输入的时间为 UTC 时间
        let utcTimestamp = timestamp.addingTimeInterval(+8 * 3600) // 减去 +8 小时，转换为 UTC 时间
        
        // 返回根据设备当前时区格式化后的时间字符串
        return formatter.string(from: utcTimestamp)
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

// 图片缓存类，使用 NSCache 缓存图片
class ImageCache {
    static let shared = ImageCache()
    private init() {
        cache.countLimit = 100 // 设置最大缓存大小
    }

    private let cache = NSCache<NSString, UIImage>()

    func image(forKey key: String) -> UIImage? {
        let image = cache.object(forKey: key as NSString)
        if image != nil {
//            print("从缓存中获取图片，Key: \(key)")
        }
        return image
    }

    func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
//        print("缓存图片，Key: \(key)")
    }

    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = url.absoluteString
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
                    DispatchQueue.main.async {
                        completion(loadedImage)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        } else {
            // 处理远程 URL
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data, let downloadedImage = UIImage(data: data) {
                    self.setImage(downloadedImage, forKey: cacheKey)
                    DispatchQueue.main.async {
                        completion(downloadedImage)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
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
    @Published var livePhoto: PHLivePhoto?
    @Published var imageSize: CGSize?

    init(_ mediaItem: MediaItemProtocol?) {
        self.mediaItem = mediaItem
    }

    @MainActor
    func generateLivePhoto() {
        guard let photo = self.mediaItem as? Photo,
              let livePhotoMovieURL = photo.livePhotoMovieURL else {
            return
        }

        if let image = UIImage(data: photo.data) {
                    self.imageSize = image.size
                }
        // 获取视频尺寸
        let asset = AVAsset(url: livePhotoMovieURL)
        if let track = asset.tracks(withMediaType: .video).first {
            let size = track.naturalSize.applying(track.preferredTransform)
            print("视频尺寸: \(size)")
        }
        
        // 将照片数据保存到临时文件
        let tempPhotoURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".jpg")
        do {
            try photo.data.write(to: tempPhotoURL)
        } catch {
            print("无法写入临时照片文件：\(error)")
            return
        }

        // 生成 PHLivePhoto 对象
        PHLivePhoto.request(withResourceFileURLs: [tempPhotoURL, livePhotoMovieURL], placeholderImage: nil, targetSize: .zero, contentMode: .aspectFit) { livePhoto, info in
            DispatchQueue.main.async {
                if let livePhoto = livePhoto {
                    self.livePhoto = livePhoto
                } else {
                    if let error = info[PHLivePhotoInfoErrorKey] as? NSError {
                        print("生成 Live Photo 失败，错误：\(error)")
                    } else {
                        print("生成 Live Photo 失败，未知错误")
                    }
                }
            }
        }
        
    }
}
