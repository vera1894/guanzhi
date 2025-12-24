# iOS 贴纸名称动态加载实现

**日期**: 2025-12-24
**作者**: Claude Code
**类型**: 新功能

---

## 背景

之前贴纸名称（displayName）是硬编码在 iOS 客户端的 `StickerDefinition.swift` 中，无法动态更新。需要实现从服务器获取贴纸名称的机制，支持缓存和回退。

---

## 实现方案

### 后端 API

```
GET /api/config/sticker-names
```

**响应格式**：
```json
{
  "respCode": 0,
  "datas": {
    "version": "202512240123",
    "names": {
      "LIKE": "赞同",
      "NEUTRAL": "无感",
      "MIJING": "秘境",
      "ZHENXIU": "珍馐",
      ...
    }
  }
}
```

**特性**：
- 无需登录（`@AnonymousAccess`）
- 支持 ETag + 304 Not Modified
- Cache-Control: max-age=86400

### iOS 实现

#### 新建文件

| 文件 | 说明 |
|------|------|
| `StickerKit/Services/StickerNameService.swift` | 贴纸名称服务单例 |

#### 核心功能

1. **API 调用**：请求 `/api/config/sticker-names`
2. **ETag 缓存**：发送 `If-None-Match`，处理 304 响应
3. **本地持久化**：缓存保存到 `Documents/sticker_names_cache.json`
4. **24 小时有效期**：缓存有效期内跳过网络请求
5. **优雅降级**：网络失败时使用本地缓存或硬编码默认值

#### 修改的文件

| 文件 | 修改内容 |
|------|----------|
| `StickerKind.swift` | 添加 `dynamicDisplayName` 计算属性 |
| `StickerDefinition.swift` | 添加 `dynamicDisplayName` 计算属性 |
| `StickerSummaryItem.swift` | 构造器使用 `dynamicDisplayName` |
| `StickerSpriteFactory.swift` | 贴纸标签使用动态名称 |
| `StickerTextureCache.swift` | 占位符纹理使用动态名称 |
| `StickerPage.swift` | UI 文字使用动态名称 |
| `StickerAvailability.swift` | 错误提示使用动态名称 |
| `ShareInteractionViewModel.swift` | `UsedStickerInfo` 和错误提示使用动态名称 |
| `guanzhiApp.swift` | 启动时调用 `StickerNameService.shared.preload()` |

---

## 数据流程

```
App 启动
    ↓
StickerNameService.preload()  [异步，不阻塞启动]
    ↓
从磁盘加载缓存（如有）
    ↓
检查缓存是否过期（24小时）
    ↓
[过期] → 请求 GET /api/config/sticker-names
         ├── [200] → 更新缓存，保存到磁盘
         ├── [304] → 仅更新时间戳
         └── [失败] → 继续使用旧缓存
    ↓
UI 调用 dynamicDisplayName
    ↓
从 StickerNameService 获取名称
    ├── [有缓存] → 返回服务器名称
    └── [无缓存] → 返回硬编码默认值
```

---

## 使用方式

### 获取动态名称

```swift
// 方式 1：从 StickerKind
let name = stickerKind.dynamicDisplayName

// 方式 2：从 StickerDefinition
let name = stickerDefinition.dynamicDisplayName

// 方式 3：直接调用服务
let name = StickerNameService.shared.getName(for: "MIJING", default: "秘境")
```

### 强制刷新

```swift
await StickerNameService.shared.forceRefresh()
```

---

## 本地缓存结构

**文件路径**：`Documents/sticker_names_cache.json`

```json
{
  "names": {
    "LIKE": "赞同",
    "NEUTRAL": "无感",
    ...
  },
  "version": "202512240123",
  "etag": "\"abc123\"",
  "loadTime": "2025-12-24T12:00:00Z"
}
```

---

## 注意事项

1. **线程安全**：`StickerNameService` 的 `loadNames` 方法标记为 `@MainActor`
2. **启动性能**：预加载是异步的，不会阻塞 App 启动
3. **首次启动**：首次启动时可能没有缓存，会使用硬编码默认值，后台加载完成后下次使用生效
4. **Debug 日志**：使用 `#if DEBUG` 包裹，Release 版本不会打印

---

## 相关变更

- 后端：新增 `ConfigController.java`
- 项目文档：更新 `01_PROJECT_OVERVIEW.md` v2.0
