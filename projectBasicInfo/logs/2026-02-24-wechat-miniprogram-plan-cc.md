# 微信小程序实施日志

**日期**：2026-02-24
**状态**：代码编写完成，等待前置条件

## 完成的工作

### 阶段 1：后端 API（已完成）

**新建文件**：
1. `Server/onettoo/src/main/java/com/cloud/onettoo/modules/rest/MiniProgramController.java`
   - `GET /api/mp/share/{shareId}` — 分享详情（匿名）
   - `GET /api/mp/shares/nearby` — 附近分享列表（匿名）
   - `GET /api/mp/user/{userId}/shares` — 用户分享列表（匿名）
   - `GET /api/mp/user/{userId}/profile` — 用户公开信息（匿名）
2. `Server/onettoo/src/main/java/com/cloud/onettoo/modules/dto/ShareNearbyDTO.java` — 附近分享简化 DTO
3. `Server/onettoo/src/main/java/com/cloud/onettoo/modules/dto/UserPublicProfileDTO.java` — 用户公开信息 DTO
4. `Server/onettoo/src/main/resources/static/.well-known/apple-app-site-association` — Universal Links

**修改文件**：
5. `GuanzhiService.java` — 新增 `getPublicSharesNearby()` 接口方法
6. `GuanzhiServiceImpl.java` — 实现 `getPublicSharesNearby()`
7. `SharePublicDTO.java` — 新增 `authorId` 字段（小程序需要跳转用户主页）

### 阶段 2：微信小程序（已完成）

`wechat-miniprogram/` 目录，36 个文件：
- 4 个页面：index（地图）、detail（详情）、list（列表）、profile（用户主页）
- 3 个组件：share-card、media-viewer、app-guide
- 工具：api.js（API 封装）、coordinate.js（WGS-84 ↔ GCJ-02 坐标转换）
- 配置：app.json（tabBar、权限）、project.config.json、sitemap.json

### 阶段 3：iOS 微信 SDK 集成（已完成）

**新建文件**：
1. `guanzhi/WeChatShareHelper.swift` — 微信分享封装（小程序卡片 + 网页链接 + 图片压缩）

**修改文件**：
2. `Podfile` — 新增 `WechatOpenSDK-XCFramework`
3. `guanzhi/Info.plist` — 新增微信 URL Scheme + LSApplicationQueriesSchemes
4. `guanzhi/guanzhiApp.swift` — AppDelegate 注册微信 SDK + WXApiDelegate 回调
5. `guanzhi/View/SharePages/ShareDetailView.swift` — 新增「分享」按钮（微信好友/复制链接/系统分享）

## 占位符清单（需用户完成注册后替换）

| 占位符 | 所在文件 | 说明 |
|--------|---------|------|
| `{WX_APP_ID}` | Info.plist, guanzhiApp.swift | 微信开放平台移动应用 AppID |
| `{GH_ORIGINAL_ID}` | WeChatShareHelper.swift | 小程序原始 ID（`gh_` 开头）|
| `{TEAM_ID}` | apple-app-site-association | Apple Team ID |
| `{APP_STORE_ID}` | wechat-miniprogram/app.js | App Store 应用 ID |
| `{MP_APPID}` | wechat-miniprogram/project.config.json | 小程序 AppID |

## 代码审查修正

- 修正小程序字段名与后端 API 返回不一致（`mediaFiles` → `mediaItems`，`content` → `data`，`userAvatar` → `authorAvatar`，`nickname` → `authorNickname`，`coverUrl` → `coverImageUrl`）
- 修正 apple-app-site-association 中 Bundle ID（`com.cloud.guanzhi` → `com.zichen.guanzhi`）
- 新增 `/api/mp/user/{userId}/shares` API（原方案通过 nearby API 按 userId 过滤不合理）
- SharePublicDTO 新增 `authorId` 字段
- 移除小程序中不存在的贴纸数据引用

## 待完成（需用户操作）

1. 完成微信公众平台小程序注册 + 开放平台移动应用注册
2. 替换所有占位符
3. 运行 `pod install`
4. Nginx 配置 `/.well-known/apple-app-site-association` 返回 `application/json`
5. 部署后端 → 小程序审核发布 → iOS 新版本提交 App Store
