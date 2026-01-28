# 地图标注缩略图自动重试机制

**日期**: 2026-01-28
**操作者**: Claude Code
**类型**: 功能增强

---

## 问题描述

用户反馈：当地图上一个标注的缩略图加载失败后，即使点进去成功加载了观之详情页，返回主页时标注的缩略图仍然是失败状态，只有重启 app 才能解决。

## 解决方案

实现了基于通知的缩略图重试机制：

1. 当分享详情加载成功时，发送 `shareDetailDidLoadSuccess` 通知
2. 地图标注 (`CustomMKAnnotationView`) 监听此通知
3. 如果标注正在显示失败占位符且 shareId 匹配，则自动重试加载缩略图

## 代码修改

### 1. SearchViewModel.swift

**新增通知定义：**
```swift
extension Notification.Name {
    /// 分享详情加载成功通知（userInfo 包含 "shareId": Int64, "thumbnailURL": URL?）
    /// 用于通知地图标注重试加载失败的缩略图
    static let shareDetailDidLoadSuccess = Notification.Name("shareDetailDidLoadSuccess")
}
```

**在 `fetchShareDetailFromServer` 成功时发送通知：**
```swift
// 更新状态为成功
if let share = self.selectedShare {
    self.shareDetailState = .loaded(share)

    // 发送通知，让地图标注重试加载失败的缩略图
    let thumbnailURL = self.getThumbnailURL(for: share)
    NotificationCenter.default.post(
        name: .shareDetailDidLoadSuccess,
        object: nil,
        userInfo: [
            "shareId": shareId,
            "thumbnailURL": thumbnailURL as Any
        ]
    )
}
```

### 2. CustomMKAnnotationView.swift

**新增属性：**
```swift
private var shareDetailLoadObserver: NSObjectProtocol?
private var currentShareId: Int64?
```

**新增通知监听：**
```swift
// 监听分享详情加载成功通知
shareDetailLoadObserver = NotificationCenter.default.addObserver(
    forName: .shareDetailDidLoadSuccess,
    object: nil,
    queue: .main
) { [weak self] notification in
    self?.handleShareDetailLoadNotification(notification)
}
```

**新增通知处理方法：**
```swift
private func handleShareDetailLoadNotification(_ notification: Notification) {
    // 只在显示失败占位符时才重试
    guard isShowingPlaceholder else { return }

    // 检查 shareId 是否匹配
    guard let notificationShareId = notification.userInfo?["shareId"] as? Int64,
          let myShareId = currentShareId,
          notificationShareId == myShareId else {
        return
    }

    // 尝试使用通知中的 thumbnailURL，或使用当前的 URL
    if let thumbnailURL = notification.userInfo?["thumbnailURL"] as? URL {
        loadThumbnail(from: thumbnailURL, fadeScore: currentFadeScore)
    } else if let currentUrl = currentImageUrl {
        loadThumbnail(from: currentUrl, fadeScore: currentFadeScore)
    }
}
```

**更新 configure 方法保存 shareId：**
```swift
// 保存 shareId 用于匹配通知
currentShareId = annotation.annotationData?.id
```

**更新 prepareForReuse 清除 shareId：**
```swift
currentShareId = nil
```

## 工作流程

```
用户操作                        系统响应
───────────────────────────────────────────────────────
1. 进入主页                     → 加载标注缩略图
2. 标注 A 缩略图加载失败        → 显示失败占位符
3. 点击标注 A 进入详情页        → 加载分享详情
4. 详情页加载成功               → 发送 shareDetailDidLoadSuccess 通知
5. 返回主页                     → 标注 A 收到通知，检测到正在显示占位符
                                → 自动重试加载缩略图
6. 缩略图加载成功               → 显示正确的缩略图
```

## 已有机制保留

- `imageCacheDidLoadImage` 通知机制仍然有效，用于图片缓存成功后的自动更新
- 网络恢复时的自动重试机制 (`retryFailedMediaDownloads`) 保持不变

## 测试建议

1. 模拟网络差的环境，让标注缩略图加载失败
2. 点击该标注进入详情页
3. 等待详情页加载成功
4. 返回主页
5. 验证标注缩略图是否自动加载成功

---

## 相关文件

- `ModelsForMap/SearchViewModel.swift`
- `View/MapPages/CustomMKAnnotationView.swift`
