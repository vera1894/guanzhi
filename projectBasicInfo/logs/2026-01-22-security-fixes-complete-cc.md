# 公测前安全修复完成报告

**日期**: 2026-01-22
**执行者**: Claude Code
**状态**: P0/P1/P2/P3 全部完成

---

## 修复总览

| 优先级 | 问题数 | 状态 |
|--------|--------|------|
| P0 严重 | 7 | ✅ 全部完成 |
| P1 高危 | 5 | ✅ 全部完成 |
| P2 中危 | 5 | ✅ 全部完成 |
| P3 低危 | 5 | ✅ 全部完成（框架就绪，部分需配置后启用）|

---

## P0 级修复详情

### P0-1: 移除管理后台测试后门
- **文件**: `admin-web/src/views/Login.vue`
- **修改**: 移除硬编码的测试账号 `admin/123456` 和 `mock-admin-token`

### P0-2: iOS 测试登录编译宏隔离
- **文件**: `guanzhi/View/LoginViews/LogInView.swift`
- **修改**: 使用 `#if APPSTORE_REVIEW` 编译宏隔离测试登录通道
- **效果**: 正式渠道版本不包含测试入口代码

### P0-3: 移除硬编码凭证
- **文件**: `guanzhi/Data/Constants.swift`
- **修改**:
  - AMAP_API_KEY 迁移到 `Secrets.xcconfig` + `Info.plist`
  - 新建 `Secrets.xcconfig.example` 模板文件
- **新增文件**: `guanzhi/Configuration/Secrets.xcconfig.example`

### P0-4: 移除敏感日志
- **文件**: `UserLoginModel.swift`, `NetworkService.swift`, `guanzhiApp.swift` 等
- **修改**: 移除 Token、手机号、设备 Token 的 print 输出

### P0-5: Token 存储迁移到 Keychain
- **新增文件**: `guanzhi/ModelsForNetwork/KeychainService.swift`
- **修改文件**: `UserLoginModel.swift` (OTOLoginStatusManager)
- **实现**:
  - 新建 `KeychainService` 封装 Keychain 操作
  - 自动迁移旧版 UserDefaults 中的 Token
  - 支持 `save`/`getString`/`delete`/`exists` 操作

### P0-6: 后端敏感配置迁移到环境变量
- **新增文件**: `Server/onettoo/.env.example`
- **修改文件**: `application.yml`, `application-prod.yml`
- **环境变量**:
  - `JWT_SECRET` - JWT 密钥
  - `KNIFE4J_USER`/`KNIFE4J_PWD` - API 文档认证
  - `ADMIN_PHONE` - 管理员手机号
  - `APNS_*` - 推送配置

### P0-7: 修复生产运行时崩溃点
- **PhotosPreview.swift**: 修复 `onDispose` 闭包类型错误
- **SearchViewModel.swift**: `.first!` 改为 `guard let` 安全解包
- **MovieCapture.swift**: `delegate!` 改为安全赋值模式

---

## P1 级修复详情

### P1-1: 关闭生产环境调试工具
- **文件**: `application-prod.yml`, `SecurityConfig.java`
- **修改**:
  - Druid 监控 `stat-view-servlet.enabled: false`
  - 注释 `/druid/**` 的 `permitAll()` 配置

### P1-2: 收敛 CORS 配置
- **文件**: `ConfigurerAdapter.java`, `application-prod.yml`
- **修改**:
  - `allowedOriginPatterns("*")` 改为配置化域名列表
  - `allowedMethods("*")` 改为 `GET, POST, PUT, DELETE, OPTIONS`
  - 新增 `CORS_ORIGINS` 环境变量

### P1-3: 修复内存泄漏
- **VideoEngine.swift**: 保存 NotificationCenter observer token，cleanup 中移除
- **ShareDetailView.swift**: 闭包使用 `[weak wrapper]` 避免循环引用
- **SearchViewModel.swift**: 添加 `deinit` 清理 Combine 订阅

### P1-4: 修复 @MainActor 缺失
- **AppStateModel.swift**: 添加 `@MainActor` 标记
- **ToastManager.swift**: 添加 `@MainActor` 标记

### P1-5: 相机模块容错处理
- **DeviceLookup.swift**: `fatalError` 改为日志警告 + 返回空数组
- **MovieCapture.swift**: `fatalError` 改为日志警告 + 提前返回

---

## P2 级修复详情

### P2-1: Token 过期检测
- **文件**: `UserLoginModel.swift`, `NetworkService.swift`, `NetworkMonitor.swift`
- **实现**:
  - 添加 `isTokenExpired()` JWT 解析（无法解析时假设未过期）
  - 添加 `.tokenExpired` 通知
  - 401 响应自动发送通知

### P2-2: 分享/举报功能处理
- **文件**: `ShareDetailView.swift`
- **修改**:
  - 移除未实现的"分享至"按钮
  - "举报"改为显示"功能即将上线"提示

### P2-3: 完善错误处理
- **文件**: `NetworkService.swift`
- **修改**:
  - `OTONetworkError` 添加 `unauthorized`/`forbidden`/`notFound`/`serverError`
  - 实现 `LocalizedError` 协议提供用户友好错误描述

### P2-4: 清理测试文件
- **删除文件**: `guanzhi/View/UIElement/test.swift`

### P2-5: 调试日志条件输出
- **新增文件**: `guanzhi/Support/Logger.swift`
- **功能**:
  - `Logger.log()`/`error()`/`warning()`/`network()` 静态方法
  - 仅 DEBUG 模式输出
  - `debugLog()` 全局便捷函数
- **修改文件**: `UserLoginModel.swift`, `NetworkService.swift` 关键日志用 `#if DEBUG` 包裹

---

## 新增文件清单

| 文件路径 | 用途 |
|----------|------|
| `guanzhi/ModelsForNetwork/KeychainService.swift` | Keychain 安全存储封装 |
| `guanzhi/Support/Logger.swift` | 统一日志工具（仅 DEBUG） |
| `guanzhi/Configuration/Secrets.xcconfig.example` | 敏感配置模板 |
| `Server/onettoo/.env.example` | 后端环境变量模板 |

---

## 修改文件清单

### iOS 客户端
- `guanzhi/View/LoginViews/LogInView.swift`
- `guanzhi/Data/Constants.swift`
- `guanzhi/ModelsForNetwork/UserLoginModel.swift`
- `guanzhi/ModelsForNetwork/NetworkService.swift`
- `guanzhi/ModelsForNetwork/NetworkMonitor.swift`
- `guanzhi/ModelsForMap/SearchViewModel.swift`
- `guanzhi/ModelsForMap/VideoEngine.swift`
- `guanzhi/View/SharePages/ShareDetailView.swift`
- `guanzhi/AppStateModel.swift`
- `guanzhi/View/UIElement/NotificationStyles/ToastManager.swift`
- `guanzhi/CaptureFunctions/DeviceLookup.swift`
- `guanzhi/CaptureFunctions/MovieCapture.swift`
- `guanzhi/guanzhiApp.swift`

### 后端
- `Server/onettoo/src/main/resources/application.yml`
- `Server/onettoo/src/main/resources/application-prod.yml`
- `Server/onettoo/.../SecurityConfig.java`
- `Server/onettoo/.../ConfigurerAdapter.java`

### 管理后台
- `admin-web/src/views/Login.vue`

---

## 验证清单

- [x] iOS 客户端编译通过
- [x] 网络请求正常工作
- [x] 登录功能正常
- [x] Token 存储在 Keychain
- [x] 后端部署验证（环境变量已配置，服务已重启）
- [x] 管理后台部署验证（已重新构建并部署）
- [x] Druid 监控已关闭（返回 404）
- [x] Swagger UI 已关闭（返回 404）
- [x] Knife4j 已关闭（无法访问）
- [x] CORS 配置已收敛（通过外部配置文件生效）

---

## P3 级修复详情（长期优化）

### P3-1: 改进缓存管理
- **文件**: `ModelsForMap/SearchViewModel.swift` (ImageCache 类)
- **修改**:
  - 添加 `totalCostLimit = 50MB` 内存限制
  - 添加低内存警告时自动清理 (`didReceiveMemoryWarningNotification`)
  - 添加 App 进入后台时重置通知记录
  - `setImage()` 方法计算图片内存 cost

### P3-2: 统一输入验证库
- **新增文件**: `guanzhi/Support/InputValidator.swift`
- **功能**:
  - `validatePhone()` - 手机号验证
  - `validateSMSCode()` - 验证码验证
  - `validateNickname()` - 昵称验证
  - `validateComment()` - 评论内容验证
  - `validateShareTitle()` - 标题验证
  - `sanitize()` - 过滤危险字符
  - String 扩展便捷方法

### P3-3: 请求签名机制（客户端部分）
- **新增文件**: `guanzhi/ModelsForNetwork/RequestSigner.swift`
- **功能**:
  - HMAC-SHA256 签名算法
  - 签名内容：method + path + timestamp + nonce + body_hash
  - 防重放攻击（时间戳验证）
  - `URLRequest.addSignatureHeaders()` 扩展
- **状态**: 客户端已就绪，需后端实现验签后启用

### P3-4: HTTPS 证书固定
- **新增文件**: `guanzhi/ModelsForNetwork/CertificatePinning.swift`
- **功能**:
  - 公钥 SHA256 Hash 固定（支持多证书轮换）
  - 域名白名单控制
  - `PinnedURLSession.shared` 便捷访问
  - 系统验证 + 公钥验证双重校验
- **状态**: 框架已就绪，需配置服务器公钥 Hash 后启用

### P3-5: 修复 Preview-only 崩溃点
- **文件**: `View/MyPages/MyView.swift`, `View/MyPages/OthersView.swift`
- **修改**: `try!` 改为 `do-catch`，失败时显示错误提示

---

## 新增文件清单（含 P3）

| 文件路径 | 用途 |
|----------|------|
| `guanzhi/ModelsForNetwork/KeychainService.swift` | Keychain 安全存储封装 |
| `guanzhi/Support/Logger.swift` | 统一日志工具（仅 DEBUG） |
| `guanzhi/Support/InputValidator.swift` | 统一输入验证库 |
| `guanzhi/ModelsForNetwork/RequestSigner.swift` | API 请求签名机制 |
| `guanzhi/ModelsForNetwork/CertificatePinning.swift` | HTTPS 证书固定 |
| `guanzhi/Configuration/Secrets.xcconfig.example` | 敏感配置模板 |
| `Server/onettoo/.env.example` | 后端环境变量模板 |

---

## 后端待办事项

以下是后端需要完成的工作，才能完全启用安全修复：

### 必做（部署前）✅ 全部完成

| 任务 | 说明 | 状态 |
|------|------|------|
| 配置生产环境变量 | 服务器使用 `/home/ec2-user/.env` + 外部 `application-prod.yml` | ✅ 已完成 |
| 重启后端服务 | 使用 `systemctl restart onettoo` 应用新配置 | ✅ 已完成（2026-01-22） |
| 重新部署管理后台 | 重新构建 `admin-web` 并部署到服务器，移除测试后门 | ✅ 已完成（2026-01-22） |
| 验证 Druid 关闭 | `/druid/**` 路径返回 404 | ✅ 已验证 |
| 验证 Swagger 关闭 | `/swagger-ui.html` 返回 404 | ✅ 已验证 |
| 验证 Knife4j 关闭 | `/doc.html` 无法访问 | ✅ 已验证 |
| 验证 CORS 配置 | 通过外部配置文件 `application-prod.yml` 配置 | ✅ 已配置 |

### 可选（P3 加固项）

| 任务 | 说明 | 状态 |
|------|------|------|
| 实现请求签名验签 | 后端实现 HMAC-SHA256 验签拦截器 | ❌ 待实现 |
| 获取服务器公钥 Hash | 用于 iOS 证书固定配置 | ❌ 待获取 |

---

### 环境变量配置详情

在服务器上创建 `/etc/onettoo/.env` 文件：

```bash
# JWT 配置
JWT_SECRET=your-secure-jwt-secret-key-here

# Knife4j API 文档认证（生产环境建议关闭或使用强密码）
KNIFE4J_USER=admin
KNIFE4J_PWD=strong-password-here

# 管理员手机号
ADMIN_PHONE=your-admin-phone

# APNs 推送配置
APNS_TEAM_ID=your-team-id
APNS_KEY_ID=your-key-id
APNS_PRIVATE_KEY_PATH=/path/to/AuthKey.p8
APNS_BUNDLE_ID=com.onettoo

# CORS 允许的来源（逗号分隔）
CORS_ORIGINS=http://localhost:5173,http://52.83.127.15
```

确保 systemd 服务配置 (`/etc/systemd/system/onettoo.service`) 包含：
```ini
[Service]
EnvironmentFile=/etc/onettoo/.env
```

---

### 请求签名验签实现指南（后端）

iOS 客户端已实现签名生成，后端需要实现以下验签逻辑：

**签名 Headers**:
- `X-Signature`: HMAC-SHA256 签名（Hex 编码）
- `X-Timestamp`: Unix 时间戳（秒）
- `X-Nonce`: 随机字符串（UUID 去横线）

**签名算法**:
```java
String signatureString = String.join("\n",
    method.toUpperCase(),    // GET, POST, etc.
    path,                    // /api/xxx
    timestamp,               // Unix timestamp
    nonce,                   // UUID
    bodyHash                 // SHA256(requestBody)
);
String signature = HMAC_SHA256(signatureString, secretKey);
```

**验签要点**:
1. 验证时间戳在 5 分钟内（防重放）
2. 验证 nonce 未使用过（Redis 存储，5分钟过期）
3. 重新计算签名并比对

---

### 获取服务器公钥 Hash（用于证书固定）

在服务器上执行：
```bash
openssl s_client -connect 52.83.127.15:443 2>/dev/null | \
openssl x509 -pubkey -noout | \
openssl pkey -pubin -outform DER | \
openssl dgst -sha256 -binary | base64
```

将输出的 Base64 字符串配置到 iOS 客户端的 `CertificatePinningManager.shared.pinnedPublicKeyHashes` 数组中。

---

## 后续建议

1. **后端部署**: 需要在服务器上配置 `.env` 文件，参考上述详情
2. **管理后台**: 重新构建并部署以移除测试后门
3. **启用请求签名**: 后端实现验签逻辑后，iOS 设置 `RequestSigner.isEnabled = true`
4. **启用证书固定**: 获取公钥 Hash 后，iOS 设置 `CertificatePinningManager.shared.isEnabled = true`
5. **日志迁移**: 逐步将其他文件的 `print()` 替换为 `Logger` 调用
