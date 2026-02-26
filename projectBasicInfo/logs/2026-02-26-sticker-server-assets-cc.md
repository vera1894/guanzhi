# 贴纸资产服务端化

**日期**: 2026-02-26
**类型**: 功能开发 + 部署
**状态**: 完成
**版本**: v3.7.6

---

## 背景

贴纸图片原本打包在 iOS App bundle（xcassets/Stickers/），更新贴纸需要发布新版 App。本次将图片资产迁移到服务端，iOS 端在启动时检查版本并下载最新资产，实现无需更新 App 即可更换贴纸图片。

---

## 方案

### 数据流
```
服务端 /home/ec2-user/images/image/stickers/
    → Nginx → CloudFront CDN → iOS 客户端 Caches/Stickers/

App 启动 → StickerAssetService.preload()
    → GET /api/config/sticker-assets（ETag 检查）
    → 版本变化 → 并行下载 10 张 PNG
    → 写入 Caches/Stickers/{code}.png
    → 清除 StickerTextureCache（触发重新渲染）

StickerTextureCache.createTexture（.image case）
    → 优先读取 Caches/Stickers/{code}.png（本地磁盘）
    → 回退到 xcassets SVG
    → 回退到占位符
```

### PNG 格式
- 透明圆形背景，400×400px
- 从 SVG 嵌入的 base64 PNG 提取并优化
- 大小：123–173 KB/张，共约 1.4 MB

---

## 修改文件

### 后端
- `ConfigController.java`：新增 `GET /config/sticker-assets` endpoint
  - 无需登录（`@AnonymousAccess`）
  - ETag 缓存（`max-age=3600`）
  - 返回：`{ version, assets: [{code, iconUrl}] }`
  - 版本基于 iconUrl 内容 hash

### 数据库
- `tag_definition.icon_url` 更新 10 条记录
  - 格式：`https://onettoo.com/image/stickers/{code}.png`

### EC2 服务器
- 新增目录：`/home/ec2-user/images/image/stickers/`
- 上传 10 张透明 PNG（从 SVG 提取并压缩）

### iOS
- **新建** `guanzhi/View/Features/StickerKit/StickerAssetService.swift`
  - 单例，仿照 StickerNameService 设计
  - JSON 元数据缓存：`Documents/sticker_assets_cache.json`
  - 图片磁盘缓存：`Caches/Stickers/{code}.png`
  - `preload()`：App 启动时异步调用，ETag 检查 + 并行下载
  - `localURL(for code:)`：供 StickerTextureCache 查询本地路径
  - `clearLocalCache()`：供 SettingView 调用
- **修改** `StickerTextureCache.swift`
  - `.image` case：优先从磁盘 PNG 加载，回退到 xcassets
- **修改** `guanzhiApp.swift`
  - `init()` 中追加 `StickerAssetService.shared.preload()`
- **修改** `SettingView.swift`
  - `clearCache()` 追加清理 `Caches/Stickers/` + StickerTextureCache
  - `calculateCacheSize()` 追加统计 Stickers 目录大小
- **修改** `guanzhi.xcodeproj/project.pbxproj`
  - 将 `StickerAssetService.swift` 加入编译目标

---

## 部署

- 版本：v3.7.6
- API 验证：`https://onettoo.com/api/config/sticker-assets` → 200 OK
- 图片验证：`https://onettoo.com/image/stickers/like.png` → 200 OK（148KB）

---

## 注意事项

1. **`Services/` 目录不在 Xcode 项目组中**：`StickerKit/Services/` 是文件系统目录，pbxproj 中没有对应 Group。新文件需放到 `StickerKit/` 根目录并手动加入 pbxproj。
2. **`StickerNameService.swift` 存在两份**：根目录版本（在 pbxproj 中）和 `Services/` 版本（孤儿文件，未编译）。
3. **图片 URL 路径**：`/home/ec2-user/images/image/` → Nginx alias → `https://onettoo.com/image/`（注意目录结构是双 `image/`）。
