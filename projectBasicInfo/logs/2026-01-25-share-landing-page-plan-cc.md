# H5 分享落地页实现规划

**文档版本**: v1.3
**日期**: 2026-01-26
**作者**: Claude Code
**类型**: 实现规划（MVP）
**更新说明**:
- v1.1: 修正图片路径、域名、字段命名，补充 Universal Links 和 App Store ID 配置
- v1.2: 补充 Universal Link 独立解析分支、coverImageUrl 拼接逻辑、公开查询路径说明
- v1.3: 补充 Universal Link 分支的"未登录缓存"策略

---

## 一、需求概述

### 1.1 用户需求

创建一个 H5 分享落地页，当用户分享「观之」到社交平台时，接收者可以：
1. 在浏览器中预览分享内容（图片、描述、地点）
2. 点击「在观之中查看」打开 App 或跳转 App Store
3. 点击「导航到这里」唤起 Apple Maps 导航

### 1.2 核心目标

| 优先级 | 目标 | 说明 |
|--------|------|------|
| P0 | 链接可打开 | `/s/{shareId}` 能正常渲染页面 |
| P0 | OG 卡片正确 | 微信/微博分享时显示标题、描述、封面图 |
| P0 | 按钮跳转正确 | Deep Link + App Store fallback |
| P1 | 导航功能 | Apple Maps 唤起 |
| P2 | 页面美观 | 复刻 iOS 端详情页风格 |

---

## 二、现状分析

### 2.1 已有资源

| 资源 | 状态 | 说明 |
|------|------|------|
| Deep Link | ✅ 已有 | `guanzhi://share/{shareId}` |
| Universal Link | ❌ 缺失 | 需要配置 AASA 文件 |
| 公开分享 API | ❌ 缺失 | 现有 `/guan/share/info` 需要登录 |
| H5 落地页 | ❌ 缺失 | 需要新建 |
| 图片公开访问 | ✅ 已有 | `/image/**` 已配置静态资源映射（注意：单数形式） |

### 2.2 技术栈现状

- **后端**: Spring Boot 2.6.3，端口 8085
- **前端**: Vue 3 管理后台（admin-web），Nginx 托管
- **域名**: `https://onettoo.com`（iOS Constants.BASE_HOST）
- **服务器 IP**: `52.83.127.15`
- **Nginx**: 已配置 `/guanzhi-admin/` 和 `/api/` 路由

> ⚠️ **重要**: 分享链接域名必须与资源域名统一使用 `onettoo.com`，避免跨域和图片加载问题。

### 2.3 Share 数据结构（后端 GuanzhiDO）

```java
private Long id;
private Long userId;
private String data;           // 分享文本内容（⚠️ iOS 端字段名也是 data）
private Double longitude;
private Double latitude;
private String address;        // 地址（⚠️ iOS 端字段名也是 address）
private String imagePath;      // 图片路径（逗号分隔）
private String title;          // 标题
private Integer fadeScore;     // 褪色度
private Integer deleted;       // 删除标记
private Integer commentCount;  // 评论数
private Integer checkinCount;  // 打卡数
// ... 其他字段
```

> ⚠️ **字段命名一致性**: 后端 DTO 必须保持与 iOS 端一致的字段名：
> - 分享文本：使用 `data`（不要用 `content`）
> - 地址：使用 `address`（不要用 `placeName`）

---

## 三、技术方案

### 3.1 整体架构

```
用户点击分享链接
      ↓
  https://{domain}/s/{shareId}
      ↓
  Nginx 路由到 /s/
      ↓
┌─────────────────────────────────────────┐
│ 后端 Controller (ShareLandingController)│
│   1. 查询 Share 公开信息                 │
│   2. 渲染 HTML（含 OG meta）             │
│   3. 返回完整 HTML 页面                  │
└─────────────────────────────────────────┘
      ↓
  浏览器渲染页面
      ↓
  用户点击按钮 → Deep Link / Apple Maps
```

### 3.2 为什么选择后端渲染 HTML

| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| 纯 SPA（Vue） | 复用技术栈 | 微信/微博无法抓取 OG | ❌ 不可行 |
| SSR（Nuxt/Next） | 现代化 | 新增技术栈，部署复杂 | ❌ 过度设计 |
| **后端渲染 HTML** | 简单直接，OG 必达 | 需要写少量模板 | ✅ 采用 |

**决策**: 使用 Spring Boot Thymeleaf 模板引擎，后端直接渲染 HTML 页面。

---

## 四、实现计划

### 4.1 后端改动

#### 4.1.1 新增公开分享详情 API

**接口**: `GET /public/share/{shareId}`
**认证**: 无需登录
**响应**:

```json
{
  "code": 0,
  "data": {
    "shareId": 12345,
    "title": "分享标题",
    "data": "分享描述文字...",
    "coverImageUrl": "https://onettoo.com/image/xxx.jpg",
    "address": "北京市朝阳区三里屯",
    "latitude": 39.9332,
    "longitude": 116.4531,
    "authorNickname": "用户昵称",
    "authorAvatar": "https://onettoo.com/image/avatar.jpg",
    "available": true
  },
  "msg": "success"
}
```

> ⚠️ **字段命名**: `data`（非 content）、`address`（非 placeName）必须与 iOS 端一致
> ⚠️ **图片路径**: 使用 `/image/`（单数形式），域名使用 `onettoo.com`

##### coverImageUrl 拼接逻辑（后端 DTO 必须实现）

iOS 端 `ResponsedShare` 使用 `imagePath`（逗号分隔的相对路径），但 H5 API 需要输出完整 URL 的 `coverImageUrl`。

**后端 DTO 需要显式拼接首图 URL**：

```java
// SharePublicDTO.java
public class SharePublicDTO {
    // ... 其他字段

    /**
     * 从 imagePath 拼接首图完整 URL
     * imagePath 格式: "abc123.jpg,def456.jpg,..."
     */
    public static SharePublicDTO fromDO(GuanzhiDO guanzhi, String baseUrl) {
        SharePublicDTO dto = new SharePublicDTO();
        // ... 其他字段赋值

        // ⚠️ 关键：拼接首图 URL
        String imagePath = guanzhi.getImagePath();
        if (imagePath != null && !imagePath.isEmpty()) {
            String firstImage = imagePath.split(",")[0].trim();
            dto.setCoverImageUrl(baseUrl + "/image/" + firstImage);
            // 结果: https://onettoo.com/image/abc123.jpg
        }

        return dto;
    }
}
```

> ⚠️ **不要返回相对路径**：如果 `coverImageUrl` 只返回 `abc123.jpg`，OG meta 和 H5 页面都无法显示图片。

**安全考虑**:
- 不返回 userId、手机号等敏感信息
- 被删除/违规/私密的分享返回 `available: false`
- 可选：添加限流（防止恶意爬取）

#### 4.1.2 新增 H5 落地页 Controller

**路由**: `GET /s/{shareId}`
**响应**: HTML 页面（含 OG meta）

```java
@Controller
public class ShareLandingController {

    @GetMapping("/s/{shareId}")
    public String shareLanding(@PathVariable Long shareId, Model model) {
        SharePublicDTO share = guanzhiService.getPublicShareInfo(shareId);

        if (share == null || !share.isAvailable()) {
            model.addAttribute("unavailable", true);
            return "share-unavailable";
        }

        model.addAttribute("share", share);
        return "share-landing";
    }
}
```

> ⚠️ **重要：getPublicShareInfo 必须走公开查询路径**
>
> H5 落地页是匿名访问（无登录 token），因此：
> - `getPublicShareInfo()` **不能**复用现有的登录态接口逻辑
> - 必须直接走 DAO 层查询，不依赖 `@LoginRequired` 或 token 校验
> - 如果复用登录态逻辑，H5 页面会返回 401/403 错误

```java
// GuanzhiServiceImpl.java
@Override
public SharePublicDTO getPublicShareInfo(Long shareId) {
    // ⚠️ 直接查 DAO，不走登录校验
    GuanzhiDO guanzhi = guanzhiMapper.selectById(shareId);

    if (guanzhi == null || guanzhi.getDeleted() == 1) {
        return null;  // 或返回 unavailable
    }

    // 转换为公开 DTO（过滤敏感字段）
    return SharePublicDTO.fromDO(guanzhi, "https://onettoo.com");
}
```

#### 4.1.3 新增文件清单

| 文件 | 路径 | 说明 |
|------|------|------|
| ShareLandingController.java | `modules/rest/` | H5 页面 Controller |
| SharePublicDTO.java | `modules/dto/` | 公开分享数据传输对象 |
| share-landing.html | `resources/templates/` | Thymeleaf 模板 |
| share-unavailable.html | `resources/templates/` | 不可用页面模板 |
| share-landing.css | `resources/static/css/` | 页面样式 |

#### 4.1.4 依赖添加

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-thymeleaf</artifactId>
</dependency>
```

### 4.2 H5 页面设计

#### 4.2.1 页面结构

```
┌─────────────────────────────────────────┐
│              [封面大图]                  │
│         （全宽，高度自适应）              │
├─────────────────────────────────────────┤
│  描述文字                                │
│  "这是一段分享的描述内容..."             │
├─────────────────────────────────────────┤
│  📍 北京市朝阳区三里屯                   │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │      在观之中查看                │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │      导航到这里                  │   │
│  └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

#### 4.2.2 OG Meta 标签

```html
<head>
    <meta property="og:title" content="${share.title ?: '观之分享'}" />
    <meta property="og:description" content="${share.data}" />
    <meta property="og:image" content="${share.coverImageUrl}" />
    <meta property="og:url" content="https://onettoo.com/s/${shareId}" />
    <meta property="og:type" content="article" />

    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="${share.title ?: '观之分享'}" />
    <meta name="twitter:description" content="${share.data}" />
    <meta name="twitter:image" content="${share.coverImageUrl}" />
</head>
```

> ⚠️ **注意**:
> - 描述字段使用 `share.data`（与 iOS 端一致）
> - `coverImageUrl` 必须是完整 URL：`https://onettoo.com/image/xxx.jpg`

### 4.3 按钮功能实现

#### 4.3.1 「在观之中查看」按钮

> ⚠️ **Deep Link 格式**:
> - ✅ 正确：`guanzhi://share/{shareId}`（path 形式，host=share, path=/{shareId}）
> - ❌ 错误：`guanzhi://share?id={shareId}`（query 形式，不会命中 iOS 解析）
>
> iOS 端解析位置：`guanzhiApp.swift:248-292`

```javascript
// App Store ID 配置（待填入实际值）
const APP_STORE_ID = 'XXXXXXXXXX';  // TODO: 填入实际 App Store ID

function openInApp() {
    const shareId = '${shareId}';
    // ⚠️ 必须使用 path 形式，不能用 query 形式
    const deepLink = 'guanzhi://share/' + shareId;
    const appStoreUrl = 'https://apps.apple.com/app/id' + APP_STORE_ID;

    // 尝试打开 App
    const startTime = Date.now();
    window.location.href = deepLink;

    // 2.5 秒后检查是否还在页面（未打开 App）
    setTimeout(function() {
        if (Date.now() - startTime < 3000) {
            // 用户仍在页面，说明 App 未安装
            window.location.href = appStoreUrl;
        }
    }, 2500);
}
```

**备选方案（更可靠）**:
```javascript
function openInApp() {
    const shareId = '${shareId}';
    const deepLink = 'guanzhi://share/' + shareId;
    const appStoreUrl = 'https://apps.apple.com/app/id' + APP_STORE_ID;

    // 使用 iframe 尝试打开 Deep Link
    const iframe = document.createElement('iframe');
    iframe.style.display = 'none';
    iframe.src = deepLink;
    document.body.appendChild(iframe);

    // 延迟跳转 App Store（作为 fallback）
    setTimeout(function() {
        window.location.href = appStoreUrl;
    }, 1500);
}
```

> ⚠️ **App Store ID 存放位置**:
> 建议在后端配置文件 `application.yml` 中添加：
> ```yaml
> app:
>   ios:
>     appStoreId: "XXXXXXXXXX"
> ```
> 然后在 Thymeleaf 模板中通过 `${appStoreId}` 注入。

#### 4.3.2 「导航到这里」按钮

```javascript
function navigateHere() {
    const lat = '${share.latitude}';
    const lng = '${share.longitude}';
    const address = encodeURIComponent('${share.address}');  // ⚠️ 使用 address 字段

    // Apple Maps URL（优先经纬度，带地点名）
    const mapsUrl = 'https://maps.apple.com/?daddr=' + lat + ',' + lng + '&q=' + address + '&dirflg=d';

    window.location.href = mapsUrl;
}
```

**备注**:
- `dirflg=d` 表示驾车导航
- 如果只有地址没有经纬度：`daddr=${encodedAddress}`
- ⚠️ 字段名使用 `address`（与 iOS 端一致）

### 4.4 Nginx 配置

```nginx
# 在现有 server block 中添加
location /s/ {
    proxy_pass http://127.0.0.1:8085;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

# 公开 API（如果需要单独暴露）
location /public/ {
    proxy_pass http://127.0.0.1:8085;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

### 4.5 iOS 端配合事项

#### 4.5.1 确认 Deep Link 路由

已有配置（guanzhiApp.swift）:
```swift
// 格式: guanzhi://share/{shareId}
if let shareId = Int64(pathComponents[1]) {
    navigationCoordinator.path.append(
        Route.shareDetailView(annotationID: "\(shareId)")
    )
}
```

**状态**: ✅ 已实现，无需改动

#### 4.5.2 分享功能改动

iOS 端分享时，需要生成 H5 链接而非 Deep Link：

```swift
// 分享时使用 H5 链接（使用 Constants.BASE_HOST 保持一致）
let shareURL = URL(string: "\(Constants.BASE_HOST)/s/\(shareId)")!
// 即：https://onettoo.com/s/{shareId}
let activityVC = UIActivityViewController(
    activityItems: [shareURL],
    applicationActivities: nil
)
```

> ⚠️ **域名一致性**: 必须使用 `Constants.BASE_HOST`（即 `https://onettoo.com`），避免硬编码其他域名或 IP。

#### 4.5.3 Universal Links（重要补充）

> ⚠️ **为什么需要 Universal Links**:
> - 微信、微博等社交 App 会拦截 custom scheme（如 `guanzhi://`）
> - 只有 Universal Links 才能在这些 App 内直接唤起目标 App
> - 不配置 Universal Links，分享到微信后点击「在观之中查看」将无响应

**配置步骤**:

##### 1. 服务器端 - AASA 文件

在服务器根目录创建 `/.well-known/apple-app-site-association`（无后缀）：

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.your.bundleid",
        "paths": ["/s/*"]
      }
    ]
  }
}
```

**Nginx 配置**:
```nginx
location /.well-known/apple-app-site-association {
    default_type application/json;
    alias /var/www/html/.well-known/apple-app-site-association;
}
```

##### 2. iOS 端配置

在 Xcode 的 **Signing & Capabilities** 中添加：
- Associated Domains: `applinks:onettoo.com`

在 `guanzhiApp.swift` 中处理 Universal Link：

> ⚠️ **重要：必须走独立解析分支**
> - 现有 `handleDeepLink` 只处理 `guanzhi://`（scheme=guanzhi, host=share）
> - Universal Link 的 URL 是 `https://onettoo.com/s/{shareId}`（scheme=https）
> - 如果把 Universal Link 直接传给 `handleDeepLink`，会被拒绝（scheme 不匹配）
> - **必须新增独立解析逻辑**，不能复用现有 `handleDeepLink`

```swift
.onOpenURL { url in
    // 独立分支 1: Universal Link (https://onettoo.com/s/{shareId})
    if url.scheme == "https" && url.host == "onettoo.com" {
        if url.pathComponents.count >= 3 && url.pathComponents[1] == "s" {
            let shareId = url.pathComponents[2]

            // ⚠️ 沿用"未登录就缓存"的策略
            if !appStateModel.isLoggedIn {
                // 缓存 deep link，登录后再处理
                pendingDeepLink = url
                return
            }

            // 已登录，直接导航
            if let id = Int64(shareId) {
                navigationCoordinator.path.append(
                    Route.shareDetailView(annotationID: "\(id)")
                )
            }
        }
        return
    }

    // 独立分支 2: Deep Link (guanzhi://share/{shareId}) - 复用现有逻辑
    handleDeepLink(url)
}
```

> ⚠️ **未登录缓存策略**：
> - 现有 `handleDeepLink` 有"未登录则缓存 deep link"的逻辑
> - Universal Link 分支**必须沿用**相同策略
> - 否则未登录时直接 `navigationCoordinator.path.append(...)` 可能导致丢失或崩溃

> ⚠️ **不要这样做**（会导致 Universal Link 无法解析）：
> ```swift
> // ❌ 错误：直接复用 handleDeepLink
> .onOpenURL { url in
>     handleDeepLink(url)  // Universal Link 的 scheme 是 https，会被拒绝
> }
> ```

##### 3. 前置条件

| 条件 | 状态 | 说明 |
|------|------|------|
| 正式域名 | ✅ 已有 | `onettoo.com` |
| HTTPS | ✅ 必须 | Universal Links 要求 HTTPS |
| AASA 文件可访问 | ❌ 待配置 | 必须返回 200，Content-Type: application/json |

**建议**: MVP 阶段可先使用 Deep Link fallback 方案，但 **建议尽快配置 Universal Links**，否则微信/微博分享体验较差。

---

## 五、安全与隐私

### 5.1 数据过滤

公开 API 只返回以下字段：
- shareId, title, data（描述，⚠️ 不是 content）
- coverImageUrl（首张图片，格式：`https://onettoo.com/image/xxx.jpg`）
- address, latitude, longitude（地点，⚠️ 不是 placeName）
- authorNickname, authorAvatar（可选）
- available（是否可用）

**不返回**:
- userId（内部 ID）
- 手机号、精确地址
- 其他敏感字段

### 5.2 内容可见性

| 状态 | 处理 |
|------|------|
| 正常 | 显示完整内容 |
| 已删除 | 显示「该内容不可用」 |
| 已举报/违规 | 显示「该内容不可用」 |
| 私密（如有） | 显示「该内容不可用」 |

### 5.3 限流（可选）

可在后端添加 IP 限流，防止恶意爬取：
- 同一 IP 每分钟最多 60 次请求
- 超限返回 429 Too Many Requests

---

## 六、域名问题

### 6.1 当前状态

- **正式域名**: `https://onettoo.com`（iOS Constants.BASE_HOST）
- **服务器 IP**: `52.83.127.15`

> ✅ 已有正式域名，可直接使用

### 6.2 域名一致性要求

| 资源 | 域名 | 说明 |
|------|------|------|
| 分享链接 | `https://onettoo.com/s/{id}` | H5 落地页 |
| 图片资源 | `https://onettoo.com/image/xxx.jpg` | 注意是 `/image/` 单数 |
| API 接口 | `https://onettoo.com/api/...` | 现有 API |
| Universal Link | `onettoo.com` | AASA 文件托管域名 |

> ⚠️ **重要**: 所有资源必须统一使用 `onettoo.com`，不要混用 IP 地址，否则会出现：
> - 跨域问题（CORS）
> - OG 图片无法抓取
> - Universal Links 无法生效

### 6.3 待确认事项

| 事项 | 状态 | 说明 |
|------|------|------|
| HTTPS 证书 | ⚠️ 待确认 | Universal Links 必须 HTTPS |
| ICP 备案 | ⚠️ 待确认 | 国内访问可能需要 |
| 微信白名单 | ⚠️ 待确认 | 分享到微信可能需要备案

---

## 七、改动文件清单

### 7.1 后端（Server/onettoo）

| 操作 | 文件路径 | 说明 |
|------|----------|------|
| 新增 | `pom.xml` | 添加 Thymeleaf 依赖 |
| 新增 | `src/main/java/.../rest/ShareLandingController.java` | H5 页面 Controller |
| 新增 | `src/main/java/.../dto/SharePublicDTO.java` | 公开数据 DTO |
| 修改 | `src/main/java/.../service/GuanzhiService.java` | 添加公开查询方法 |
| 修改 | `src/main/java/.../service/impl/GuanzhiServiceImpl.java` | 实现公开查询 |
| 新增 | `src/main/resources/templates/share-landing.html` | 落地页模板 |
| 新增 | `src/main/resources/templates/share-unavailable.html` | 不可用页面模板 |
| 新增 | `src/main/resources/static/css/share-landing.css` | 页面样式 |
| 修改 | `src/main/resources/application.yml` | Thymeleaf 配置（可选） |

### 7.2 Nginx

| 操作 | 说明 |
|------|------|
| 修改 | `/etc/nginx/nginx.conf` 添加 `/s/` 路由 |
| 修改 | `/etc/nginx/nginx.conf` 添加 `/.well-known/` 路由（Universal Links） |

### 7.3 服务器静态文件

| 操作 | 文件路径 | 说明 |
|------|----------|------|
| 新增 | `/.well-known/apple-app-site-association` | Universal Links AASA 文件 |

### 7.4 iOS 端

| 操作 | 文件 | 说明 |
|------|------|------|
| 修改 | ShareService.swift | 分享时使用 H5 链接 |
| 修改 | guanzhi.entitlements | 添加 Associated Domains |
| 修改 | guanzhiApp.swift | 处理 Universal Link（可选，增强体验） |

---

## 八、验收清单

| # | 测试项 | 预期结果 |
|---|--------|----------|
| 1 | 桌面浏览器打开 `/s/{id}` | 页面正常渲染 |
| 2 | iPhone Safari 打开 `/s/{id}` | 页面正常渲染，按钮可点击 |
| 3 | 点击「在观之中查看」（已安装） | 打开 App 并跳转到该分享详情页 |
| 4 | 点击「在观之中查看」（未安装） | 跳转 App Store |
| 5 | 点击「导航到这里」 | 打开 Apple Maps 并显示导航路线 |
| 6 | 微信分享链接 | 预览卡片显示标题、描述、封面图 |
| 7 | 访问已删除分享 | 显示「该内容不可用」页面 |

---

## 九、后续优化（非 MVP）

| 优先级 | 事项 | 说明 |
|--------|------|------|
| P1 | 正式域名 + HTTPS | 上线前必须 |
| P1 | Universal Link | 更好的打开体验 |
| P2 | 多图轮播 | 支持查看所有图片 |
| P2 | 视频预览 | 支持视频类型分享 |
| P3 | 评论预览 | 显示热门评论 |
| P3 | Android 支持 | Intent URL + Google Play |

---

## 十、时间线

| 阶段 | 内容 |
|------|------|
| 阶段 1 | 后端 API + 页面模板 |
| 阶段 2 | Nginx 配置 + 部署 |
| 阶段 3 | 测试验收 |
| 阶段 4 | iOS 端分享改造（可选） |

---

## 附录 A：App Store ID 配置

### A.1 获取 App Store ID

App Store ID 可在 App Store Connect 或 App Store 链接中找到：
- 格式：`https://apps.apple.com/app/id1234567890`
- ID 即 `1234567890` 部分

### A.2 配置位置

**后端配置** (`application.yml`):
```yaml
app:
  ios:
    appStoreId: "1234567890"  # TODO: 填入实际值
    bundleId: "com.your.bundleid"
    teamId: "XXXXXXXXXX"
```

**H5 页面使用**:
```javascript
const APP_STORE_ID = '[[${appStoreId}]]';  // Thymeleaf 注入
```

---

## 附录 B：关键路径对照表

| 类型 | 正确格式 | 错误格式 |
|------|----------|----------|
| 图片路径 | `/image/xxx.jpg` | `/images/xxx.jpg` |
| 分享链接 | `https://onettoo.com/s/{id}` | `http://52.83.127.15/s/{id}` |
| Deep Link | `guanzhi://share/{id}` | `guanzhi://share?id={id}` |
| API 字段（描述） | `data` | `content` |
| API 字段（地址） | `address` | `placeName` |

---

## 附录 C：Codex 审查问题修复清单

### v1.1 修复项

| # | 问题 | 状态 | 修复说明 |
|---|------|------|----------|
| 1 | 图片路径写错 `/images/` | ✅ 已修复 | 改为 `/image/`（单数） |
| 2 | 域名与 BASE_HOST 不一致 | ✅ 已修复 | 统一使用 `onettoo.com` |
| 3 | Deep Link 格式要与实际解析一致 | ✅ 已修复 | 明确使用 path 形式 |
| 4 | 公开分享 API 必须新增 | ✅ 已确认 | `/public/share/{shareId}` |
| 5 | App Store ID 存放位置 | ✅ 已补充 | `application.yml` 配置 |
| 6 | 缺少 Universal Link 说明 | ✅ 已补充 | 详细 AASA 配置步骤 |
| 7 | 分享字段命名不一致 | ✅ 已修复 | `data`/`address` |

### v1.2 补充项

| # | 问题 | 状态 | 修复说明 |
|---|------|------|----------|
| 8 | Universal Link 解析与 handleDeepLink 不兼容 | ✅ 已补充 | 必须走独立解析分支，不能复用 handleDeepLink |
| 9 | coverImageUrl 需要后端显式拼接 | ✅ 已补充 | imagePath → `https://onettoo.com/image/` + 首图 |
| 10 | getPublicShareInfo 必须走公开查询路径 | ✅ 已补充 | 直接查 DAO，不依赖登录 token |

### v1.3 补充项

| # | 问题 | 状态 | 修复说明 |
|---|------|------|----------|
| 11 | Universal Link 分支缺少未登录缓存逻辑 | ✅ 已补充 | 沿用"未登录就缓存 pendingDeepLink"策略 |

---

**文档已与项目代码对齐，可以执行实施。**
