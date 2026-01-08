# 2026-01-08 图片占位符统一 + 缓存通知 + OneCode修复

## 概述

本次更新包含三个修复任务：
1. OneCode Toast 通知修复（OthersView 缺失 + 防重复）
2. 地图标注缩略图不更新问题（ImageCache 通知机制）
3. 统一图片占位符图标（ImagePlaceholder 组件）

---

## 任务 1：OneCode Toast 通知修复

### 问题描述
- OthersView（他人主页）点击被遮挡的 OneCode 时不弹出提示
- 连续点击会产生多个重复的 Toast 通知

### 解决方案

#### 1.1 ToastManager 防重复机制

**文件**: `View/UIElement/NotificationStyles/ToastManager.swift`

```swift
/// 显示新的 Toast（防重复：相同 title 的 toast 存在时不重复添加）
func showIfNotPresent(_ item: ToastItem) {
    let newTitle = item.style.title
    let alreadyExists = toasts.contains { $0.style.title == newTitle }
    if !alreadyExists {
        withAnimation(.spring()) {
            toasts.append(item)
        }
    }
}

// ToastStyle 扩展：提取标题用于去重
extension ToastStyle {
    var title: String {
        switch self {
        case .notificationOnly(let title, _, _, _, _, _): return title
        case .notificationOfWelcome(let title, _, _, _, _, _): return title
        case .notificationWithButton(let title, _, _, _, _, _, _, _): return title
        }
    }
}
```

#### 1.2 OthersView 添加 Toast 支持

**文件**: `View/MyPages/OthersView.swift`

```swift
@EnvironmentObject var toastManager: ToastManager

// ProfileHeaderView 中添加回调
ProfileHeaderView(
    displayModel: displayModel,
    mode: .other,
    cachedAvatarImage: nil,
    onOneCodeTap: {
        showNotification(message: "🔏 与手机号相同的OneCode会被隐藏")
    }
)

private func showNotification(message: String) {
    let newItem = ToastItem(style: .notificationOnly(
        title: message, symbol: "", tint: Color("color-primary"),
        isUserInteractionEnabled: true, timing: .short, isAutoClose: true
    ))
    toastManager.showIfNotPresent(newItem)
}
```

---

## 任务 2：地图标注缩略图更新机制

### 问题描述
地图标注初始加载失败后显示占位图，即使后续在其他地方（列表/详情）成功加载了该图片，标注也不会自动更新。

### 解决方案：ImageCache 通知机制

**文件**: `ModelsForNetwork/SearchViewModel.swift`

```swift
// MARK: - 图片缓存通知
extension Notification.Name {
    static let imageCacheDidLoadImage = Notification.Name("imageCacheDidLoadImage")
}

class ImageCache {
    // 记录已通知的 URL（避免重复通知）
    private var notifiedUrls: Set<String> = []
    private let notifiedUrlsLock = NSLock()

    private func completeRequest(cacheKey: String, image: UIImage?, originalUrl: URL? = nil) {
        // ... 现有代码 ...
        DispatchQueue.main.async {
            for completion in waiters { completion(image) }
            // 新增：成功加载时发送通知
            if let image = image, let url = originalUrl {
                self.notifyImageLoaded(url: url)
            }
        }
    }

    private func notifyImageLoaded(url: URL) {
        let urlString = url.absoluteString
        notifiedUrlsLock.lock()
        let alreadyNotified = notifiedUrls.contains(urlString)
        if !alreadyNotified { notifiedUrls.insert(urlString) }
        notifiedUrlsLock.unlock()

        if !alreadyNotified {
            NotificationCenter.default.post(
                name: .imageCacheDidLoadImage, object: nil,
                userInfo: ["url": url]
            )
        }
    }
}
```

**标注视图监听**（CustomMKAnnotationView / ClusterAnnotationView）:

```swift
private var isShowingPlaceholder: Bool = false
private var imageCacheObserver: NSObjectProtocol?

private func setupNotificationObserver() {
    imageCacheObserver = NotificationCenter.default.addObserver(
        forName: .imageCacheDidLoadImage, object: nil, queue: .main
    ) { [weak self] notification in
        self?.handleImageCacheNotification(notification)
    }
}

private func handleImageCacheNotification(_ notification: Notification) {
    guard isShowingPlaceholder,
          let url = notification.userInfo?["url"] as? URL,
          let currentUrl = currentImageUrl,
          url.absoluteString == currentUrl.absoluteString else { return }
    // 重新加载图片
    loadThumbnail(from: currentUrl, fadeScore: currentFadeScore)
}
```

---

## 任务 3：统一图片占位符组件

### 需求
- 加载中：使用 `wand.and.rays.inverse`（动态效果）
- 加载失败：使用 `photo.badge.exclamationmark`

### 新增文件

**文件**: `View/Shared/ImagePlaceholder.swift`

```swift
import SwiftUI
import UIKit

// MARK: - 符号常量
enum ImagePlaceholderSymbol {
    static let loading = "wand.and.rays.inverse"
    static let failed = "photo.badge.exclamationmark"
}

// MARK: - 状态枚举
enum ImagePlaceholderState {
    case loading
    case failed
}

// MARK: - SwiftUI 方形占位符
struct ImagePlaceholderView: View {
    let state: ImagePlaceholderState
    let size: CGFloat
    var backgroundColor: Color = Color("color-primary")
    var iconColor: Color = .white

    var body: some View {
        Group {
            switch state {
            case .loading:
                Image(systemName: ImagePlaceholderSymbol.loading)
                    .resizable().scaledToFit()
                    .frame(width: size * 0.5, height: size * 0.5)
                    .foregroundColor(iconColor)
                    .symbolEffect(.variableColor.iterative.dimInactiveLayers.reversing)
            case .failed:
                Image(systemName: ImagePlaceholderSymbol.failed)
                    .resizable().scaledToFit()
                    .frame(width: size * 0.5, height: size * 0.5)
                    .foregroundColor(iconColor)
            }
        }
        .frame(width: size, height: size)
        .background(backgroundColor)
    }
}

// MARK: - SwiftUI 圆形占位符（地图标注用）
struct CircularImagePlaceholderView: View {
    // 类似实现，添加圆形裁剪和边框
}

// MARK: - UIKit 辅助方法
enum ImagePlaceholderUIKit {
    static func configureForLoading(_ imageView: UIImageView, pointSize: CGFloat = 24) {
        imageView.image = loadingImage(pointSize: pointSize)
        imageView.tintColor = .white
        imageView.contentMode = .center
        // 添加脉冲动画
        addPulseAnimation(to: imageView)
    }

    static func configureForFailed(_ imageView: UIImageView, pointSize: CGFloat = 24) {
        imageView.image = failedImage(pointSize: pointSize)
        imageView.tintColor = .white
        imageView.contentMode = .center
        removeAnimation(from: imageView)
    }

    private static func addPulseAnimation(to imageView: UIImageView) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.4
        animation.duration = 0.8
        animation.autoreverses = true
        animation.repeatCount = .infinity
        imageView.layer.add(animation, forKey: "pulseAnimation")
    }
}
```

### 更新的视图

| 文件 | 变更 |
|------|------|
| `CustomMKAnnotationView.swift` | 使用 `ImagePlaceholderUIKit` |
| `ClusterAnnotationView.swift` | 使用 `ImagePlaceholderUIKit` |
| `CustomAnnotation.swift` | 添加 `ImageLoadState` 枚举，使用 `CircularImagePlaceholderView` |
| `ShareSingleView.swift` | 添加 `ListImageLoadState` 枚举，使用 `ImagePlaceholderView` |

---

## 修改文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `ToastManager.swift` | 修改 | 添加 `showIfNotPresent` + `ToastStyle.title` |
| `OthersView.swift` | 修改 | 添加 toastManager + onOneCodeTap |
| `SearchViewModel.swift` | 修改 | ImageCache 通知机制 |
| `CustomMKAnnotationView.swift` | 修改 | 通知监听 + 新占位符 |
| `ClusterAnnotationView.swift` | 修改 | 通知监听 + 新占位符 |
| `CustomAnnotation.swift` | 修改 | ImageLoadState + CircularImagePlaceholderView |
| `ShareSingleView.swift` | 修改 | ListImageLoadState + ImagePlaceholderView |
| `ImagePlaceholder.swift` | **新增** | 统一占位符组件 |
| `project.pbxproj` | 修改 | 添加 ImagePlaceholder.swift 到项目 |

---

## 技术要点

### SF Symbols 动画（SwiftUI）
```swift
.symbolEffect(.variableColor.iterative.dimInactiveLayers.reversing)
```
- `variableColor`: 变量颜色动画
- `iterative`: 顺序激活各层
- `dimInactiveLayers`: 非活跃层变暗
- `reversing`: 播放完后反向

### CABasicAnimation 脉冲（UIKit）
```swift
let animation = CABasicAnimation(keyPath: "opacity")
animation.fromValue = 1.0
animation.toValue = 0.4
animation.autoreverses = true
animation.repeatCount = .infinity
```

### 状态机模式
使用枚举管理图片加载状态，避免多个 Bool 标志位的复杂度：
```swift
private enum ImageLoadState {
    case loading
    case loaded(UIImage)
    case failed
}
```

---

## 测试验证

1. **OneCode Toast**
   - [ ] MyView 点击遮挡的 OneCode 弹出提示
   - [ ] OthersView 点击遮挡的 OneCode 弹出提示
   - [ ] 连续快速点击不产生重复 Toast

2. **标注缩略图更新**
   - [ ] 标注初始加载失败显示占位图
   - [ ] 打开详情页成功加载图片后，返回地图标注自动更新
   - [ ] 滚动标注出屏幕再滚回来保持更新状态

3. **占位符图标**
   - [ ] 地图单标注加载中显示 wand.and.rays.inverse（动画）
   - [ ] 地图单标注加载失败显示 photo.badge.exclamationmark
   - [ ] 聚合标注同上
   - [ ] 列表项同上

---

*Generated by Claude Code on 2026-01-08*
