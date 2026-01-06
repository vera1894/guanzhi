# 褪色白化效果（Fade Veil）实现完成

**日期**: 2026-01-06
**作者**: Claude Code
**状态**: 已完成

---

## 需求背景

当分享的 `fadeScore >= 90` 时，需要在缩略图上显示"发白"视觉效果，提示用户该分享即将褪色。

### 应用范围

| 场景 | 是否应用白化 | 说明 |
|------|-------------|------|
| 地图单标注 | 是 | `CustomMKAnnotationView` |
| 个人列表项 | 是 | `ShareSingleView`（个人主页） |
| 聚合列表项 | 是 | `ShareSingleView`（聚合弹窗） |
| 聚合图标 | **否** | `ClusterAnnotationView`（即使代表图 fadeScore >= 90） |

---

## 技术方案

### 设计决策

GPT 建议：SwiftUI 和 UIKit 共用单一 Core Image 实现，而非分别用 ViewModifier 和 CALayer Filter。

**优势**：
- 参数改一处全局生效
- 处理后的 `UIImage` 可直接用于 SwiftUI `Image(uiImage:)` 和 UIKit `UIImageView`
- Core Image 支持 GPU 加速

### 核心组件

#### 1. FadeVeilProcessor（新建）

**路径**: `View/Shared/FadeVeilProcessor.swift`

```swift
final class FadeVeilProcessor {
    static let shared = FadeVeilProcessor()

    // 参数集中管理
    static let threshold: Int = 90        // 触发阈值
    static let saturation: CGFloat = 0.15 // 饱和度（0=灰，1=原色）
    static let veilOpacity: CGFloat = 0.24 // 白色蒙版透明度
    static let version: String = "fv_v1"  // 缓存版本号

    func process(_ image: UIImage, fadeScore: Int) -> UIImage
}
```

**处理流程**：
1. `fadeScore < threshold` → 直接返回原图
2. 转换为 CIImage（处理 EXIF 方向）
3. CIColorControls 降低饱和度
4. CIConstantColorGenerator 生成白色蒙版
5. CIScreenBlendMode 混合
6. 返回 UIImage（orientation = .up 避免二次旋转）

#### 2. ImageCache 统一 API（修改）

**路径**: `ModelsForMap/SearchViewModel.swift`

新增 `ImageVariant` 枚举：
```swift
enum ImageVariant: Hashable {
    case original                    // 原图
    case fadeVeil(fadeScore: Int)    // 白化图

    var cacheKeySuffix: String {
        switch self {
        case .original: return ""
        case .fadeVeil(let score):
            guard score >= FadeVeilProcessor.threshold else { return "" }
            return "_\(FadeVeilProcessor.version)"
        }
    }

    var needsProcessing: Bool {
        switch self {
        case .original: return false
        case .fadeVeil(let score): return score >= FadeVeilProcessor.threshold
        }
    }
}
```

新增统一加载方法：
```swift
func loadImage(
    from url: URL,
    variant: ImageVariant = .original,
    completion: @escaping (UIImage?) -> Void
)
```

**关键改进**：
- In-flight 请求去重（NSLock + 请求队列）
- 统一主线程回调
- 缓存 key 包含版本号

#### 3. 调用方修改

| 文件 | 修改内容 |
|------|----------|
| `CustomMKAnnotationView.swift` | `loadThumbnail(from:fadeScore:)` 使用 `.fadeVeil(fadeScore:)` |
| `ClusterAnnotationView.swift` | 明确使用 `.original` |
| `ShareSingleView.swift` | 使用 `.fadeVeil(fadeScore:)` |

---

## 文件清单

### 新建文件

| 文件 | 说明 |
|------|------|
| `View/Shared/FadeVeilProcessor.swift` | Core Image 处理器 |

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `ModelsForMap/SearchViewModel.swift` | ImageCache 添加 ImageVariant、统一 API、in-flight 去重 |
| `View/MapPages/CustomMKAnnotationView.swift` | 传入 fadeScore 参数 |
| `View/MapPages/ClusterAnnotationView.swift` | 明确使用 .original |
| `View/MyPages/ShareSingleView.swift` | 使用 .fadeVeil |
| `guanzhi.xcodeproj/project.pbxproj` | 添加 FadeVeilProcessor.swift 到项目 |

---

## 参数调整指南

如需调整白化效果：

1. 修改 `FadeVeilProcessor.swift` 中的参数：
   - `threshold` - 触发阈值（默认 90）
   - `saturation` - 饱和度（默认 0.15，越小越灰）
   - `veilOpacity` - 白色蒙版透明度（默认 0.24）

2. **必须** bump `version` 版本号（如 `fv_v2`），否则旧缓存不会更新

---

## GPT Review 要点整合

| 问题 | 解决方案 |
|------|----------|
| EXIF 方向处理 | `CIImage.oriented(forExifOrientation:)` + 返回时用 `.up` |
| 回调线程不一致 | 统一在主线程回调（缓存命中/网络返回/处理完成） |
| ImageCache 是单例 | 闭包中移除 `[weak self]`（单例不会被释放） |
| 缓存 key 无版本号 | 添加 `FadeVeilProcessor.version` 到 cache key |

---

## 未来优化建议（GPT 提供，暂不实现）

1. **Retry-After HTTP 日期解析** - 支持 RFC 7231 日期格式
2. **NetworkMonitor 状态简化** - 使用 enum 替代多个 Bool
3. **nearbyShares 缓存 key 精度** - 考虑小数位数舍入

---

## 验证清单

- [x] fadeScore >= 90 的分享缩略图显示白化效果
- [x] fadeScore < 90 的分享显示原图
- [x] 聚合图标始终显示原图（不白化）
- [x] 编译通过
- [x] 真机测试通过
