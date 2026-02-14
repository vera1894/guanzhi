# 媒体上传/下载性能瓶颈全链路调查

**日期**: 2026-02-13
**角色**: Claude Code
**类型**: 调查报告

---

## 背景

用户反馈即使网络良好，发布观之需要约 1 分钟，查看未缓存的观之需要约 30 秒。对发布和查看两条完整链路进行代码级排查。

---

## 一、当前架构（根本瓶颈）

```
发布: iOS → multipart POST → EC2 后端 → 写入 EC2 本地磁盘
查看: iOS → https://onettoo.com/images/xxx → Nginx/Spring ResourceHandler → EC2 本地磁盘 → iOS
```

**所有媒体文件经过 EC2 单点中转**，EC2 实例的网络带宽是整个系统的硬上限。没有 CDN，没有 S3 直传。

---

## 二、发布链路瓶颈（~1 分钟）

### 瓶颈 1：多照片串行上传（影响最大）

**位置**: `MainToolbar.swift:291` `uploadNextPhoto()` 递归调用

- 每张照片的所有文件（图+视频+缩略图）上传完成后，才开始下一张
- 3 张照片 = 单张耗时 × 3，没有并行

### 瓶颈 2：文件经后端中转

**位置**: `GuanZhiController.java:109-115` → `FileUtil.java:39`

- iOS 通过 `POST /api/guan/uploadImage` 把文件 multipart 上传到后端
- 后端 `file.transferTo(dest)` 写到 EC2 本地磁盘
- 没有 S3 presigned URL 直传

### 瓶颈 3：LivePhoto 视频重封装

**位置**: `LivePhotoPackager.swift:111-169`

- `AVAssetExportSession(presetName: .Passthrough)` 即使不重新编码，也需要重封装 MOV 容器
- 单个 LivePhoto 处理耗时 30-45 秒（I/O + CPU）
- 在用户点发布后才开始处理，没有预处理

### 瓶颈 4：大文件主线程读取

**位置**: `MainToolbar.swift:361-363`

```swift
let pairedImageData = try Data(contentsOf: pairedImageURL)
let pairedVideoData = try Data(contentsOf: pairedVideoURL)
```

- 同步读取 100MB+ MOV 文件到内存，阻塞主线程

### 瓶颈 5：网络超时不合理

**位置**: `CertificatePinning.swift:184-185`

- `timeoutIntervalForRequest = 30` 秒，对大文件上传不够
- 100MB ÷ 5Mbps = 160 秒，远超 30 秒超时，会触发重试

### 发布流程时序

```
LivePhoto处理(30-45s) → 图片上传(5-8s) → 视频上传(8-15s) → 等完成
                                                              ↓
                                                      下一张照片(重复)
                                                              ↓
                                                    缩略图生成+上传(3-5s)
                                                              ↓
                                                    调用后端创建API(2-5s)
```

---

## 三、查看链路瓶颈（~30 秒）

### 瓶颈 1：下载原图

**位置**: `SearchViewModel.swift:1530` `downloadMediaFile()`

- 打开详情页直接下载完整 HEIC/JPG（3-10MB/张），没有先显示缩略图
- 上传时虽然生成了 thumbnail，但查看时没有用它做首屏显示

### 瓶颈 2：无 CDN 加速

**位置**: `ConfigurerAdapter.java:58`

```java
registry.addResourceHandler("/images/**").addResourceLocations("file:" + baseImagePath);
```

- Spring ResourceHandler 直接从本地磁盘提供文件
- 受 EC2 出口带宽限制（通常只有几百 Mbps，共享）

### 瓶颈 3：串行加载链

**位置**: `SearchViewModel.swift:1308-1406`

```
API 请求(1-2s) → 保存到本地 DB → 解析 mediaFiles → 下载文件(8-30s) → 创建 MediaItem → 渲染
```

- 严格串行，每一步等前一步完成

### 瓶颈 4：视频全量下载

**位置**: `SearchViewModel.swift:1487-1500`

- LivePhoto 的 MOV 视频也全量下载（可达 50-100MB）
- 同一个 mediaItem 的 photo 和 video 是并发下载的（✅ 这点做对了），但文件本身太大

### 查看流程时序

```
Share API(1-2s) → 解析 mediaFiles → 下载图片(8-15s) ─┐
                                     下载视频(15-30s) ─┤ 并发
                                                       ↓
                                              创建 MediaItem 渲染
```

---

## 四、关键代码位置索引

| 问题 | 文件 | 行号 |
|------|------|------|
| 发布入口 | MainToolbar.swift | 135-186 |
| 串行上传循环 | MainToolbar.swift | 271-577（uploadNextPhoto 递归） |
| 单文件上传 | MainToolbar.swift | 467-508（uploadFile） |
| LivePhoto 处理 | LivePhotoPackager.swift | 43-169 |
| 后端接收上传 | GuanZhiController.java | 109-115 |
| 后端存文件 | FileUtil.java | 23-46 |
| 后端提供静态文件 | ConfigurerAdapter.java | 55-58 |
| 查看详情加载 | SearchViewModel.swift | 1308-1406 |
| 媒体下载 | SearchViewModel.swift | 1463-1589 |
| 下载 URLSession 配置 | SearchViewModel.swift | 106-113 |
| 上传超时配置 | CertificatePinning.swift | 184-185 |
| 缩略图生成上传 | MainToolbar.swift | 510-559 |

---

## 五、耗时估算

### 发布（1 张 LivePhoto）

| 环节 | 耗时 |
|------|------|
| LivePhoto 视频重封装 | 30-45s |
| LivePhoto 图片元数据写入 | 5-10s |
| 图片上传（经后端中转） | 5-8s |
| 视频上传（经后端中转） | 8-15s |
| 缩略图生成 + 上传 | 3-5s |
| 后端 API 创建 Share | 2-5s |
| **总计** | **53-88s** |

### 查看（1 张图 + LivePhoto 视频）

| 环节 | 耗时 |
|------|------|
| Share API 请求 | 1-2s |
| 图片下载（3-10MB） | 8-15s |
| 视频下载（50MB，与图片并发） | 15-30s |
| MediaItem 创建 + 渲染 | 1-2s |
| **总计** | **17-34s** |
