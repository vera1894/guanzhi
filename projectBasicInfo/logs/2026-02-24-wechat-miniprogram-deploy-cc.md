# 微信小程序 — 后端部署 & Nginx 配置

**日期**：2026-02-24
**角色**：Claude Code

## 背景

为观之 App 添加微信小程序支持。本次完成开发侧部署工作。

## 完成的工作

### 1. 后端 v3.8.0 部署

新增文件：
- `MiniProgramController.java` — 小程序匿名 API（`@RequestMapping("/mp")`）
- `ShareNearbyDTO.java` — 附近分享简化 DTO
- `UserPublicProfileDTO.java` — 用户公开信息 DTO
- `SharePublicDTO.java` — 新增 `authorId` 字段

新增 API 端点（全部 `@AnonymousAccess`）：
- `GET /api/mp/share/{shareId}` — 分享详情
- `GET /api/mp/shares/nearby` — 附近分享列表
- `GET /api/mp/user/{userId}/shares` — 用户分享列表
- `GET /api/mp/user/{userId}/profile` — 用户公开信息

### 2. Nginx 配置

- 添加 `/.well-known/apple-app-site-association` location 到三个 server 块（80 onettoo.com, 443, 80 catch-all）
- AASA 文件存放于 `/var/www/html/.well-known/apple-app-site-association`

### 3. 小程序代码

36 个文件，包含：
- 4 个页面：index（地图）、detail（详情）、list（列表）、profile（用户主页）
- 3 个组件：share-card、media-viewer、app-guide
- 工具：api.js（API 封装）、coordinate.js（坐标转换）

### 4. iOS 微信 SDK 集成

- Podfile 添加 `WechatOpenSDK-XCFramework`
- Info.plist 添加微信 URL Scheme 和 LSApplicationQueriesSchemes
- guanzhiApp.swift 注册微信 SDK 和处理回调
- WeChatShareHelper.swift 封装分享逻辑
- ShareDetailView.swift 添加分享按钮

## 遇到的问题

### 问题 1：API 401 Unauthorized

**现象**：小程序 API 返回 401
**根因**：Nginx 的 `/api/` 规则使用 `proxy_pass http://onettoo/;`（末尾斜杠），会剥离 `/api` 前缀。Controller 原本使用 `@RequestMapping("/api/mp")`，Nginx 剥离后变成 `/mp/...`，后端找不到 `/api/mp/...` 匹配。
**修复**：Controller 改为 `@RequestMapping("/mp")`

### 问题 2：部署未生效

**现象**：修复后重新部署仍然 401
**根因**：systemd 服务运行的是 `/home/ec2-user/current/app.jar`，但我部署到了 `/home/ec2-user/onettoo/releases/v3.8.0/onettoo.jar` — 完全不同的路径和文件名
**修复**：`cp onettoo.jar /home/ec2-user/current/app.jar && systemctl restart onettoo`

### 问题 3：AASA 文件 404

**现象**：`/.well-known/apple-app-site-association` 返回 404
**根因**：`@EnableWebMvc` 禁用了 Spring Boot 静态资源服务，Nginx 也没有对应 location
**修复**：将文件放到 `/var/www/html/.well-known/`，Nginx 添加 `location` 配置并设置 `default_type application/json`

## 待办

- [ ] 用户手动执行 `pod install`
- [ ] 微信开发者工具上传小程序并提交审核
- [ ] iOS Xcode 构建测试
