# 媒体上传/下载性能优化 — 实施记录

**日期**: 2026-02-13
**角色**: Claude Code
**状态**: 阶段一 iOS 客户端优化完成

---

## 背景

用户反馈发布观之需约 1 分钟、查看未缓存观之需约 30 秒。全链路调查发现核心瓶颈：
- 主图无压缩直传原始相机输出（3-8MB）
- 多照片串行上传
- 查看时直接下载原图，未利用已有缩略图做首屏

## 修改的文件

### 1. `MainToolbar.swift` — 上传优化

**1.1 上传前图片压缩**
- 新增 `compressImageForUpload(data:) -> Data` 方法
- 缩放到最大 2048px 边长 + JPEG 0.7 压缩质量
- 普通照片和 LivePhoto 的 HEIC 图片都应用压缩
- 预期：单张从 3-8MB 降到 300-800KB

**1.2 多照片并行上传**
- 将递归串行的 `uploadNextPhoto()` 重构为 `DispatchGroup` 并行上传
- 所有照片同时开始上传，用 `NSLock` 保护线程安全的 `imagePaths` 收集
- 每张 LivePhoto 内部的图片+视频仍然并行（`photoDispatchGroup`）
- 所有照片完成后再上传缩略图
- 预期：3 张照片从 45-60s 降到 15-20s

**1.4 上传超时调整**
- 创建独立的 `uploadSession`，`timeoutIntervalForRequest = 120`（原 30s）
- 避免大文件上传时不必要的超时重试

### 2. `SearchViewModel.swift` — 下载优化

**1.3 缩略图优先显示**
- `MediaItemWrapper` 新增 `thumbnailFile` 属性
- `parseMediaFiles` 中将 thumbnail 文件关联到对应的 wrapper
- `downloadMediaFiles` 重构为两阶段：
  - 阶段一：快速下载所有缩略图，用缩略图数据创建 `Photo(isProxy: true)` 供 UI 立即显示
  - 阶段二：后台下载所有原图/视频，完成后用 `createMediaItem` 替换缩略图
- 预期：首屏时间从 15-30s 降到 1-3s

## 未实施（阶段二）

- Nginx gzip 压缩和静态文件缓存头 — 需要 SSH 到服务器操作
- S3 直传 + CloudFront CDN — 更大架构改动

## 预期效果

| 场景 | 优化前 | 优化后 |
|------|--------|--------|
| 发布 1 张照片 | ~60s | ~10-15s |
| 发布 3 张照片 | ~120-180s | ~15-25s |
| 查看首屏 | ~30s | ~1-3s（缩略图） |

## 验证方式

- Xcode console 中观察 `📦 图片压缩:` 日志确认压缩效果
- 观察 `🖼️ 缩略图首屏显示:` 日志确认缩略图优先生效
- 观察 `✅ 所有照片并行上传完成` 日志确认并行上传
- 对比优化前后的实际上传/查看耗时
