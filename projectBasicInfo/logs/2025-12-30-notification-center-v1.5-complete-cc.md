# 通知中台 V1.5 完成

**日期**: 2025-12-30
**作者**: Claude Code
**版本**: V1.5（管理可配置）

---

## 概述

在 V1.0（基础推送功能）基础上，完成了 V1.5 版本，增加了通知系统的后台可配置能力，包括事件配置、模板管理、用户偏好设置和频率控制。

---

## 新增数据库表

### 1. notification_event_config（事件配置表）

```sql
CREATE TABLE notification_event_config (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_code VARCHAR(50) NOT NULL UNIQUE,     -- 事件代码
    event_name VARCHAR(100) NOT NULL,           -- 事件名称（如"评论回复"）
    event_group VARCHAR(50) DEFAULT 'interaction', -- 事件分组
    is_enabled TINYINT(1) DEFAULT 1,            -- 是否启用
    channels JSON,                              -- 支持的渠道 ["apns","in_app"]
    frequency_limit INT DEFAULT 0,              -- 每小时频率限制（0=无限制）
    cooldown_seconds INT DEFAULT 0,             -- 冷却时间（秒）
    default_title_template VARCHAR(200),        -- 默认标题模板
    default_body_template VARCHAR(500),         -- 默认内容模板
    deep_link_pattern VARCHAR(200),             -- Deep Link 模式
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### 2. notification_template（通知模板表）

```sql
CREATE TABLE notification_template (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_code VARCHAR(50) NOT NULL,            -- 关联事件代码
    channel VARCHAR(30) NOT NULL,               -- 渠道 (apns/in_app/sms/email)
    locale VARCHAR(10) DEFAULT 'zh_CN',         -- 语言
    title_template VARCHAR(200),                -- 标题模板
    body_template VARCHAR(500),                 -- 内容模板
    deep_link_pattern VARCHAR(200),             -- Deep Link 模式
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_event_channel_locale (event_code, channel, locale)
);
```

### 3. user_notification_preference（用户偏好表）

```sql
CREATE TABLE user_notification_preference (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    event_code VARCHAR(50) NOT NULL,            -- 事件代码或 '_global_'
    push_enabled TINYINT(1) DEFAULT 1,          -- 是否接收推送
    in_app_enabled TINYINT(1) DEFAULT 1,        -- 是否显示站内通知
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_event (user_id, event_code)
);
```

---

## 新增 Java 文件

### 实体类 (model/)

| 文件 | 说明 |
|------|------|
| `NotificationEventConfigDO.java` | 事件配置实体 |
| `NotificationTemplateDO.java` | 通知模板实体 |
| `UserNotificationPreferenceDO.java` | 用户偏好实体 |

### Mapper (mapper/)

| 文件 | 说明 |
|------|------|
| `NotificationEventConfigMapper.java` | 事件配置 Mapper |
| `NotificationTemplateMapper.java` | 模板 Mapper |
| `UserNotificationPreferenceMapper.java` | 用户偏好 Mapper（含自定义查询） |

### Service (service/)

| 文件 | 说明 |
|------|------|
| `NotificationEventConfigService.java` | 事件配置服务（内存缓存、启动加载） |
| `NotificationTemplateService.java` | 模板服务（变量渲染） |
| `UserNotificationPreferenceService.java` | 用户偏好服务 |
| `NotificationRateLimitService.java` | 频率控制服务（Redis 滑动窗口） |

### DTO (dto/)

| 文件 | 说明 |
|------|------|
| `NotificationPreferenceDTO.java` | 偏好设置请求 DTO |

---

## 核心功能实现

### 1. 事件配置服务 (NotificationEventConfigService)

```java
@Service
public class NotificationEventConfigService {
    // 内存缓存，应用启动时加载
    private final Map<String, NotificationEventConfigDO> configCache = new ConcurrentHashMap<>();

    @PostConstruct
    public void init() {
        refreshCache();  // 启动时加载所有配置
    }

    public boolean isEventEnabled(String eventCode);     // 检查事件是否启用
    public int getFrequencyLimit(String eventCode);      // 获取频率限制
    public int getCooldownSeconds(String eventCode);     // 获取冷却时间
}
```

### 2. 模板服务 (NotificationTemplateService)

支持 `{{variableName}}` 格式的变量替换：

```java
public String[] renderNotification(String eventCode, Map<String, Object> variables) {
    // 返回 [title, body]
    // 替换模板中的 {{fromUserName}}, {{shareId}} 等变量
}

public String renderDeepLink(String eventCode, Map<String, Object> variables) {
    // 渲染 Deep Link，如 guanzhi://share/{{shareId}}/comment/{{commentId}}
}
```

### 3. 用户偏好服务 (UserNotificationPreferenceService)

```java
public boolean isPushEnabled(Long userId, String eventCode);  // 检查推送开关
public boolean isInAppEnabled(Long userId, String eventCode); // 检查站内通知开关
public Map<String, Object> getUserPreferences(Long userId);   // 获取用户所有偏好
public void batchUpdatePreferences(...);                       // 批量更新偏好
```

### 4. 频率控制服务 (NotificationRateLimitService)

基于 Redis 实现滑动窗口限流：

```java
public boolean isAllowed(Long userId, String eventCode);       // 检查是否允许发送
public void recordNotification(Long userId, String eventCode); // 记录一次发送

// Redis Key 格式：
// notification:rate:{userId}:{eventCode}     - 频率计数（1小时过期）
// notification:cooldown:{userId}:{eventCode} - 冷却标记
```

---

## 通知发送流程重构

CommentNotificationService 中的所有通知方法现在使用统一的前置检查：

```java
private boolean preCheck(Long toUserId, Long fromUserId, String eventCode) {
    // 1. 不通知自己
    if (toUserId.equals(fromUserId)) return false;

    // 2. 检查事件是否启用
    if (!eventConfigService.isEventEnabled(eventCode)) return false;

    // 3. 检查用户偏好
    if (!preferenceService.isPushEnabled(toUserId, eventCode)) return false;

    // 4. 检查频率限制
    if (!rateLimitService.isAllowed(toUserId, eventCode)) return false;

    return true;
}
```

发送流程：
```
1. preCheck() 前置检查
2. templateService.renderNotification() 渲染内容
3. 保存通知记录到数据库
4. apnsPushService.sendToUser() 发送推送
5. rateLimitService.recordNotification() 记录频率
```

---

## 新增 API

### GET /api/notifications/preferences

获取用户通知偏好设置。

**响应**：
```json
{
  "respCode": 0,
  "datas": {
    "globalPushEnabled": true,
    "preferences": [
      {
        "eventCode": "comment_reply",
        "eventName": "评论回复",
        "eventGroup": "interaction",
        "pushEnabled": true,
        "inAppEnabled": true
      }
    ]
  }
}
```

### PUT /api/notifications/preferences

更新用户通知偏好设置。

**请求**：
```json
{
  "globalPushEnabled": true,
  "preferences": [
    {
      "eventCode": "comment_reply",
      "pushEnabled": false,
      "inAppEnabled": true
    }
  ]
}
```

---

## 默认事件配置

| 事件代码 | 名称 | 频率限制 | 冷却时间 | 标题模板 | 内容模板 |
|----------|------|----------|----------|----------|----------|
| `comment_reply` | 评论回复 | 20次/小时 | 30秒 | 有人回复了你 | {{fromUserName}} 回复了你的评论 |
| `comment_like` | 评论点赞 | 30次/小时 | 60秒 | 有人赞了你的评论 | {{fromUserName}} 赞了你的评论 |
| `new_comment` | 新评论 | 20次/小时 | 30秒 | 有人评论了你的分享 | {{fromUserName}} 评论了你的分享 |
| `sticker_received` | 收到贴纸 | 15次/小时 | 60秒 | 收到新贴纸 | {{fromUserName}} 给你的分享贴了贴纸 |
| `system` | 系统通知 | 无限制 | 无 | 系统通知 | - |

---

## 部署验证

应用启动日志显示 V1.5 服务正常加载：

```
2025-12-30 09:12:59,204 main  INFO  [NotificationEventConfigService]
  Event config cache refreshed, 5 configs loaded
2025-12-30 09:12:59,204 main  INFO  [NotificationEventConfigService]
  NotificationEventConfigService initialized with 5 event configs
```

---

## 管理后台 UI（V1.5 补充）

### 新增后端 API（AdminController.java）

| API | 方法 | 说明 |
|-----|------|------|
| `/admin/config/notification-events` | GET | 获取所有通知事件配置 |
| `/admin/config/notification-event` | POST | 新增或修改事件配置 |
| `/admin/config/notification-event/{id}` | DELETE | 删除事件配置 |
| `/admin/config/notification-templates` | GET | 获取所有通知模板 |
| `/admin/config/notification-template` | POST | 新增或修改模板 |
| `/admin/config/notification-template/{id}` | DELETE | 删除模板 |

### 新增 Vue 页面

| 文件 | 路径 | 说明 |
|------|------|------|
| `EventConfig.vue` | `/admin-web/src/views/notification/` | 通知事件配置页面 |
| `TemplateConfig.vue` | `/admin-web/src/views/notification/` | 通知模板管理页面 |

### 功能特性

**EventConfig.vue（通知事件配置）**：
- 事件列表展示（代码、名称、分组、状态）
- 启用/禁用开关（实时生效）
- 频率限制和冷却时间配置
- 默认标题/内容模板配置
- Deep Link 模式配置
- 新增/编辑/删除操作

**TemplateConfig.vue（通知模板管理）**：
- 模板列表展示（事件、渠道、语言、状态）
- 支持多渠道：APNs、站内、短信、邮件
- 支持多语言：中文、English
- 模板变量实时预览功能
- 激活/禁用开关
- 新增/编辑/删除操作

### 路由配置

```javascript
// router/index.js
{
  path: 'notification-events',
  name: 'NotificationEventConfig',
  component: () => import('../views/notification/EventConfig.vue')
},
{
  path: 'notification-templates',
  name: 'NotificationTemplateConfig',
  component: () => import('../views/notification/TemplateConfig.vue')
}
```

### 菜单位置

配置管理 → 通知事件配置 / 通知模板管理

### 服务层修改

`NotificationEventConfigService` 和 `NotificationTemplateService` 改为继承 `ServiceImpl<Mapper, Entity>`，获得 MyBatis-Plus 标准 CRUD 方法：
- `list()` - 查询所有
- `getById(id)` - 按 ID 查询
- `saveOrUpdate(entity)` - 新增或更新
- `removeById(id)` - 按 ID 删除

---

## 后续计划 (V2.0)

- P1: 新增社交事件（关注、点赞分享、@提及）
- P2: ~~管理后台事件配置界面~~ ✅ 已完成
- P3: 通知聚合（同一分享多个点赞合并）
- P4: 邮件/短信渠道支持
