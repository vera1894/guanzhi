# 通知 Channel 语义统一

**日期**: 2026-01-08
**作者**: Claude Code
**类型**: 架构优化

---

## 问题背景

推送通知显示"分享"而非"观之"，经排查发现两个问题：

1. **内存缓存问题**：`NotificationEventConfigService` 在启动时缓存配置，数据库更新后未刷新
2. **Channel 命名不一致**：代码硬编码查询 `channel='apns'`，但数据库模板使用 `channel='push'`

## 解决方案：统一 Channel 语义

采用两层抽象设计，分离业务层和技术层概念：

```
┌─────────────────────────────────────────────────┐
│ 业务层 (channel)                                 │
│   push    - 推送通知（需要推送到设备）            │
│   inApp   - 应用内通知（仅存数据库）              │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ 技术层 (provider) - 运行时决定                   │
│   apns    - iOS 设备，使用 Apple Push Service    │
│   fcm     - Android 设备，使用 Firebase Cloud    │
└─────────────────────────────────────────────────┘
```

## 代码改动

### 1. NotificationTemplateMapper.java

```java
// 改动前
@Select("SELECT * FROM notification_template WHERE event_code = #{eventCode} AND channel = 'apns' AND is_active = 1 LIMIT 1")
NotificationTemplateDO findApnsTemplate(@Param("eventCode") String eventCode);

// 改动后
@Select("SELECT * FROM notification_template WHERE event_code = #{eventCode} AND channel = 'push' AND is_active = 1 LIMIT 1")
NotificationTemplateDO findPushTemplate(@Param("eventCode") String eventCode);
```

### 2. NotificationTemplateService.java

```java
// 改动前
public NotificationTemplateDO getApnsTemplate(String eventCode) { ... }

// 改动后
public NotificationTemplateDO getPushTemplate(String eventCode) { ... }
```

方法调用点 `renderNotification()` 同步更新。

### 3. 数据库迁移

```sql
UPDATE notification_template SET channel='push' WHERE channel='apns';
```

迁移后数据库状态：
- 所有推送模板：`channel = 'push'`
- 所有应用内模板：`channel = 'inApp'`

## 设计优势

1. **语义清晰**：`push`/`inApp` 表达业务意图，`apns`/`fcm` 为实现细节
2. **扩展性好**：未来添加 Android 支持时，只需在运行时判断设备类型选择 provider
3. **一致性强**：所有模板使用统一的 channel 命名，避免混乱

## 相关文件

| 文件 | 改动 |
|------|------|
| `NotificationTemplateMapper.java` | 方法重命名 + SQL 更新 |
| `NotificationTemplateService.java` | 方法重命名 + 调用更新 |
| `notification_template` 表 | channel 字段值迁移 |

## 验证

- 服务重启后缓存已刷新（12 configs loaded）
- APNs 推送服务正常初始化
- 下次触发通知将使用正确的"观之"术语
