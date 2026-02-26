//
//  StickerAssetService.swift
//  guanzhi
//
//  Created by Claude Code on 2026/2/26.
//
//  贴纸图片资产服务 - 从服务器下载贴纸 PNG 并本地缓存
//
//  存储策略：
//  - 元数据：Documents/sticker_assets_cache.json（版本/ETag/文件路径）
//  - 图片文件：Caches/Stickers/{code}.png
//

import Foundation

// MARK: - Response Models

private struct StickerAssetsResponse: Codable {
    let version: String
    let assets: [StickerAssetItem]
}

private struct StickerAssetItem: Codable {
    let code: String
    let iconUrl: String
}

// MARK: - StickerAssetService

/// 贴纸图片资产服务
/// 负责从服务器下载贴纸 PNG、本地缓存、启动时检查更新
final class StickerAssetService {

    // MARK: - Singleton

    static let shared = StickerAssetService()

    private init() {
        loadMetadataFromDisk()
    }

    // MARK: - Properties

    /// 本地图片 URL 映射 [tagCode(小写): localURL]
    private var localURLs: [String: URL] = [:]

    /// 当前版本号
    private var currentVersion: String?

    /// 上次 ETag
    private var lastETag: String?

    /// 上次成功检查时间
    private var lastCheckTime: Date?

    /// API 路径
    private let apiPath = "/api/config/sticker-assets"

    /// 元数据缓存文件
    private var metadataFilePath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sticker_assets_cache.json")
    }

    /// 图片缓存目录
    private var stickersDir: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Stickers")
    }

    // MARK: - Public Methods

    /// 获取本地缓存的贴纸图片 URL
    /// - Parameter code: 贴纸代码（小写，如 "like"、"mijing"）
    func localURL(for code: String) -> URL? {
        return localURLs[code.lowercased()]
    }

    /// App 启动时预加载（异步，不阻塞主线程）
    func preload() {
        Task {
            await checkAndRefreshIfNeeded()
        }
    }

    /// 强制刷新（忽略版本缓存）
    func forceRefresh() async {
        await downloadAssets(ignoreCache: true)
    }

    // MARK: - Core Logic

    @MainActor
    private func checkAndRefreshIfNeeded() async {
        await downloadAssets(ignoreCache: false)
    }

    private func downloadAssets(ignoreCache: Bool) async {
        do {
            let result = try await fetchAssetList(ignoreCache: ignoreCache)

            if let result = result {
                // 有新版本，下载所有资产
                let downloadedURLs = await downloadAllImages(assets: result.assets)

                currentVersion = result.version
                localURLs = downloadedURLs
                lastCheckTime = Date()
                saveMetadataToDisk()

                // 清除纹理缓存，触发重新加载
                await MainActor.run {
                    StickerTextureCache.shared.clearCache()
                }

                #if DEBUG
                print("✅ [StickerAssetService] 更新完成，版本: \(result.version)，下载: \(downloadedURLs.count) 张")
                #endif
            } else {
                // 304 Not Modified，无需更新
                lastCheckTime = Date()
                saveMetadataToDisk()

                #if DEBUG
                print("📦 [StickerAssetService] 版本未变化，使用本地缓存")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ [StickerAssetService] 检查失败: \(error.localizedDescription)")
            #endif
        }
    }

    /// 获取资产列表（带 ETag 缓存）
    /// - Returns: 新数据（版本变化），nil 表示 304
    private func fetchAssetList(ignoreCache: Bool) async throws -> StickerAssetsResponse? {
        guard let url = URL(string: "\(Constants.BASE_HOST)\(apiPath)") else {
            throw OTONetworkError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if !ignoreCache, let etag = lastETag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OTONetworkError.invalidResponse
        }

        if httpResponse.statusCode == 304 {
            return nil
        }

        if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
            lastETag = etag
        }

        guard httpResponse.statusCode == 200 else {
            throw OTONetworkError.badRequest
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(OTOResponseModel<StickerAssetsResponse>.self, from: data)

        guard apiResponse.respCode == 0, let datas = apiResponse.datas else {
            throw OTONetworkError.customError(apiResponse.respMsg ?? "未知错误")
        }

        // 如果版本相同，无需更新（双重检查）
        if !ignoreCache, datas.version == currentVersion, !localURLs.isEmpty {
            return nil
        }

        return datas
    }

    /// 并行下载所有贴纸图片
    private func downloadAllImages(assets: [StickerAssetItem]) async -> [String: URL] {
        guard let dir = stickersDir else { return [:] }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var result: [String: URL] = [:]

        await withTaskGroup(of: (String, URL?)?.self) { group in
            for asset in assets {
                group.addTask {
                    let localPath = dir.appendingPathComponent("\(asset.code).png")
                    if await self.downloadImage(from: asset.iconUrl, to: localPath) {
                        return (asset.code, localPath)
                    }
                    return nil
                }
            }

            for await item in group {
                if let (code, url) = item {
                    result[code] = url
                }
            }
        }

        return result
    }

    /// 下载单张图片
    private func downloadImage(from urlString: String, to destination: URL) async -> Bool {
        guard let url = URL(string: urlString) else { return false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return false }
            try data.write(to: destination, options: .atomic)
            return true
        } catch {
            #if DEBUG
            print("❌ [StickerAssetService] 下载失败: \(urlString) - \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Persistence

    private struct MetadataCache: Codable {
        let version: String?
        let etag: String?
        let checkTime: Date?
        let localPaths: [String: String]  // code -> absolute path string
    }

    private func saveMetadataToDisk() {
        var paths: [String: String] = [:]
        for (code, url) in localURLs {
            paths[code] = url.absoluteString
        }

        let cache = MetadataCache(
            version: currentVersion,
            etag: lastETag,
            checkTime: lastCheckTime,
            localPaths: paths
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            try data.write(to: metadataFilePath)
        } catch {
            #if DEBUG
            print("❌ [StickerAssetService] 保存元数据失败: \(error.localizedDescription)")
            #endif
        }
    }

    private func loadMetadataFromDisk() {
        guard FileManager.default.fileExists(atPath: metadataFilePath.path) else { return }

        do {
            let data = try Data(contentsOf: metadataFilePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cache = try decoder.decode(MetadataCache.self, from: data)

            currentVersion = cache.version
            lastETag = cache.etag
            lastCheckTime = cache.checkTime

            // 只加载磁盘上实际存在的文件
            for (code, pathString) in cache.localPaths {
                if let url = URL(string: pathString),
                   FileManager.default.fileExists(atPath: url.path) {
                    localURLs[code] = url
                }
            }

            #if DEBUG
            print("📦 [StickerAssetService] 从磁盘加载 \(localURLs.count) 个贴纸资产，版本: \(currentVersion ?? "无")")
            #endif
        } catch {
            #if DEBUG
            print("❌ [StickerAssetService] 加载元数据失败: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Cache Cleanup

    /// 清除所有本地缓存（供 SettingView 调用）
    func clearLocalCache() {
        // 删除磁盘图片文件
        if let dir = stickersDir {
            try? FileManager.default.removeItem(at: dir)
        }
        // 删除元数据
        try? FileManager.default.removeItem(at: metadataFilePath)

        // 重置内存状态
        localURLs = [:]
        currentVersion = nil
        lastETag = nil
        lastCheckTime = nil
    }
}
