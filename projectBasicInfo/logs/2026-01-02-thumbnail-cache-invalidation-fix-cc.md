# 主页缩略图缓存失效问题修复

**日期**: 2026-01-02
**操作者**: Claude Code (cc)
**类型**: Bug 修复
**状态**: 已完成

---

## 一、问题描述

### 现象

在主页地图上，部分分享（如 ID 48、44、41）的缩略图一直显示 loading 状态，无法正常加载。需要反复点击进入分享详情再退出，才可能显示缩略图。

### 控制台日志特征

```
使用分享 ID 48 的第一张照片的本地 URL
Added annotation for share ID: 48
...
创建媒体项，照片文件已下载，本地 URL：file:///.../48_20240921051548.652.jpg
⚠️ 缓存文件不存在，清除 localURL 以触发重新下载
```

---

## 二、根因分析

### 问题链

```
1. 用户之前访问过分享，媒体文件被下载到 Caches 目录
2. MediaFile 数据库记录了 localURL（表示已下载）
3. iOS 系统自动清理 Caches 目录（存储空间不足时）
4. 主页加载缩略图时：
   - getThumbnailURL() 查询数据库 → 发现有 localURL
   - 直接返回 localURL → 但实际文件已被删除
   - 图片组件尝试加载本地文件 → 文件不存在 → 一直 loading
5. 用户进入详情页时：
   - createMediaItem() 检查文件存在性
   - 发现不存在 → 清除 localURL → 触发重新下载
   - 返回主页后缩略图正常（因为文件刚被重新下载）
```

### 核心问题

`SearchViewModel.getThumbnailURL()` 函数直接返回数据库中的 `localURL`，没有验证文件是否真实存在。

```swift
// 问题代码
if let localURL = firstPhotoMediaFile.localURL {
    print("使用分享 ID \(shareId) 的第一张照片的本地 URL")
    return localURL  // ❌ 未验证文件是否存在
}
```

---

## 三、修复方案

### 代码变更

**文件**: `guanzhi/ModelsForMap/SearchViewModel.swift`

**修改位置**: `getThumbnailURL(for:)` 函数

**修复逻辑**:

```swift
if let localURL = thumbnailMediaFile.localURL {
    // 检查本地文件是否真实存在（iOS 可能已清理 Caches 目录）
    if FileManager.default.fileExists(atPath: localURL.path) {
        return localURL
    } else {
        // 文件不存在，清除 localURL 并使用远程 URL
        print("⚠️ 缩略图缓存已失效，使用远程 URL: shareId=\(shareId)")
        thumbnailMediaFile.localURL = nil
        if let url = thumbnailMediaFile.url {
            return url
        }
    }
}
```

### 修复范围

1. **缩略图类型媒体文件** (line 963-982)
2. **照片类型媒体文件** (line 996-1016)

两处都添加了 `FileManager.default.fileExists(atPath:)` 检查。

---

## 四、技术要点

### iOS Caches 目录特性

- 路径: `Library/Caches/`
- 特点: iOS 会在设备存储空间不足时自动清理
- 影响: 之前下载的媒体文件可能被删除，但数据库记录仍存在

### 防御性编程原则

对于缓存文件，**永远不要假设文件存在**。即使数据库记录了路径，也要验证实际文件。

### 类似问题的其他位置

`createMediaItem()` 方法中已有类似检查逻辑，这也是为什么进入详情页后能触发重新下载的原因。

---

## 五、Git 提交

```
5c05031 修复主页缩略图 loading 问题：添加缓存文件存在性检查
```

---

## 六、测试验证

修复后预期行为：

1. 缩略图缓存有效 → 使用本地文件（快）
2. 缓存被清理 → 自动回退到远程 URL（稍慢但正常显示）
3. 不再出现一直 loading 的情况

---

## 七、相关文件

| 文件 | 说明 |
|------|------|
| `guanzhi/ModelsForMap/SearchViewModel.swift` | 主页 ViewModel，包含 getThumbnailURL() |
| `guanzhi/View/FrontPages/CustomAnnotation.swift` | 地图标注，使用 getThumbnailURL() 获取缩略图 |
