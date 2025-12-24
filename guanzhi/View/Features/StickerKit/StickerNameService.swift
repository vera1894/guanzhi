//
//  StickerNameService.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/24.
//
//  贴纸名称服务 - 从服务器获取贴纸名称并缓存
//

import Foundation

// MARK: - Response Models

/// 贴纸名称 API 响应
struct StickerNamesResponse: Codable {
    let version: String
    let names: [String: String]
}

// MARK: - StickerNameService

/// 贴纸名称服务
/// 负责从服务器获取贴纸名称，支持 ETag 缓存和本地持久化
final class StickerNameService {

    // MARK: - Singleton

    static let shared = StickerNameService()

    private init() {
        loadFromDisk()
    }

    // MARK: - Properties

    /// 贴纸名称缓存 [tagCode: name]
    private var namesCache: [String: String] = [:]

    /// 当前版本号
    private var currentVersion: String?

    /// 上次 ETag 值
    private var lastETag: String?

    /// 上次成功加载时间
    private var lastLoadTime: Date?

    /// 缓存有效期（24小时）
    private let cacheValidDuration: TimeInterval = 24 * 60 * 60

    /// 本地缓存文件路径
    private var cacheFilePath: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("sticker_names_cache.json")
    }

    /// API 路径
    private let apiPath = "/api/config/sticker-names"

    // MARK: - Public Methods

    /// 获取贴纸名称
    /// - Parameter tagCode: 贴纸代码（如 "MIJING"、"LIKE"）
    /// - Returns: 贴纸名称，如果没有缓存则返回 nil
    func getName(for tagCode: String) -> String? {
        return namesCache[tagCode.uppercased()]
    }

    /// 获取贴纸名称（带默认值）
    /// - Parameters:
    ///   - tagCode: 贴纸代码
    ///   - defaultName: 默认名称（当缓存不存在时使用）
    /// - Returns: 贴纸名称
    func getName(for tagCode: String, default defaultName: String) -> String {
        return namesCache[tagCode.uppercased()] ?? defaultName
    }

    /// 预加载贴纸名称
    /// 在 App 启动时调用，异步加载不阻塞主线程
    func preload() {
        Task {
            await loadNames()
        }
    }

    /// 强制刷新贴纸名称（忽略缓存）
    func forceRefresh() async {
        await loadNames(ignoreCache: true)
    }

    /// 加载贴纸名称
    /// - Parameter ignoreCache: 是否忽略本地缓存
    @MainActor
    func loadNames(ignoreCache: Bool = false) async {
        // 检查缓存是否有效
        if !ignoreCache, isCacheValid() {
            #if DEBUG
            print("📦 [StickerNameService] 缓存有效，跳过网络请求")
            #endif
            return
        }

        do {
            let result = try await fetchFromServer()

            if let result = result {
                // 有新数据
                namesCache = result.names
                currentVersion = result.version
                lastLoadTime = Date()
                saveToDisk()

                #if DEBUG
                print("✅ [StickerNameService] 成功加载 \(result.names.count) 个贴纸名称，版本: \(result.version)")
                #endif
            } else {
                // 304 Not Modified，更新加载时间
                lastLoadTime = Date()
                saveToDisk()

                #if DEBUG
                print("📦 [StickerNameService] 服务器返回 304，使用缓存数据")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ [StickerNameService] 加载失败: \(error.localizedDescription)")
            #endif
            // 网络失败时继续使用本地缓存
        }
    }

    // MARK: - Private Methods

    /// 检查缓存是否有效
    private func isCacheValid() -> Bool {
        guard let lastLoad = lastLoadTime else { return false }
        return Date().timeIntervalSince(lastLoad) < cacheValidDuration
    }

    /// 从服务器获取数据
    /// - Returns: 新数据（如果有更新），nil 表示 304 未修改
    private func fetchFromServer() async throws -> StickerNamesResponse? {
        guard let url = URL(string: "\(Constants.BASE_HOST)\(apiPath)") else {
            throw OTONetworkError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // 添加 ETag 支持
        if let etag = lastETag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        #if DEBUG
        print("🌐 [StickerNameService] 请求: \(url.absoluteString)")
        if let etag = lastETag {
            print("   If-None-Match: \(etag)")
        }
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OTONetworkError.invalidResponse
        }

        #if DEBUG
        print("📥 [StickerNameService] HTTP 状态码: \(httpResponse.statusCode)")
        #endif

        // 304 Not Modified
        if httpResponse.statusCode == 304 {
            return nil
        }

        // 保存新的 ETag
        if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
            lastETag = etag
            #if DEBUG
            print("   新 ETag: \(etag)")
            #endif
        }

        // 解析响应
        guard httpResponse.statusCode == 200 else {
            throw OTONetworkError.badRequest
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(OTOResponseModel<StickerNamesResponse>.self, from: data)

        guard apiResponse.respCode == 0, let datas = apiResponse.datas else {
            throw OTONetworkError.customError(apiResponse.respMsg ?? "未知错误")
        }

        return datas
    }

    // MARK: - Persistence

    /// 本地缓存数据结构
    private struct CacheData: Codable {
        let names: [String: String]
        let version: String?
        let etag: String?
        let loadTime: Date?
    }

    /// 保存到磁盘
    private func saveToDisk() {
        let cacheData = CacheData(
            names: namesCache,
            version: currentVersion,
            etag: lastETag,
            loadTime: lastLoadTime
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cacheData)
            try data.write(to: cacheFilePath)

            #if DEBUG
            print("💾 [StickerNameService] 缓存已保存到: \(cacheFilePath.path)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [StickerNameService] 保存缓存失败: \(error.localizedDescription)")
            #endif
        }
    }

    /// 从磁盘加载
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: cacheFilePath.path) else {
            #if DEBUG
            print("📦 [StickerNameService] 无本地缓存文件")
            #endif
            return
        }

        do {
            let data = try Data(contentsOf: cacheFilePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cacheData = try decoder.decode(CacheData.self, from: data)

            namesCache = cacheData.names
            currentVersion = cacheData.version
            lastETag = cacheData.etag
            lastLoadTime = cacheData.loadTime

            #if DEBUG
            print("📦 [StickerNameService] 从磁盘加载 \(namesCache.count) 个贴纸名称")
            if let version = currentVersion {
                print("   版本: \(version)")
            }
            if let loadTime = lastLoadTime {
                print("   上次加载: \(loadTime)")
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ [StickerNameService] 加载缓存失败: \(error.localizedDescription)")
            #endif
        }
    }
}
