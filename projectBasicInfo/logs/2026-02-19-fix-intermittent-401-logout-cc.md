# 修复间歇性 401 导致意外登出 — v3.7.3

**日期**: 2026-02-19
**版本**: v3.7.3
**类型**: Bug 修复（iOS + 后端）

---

## 背景

iOS app 每 60 秒轮询 `/api/notifications/unread-count`，偶尔收到 401 响应后立即删除 Keychain token 并强制登出，用户被迫重新短信验证码登录。近两天多次发生。

调查发现：
- 后端日志在 401 时刻无异常（排除 Redis 主动报错）
- 同一秒内出现 401+200 并存 → token 在 Redis 中有效，非真正过期
- Jedis 连接池完全未配置（默认 max-active=8），TokenFilter 每次认证最多 4 次 Redis 调用，高并发下连接耗尽
- `TokenFilter.java` 只 catch `ExpiredJwtException`，Redis 连接异常未被捕获 → 认证上下文为空 → 401

## 修改内容

### 1. iOS 端 — 401 容错（NetworkService.swift）

- 添加 `consecutive401Count` 静态计数器，阈值 `logout401Threshold = 3`
- 401 时递增计数，**连续 3 次 401 才触发 `.tokenExpired` 登出通知**
- 200 响应时重置计数为 0
- 效果：偶发 1-2 次 401 不会登出，60 秒轮询下最多延迟 3 分钟检测真正过期

### 2. 后端 — Jedis 连接池（application-prod.yml）

添加连接池配置：
```yaml
jedis:
  pool:
    max-active: 20
    max-idle: 10
    min-idle: 5
    max-wait: 3000ms
```

源码和服务器外部 `/home/ec2-user/application-prod.yml` 均已同步更新。

### 3. 后端 — TokenFilter 异常处理（TokenFilter.java）

- `catch (ExpiredJwtException)` → `catch (Exception)`，捕获所有异常含 Redis 连接异常
- 移除不再需要的 `ExpiredJwtException` import
- 新增 WARN 日志：token 非空但 Redis 找不到时记录 token 前 8 位，便于排查

## 修改的文件

| 文件 | 改动 |
|------|------|
| `guanzhi/ModelsForNetwork/NetworkService.swift` | 添加连续 401 计数逻辑 |
| `Server/onettoo/src/main/resources/application-prod.yml` | 添加 jedis.pool 配置 |
| `Server/.../security/security/TokenFilter.java` | 扩大 catch 范围 + 添加日志 |
| 服务器 `/home/ec2-user/application-prod.yml` | 同步添加 jedis.pool 配置 |
| `projectBasicInfo/05_DEPLOYMENT_SSOT.md` | 更新当前版本为 v3.7.3 |

## 部署过程

1. 清理 iCloud 重复文件（无重复）
2. `mvn clean package -DskipTests` — BUILD SUCCESS（9.5s）
3. 上传 JAR 到 S3（114.9MB）
4. SSM 创建 `/home/ec2-user/releases/v3.7.3/` 目录
5. SSM curl 下载 JAR 到服务器
6. SSM Python 脚本更新服务器外部 `application-prod.yml`（sed 在 Amazon Linux 上语法不同，改用 Python）
7. `ln -sfn` 切换版本 + `systemctl restart onettoo`

## 部署验收

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 服务状态 | ✅ | active (running), PID 809389 |
| 入口路径 | ✅ | current -> releases/v3.7.3 |
| 进程命令行 | ✅ | -jar /home/ec2-user/current/app.jar |
| 版本接口 | ✅ | buildTime: 2026-02-19T04:53:05.289Z |
| 启动日志 | ✅ | Started in 14.107s，时区验证通过，无错误 |
| 外部配置 | ✅ | jedis pool 已生效 |

## 遇到的问题

- **sed 在 Amazon Linux 上的 `a\` 命令不支持 `\n` 换行**：改用 Python 脚本通过 base64 编码传到服务器执行

## 后续观察

- 监控命令：`journalctl -u onettoo | grep "Token 验证"`
- 关注 WARN 日志频率：如果频繁出现 "Redis 未找到 tokenKey"，说明连接池仍不够或有其他问题
- iOS 端修改需下次 Xcode build 打包后生效

## 未改动（本次范围外）

- `RedisUtils.java` scan 连接泄漏 — 仅管理后台使用，风险低
- `NotificationBadgeManager.swift` — 401 容错在网络层统一处理
- `guanzhiApp.swift` — `.tokenExpired` 处理逻辑不变，只是触发频率降低
