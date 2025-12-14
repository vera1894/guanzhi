# 贴纸权限 + 每日使用次数 实施计划 v5.1（最终可执行版）

**文档版本**: v5.1
**创建时间**: 2025-12-14
**作者**: Claude Code
**状态**: 待实施

---

## 〇、核心产品规则（最高优先级）

> **任何贴纸对同一条分享、同一用户，只允许使用一次，不可撤回，不可改投。**

| 类型 | 规则 | 强制约束 |
|------|------|----------|
| **tag 类** | 同用户对同 share 的同 tagCode 只能一次 | DB 唯一约束 |
| **vote 类** | 同用户对同 share 只能投一次（LIKE/NEUTRAL 互斥） | DB 唯一约束 |
| **撤回** | 不支持，无撤回 API | - |

**事实来源声明**：
> 统计与展示以 `share_sticker_action` 为准；`share_vote` 仅用于兼容旧查询/快速读取当前投票状态。

**sticker_group 约束**：
> - vote 类贴纸（LIKE/NEUTRAL）的 `sticker_group` **必须**为 `'vote'`
> - tag 类贴纸的 `sticker_group` **必须**为 `'tag'`（或 `'fun'`）
> - 这保证了 vote 互斥约束只在 vote 内部生效，不会误伤 tag

---

## 一、数据库迁移脚本（完整 DDL）

### 1.1 migration-add-sticker-quota.sql

```sql
-- ================================================================
-- 迁移脚本：贴纸配额系统
-- 创建时间：2025-12-14
-- ================================================================

-- ==================== 1. 扩展 tag_definition ====================

ALTER TABLE tag_definition
ADD COLUMN sticker_group VARCHAR(20) NOT NULL DEFAULT 'tag'
    COMMENT '贴纸分组: vote/tag/fun' AFTER tag_type,
ADD COLUMN base_daily_limit INT DEFAULT NULL
    COMMENT '基础每日上限, NULL=不限制' AFTER sticker_group,
ADD COLUMN icon_url VARCHAR(255) DEFAULT NULL
    COMMENT '贴纸图标URL' AFTER base_daily_limit,
ADD COLUMN pending_daily_limit INT DEFAULT NULL
    COMMENT '待生效的每日上限' AFTER icon_url,
ADD COLUMN pending_effective_day DATE DEFAULT NULL
    COMMENT '待生效日期（次日04:00生效）' AFTER pending_daily_limit;

CREATE INDEX idx_tag_group ON tag_definition(sticker_group);
CREATE INDEX idx_tag_active_group ON tag_definition(is_active, sticker_group);

-- ==================== 2. 扩展 level_definition ====================

ALTER TABLE level_definition
ADD COLUMN daily_multiplier DECIMAL(4,2) NOT NULL DEFAULT 1.00
    COMMENT '每日限额倍率' AFTER tagging_allowance,
ADD COLUMN pending_multiplier DECIMAL(4,2) DEFAULT NULL
    COMMENT '待生效的倍率' AFTER daily_multiplier,
ADD COLUMN pending_effective_day DATE DEFAULT NULL
    COMMENT '待生效日期' AFTER pending_multiplier;

-- 废弃旧字段（保留但标记）
ALTER TABLE level_definition
MODIFY COLUMN tagging_allowance INT DEFAULT NULL
    COMMENT '[DEPRECATED] 已废弃，使用 per-tag 配额';

-- ==================== 3. 新建贴纸动作表（核心） ====================

CREATE TABLE share_sticker_action (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    share_id BIGINT NOT NULL COMMENT '分享ID',
    actor_user_id BIGINT NOT NULL COMMENT '操作用户ID',
    tag_code VARCHAR(50) NOT NULL COMMENT '贴纸代码 (LIKE/NEUTRAL/MIJING/...)',
    sticker_group VARCHAR(20) NOT NULL COMMENT '贴纸分组 (vote/tag/fun)',
    quota_day DATE NOT NULL COMMENT '计数日（按04:00规则）',
    client_action_id VARCHAR(36) DEFAULT NULL COMMENT '客户端幂等ID',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- ========== 三个唯一约束（核心，必须有） ==========

    -- 约束1: tag 去重 - 同用户对同 share 的同 tagCode 只能一次
    CONSTRAINT uk_share_user_tag UNIQUE (share_id, actor_user_id, tag_code),

    -- 约束2: vote 互斥 - 同用户对同 share 的 vote 类只能一条
    --        LIKE 和 NEUTRAL 的 sticker_group 都是 'vote'，此约束阻止两者共存
    --        tag 类的 sticker_group 是 'tag'，不会被此约束影响
    CONSTRAINT uk_share_user_vote_group UNIQUE (share_id, actor_user_id, sticker_group),

    -- 约束3: 幂等 - 同用户的同 clientActionId 只能一次（用户维度）
    CONSTRAINT uk_user_client_action UNIQUE (actor_user_id, client_action_id),

    -- ========== 查询索引 ==========
    INDEX idx_share_group (share_id, sticker_group),
    INDEX idx_share_tag (share_id, tag_code),
    INDEX idx_user_quota (actor_user_id, quota_day, tag_code),
    INDEX idx_created (created_at)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='贴纸使用动作表（事实来源）';

-- ==================== 4. 新建限额覆盖表 ====================

CREATE TABLE sticker_level_quota_override (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    tag_code VARCHAR(50) NOT NULL COMMENT '贴纸代码',
    level_code VARCHAR(50) NOT NULL COMMENT '等级代码',
    daily_limit INT NOT NULL COMMENT '覆盖的每日上限（最终值，不乘倍率）',
    pending_limit INT DEFAULT NULL COMMENT '待生效值',
    pending_effective_day DATE DEFAULT NULL COMMENT '待生效日期',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uk_tag_level UNIQUE (tag_code, level_code),
    INDEX idx_tag (tag_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='等级-贴纸限额覆盖表';

-- ==================== 5. 初始化数据 ====================

-- 5.1 插入 vote 类贴纸（sticker_group 必须是 'vote'）
INSERT INTO tag_definition
(tag_code, tag_name, tag_type, sticker_group, min_level_code, base_daily_limit, is_active, sort_order)
VALUES
('LIKE', '赞同', 'POSITIVE', 'vote', NULL, 100, 1, -2),
('NEUTRAL', '无感', 'NEGATIVE', 'vote', NULL, 100, 1, -1);

-- 5.2 更新现有标签为 tag 类（sticker_group 必须是 'tag'，不能是 'vote'）
UPDATE tag_definition
SET sticker_group = 'tag',
    base_daily_limit = 20
WHERE tag_code NOT IN ('LIKE', 'NEUTRAL');

-- 5.3 设置等级倍率（根据实际等级调整）
UPDATE level_definition SET daily_multiplier = 1.0 WHERE level_code = 'YOMIN';
UPDATE level_definition SET daily_multiplier = 1.0 WHERE level_code = 'LANDONG';
UPDATE level_definition SET daily_multiplier = 1.2 WHERE level_code = 'CHONGLANG';
UPDATE level_definition SET daily_multiplier = 1.5 WHERE level_code = 'SHUIMU';
UPDATE level_definition SET daily_multiplier = 2.0 WHERE level_code = 'QIANFAN';

-- ==================== 6. 验证唯一约束存在 ====================

-- 验证 share_sticker_action 表的约束
SELECT
    CONSTRAINT_NAME,
    COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'ONETTOO'
  AND TABLE_NAME = 'share_sticker_action'
  AND CONSTRAINT_NAME LIKE 'uk_%'
ORDER BY CONSTRAINT_NAME;

-- 预期结果应包含：
-- uk_share_user_tag: share_id, actor_user_id, tag_code
-- uk_share_user_vote_group: share_id, actor_user_id, sticker_group
-- uk_user_client_action: actor_user_id, client_action_id
```

---

## 二、quotaDay 工具类

### 2.1 QuotaDayUtil.java

```java
package com.cloud.onettoo.modules.utils;

import java.time.*;
import java.time.format.DateTimeFormatter;

/**
 * quotaDay 计算工具类
 *
 * 规则：
 * - 时区固定 Asia/Shanghai
 * - 日切点：每天 04:00
 * - quotaDay = date(nowCN - 4 hours)
 */
public class QuotaDayUtil {

    private static final ZoneId ZONE_SHANGHAI = ZoneId.of("Asia/Shanghai");
    private static final int CUT_OFF_HOUR = 4; // 04:00 日切

    /**
     * 获取当前 quotaDay
     *
     * 示例：
     * - 2025-12-14 03:59 → quotaDay = 2025-12-13
     * - 2025-12-14 04:00 → quotaDay = 2025-12-14
     */
    public static LocalDate getCurrentQuotaDay() {
        ZonedDateTime nowCN = ZonedDateTime.now(ZONE_SHANGHAI);
        return calculateQuotaDay(nowCN);
    }

    /**
     * 根据指定时间计算 quotaDay
     */
    public static LocalDate calculateQuotaDay(ZonedDateTime time) {
        ZonedDateTime timeCN = time.withZoneSameInstant(ZONE_SHANGHAI);
        // 减去4小时后取日期
        return timeCN.minusHours(CUT_OFF_HOUR).toLocalDate();
    }

    /**
     * 获取下一个 quotaDay（用于 pending 配置生效日期）
     *
     * 重要：基于 04:00 日切规则，不是简单的 +1 天
     */
    public static LocalDate getNextQuotaDay() {
        return getCurrentQuotaDay().plusDays(1);
    }

    /**
     * 获取下一次配额重置时间（下一个 04:00）
     */
    public static ZonedDateTime getNextResetTime() {
        ZonedDateTime nowCN = ZonedDateTime.now(ZONE_SHANGHAI);
        LocalDate today = nowCN.toLocalDate();
        ZonedDateTime todayCutOff = today.atTime(CUT_OFF_HOUR, 0).atZone(ZONE_SHANGHAI);

        if (nowCN.isBefore(todayCutOff)) {
            return todayCutOff;
        } else {
            return todayCutOff.plusDays(1);
        }
    }

    /**
     * 获取 ISO8601 格式的重置时间字符串
     */
    public static String getNextResetTimeISO() {
        return getNextResetTime().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME);
    }

    /**
     * 生成 Redis key
     */
    public static String buildRedisKey(Long userId, String tagCode, LocalDate quotaDay) {
        return String.format("sticker:quota:%d:%s:%s", userId, tagCode, quotaDay);
    }
}
```

### 2.2 QuotaDayUtil 单元测试（必须覆盖 04:00 边界）

```java
@Test
public void testQuotaDayBoundary() {
    ZoneId shanghai = ZoneId.of("Asia/Shanghai");

    // 03:59 → 前一天
    ZonedDateTime before = ZonedDateTime.of(2025, 12, 14, 3, 59, 0, 0, shanghai);
    assertEquals(LocalDate.of(2025, 12, 13), QuotaDayUtil.calculateQuotaDay(before));

    // 04:00 → 当天
    ZonedDateTime at = ZonedDateTime.of(2025, 12, 14, 4, 0, 0, 0, shanghai);
    assertEquals(LocalDate.of(2025, 12, 14), QuotaDayUtil.calculateQuotaDay(at));

    // 04:01 → 当天
    ZonedDateTime after = ZonedDateTime.of(2025, 12, 14, 4, 1, 0, 0, shanghai);
    assertEquals(LocalDate.of(2025, 12, 14), QuotaDayUtil.calculateQuotaDay(after));
}

@Test
public void testNextQuotaDay() {
    // getNextQuotaDay 应该基于 04:00 规则，不是简单 +1
    LocalDate current = QuotaDayUtil.getCurrentQuotaDay();
    LocalDate next = QuotaDayUtil.getNextQuotaDay();
    assertEquals(current.plusDays(1), next);
}
```

---

## 三、Redis Lua 脚本

### 3.1 原子扣减脚本

```lua
-- sticker_quota_consume.lua
-- KEYS[1] = sticker:quota:{userId}:{tagCode}:{quotaDay}
-- ARGV[1] = effectiveLimit (-1 表示无限制)
-- 返回: [success(0/1), usedAfter, remaining]

local limit = tonumber(ARGV[1])
local used = tonumber(redis.call('GET', KEYS[1]) or '0')

-- 无限制模式
if limit == -1 then
    local newUsed = redis.call('INCR', KEYS[1])
    redis.call('EXPIRE', KEYS[1], 172800) -- 48h TTL
    return {1, newUsed, -1}
end

-- 有限制模式：检查是否超限
if used >= limit then
    return {0, used, 0} -- remaining = 0
end

-- 扣减成功
local newUsed = redis.call('INCR', KEYS[1])
redis.call('EXPIRE', KEYS[1], 172800)
return {1, newUsed, limit - newUsed}
```

### 3.2 失败回滚脚本（仅事务失败时使用，保护下界）

```lua
-- sticker_quota_rollback.lua
-- KEYS[1] = sticker:quota:{userId}:{tagCode}:{quotaDay}
-- 返回: newUsed
--
-- 重要说明：
-- 1. 此脚本仅在 DB 写入失败/唯一约束冲突时调用
-- 2. 这是事务回滚，不是撤回功能（系统无撤回功能）
-- 3. 保护下界，不会减成负数
-- 4. 不影响 TTL

local used = tonumber(redis.call('GET', KEYS[1]) or '0')
if used > 0 then
    -- 使用 max(used-1, 0) 保护下界
    local newUsed = used - 1
    if newUsed < 0 then
        newUsed = 0
    end
    redis.call('SET', KEYS[1], newUsed, 'KEEPTTL')
    return newUsed
end
return 0
```

### 3.3 回滚并发测试用例（必须覆盖）

```java
/**
 * 测试并发场景下回滚不会导致 used 变负
 * 场景：两个并发请求，一个成功写 DB，一个因唯一冲突回滚
 */
@Test
public void testConcurrentRollbackNotNegative() throws Exception {
    Long userId = 11L;
    String tagCode = "MIJING";
    LocalDate quotaDay = LocalDate.of(2025, 12, 14);
    String redisKey = QuotaDayUtil.buildRedisKey(userId, tagCode, quotaDay);

    // 初始化：used = 1
    redisTemplate.opsForValue().set(redisKey, "1");

    // 模拟两个并发回滚
    CountDownLatch latch = new CountDownLatch(2);
    AtomicInteger finalUsed = new AtomicInteger(-1);

    for (int i = 0; i < 2; i++) {
        executor.submit(() -> {
            try {
                Long result = stickerQuotaService.rollbackQuota(userId, tagCode, quotaDay);
                finalUsed.set(result.intValue());
            } finally {
                latch.countDown();
            }
        });
    }

    latch.await(5, TimeUnit.SECONDS);

    // 验证：used 不应该为负数
    String usedStr = redisTemplate.opsForValue().get(redisKey);
    int used = Integer.parseInt(usedStr);
    assertTrue("used should not be negative", used >= 0);
}
```

---

## 四、定时任务（完整 applyPending SQL）

### 4.1 PendingConfigApplyTask.java

```java
@Component
@Slf4j
public class PendingConfigApplyTask {

    @Autowired
    private TagDefinitionMapper tagDefinitionMapper;
    @Autowired
    private LevelDefinitionMapper levelDefinitionMapper;
    @Autowired
    private StickerLevelQuotaOverrideMapper overrideMapper;
    @Autowired
    private AdminAuditLogService auditLogService;
    @Autowired
    private StickerQuotaService stickerQuotaService;
    @Autowired
    private ApplicationEventPublisher eventPublisher;

    /**
     * 每天 04:00 执行配置生效
     */
    @Scheduled(cron = "0 0 4 * * ?", zone = "Asia/Shanghai")
    public void applyPendingConfigs() {
        LocalDate today = QuotaDayUtil.getCurrentQuotaDay();
        log.info("开始执行 04:00 配置生效任务, quotaDay={}", today);

        try {
            // 1. 应用 tag_definition 的 pending 配置
            int tagCount = tagDefinitionMapper.applyPendingConfigs(today);

            // 2. 应用 level_definition 的 pending 配置
            int levelCount = levelDefinitionMapper.applyPendingConfigs(today);

            // 3. 应用 override 的 pending 配置
            int overrideCount = overrideMapper.applyPendingConfigs(today);

            // 4. 记录审计日志
            auditLogService.logConfigApply(today, tagCount, levelCount, overrideCount);

            // 5. 刷新缓存
            stickerQuotaService.refreshCache();

            // 6. 发布配额重置事件（未来用于推送）
            eventPublisher.publishEvent(new StickerQuotaResetEvent(today));

            log.info("04:00 配置生效完成: quotaDay={}, tags={}, levels={}, overrides={}",
                     today, tagCount, levelCount, overrideCount);

        } catch (Exception e) {
            log.error("04:00 配置生效任务失败", e);
            // 可选：发送告警
        }
    }
}
```

### 4.2 Mapper SQL（三个表的 applyPending）

**TagDefinitionMapper.xml**：
```xml
<update id="applyPendingConfigs">
    UPDATE tag_definition
    SET base_daily_limit = pending_daily_limit,
        pending_daily_limit = NULL,
        pending_effective_day = NULL
    WHERE pending_effective_day = #{today}
      AND pending_effective_day IS NOT NULL
</update>
```

**LevelDefinitionMapper.xml**：
```xml
<update id="applyPendingConfigs">
    UPDATE level_definition
    SET daily_multiplier = pending_multiplier,
        pending_multiplier = NULL,
        pending_effective_day = NULL
    WHERE pending_effective_day = #{today}
      AND pending_effective_day IS NOT NULL
</update>
```

**StickerLevelQuotaOverrideMapper.xml**：
```xml
<update id="applyPendingConfigs">
    UPDATE sticker_level_quota_override
    SET daily_limit = pending_limit,
        pending_limit = NULL,
        pending_effective_day = NULL
    WHERE pending_effective_day = #{today}
      AND pending_effective_day IS NOT NULL
</update>
```

---

## 五、API 响应格式（完整版）

### 5.1 使用贴纸 - 成功响应

```json
{
  "success": true,
  "duplicate": false,
  "actionId": 12345,
  "tagCode": "LIKE",
  "tagName": "赞同",
  "usedToday": 4,
  "remainingToday": 116,
  "quotaDay": "2025-12-14",
  "quotaResetAt": "2025-12-15T04:00:00+08:00"
}
```

### 5.2 使用贴纸 - 幂等响应（返回完整字段 + actionId）

```json
{
  "success": true,
  "duplicate": true,
  "actionId": 12345,
  "tagCode": "LIKE",
  "tagName": "赞同",
  "usedToday": 4,
  "remainingToday": 116,
  "quotaDay": "2025-12-14",
  "quotaResetAt": "2025-12-15T04:00:00+08:00",
  "message": "操作已完成（重复请求）"
}
```

### 5.3 使用贴纸 - 失败响应（包含 quota 信息）

**ALREADY_APPLIED**：
```json
{
  "success": false,
  "errorCode": "ALREADY_APPLIED",
  "i18nKey": "sticker.already_applied",
  "message": "你已对该分享使用过「秘境」",
  "tagCode": "MIJING",
  "quotaDay": "2025-12-14",
  "quotaResetAt": "2025-12-15T04:00:00+08:00"
}
```

**ALREADY_VOTED**：
```json
{
  "success": false,
  "errorCode": "ALREADY_VOTED",
  "i18nKey": "sticker.already_voted",
  "message": "你已对该分享投过票",
  "tagCode": "NEUTRAL",
  "quotaDay": "2025-12-14",
  "quotaResetAt": "2025-12-15T04:00:00+08:00"
}
```

**QUOTA_EXCEEDED**：
```json
{
  "success": false,
  "errorCode": "QUOTA_EXCEEDED",
  "i18nKey": "sticker.quota_exceeded",
  "message": "今日「秘境」使用次数已用完",
  "tagCode": "MIJING",
  "usedToday": 24,
  "remainingToday": 0,
  "dailyLimit": 24,
  "quotaDay": "2025-12-14",
  "quotaResetAt": "2025-12-15T04:00:00+08:00"
}
```

**LEVEL_LOCKED**：
```json
{
  "success": false,
  "errorCode": "LEVEL_LOCKED",
  "i18nKey": "sticker.level_locked",
  "message": "需要达到「水木清华」等级才能使用",
  "tagCode": "QIANFAN",
  "minLevelCode": "SHUIMU",
  "minLevelName": "水木清华",
  "quotaDay": "2025-12-14",
  "quotaResetAt": "2025-12-15T04:00:00+08:00"
}
```

---

## 六、业务流程（完整版）

```
┌─────────────────────────────────────────────────────────────────┐
│ POST /api/shares/{shareId}/stickers                             │
│ Body: { tagCode, clientActionId }                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. 幂等检查                                                      │
│    查询 WHERE actor_user_id=? AND client_action_id=?            │
│    → 命中 → 返回完整响应 {success:true, duplicate:true,          │
│             actionId:原记录ID, usedToday, remainingToday, ...}  │
│             【不扣配额、不加积分】                                │
└─────────────────────────────────────────────────────────────────┘
                              │ 未命中
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. 基础校验                                                      │
│    - shareId 存在？                                              │
│    - tagCode 存在且 is_active=true？                             │
│    - 用户等级 >= minLevelCode？                                  │
└─────────────────────────────────────────────────────────────────┘
                              │ 通过
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Share 级去重/互斥（快速失败，非最终确认）                       │
│    - tag 类：查 (share_id, actor_user_id, tag_code)             │
│    - vote 类：查 (share_id, actor_user_id, sticker_group='vote')│
│    → 存在 → ALREADY_APPLIED / ALREADY_VOTED【不扣配额】          │
│                                                                  │
│    ⚠️ 此步仅为快速失败，最终以 DB 唯一约束为准                    │
└─────────────────────────────────────────────────────────────────┘
                              │ 不存在
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Redis 原子扣减配额                                            │
│    调用 Lua 脚本                                                 │
│    → 失败 → QUOTA_EXCEEDED【不扣配额】                           │
└─────────────────────────────────────────────────────────────────┘
                              │ 成功
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. 写入 share_sticker_action                                     │
│                                                                  │
│    → 唯一约束冲突                                                │
│       → 调用 rollback Lua (保护下界，不减负)                     │
│       → ALREADY_APPLIED / ALREADY_VOTED                          │
│                                                                  │
│    → 其他错误                                                    │
│       → 调用 rollback Lua                                        │
│       → 系统错误                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │ 成功
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. 同步兼容表（仅 vote）                                         │
│    - vote 类：写入 share_vote + 更新 guanzhi 计数                │
│    - tag 类：【不写 share_tag_user】                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. 发放积分                                                      │
│    条件：步骤5 INSERT 成功 且 非幂等                              │
│    UserPointsService.addPoints(...)                              │
│                                                                  │
│    ⚠️ ALREADY_* / DUPLICATE / 失败 均不发放积分                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. 返回成功响应（含 actionId + 完整 quota 信息）                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 七、Checklist（实施前必须确认）

### 数据库
- [ ] migration 脚本包含 `share_sticker_action` 表的 **3 个唯一约束 DDL**
- [ ] 执行后用 SQL 验证约束确实存在
- [ ] vote 类贴纸的 `sticker_group` = `'vote'`
- [ ] tag 类贴纸的 `sticker_group` = `'tag'`（不能是 `'vote'`）
- [ ] 幂等约束是用户维度：`(actor_user_id, client_action_id)`

### Redis
- [ ] DECR 回滚脚本使用 `max(used-1, 0)` 保护下界
- [ ] DECR 仅用于 DB 写入失败回滚，**无撤回功能**
- [ ] TTL 设置 48 小时
- [ ] 并发回滚测试通过（used 不会变负）

### 业务逻辑
- [ ] 积分仅在首次 INSERT 成功时发放
- [ ] tag 类**不写** `share_tag_user`
- [ ] vote 类同步写 `share_vote`

### 定时任务
- [ ] applyPending 条件：`pending_effective_day = today`
- [ ] 三个表（tag/level/override）都有 applyPending SQL
- [ ] 应用后清空 pending 字段并记录日志

### 工具类
- [ ] `QuotaDayUtil.getNextQuotaDay()` 基于 04:00 日切规则
- [ ] 04:00 边界单元测试通过

### API
- [ ] 幂等响应返回 `actionId` + 完整字段
- [ ] 失败响应包含 `quotaDay`, `quotaResetAt`

---

## 八、验收标准

### 阶段 1：数据库迁移
```sql
-- 验证唯一约束存在
SELECT CONSTRAINT_NAME FROM information_schema.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = 'ONETTOO'
  AND TABLE_NAME = 'share_sticker_action'
  AND CONSTRAINT_TYPE = 'UNIQUE';

-- 预期结果：
-- uk_share_user_tag
-- uk_share_user_vote_group
-- uk_user_client_action
```

### 阶段 2：QuotaDayUtil
- 04:00 边界单元测试全部通过

### 阶段 3：Redis Lua
- 扣减/回滚逻辑单元测试通过
- 并发回滚测试 used 不会变负

### 阶段 4-5：Service + Controller
- 接口可调用，响应格式符合规范

### 阶段 6：定时任务
- pending 配置在 04:00 按时生效
- 只应用 `pending_effective_day = today` 的记录

### 阶段 7：管理后台
- 可配置各字段
- 保存时提示"次日 04:00 生效"

### 阶段 8：集成测试
- [ ] tag 去重测试通过
- [ ] vote 互斥测试通过
- [ ] 幂等测试通过
- [ ] 配额扣减/回滚测试通过
- [ ] 积分仅首次成功发放测试通过

---

## 九、代码文件清单

### 新增文件

| 文件 | 说明 |
|------|------|
| `ShareStickerActionDO.java` | 动作表实体 |
| `ShareStickerActionMapper.java` | Mapper |
| `ShareStickerActionMapper.xml` | Mapper XML |
| `StickerLevelQuotaOverrideDO.java` | 覆盖表实体 |
| `StickerLevelQuotaOverrideMapper.java` | Mapper |
| `StickerLevelQuotaOverrideMapper.xml` | Mapper XML |
| `StickerQuotaService.java` | 配额服务接口 |
| `StickerQuotaServiceImpl.java` | 配额服务实现 |
| `StickerController.java` | REST API |
| `QuotaDayUtil.java` | quotaDay 工具类 |
| `StickerErrorCode.java` | 错误码枚举 |
| `PendingConfigApplyTask.java` | 04:00 定时任务 |
| `StickerQuotaResetEvent.java` | 配额重置事件 |
| `migration-add-sticker-quota.sql` | 迁移脚本 |
| `sticker_quota_consume.lua` | Redis 扣减脚本 |
| `sticker_quota_rollback.lua` | Redis 回滚脚本 |

### 修改文件

| 文件 | 改动 |
|------|------|
| `TagDefinitionDO.java` | +stickerGroup, baseDailyLimit, iconUrl, pendingDailyLimit, pendingEffectiveDay |
| `TagDefinitionMapper.xml` | +applyPendingConfigs |
| `LevelDefinitionDO.java` | +dailyMultiplier, pendingMultiplier, pendingEffectiveDay |
| `LevelDefinitionMapper.xml` | +applyPendingConfigs |
| `TagDefinitionServiceImpl.java` | +getByGroup(); 废弃 hasReachedDailyTagLimit() |
| `UserLevelServiceImpl.java` | 等级条件过滤 group='tag' |

---

## 十、实施步骤

| 阶段 | 内容 | 验收标准 |
|------|------|----------|
| 1 | 执行 migration 脚本 | 3 个唯一约束存在，现有功能正常 |
| 2 | 实现 QuotaDayUtil | 04:00 边界单元测试通过 |
| 3 | 实现 Redis Lua 脚本 | 扣减/回滚测试通过，并发不变负 |
| 4 | 实现 StickerQuotaService | 配额计算正确 |
| 5 | 实现 StickerController | API 可调用，响应格式正确 |
| 6 | 实现 04:00 定时任务 | pending 配置按时生效 |
| 7 | 管理后台扩展 | 可配置，提示次日生效 |
| 8 | 集成测试 | 去重/互斥/幂等/配额/积分全通过 |

---

**文档结束**
