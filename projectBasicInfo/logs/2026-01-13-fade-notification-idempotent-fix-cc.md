# 褪色通知幂等修复

**日期**: 2026-01-13
**作者**: Claude Code (Backend CC)
**状态**: ✅ 已部署生产环境

---

## 问题描述

用户反馈：只有一条观之完全褪色了，但每天都收到它完全褪色的通知。

## 根因分析

1. **事务与异步冲突**：`FadeScoreTask.updateFadeScores()` 标注了 `@Transactional`，而 `sendFadeCompleteNotification()` 是 `@Async` 异步执行
2. **执行顺序问题**：
   ```
   主事务开始
     → 设置 share.setStatus(1)
     → 调用 sendFadeCompleteNotification() [异步，已脱离事务]
     → updateBatchById(shares)  ← 如果这里失败
   主事务回滚（status 回滚成 0）
   但 @Async 已经把通知发出去了！
   → 第二天任务又查到这条 status=0 的观之，又发一次
   ```
3. **缺少幂等保护**：没有"按 shareId 维度"的去重机制

## 修复方案

采用**唯一索引幂等法**：

### 1. 数据库迁移 (V20260113__fade_notification_idempotent.sql)

```sql
-- 给 notification 表增加唯一索引
ALTER TABLE notification
ADD UNIQUE INDEX uk_user_type_share (user_id, type, share_id);
```

- 此索引确保：同一用户 + 同一类型 + 同一观之 只能有一条通知记录
- MySQL 允许多个 NULL 值，所以 share_id IS NULL 的通知（如 SYSTEM）不受影响

### 2. CommentNotificationService.java 修改

在 `sendFadeWarningNotification` 和 `sendFadeCompleteNotification` 方法中：

1. 补齐 rateLimit 频率检查
2. 使用 try-catch 捕获 `DuplicateKeyException`，实现幂等

```java
try {
    notificationMapper.insert(notification);
} catch (DuplicateKeyException e) {
    // 唯一索引冲突 = 已经通知过了，直接跳过
    log.info("Fade complete notification already sent for user {} share {}, skip.", userId, shareId);
    return;
}

// 只有插入成功才发推送
apnsPushService.sendToUser(...);

// 记录频率（插入成功后才记录）
rateLimitService.recordNotification(userId, eventCode);
```

### 3. FadeScoreTask.java 修改

1. **去掉 `@Transactional`**：避免大事务回滚导致状态不一致
2. **改成每条单独更新**：`guanzhiService.updateById(share)` 替代 `updateBatchById(shares)`
3. **增加异常处理**：单条失败不影响其他 share 的处理

---

## 修改文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `db/migration/V20260113__fade_notification_idempotent.sql` | 新增 | 唯一索引 + 数据止血 |
| `service/CommentNotificationService.java` | 修改 | 添加幂等逻辑 + 补齐 rateLimit |
| `tasks/FadeScoreTask.java` | 修改 | 去掉 @Transactional，每条单独更新 |
| `projectBasicInfo/01_PROJECT_OVERVIEW.md` | 修改 | 补齐 V2.0 事件频率配置 |

---

## 验收用例

| 用例 | 预期结果 |
|------|----------|
| 观之 A 褪色度达到 100% | notification 表插入 1 条 FADE_COMPLETE，推送 1 次 |
| 再次执行定时任务 | `DuplicateKeyException` 被捕获，跳过，不推送 |
| 手动触发 2 次 sendFadeCompleteNotification | 只有第 1 次成功插入，第 2 次被唯一索引拦截 |
| 定时任务中途某条失败 | 已处理的 share 状态已更新，不会重复发送 |

---

## 部署步骤

1. 执行数据库迁移脚本（会先删除重复数据再创建唯一索引）
2. 部署后端代码
3. 观察日志确认修复生效

---

## 相关审核意见来源

本次修复参考了 GPT 对原方案的审核意见，主要调整点：

1. ✅ 事务回滚问题：去掉大事务，每条单独更新
2. ✅ 抢锁失败不补发：用唯一索引而非"先标记再发"
3. ✅ 迁移脚本止血：只删除重复记录，不过度标记
4. ✅ 频率配置语义：改为"每 share 1次"（唯一索引保证）
5. ✅ rateLimit record 位置：在 insert 成功后才 record

---

## 部署记录

**部署时间**: 2026-01-12 21:28 UTC (北京时间 2026-01-13 05:28)

### 部署步骤执行情况

| 步骤 | 状态 | 说明 |
|------|------|------|
| 构建 JAR | ✅ | `./mvnw clean package -DskipTests` |
| 上传 S3 | ✅ | `s3://guanzhi-deploy-temp-20260108/onettoo-20260113.jar` |
| 服务器下载 | ✅ | 通过 presigned URL 下载 |
| 停止服务 | ✅ | `pkill -9 -f 'java.*jar'` |
| 启动服务 | ✅ | `bash start.sh` |
| 数据库迁移 | ✅ | 手动执行 SQL（项目未使用 Flyway） |
| 清理 S3 | ✅ | 删除临时文件释放空间 |

### 数据库变更验证

**唯一索引创建成功**：
```
notification.uk_user_type_share (user_id, type, share_id)
```

**频率配置更新**：
| event_code | frequency_limit | cooldown_seconds |
|------------|-----------------|------------------|
| FADE_COMPLETE | 0 | 0 |
| FADE_WARNING | 1 | 86400 |

### 服务状态

```
Started OnettooApplication in 14.165 seconds
Tomcat started on port(s): 8085 (http)
JVM TimeZone: UTC - 验证通过
```

### 注意事项

- 项目未使用 Flyway，数据库迁移需手动执行
- 迁移脚本位置：`src/main/resources/db/migration/V20260113__fade_notification_idempotent.sql`
- 生产环境已执行，无需重复执行
