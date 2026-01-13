//
//  ShareThumbnailView.swift
//  guanzhi
//
//  Created by Claude Code on 2025/01/12.
//

import SwiftUI
import SwiftData

/// 观之缩略图视图：先从本地缓存获取，没有则异步加载
struct ShareThumbnailView: View {
    let shareId: Int64
    let size: CGFloat
    let cornerRadius: CGFloat

    @Environment(\.modelContext) private var modelContext
    @State private var thumbnailURL: URL?
    @State private var isLoading = false
    @State private var loadFailed = false

    init(shareId: Int64, size: CGFloat = 44, cornerRadius: CGFloat = 8) {
        self.shareId = shareId
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let url = thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholderView
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    case .failure:
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
            } else if isLoading {
                loadingView
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            loadThumbnail()
        }
    }

    // MARK: - 占位视图

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.2))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            )
    }

    private var loadingView: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.1))
            .frame(width: size, height: size)
            .overlay(
                ProgressView()
                    .scaleEffect(0.7)
            )
    }

    // MARK: - 加载逻辑

    private func loadThumbnail() {
        // 1. 先尝试从本地缓存获取
        if let localURL = getLocalThumbnailURL() {
            thumbnailURL = localURL
            return
        }

        // 2. 没有本地缓存，异步加载
        isLoading = true
        Task {
            await fetchFromServer()
        }
    }

    /// 从本地 SwiftData 获取缩略图 URL
    private func getLocalThumbnailURL() -> URL? {
        let thumbnailTypeString = MediaType.thumbnail.rawValue
        let photoTypeString = MediaType.photo.rawValue
        let livePhotoTypeString = MediaType.livePhoto.rawValue

        // 首先查找缩略图
        let thumbnailDescriptor = FetchDescriptor<MediaFile>(
            predicate: #Predicate { mediaFile in
                mediaFile.shareId == shareId &&
                mediaFile.typeString == thumbnailTypeString
            },
            sortBy: [SortDescriptor(\MediaFile.timestamp, order: .forward)]
        )

        if let mediaFile = try? modelContext.fetch(thumbnailDescriptor).first {
            // 优先本地文件
            if let localURL = mediaFile.localURL,
               FileManager.default.fileExists(atPath: localURL.path) {
                return localURL
            }
            // 否则使用远程 URL
            if let remoteURL = mediaFile.url {
                return remoteURL
            }
        }

        // 没有缩略图，尝试获取第一张照片
        let photoDescriptor = FetchDescriptor<MediaFile>(
            predicate: #Predicate { mediaFile in
                mediaFile.shareId == shareId &&
                (mediaFile.typeString == photoTypeString || mediaFile.typeString == livePhotoTypeString)
            },
            sortBy: [SortDescriptor(\MediaFile.timestamp, order: .forward)]
        )

        if let mediaFile = try? modelContext.fetch(photoDescriptor).first {
            if let localURL = mediaFile.localURL,
               FileManager.default.fileExists(atPath: localURL.path) {
                return localURL
            }
            if let remoteURL = mediaFile.url {
                return remoteURL
            }
        }

        return nil
    }

    /// 从服务器获取 Share 详情并提取缩略图
    @MainActor
    private func fetchFromServer() async {
        do {
            let detail = try await ShareService.shared.fetchShareDetail(shareId: shareId)

            // 从 imagePath 提取缩略图 URL
            if let url = extractThumbnailURL(from: detail.imagePath) {
                thumbnailURL = url
            }
        } catch {
            print("⚠️ ShareThumbnailView: 加载失败 shareId=\(shareId), error=\(error)")
            loadFailed = true
        }

        isLoading = false
    }

    /// 从 imagePath 字符串提取缩略图 URL
    private func extractThumbnailURL(from imagePath: String) -> URL? {
        let baseURL = Constants.BASE_HOST

        let pathList = imagePath.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if pathList.isEmpty { return nil }

        // 优先 thumbnail
        if let thumbPath = pathList.first(where: { $0.lowercased().contains("thumbnail") }) {
            return URL(string: baseURL + thumbPath)
        }

        // 其次 photo
        if let photoPath = pathList.first(where: { $0.lowercased().contains("photo") }) {
            return URL(string: baseURL + photoPath)
        }

        // 否则用第一个
        return URL(string: baseURL + pathList[0])
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ShareThumbnailView(shareId: 123)
        ShareThumbnailView(shareId: 456, size: 60, cornerRadius: 12)
    }
    .padding()
}
