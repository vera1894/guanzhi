# 查看体验优化 + 服务器 CDN 部署

**日期**: 2026-02-13
**角色**: Claude Code
**类型**: 功能开发 + 服务器优化

---

## 背景

用户查看观之详情页时存在三个体验问题：
1. AsyncImage 加载失败后无法重试，只显示空白
2. LivePhoto 下载进度是文件级跳变（0%→50%→100%），不够平滑
3. 缩略图每次打开都需要重新从服务器获取

同时服务器侧缺少媒体文件缓存策略和 CDN 加速。

---

## iOS 客户端改动

### 1. AsyncImage 失败重试机制

**文件**: `guanzhi/View/SharePages/MediaItemView.swift`

- 新增 `@State private var asyncImageRetryId = UUID()`
- AsyncImage 添加 `.id(asyncImageRetryId)`，改变 ID 强制 SwiftUI 重新创建实例
- `.failure` 分支显示错误图标 + "点击重试" 按钮，点击时 `asyncImageRetryId = UUID()`
- 同时优先读取本地缓存的缩略图 URL（如果存在）

### 2. 字节级下载进度

**文件**: `guanzhi/guanzhi/ModelsForMap/SearchViewModel.swift`

**MediaItemWrapper 进度拆分**:
- `@Published var downloadProgress: Double = 0` → 拆为 `photoDownloadProgress` + `videoDownloadProgress`
- `downloadProgress` 变为计算属性：photo 30% + video 70% 加权

**downloadMediaFile 方法**:
- 新增 `onProgress: ((Double) -> Void)? = nil` 参数
- 当传入 onProgress 时，使用 `URLSession.download(from:delegate:)` + `DownloadProgressDelegate`
- 不传 onProgress 时（如 redownloadMediaFile），行为不变

**DownloadProgressDelegate 类**（新增，在 SearchViewModel 文件顶部）:
- 实现 `URLSessionDownloadDelegate`
- 每 2% 变化才回调一次，避免过多 `objectWillChange` 触发 SwiftUI body 重绘

**踩坑记录**:
初始方案使用 `URLSession.bytes(from:)` 逐字节异步迭代 + 64KB 缓冲区。5MB 文件 = 500 万次 async iteration，导致 LivePhoto 加载极慢且 body 疯狂重渲染。改为 `download(from:delegate:)` 后完全解决。

### 3. 缩略图本地缓存

**文件**: `guanzhi/guanzhi/ModelsForMap/SearchViewModel.swift` — `downloadSingleWrapper` 方法

- 新增 Phase 0：先下载 thumbnailFile 到本地缓存（小文件极快），失败不阻塞
- Phase 1：photo + video 并行下载，各自传 onProgress 回调
- 移除旧的 `totalFiles` / `progressPerFile` / `+= progressPerFile` 逻辑

**MediaItemView** 优先使用本地缩略图 URL：
```swift
let imageURL: URL? = {
    if let localURL = mediaItemWrapper.thumbnailFile?.localURL,
       FileManager.default.fileExists(atPath: localURL.path) {
        return localURL
    }
    return mediaItemWrapper.thumbnailFile?.url ?? mediaItemWrapper.photoFile?.url
}()
```

---

## 服务器改动

### 4. Nginx Cache-Control 头

**文件**: `/etc/nginx/nginx.conf`（HTTP 80 + HTTPS 443 的 `/image/` location）

```nginx
location /image/ {
    add_header Cache-Control "public, max-age=604800, immutable";
    etag on;
    alias /home/ec2-user/images/image/;
    autoindex on;
}
```

- 客户端和 CDN 缓存 7 天
- `immutable` 表示内容不会变，浏览器不发条件请求
- Content-Length 由 Nginx 自动返回（静态文件），无需额外配置

### 5. CloudFront CDN 部署

**Distribution ID**: `E37ZE0ABRM5VX9`
**域名**: `d1v2g47jgn8fwk.cloudfront.cn`
**CNAME**: `onettoo.com`（DNS 在 DNSPod 设置 CNAME → CloudFront）

**缓存策略**:
| 路径模式 | 缓存行为 | TTL |
|----------|----------|-----|
| `/image/*` | 缓存 7 天 | min 1d, default 7d, max 30d |
| `*`（默认） | 不缓存，透传到源站 | TTL=0，转发全部 header/cookie/query |

**SSL 证书**: 通过 IAM 导入（路径 `/cloudfront/onettoo-com-2025`），有效期至 2026-02-24

**Nginx catch-all 补丁**:
- `/etc/nginx/conf.d/guanzhi-admin.conf` 的 `server_name _` 块新增 `/image/` location
- 原因：CloudFront 回源时 Host 头可能非 `onettoo.com`，命中 catch-all，没有 `/image/` → 404

### 踩坑总结

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| CloudFront 默认域名 403 | AWS 中国区要求绑 ICP 备案域名 | 添加 `onettoo.com` 为 CNAME |
| ACM 证书无法用于 CloudFront | 中国区 CloudFront 不支持 ACM | 改用 IAM server certificate |
| `/image/` CDN 回源 404 | Nginx catch-all 无 `/image/` location | 补加 location 到 catch-all server block |
| `bytes(from:)` 极慢 | 逐字节 async 迭代开销巨大 | 改用 `download(from:delegate:)` |

---

## iOS 客户端 CDN 域名配置

**文件**: `guanzhi/guanzhi/Data/Constants.swift`

```swift
static let BASE_HOST = "https://onettoo.com"
// CDN 域名（当前回退到源站直连；未来接入国内 CDN 时改为 CDN 域名即可）
static let MEDIA_CDN_HOST = "https://onettoo.com"
```

**文件**: `SearchViewModel.swift` 和 `ShareSingleView.swift` 的 `baseURL` 改为引用 `Constants.MEDIA_CDN_HOST`

> 由于 `onettoo.com` DNS 已直接指向 CloudFront，所有媒体请求自动走 CDN。

---

## 修改文件清单

| 文件 | 改动 |
|------|------|
| `SearchViewModel.swift` | MediaItemWrapper 进度拆分、DownloadProgressDelegate、downloadMediaFile 字节进度、downloadSingleWrapper 缩略图缓存、baseURL → CDN |
| `MediaItemView.swift` | AsyncImage 重试、本地缩略图优先 |
| `Constants.swift` | 新增 MEDIA_CDN_HOST |
| `ShareSingleView.swift` | baseURL → Constants.MEDIA_CDN_HOST |
| `/etc/nginx/nginx.conf` | Cache-Control 头 |
| `/etc/nginx/conf.d/guanzhi-admin.conf` | catch-all /image/ location |
| CloudFront | 新建 distribution + 双缓存策略 |
| DNSPod | onettoo.com CNAME → CloudFront |
