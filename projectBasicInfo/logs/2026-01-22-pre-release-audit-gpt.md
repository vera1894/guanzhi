# 上线前大规模检查（公测前）- 风险扫描

## 背景
公测版上线前，对 iOS、后端、管理后台进行全量代码与配置的静态风险扫描，识别重大问题与上线风险。

## 环境
- 本地检查（未运行编译/测试）
- 仓库路径：`guanzhi/`

## 实施步骤
1. 阅读项目规则与概述文档
2. 使用全局搜索定位 TODO/调试/后门/明文配置等高风险模式
3. 抽查关键模块（登录、鉴权、配置、推送、分享详情、监控接口）

## 重大问题与风险（需在公测前处理）

### P0 / 安全后门
1. **管理后台存在测试后门账号**
   - 文件：`admin-web/src/views/Login.vue`
   - 现状：页面提示“测试后门: admin / 123456”，并在代码中硬编码放行登录，写入 `mock-admin-token`
   - 风险：任何人可直接登录后台（或绕过验证码流程）

2. **iOS 客户端存在隐藏测试登录通道**
   - 文件：`guanzhi/View/LoginViews/LogInView.swift`
   - 现状：连续点击 10 次开启“测试模式”，输入指定手机号直接使用硬编码 JWT 登录
   - 风险：生产环境可被利用，绕过验证码认证

### P1 / 配置与安全暴露
3. **后端默认配置存在明文敏感信息**
   - 文件：`Server/onettoo/src/main/resources/application.yml`
   - 现状：JWT 密钥、Knife4j 账号/密码、管理员手机号等配置直接写在仓库中
   - 风险：若默认 profile 被误用或配置泄露，导致认证失效或后台暴露

4. **Druid 监控与相关接口对外开放**
   - 文件：`Server/onettoo/src/main/java/com/cloud/onettoo/modules/security/config/SecurityConfig.java`
   - 现状：`/druid/**` 直接 `permitAll()`；生产配置中 Druid 监控开启
   - 风险：可能暴露数据库连接池/SQL/运行时信息

5. **CORS 允许任意来源 + 允许携带凭证**
   - 文件：`Server/onettoo/src/main/java/com/cloud/onettoo/common/config/ConfigurerAdapter.java`
   - 现状：`allowedOriginPatterns("*")` + `allowCredentials(true)` + `allowedMethods("*")`
   - 风险：浏览器侧跨站风险增大，若将来使用 cookie/会话或误配 Authorization，将存在 CSRF 风险

### P2 / 功能缺失与调试泄露
6. **分享详情页的“分享/举报”功能未实现**
   - 文件：`guanzhi/View/SharePages/ShareDetailView.swift`
   - 风险：公测用户入口可见但功能不可用，影响体验与反馈

7. **大量调试日志与敏感信息输出未限制 DEBUG**
   - 文件示例：
     - `guanzhi/guanzhiApp.swift`（Device Token、Deep Link、通知 payload）
     - `guanzhi/ModelsForMap/ShareService.swift`（原始 JSON 及解析数据）
     - `guanzhi/ModelsForNetwork/NotificationService.swift`（原始响应）
   - 风险：生产日志泄露用户数据与 token、影响隐私合规

8. **相机相关模块存在 `fatalError` 直接崩溃路径**
   - 文件示例：
     - `guanzhi/CameraViews/CameraPreview.swift`
     - `guanzhi/CaptureFunctions/DeviceLookup.swift`
     - `guanzhi/CaptureFunctions/MovieCapture.swift`
   - 风险：在无相机设备/异常配置情况下直接崩溃（需容错）

9. **测试/临时 UI 文件存在于主工程**
   - 文件示例：`guanzhi/View/UIElement/test.swift`
   - 风险：非致命，但建议清理或仅 Debug 编译

## 验证结果
- 本次为静态审查，未运行 build/test

## TODO / 建议（上线前优先级）
1. **立即移除后台/客户端测试后门与硬编码 token**
2. **将所有敏感配置迁移到环境变量或 .private 文件（禁止出现在仓库）**
3. **限制/关闭生产环境 druid/Swagger/Knife4j 暴露**
4. **收敛 CORS 允许域名列表，并与前端部署域一致**
5. **将调试日志改为 DEBUG 条件输出或移除**
6. **补齐 Share 分享/举报能力或隐藏入口**
7. **对相机模块补充容错处理（无设备/权限被拒）**

