# 褪色白化效果实现计划

**日期**: 2026-01-06
**状态**: 待实施
**协作**: Claude Code + GPT

---

## 需求概述

为褪色度 ≥ 90 的观之添加视觉白化效果，表示"即将褪色"：
- **效果**：白化蒙版（white veil）+ 去饱和（desaturate）
- **作用范围**：
  - ✅ 地图单个标注的缩略图
  - ✅ 个人列表条目的缩略图（ShareSingleView）
  - ✅ 聚合列表条目的缩略图（复用 ShareSingleView）
  - ❌ 聚合图标（即使代表图 fadeScore ≥ 90 也不白化）

---

## 技术方案：单一实现（Core Image）

### 核心思路

```
原图 (UIImage)
    ↓
FadeVeilProcessor.process(image, fadeScore)  ← 单一处理入口（Core Image）
    ↓
处理后图片 (UIImage)  ← SwiftUI 和 UIKit 共用同一张图
```

**优势**：
- SwiftUI 和 UIKit 视觉效果完全一致（同一张处理后的 UIImage）
- 参数集中管理，调一处全局生效
- 避免两套实现（SwiftUI modifier + UIKit filter）导致的效果偏差

---

## 组件设计

### 1. FadeVeilProcessor（Core Image 处理器）

**文件**：`Shared/FadeVeilProcessor.swift`

```swift
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// 褪色白化效果处理器（单一实现，SwiftUI/UIKit 共用）
final class FadeVeilProcessor {
    static let shared = FadeVeilProcessor()
    private init() {}

    // ===== 参数集中管理 =====
    static let threshold: Int = 90           // 触发阈值
    static let saturation: CGFloat = 0.15    // 饱和度（0=全灰，1=原色）
    static let veilOpacity: CGFloat = 0.24   // 白色蒙版透明度
    static let version: String = "fv_v1"     // 缓存版本号（调参时 bump）

    // CIContext 复用（创建成本高）
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    /// 处理图片：当 fadeScore >= threshold 时应用白化效果
    func process(_ image: UIImage, fadeScore: Int) -> UIImage {
        guard fadeScore >= Self.threshold else { return image }

        // 1. 转换为 CIImage（处理 EXIF 方向）
        guard let ciImage = CIImage(image: image)?.oriented(forExifOrientation: Int32(image.imageOrientation.exifOrientation)) else {
            return image
        }

        // 2. 降低饱和度（CIColorControls）
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = ciImage
        colorControls.saturation = Float(Self.saturation)

        guard let desaturated = colorControls.outputImage else { return image }

        // 3. 生成白色蒙版（CIConstantColorGenerator）
        let whiteGenerator = CIFilter.constantColorGenerator()
        whiteGenerator.color = CIColor(red: 1, green: 1, blue: 1, alpha: Self.veilOpacity)

        guard let whiteImage = whiteGenerator.outputImage?.cropped(to: desaturated.extent) else {
            return image
        }

        // 4. Screen 混合（类似 SwiftUI .blendMode(.screen)）
        let screenBlend = CIFilter.screenBlendMode()
        screenBlend.inputImage = whiteImage
        screenBlend.backgroundImage = desaturated

        guard let output = screenBlend.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }

        // ⚠️ 关键：CIImage 已经校正过方向，返回时用 .up 避免二次旋转
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }
}

// MARK: - UIImageOrientation -> EXIF Orientation
private extension UIImage.Orientation {
    var exifOrientation: Int {
        switch self {
        case .up: return 1
        case .down: return 3
        case .left: return 8
        case .right: return 6
        case .upMirrored: return 2
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .rightMirrored: return 7
        @unknown default: return 1
        }
    }
}
```

### 2. ImageCache 统一 API

**修改**：`ModelsForMap/SearchViewModel.swift` 中的 `ImageCache`

```swift
// MARK: - 图片变体枚举（统一 API）
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
}

class ImageCache {
    static let shared = ImageCache()
    private init() {
        cache.countLimit = 100
    }

    private let cache = NSCache<NSString, UIImage>()

    // 并发去重：记录正在处理的请求
    private var inFlightRequests: [String: [(UIImage?) -> Void]] = [:]
    private let lock = NSLock()

    // ... 现有方法保留 ...

    /// 统一图片加载 API
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

        // 3. 加载原图
        // ⚠️ 单例不需要 weak self，避免请求永远不 complete
        loadOriginalImage(from: url) { originalImage in
            guard let originalImage = originalImage else {
                self.completeRequest(cacheKey: cacheKey, image: nil)
                return
            }

            // 4. 处理（异步）
            if variant.needsProcessing {
                DispatchQueue.global(qos: .userInitiated).async {
                    let processed = FadeVeilProcessor.shared.process(
                        originalImage,
                        fadeScore: self.extractFadeScore(from: variant)
                    )
                    self.setImage(processed, forKey: cacheKey)
                    self.completeRequest(cacheKey: cacheKey, image: processed)
                }
            } else {
                self.completeRequest(cacheKey: cacheKey, image: originalImage)
            }
        }
    }

    /// 完成请求并通知所有等待者（统一回主线程）
    private func completeRequest(cacheKey: String, image: UIImage?) {
        lock.lock()
        let waiters = inFlightRequests.removeValue(forKey: cacheKey) ?? []
        lock.unlock()

        // ⚠️ 关键：统一在主线程回调，避免调用方线程不一致
        DispatchQueue.main.async {
            for completion in waiters {
                completion(image)
            }
        }
    }

    private func extractFadeScore(from variant: ImageVariant) -> Int {
        switch variant {
        case .original: return 0
        case .fadeVeil(let fadeScore): return fadeScore
        }
    }

    /// 加载原图（内部方法）
    private func loadOriginalImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = url.absoluteString
        if let cachedImage = image(forKey: cacheKey) {
            completion(cachedImage)
            return
        }

        // ... 现有下载逻辑 ...
    }
}
```

---

## 调用方修改

### 1. CustomMKAnnotationView（地图单个标注）✅ 需要白化

```swift
func configure(with annotation: CustomAnnotation) {
    let fadeScore = annotation.annotationData?.fadeScore ?? 0
    if let imageUrl = annotation.imageUrl {
        loadThumbnail(from: imageUrl, fadeScore: fadeScore)
    }
}

private func loadThumbnail(from url: URL, fadeScore: Int) {
    currentImageUrl = url
    activityIndicator.startAnimating()

    ImageCache.shared.loadImage(
        from: url,
        variant: .fadeVeil(fadeScore: fadeScore)
    ) { [weak self] loadedImage in
        // ⚠️ 回调已统一在主线程，无需再 DispatchQueue.main.async
        guard let self = self, self.currentImageUrl == url else { return }
        self.activityIndicator.stopAnimating()
        if let image = loadedImage {
            self.thumbnailImage = image
            self.thumbnailImageView.image = image
        } else {
            self.showPlaceholder()
        }
    }
}
```

### 2. ClusterAnnotationView（聚合图标）❌ 不白化

```swift
private func loadThumbnail(from url: URL) {
    currentImageUrl = url
    activityIndicator.startAnimating()

    ImageCache.shared.loadImage(
        from: url,
        variant: .original  // 明确使用原图，永不白化
    ) { [weak self] loadedImage in
        guard let self = self, self.currentImageUrl == url else { return }
        self.activityIndicator.stopAnimating()
        if let image = loadedImage {
            self.thumbnailImageView.image = image
        } else {
            self.showPlaceholder()
        }
    }
}
```

### 3. ShareSingleView（个人列表 + 聚合列表条目）✅ 需要白化

> **说明**：聚合列表条目复用 `ShareSingleView`，因此修改此文件即可同时覆盖两处。

```swift
private func loadImage() {
    if let url = ephemeralGetThumbnailOrPhotoURL(responsedShare: share) {
        let fadeScore = share.fadeScore ?? 0
        ImageCache.shared.loadImage(
            from: url,
            variant: .fadeVeil(fadeScore: fadeScore)
        ) { downloaded in
            // ⚠️ 回调已统一在主线程，无需再 DispatchQueue.main.async
            self.image = downloaded
        }
    }
}
```

---

## 文件修改清单

| 操作 | 文件 | 说明 |
|------|------|------|
| **新建** | `Shared/FadeVeilProcessor.swift` | Core Image 处理器 |
| **修改** | `ModelsForMap/SearchViewModel.swift` | ImageCache 添加统一 API + 并发去重 |
| **修改** | `View/MapPages/CustomMKAnnotationView.swift` | 使用 `.fadeVeil(fadeScore:)` |
| **修改** | `View/MapPages/ClusterAnnotationView.swift` | 使用 `.original` |
| **修改** | `View/MyPages/ShareSingleView.swift` | 使用 `.fadeVeil(fadeScore:)`（覆盖个人列表+聚合列表） |

---

## GPT 审查修补点（已整合）

| # | 问题 | 修复方案 | 状态 |
|---|------|----------|------|
| 1 | **EXIF 方向二次旋转**：校正后又按原 orientation 包装会二次旋转 | 返回时使用 `.up`：`UIImage(cgImage:..., orientation: .up)` | ✅ 已修复 |
| 2 | **回调线程不一致**：有的路径在主线程，有的不在 | `completeRequest` 内统一 `DispatchQueue.main.async` | ✅ 已修复 |
| 3 | **[weak self] 导致请求不 complete**：单例意外 nil 时 waiters 永远收不到回调 | ImageCache 是单例，移除 weak，使用强引用 | ✅ 已修复 |
| 4 | **聚合列表条目接入点未明确**：计划写了但调用清单没体现 | 明确说明：聚合列表复用 ShareSingleView，修改一处即覆盖 | ✅ 已补充 |

---

## 关键设计点总结

| 设计点 | 说明 | 状态 |
|--------|------|------|
| CIContext 复用 | 创建成本高，作为单例属性复用 | ✅ |
| CIFilter 每次新建 | 可变对象，不应多线程共享 | ✅ |
| 白色蒙版裁剪到原图 extent | generator 类滤镜需要手动对齐尺寸 | ✅ |
| 缓存 key 带版本号 | 调参后 bump 版本号，避免旧缓存 | ✅ |
| 并发去重（in-flight dedupe） | 同一图片多次请求合并 | ✅ |
| EXIF 方向校正 | 进入滤镜前校正，返回时用 `.up` | ✅ |
| 回调线程统一 | 所有 completion 统一在主线程 | ✅ |
| 单例强引用 | ImageCache 是单例，不用 weak | ✅ |

---

## 参数配置

```swift
// FadeVeilProcessor.swift - 集中管理
static let threshold: Int = 90           // 触发阈值
static let saturation: CGFloat = 0.15    // 饱和度（0=全灰，1=原色）
static let veilOpacity: CGFloat = 0.24   // 白色蒙版透明度
static let version: String = "fv_v1"     // 缓存版本号
```

**调参指南**：
- 如果白化后"图片细节看不清"：降低 `veilOpacity`（如 0.18）
- 如果感觉"不够灰"：降低 `saturation`（如 0.10）
- 修改任何参数后：**必须 bump `version`**（如 `fv_v2`），否则旧缓存会导致"改了参数但看起来没变"

**BlendMode 选型说明**：
- 当前使用 `screenBlendMode`（提亮效果）
- 如需更稳定的"白色覆盖"观感，可改用 `sourceOverCompositing`（白色直接覆盖）
- 这是审美选择，不影响功能

---

## 缓存策略

| 图片类型 | 缓存 Key | 说明 |
|----------|----------|------|
| 原图 | `url` | 所有图片共用 |
| 白化图 | `url + "_fv_v1"` | fadeScore ≥ 90 时单独缓存 |

---

## 验证清单

- [ ] 地图单个标注：fadeScore ≥ 90 显示白化效果
- [ ] 地图单个标注：fadeScore < 90 显示原图
- [ ] 聚合图标：无论代表图 fadeScore 多少，都显示原图
- [ ] 个人列表条目：fadeScore ≥ 90 显示白化效果
- [ ] 聚合列表条目：fadeScore ≥ 90 显示白化效果
- [ ] 调整参数后 bump version，验证新效果生效
- [ ] 同一张图多次出现时，只处理一次（并发去重）
- [ ] 带方向的图片（如手机竖拍）显示正确，无旋转问题
- [ ] 回调线程一致性：调用方无需手动 dispatch 到主线程

---

## 后续优化建议（GPT 补充，非本次范围）

以下是 GPT 审查时提出的额外加固点，与 FadeVeil 功能无直接关系，可作为后续优化：

### 1. Retry-After 解析不完整（优先级：高）

**问题**：当前 `HTTPError.retryAfterSeconds` 只解析秒数格式，但 RFC 允许 HTTP 日期格式（如 `"Wed, 21 Oct 2015 07:28:00 GMT"`）。

**风险**：服务端返回日期格式时会被当作 nil，走默认 backoff，可能造成更频繁的 429。

**建议**：添加日期格式解析，换算成 `max(0, date - now)` 秒。

### 2. NetworkMonitor 状态变量简化（优先级：中）

**问题**：`previousConnectionType` 和 `connectionType` 语义有点打架，更新顺序容易出错。

**建议**：简化为单一变量：
```swift
let old = connectionType
let new = getConnectionType(path)
connectionTypeChanged = old != new
connectionType = new
```

### 3. nearbyShares 缓存 key 精度（优先级：低）

**问题**：当前用 `%.3f` 量化经纬度（约 110m），但用户拖动地图时频繁跨过边界，可能导致冷却失效。

**建议**：改用"请求语义"的 tile key，如 `floor(lat / grid) * grid` 或 region 中心 + span 离散化。
