# Token 过期自动登出 + 分享落地页 404 修复

**日期**: 2026-02-18
**角色**: Claude Code

---

## 问题 1：Token 过期后 App 卡死

### 现象
所有 API 返回 401 Unauthorized，地图和列表显示"加载失败"，但用户未被引导至登录页。

### 根因
- `NetworkService` 收到 401 时发送 `.tokenExpired` 通知
- **但 `guanzhiApp.swift` 没有监听该通知**，无人处理
- `OTOLoginStatusManager.isLoggedIn` 仅检查 Keychain 存在性，不校验 Token 有效性

### Token 过期原因
- JWT 本身**不含 `exp` 声明**（`TokenProvider.createToken()` 未调用 `setExpiration()`）
- 过期完全由 Redis key TTL 管理（365 天 + 自动续期）
- 服务器 Redis 于 ~2026-01-28 重启，仅有 RDB 快照（AOF 未启用），部分 Token 在快照间隙丢失

### 修复
在 `guanzhiApp.swift` 添加 `.tokenExpired` 监听：

```swift
.onReceive(NotificationCenter.default.publisher(for: .tokenExpired)) { _ in
    handleTokenExpired()
}
```

`handleTokenExpired()` 逻辑：
1. `guard loginManager.isLoggedIn`：防多个并发 401 重复触发
2. 清空 `navigationCoordinator.path`：回到根视图
3. `loginManager.logout()`：清 Keychain + 发 `userDidLogout` 通知
4. `toastManager.showIfNotPresent(...)`：显示提示（`showIfNotPresent` 按 title 去重防重复 Toast）

### 用户反馈的子问题
初始实现用 `toastManager.show()`，用户测试时出现 ~5 条 Toast 竖向叠加。原因：多个并发 API 同时返回 401，`logout()` 内部 `DispatchQueue.main.async` 设置 `isLoggedIn = false` 是异步的，guard 来不及拦截。改用 `showIfNotPresent()` 解决。

---

## 问题 2：分享网页链接 404

### 现象
`onettoo.com/s/{shareId}` 返回 Nginx 404 页面。

### 根因
- Nginx 有两个 server block：端口 80（HTTP）和端口 443（HTTPS）
- `/s/` proxy_pass 只配置在端口 443
- **CloudFront 回源走 HTTP 端口 80**，端口 80 没有 `/s/` 路由 → 404

### 修复

1. 在端口 80 server block 添加 `/s/` proxy：
```nginx
location /s/ {
    proxy_set_header HOST $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_pass http://onettoo;
}
```

2. CSS 404 子问题：
   - `@EnableWebMvc` 禁用了 Spring Boot 默认静态资源服务
   - `ConfigurerAdapter.addResourceHandlers()` 未注册 `/css/**`
   - 解决：从 JAR 提取 CSS 到 `/var/www/onettoo-homepage/css/`，Nginx 用 `alias` 直接提供
```nginx
location = /css/share-landing.css {
    alias /var/www/onettoo-homepage/css/share-landing.css;
}
```

3. `nginx -t && nginx -s reload` 生效

### 验证
- `curl -H "Host: onettoo.com" http://127.0.0.1/s/113` → 200
- `curl -H "Host: onettoo.com" http://127.0.0.1/css/share-landing.css` → 200
- 外部通过 CloudFront 访问 → 200

---

## 修改文件清单

| 文件 | 操作 |
|------|------|
| `guanzhi/guanzhiApp.swift` | 添加 `.tokenExpired` 监听 + `handleTokenExpired()` |
| `/etc/nginx/nginx.conf`（服务器） | 端口 80 添加 `/s/` proxy + CSS alias |
| `/var/www/onettoo-homepage/css/share-landing.css`（服务器） | 从 JAR 提取 CSS |
| `projectBasicInfo/01_PROJECT_OVERVIEW.md` | 更新登录管理、Nginx 规则、通知名称、文档索引 |

---

## 经验总结

1. **CloudFront 回源走 HTTP 80**：所有公开路由必须同时配置在端口 80 和 443
2. **`@EnableWebMvc` 陷阱**：会禁用 Spring Boot 默认静态资源服务，需要的静态资源路径必须在 `addResourceHandlers()` 显式注册，或由 Nginx 直接提供
3. **并发 401 Toast 重复**：`logout()` 内部异步执行，guard 检查有时间窗口，需配合 Toast 去重机制
