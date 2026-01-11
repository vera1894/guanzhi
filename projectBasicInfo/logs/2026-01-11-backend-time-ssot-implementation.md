# 后端 Time SSOT 实施计划

**版本**: v2.9（放行版）
**创建日期**: 2026-01-11
**更新日期**: 2026-01-11
**状态**: **已通过审查，可实施**

> v2.9 更新（根据 GPT 最终放行审查）：
> - **Druid init-sqls**：改成数组写法（避免 Spring binder 不解析导致失效）
> - **StartupTimeZoneValidator**：改用 Map 注入 + 白名单校验，去掉 required=false（确保 fail-fast 生效）
> - **Phase 7 示例日志**：对齐 v2.8（移除 global/system，只显示 session）
> - **CI 脚本 grep**：改用 `-Ew` 扩展正则（跨平台更稳定）
> - **ZoneId.systemDefault 说明**：明确禁止范围是后端，前端展示应跟随系统时区

---

## 一、简化前提

| 条件 | 状态 |
|------|------|
| 当前数据几乎都是自己的 | ✅ |
| 还没有公测 | ✅ |
| 没有外部用户/旧版本需要兼容 | ✅ |
| 可以清空互动/日志类数据 | ✅ |

**结论**：采用最简方案，不做历史兼容。

---

## 二、核心约定

### 2.1 LocalDateTime UTC 语义约定

> **从 v2.6 起，所有写入 LocalDateTime/Date 字段的值，都代表 UTC 时间。**
>
> 任何需要本地日历含义的业务（如配额日）必须走业务日历工具，不得直接调用 `LocalDateTime.now()`。

**v2.6 硬性守门机制**：
- 禁止项落地为 CI 检查脚本（见 5.6 节），**全部 ERROR 级别**
- 新增禁止：`System.currentTimeMillis()`、`ZoneId.systemDefault()`、`new Date()`
- 白名单机制：仅允许 TimeProvider.java、*Test*.java、metrics/trace 包内使用
- **v2.6 新增**：同一 API 响应禁止同时出现旧 key（createDate）与新 key（createDateMs）

### 2.2 业务日历例外：QuotaDayUtil

**QuotaDayUtil** 是唯一允许使用上海时区的特殊业务模块：
- 用途：配额日计算（按上海时区 04:00 切换日期）
- 规则：这是**业务日历例外**，不是系统时间

**当前状态**（v2.3 确认）：
- QuotaDayUtil 是 **static 工具类**（非 Spring Bean）
- 无法直接注入 TimeProvider

**落地方式：传参方案**（Phase 4 执行）：
```java
// 改造前（违规：直接调用 LocalDateTime.now）
public static LocalDate getCurrentQuotaDay() {
    return getQuotaDay(LocalDateTime.now(ZONE_SHANGHAI));
}

// 改造后（合规：调用方传入 Instant）
public static LocalDate getCurrentQuotaDay(Instant now) {
    ZonedDateTime shanghaiTime = now.atZone(ZONE_SHANGHAI);
    return getQuotaDay(shanghaiTime.toLocalDateTime());
}
```

### 2.3 接口路径规范（v2.4 澄清）

**规则**：
- **GuanZhi 模块**：无 `/api` 前缀，直接 `/guan/...`
- **其他模块**（Comments、Notifications 等）：使用 `/api/...` 前缀
- **验收以 Controller 的 `@RequestMapping` 为准**

**模块与前缀对应关系**：

| 模块 | Controller 文件 | @RequestMapping | 验收路径示例 |
|------|----------------|-----------------|--------------|
| 观之 | GuanZhiController.java | `/guan` | `POST /guan/list` |
| 评论 | CommentsController.java | `/api/shares` | `GET /api/shares/{id}/comments` |
| 通知 | NotificationController.java | `/api/notifications` | `GET /api/notifications` |
| 用户 | UserController.java | 待确认 | 待确认 |

### 2.4 DB 字段类型确认（v2.4 新增）

**Java 类型与 DB 字段对应**：

| DO 类 | Java 字段 | Java 类型 | DB 字段类型（待确认） |
|-------|----------|-----------|---------------------|
| GuanzhiDO (BaseDO) | createDate | `java.util.Date` | 待确认 |
| ShareCommentDO | createdAt | `LocalDateTime` | 待确认 |
| ShareViewLogDO | createdAt | `LocalDateTime` | 待确认 |
| NotificationDO | createdAt | `LocalDateTime` | 待确认 |

**TIMESTAMP vs DATETIME 行为差异**：
- **TIMESTAMP**：受 `session time_zone` 影响，读写会做时区转换
- **DATETIME**：不带时区语义，存什么就是什么

**Phase 1 必须执行的字段类型检查**：见 3.2 节

---

## 三、数据处理策略

### 3.1 保留的表

| 表 | 说明 |
|----|------|
| guanzhi (Share) | 观之主内容 |
| user | 用户信息 |

### 3.2 DB 字段类型检查（v2.4 新增，必须执行）

**目的**：确认关键时间字段是 TIMESTAMP 还是 DATETIME

```sql
-- 先设置 session 时区
SET time_zone = '+00:00';

-- 检查 guanzhi 表
SHOW COLUMNS FROM guanzhi LIKE 'create_date';

-- 检查 share_comment 表
SHOW COLUMNS FROM share_comment LIKE 'created_at';

-- 检查 share_view_log 表
SHOW COLUMNS FROM share_view_log LIKE 'created_at';

-- 检查 notification 表
SHOW COLUMNS FROM notification LIKE 'created_at';
```

**记录结果**（执行后填写）：

| 表 | 字段 | 类型 | 说明 |
|----|------|------|------|
| guanzhi | create_date | ___ | |
| share_comment | created_at | ___ | |
| share_view_log | created_at | ___ | |
| notification | created_at | ___ | |

**处理规则**：
- 如果是 **TIMESTAMP**：`SET time_zone = '+00:00'` 是关键保障
- 如果是 **DATETIME**：强制 session UTC 是"纪律"，需确保写入时已是 UTC

### 3.3 清空的表

| 表 | 说明 |
|----|------|
| share_comment | 评论 |
| comment_like | 评论点赞 |
| share_view_log | 浏览记录 |
| share_sticker_action | 贴纸行为 |
| share_vote | 赞同/无感 |
| share_checkin | 打卡记录 |

### 3.4 guanzhi 旧数据抽样检查与修正（v2.8 强默认决策门）

**重要**：执行前先设置 session 时区，避免客户端转换影响判断

#### 3.4.0 决策门（v2.8 强默认，不可跳过）

**v2.8 强默认策略**：既然还没公测、数据几乎都是自己的，默认走"清空"最简路径。

| will_fix 数量 | 默认决策 | 操作 |
|--------------|---------|------|
| 0 | 无需修正 | 直接跳过 3.4.3 |
| < 100 条 | 直接修 | 有备份表，执行 3.4.3 |
| **≥ 100 条** | **默认清空 guanzhi** | 最干净、最快闭环，重新发几条即可 |
| ≥ 100 条 且明确要保留 | 例外：抽样确认 | 只有明确要保留才走 3.4.2 → 3.4.3 |

**强默认原则**：
- will_fix ≥ 100 且未公测 → **默认清空**（不需要讨论）
- 只有"明确要保留那批数据"时才走抽样修正路径
- 目标是"不复杂"，不是"兼容旧数据"

**不可跳过**：必须先跑 3.4.1 统计，记录 total/will_fix，然后按上表决策。

#### 3.4.1 执行前统计

```sql
-- 先设置 session 时区为 UTC
SET time_zone = '+00:00';

-- 统计总量
SELECT COUNT(*) AS total FROM guanzhi;

-- v2.6：使用半开区间统计（避免边界歧义）
-- 假设 bug 发生在 2026-01-01 00:00:00 ~ 2026-01-11 00:00:00 之间
SELECT COUNT(*) AS will_fix
FROM guanzhi
WHERE create_date >= '2026-01-01 00:00:00'
  AND create_date < '2026-01-11 00:00:00';

-- 查看时间分布（按日）
SELECT DATE(create_date) as dt, COUNT(*) as cnt
FROM guanzhi
GROUP BY DATE(create_date)
ORDER BY dt DESC
LIMIT 20;

-- v2.6 新增：抽样将要修正的 id 列表（前 50 条）
SELECT id, create_date, UNIX_TIMESTAMP(create_date) as epoch_sec
FROM guanzhi
WHERE create_date >= '2026-01-01 00:00:00'
  AND create_date < '2026-01-11 00:00:00'
ORDER BY id ASC
LIMIT 50;
-- 肉眼确认：这些都是我那几天发的吗？
```

#### 3.4.2 抽样并备份

```sql
-- 抽样 10 条老数据并记录到临时备份
CREATE TABLE guanzhi_time_backup AS
SELECT id, create_date, UNIX_TIMESTAMP(create_date) as epoch_sec
FROM guanzhi
ORDER BY id ASC
LIMIT 10;

-- 查看备份
SELECT * FROM guanzhi_time_backup;
```

**判断**：
- 用肉眼对比"当时发的北京时间"与 DB 里的 `create_date`
- 如果发现整体偏 +8 或 -8 小时，说明历史写入有问题

#### 3.4.3 修正（只执行一次！半开区间）

```sql
-- 先设置 session 时区
SET time_zone = '+00:00';

-- v2.6：使用半开区间（>= start AND < end），避免边界歧义
-- 方案 A：如果偏移 +8 小时（把北京时间当 UTC 写入）
UPDATE guanzhi
SET create_date = DATE_SUB(create_date, INTERVAL 8 HOUR)
WHERE create_date >= '2026-01-01 00:00:00'
  AND create_date < '2026-01-11 00:00:00';

-- 方案 B：如果偏移 -8 小时（把 UTC 当北京时间写入）
UPDATE guanzhi
SET create_date = DATE_ADD(create_date, INTERVAL 8 HOUR)
WHERE create_date >= '2026-01-01 00:00:00'
  AND create_date < '2026-01-11 00:00:00';
```

**注意**：
- 根据 3.4.1 的统计结果调整时间窗口
- **必须先看抽样 id 列表**，确认都是你那几天发的
- 半开区间 `[start, end)` 含义：包含 start，不含 end

#### 3.4.4 修正后验证

```sql
-- 对比修正前后
SELECT
    b.id,
    b.create_date as before_fix,
    g.create_date as after_fix,
    b.epoch_sec as before_epoch,
    UNIX_TIMESTAMP(g.create_date) as after_epoch
FROM guanzhi_time_backup b
JOIN guanzhi g ON b.id = g.id;

-- 确认无误后删除备份表
DROP TABLE guanzhi_time_backup;
```

### 3.5 清空 SQL（FK 安全）

```sql
-- 先设置 session 时区
SET time_zone = '+00:00';

-- 关闭外键检查，防止 TRUNCATE 失败
SET FOREIGN_KEY_CHECKS=0;

TRUNCATE TABLE share_comment;
TRUNCATE TABLE comment_like;
TRUNCATE TABLE share_view_log;
TRUNCATE TABLE share_sticker_action;
TRUNCATE TABLE share_vote;
TRUNCATE TABLE share_checkin;

-- 恢复外键检查
SET FOREIGN_KEY_CHECKS=1;
```

### 3.6 清空验收

```sql
SELECT 'share_comment' as tbl, COUNT(*) as cnt FROM share_comment
UNION ALL SELECT 'comment_like', COUNT(*) FROM comment_like
UNION ALL SELECT 'share_view_log', COUNT(*) FROM share_view_log
UNION ALL SELECT 'share_sticker_action', COUNT(*) FROM share_sticker_action
UNION ALL SELECT 'share_vote', COUNT(*) FROM share_vote
UNION ALL SELECT 'share_checkin', COUNT(*) FROM share_checkin;
-- 所有 cnt 应为 0
```

---

## 四、目标架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    后端 Time SSOT 架构（v2.4）                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  环境层                        写入层                      输出层            │
│  ─────                        ─────                       ─────            │
│  JVM: -Duser.timezone=UTC     TimeProvider.now()         epoch ms (Long)   │
│  DB session: +00:00           (Instant → LocalDateTime)   唯一格式          │
│  JDBC: serverTimezone=UTC     统一 UTC 语义               通过 VO 显式输出   │
│                                                                             │
│  强制约束：                                                                  │
│  - 启动时验证时区，不一致则 fail-fast（启动失败）                            │
│  - v2.7：session 必须显式 +00:00，不允许 SYSTEM（避免权限误伤）              │
│  - 所有 API 只返回 *Ms 字段，不返回字符串时间                                │
│  - 不依赖 Jackson 全局配置                                                  │
│  - 禁止代码中直接调用 LocalDateTime.now() / new Date() / Instant.now()      │
│                                                                             │
│  业务例外：                                                                  │
│  - QuotaDayUtil：配额日计算（固定 Asia/Shanghai + 04:00 规则）              │
│  - 调用方传入 TimeProvider.now() 的 Instant                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 五、实施步骤

### Phase 1: 数据处理

#### 1.1 DB 字段类型检查（必须先做）
见 3.2 节

#### 1.2 guanzhi 旧数据抽样检查与修正
见 3.4 节

#### 1.3 清空互动/日志表
见 3.5 节

---

### Phase 2: 强制 UTC 环境 + Fail-Fast 验证

**目标**：确保 JVM/DB session/JDBC 全部 UTC，不一致则启动失败

#### 2.1 JVM 启动参数（必须）

```bash
# start.sh 中添加
java -Duser.timezone=UTC -jar onettoo.jar --spring.profiles.active=prod
```

#### 2.2 JDBC URL serverTimezone（必须）

**确认配置**（已在 application.yml / application-prod.yml 中）：
```yaml
spring:
  datasource:
    one:
      jdbc-url: jdbc:log4jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?serverTimezone=UTC&characterEncoding=utf8&useSSL=false
    druid:
      url: jdbc:log4jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?serverTimezone=UTC&characterEncoding=utf8&useSSL=false
```

#### 2.3 DB Session 强制 UTC（v2.7 多数据源落地）

**v2.7 要求**：必须明确列出所有 DataSource 及各自的 init-sql 配置位置

##### 2.3.1 项目 DataSource 清单

| DataSource 名称（Spring Bean） | 配置位置 | init-sql 配置方式 |
|------------------------------|---------|------------------|
| `dataSourceOne` (spring.datasource.one) | application.yml | HikariCP: connection-init-sql |
| `druidDataSource` (spring.datasource.druid) | application.yml | Druid: connection-init-sqls |

> **验收要求**：StartupTimeZoneValidator 日志必须输出每个 DS 的成功验证行

##### 2.3.2 各 DataSource 配置示例（v2.9 修正）

```yaml
# application.yml - 所有 DataSource 都必须配置 init-sql
spring:
  datasource:
    # DataSource One (HikariCP)
    one:
      jdbc-url: jdbc:log4jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?serverTimezone=UTC&characterEncoding=utf8&useSSL=false
      # HikariCP 使用 connection-init-sql（注意是单数，字符串）
      hikari:
        connection-init-sql: SET time_zone = '+00:00'

    # DataSource Druid
    druid:
      url: jdbc:log4jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?serverTimezone=UTC&characterEncoding=utf8&useSSL=false
      # v2.9 重要：Druid 必须用数组写法！字符串写法可能不生效
      connection-init-sqls:
        - "SET time_zone = '+00:00'"
```

**v2.9 关键修正**：
- **HikariCP**: `hikari.connection-init-sql`（单数，字符串）
- **Druid**: `connection-init-sqls`（复数，**必须用数组写法**）

⚠️ **警告**：Druid 写成 `connection-init-sqls: SET time_zone = '+00:00'` 可能被 Spring binder 忽略，导致 session 仍是 SYSTEM！

#### 2.4 业务连接健康检查端点（v2.7 安全加固）

**目的**：验证 `connection-init-sqls` 配置确实生效

##### 2.4.0 安全要求（v2.7 新增）

**⚠️ 上线门槛**：`/internal/health/*` 必须受保护，不可公网访问

| 保护方式 | 说明 |
|---------|------|
| IP 白名单 | 只允许内网/堡垒机 IP 访问 |
| Spring Security | 添加 Basic Auth 或 JWT 鉴权 |
| Nginx 层拦截 | location /internal/ { deny all; } |

**原因**：该端点会返回 JVM 时区、数据源名称、session time_zone 等内部信息，属于不必要的信息暴露。

**定位**：这是"上线前验收工具"，不是开放 API。

```java
package com.cloud.onettoo.common.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.HashMap;
import java.util.Map;

/**
 * Time SSOT 健康检查端点
 * 用于验证业务连接的 session time_zone 是否正确
 */
@RestController
@RequestMapping("/internal/health")
public class TimeZoneHealthController {

    @Autowired
    private Map<String, DataSource> dataSources;

    @GetMapping("/timezone")
    public Map<String, Object> checkTimeZone() throws Exception {
        Map<String, Object> result = new HashMap<>();
        result.put("jvmTimeZone", java.util.TimeZone.getDefault().getID());

        Map<String, Map<String, String>> dsResults = new HashMap<>();
        for (Map.Entry<String, DataSource> entry : dataSources.entrySet()) {
            String dsName = entry.getKey();
            DataSource ds = entry.getValue();

            Map<String, String> dsInfo = new HashMap<>();
            try (Connection conn = ds.getConnection();
                 Statement stmt = conn.createStatement();
                 ResultSet rs = stmt.executeQuery(
                     "SELECT @@session.time_zone, NOW(), UTC_TIMESTAMP()")) {
                if (rs.next()) {
                    dsInfo.put("sessionTimeZone", rs.getString(1));
                    dsInfo.put("now", rs.getString(2));
                    dsInfo.put("utcTimestamp", rs.getString(3));
                }
            }
            dsResults.put(dsName, dsInfo);
        }
        result.put("dataSources", dsResults);
        return result;
    }
}
```

**使用方式**：
```bash
# 部署后调用健康检查，确认所有连接的 session time_zone 都是 +00:00
curl http://localhost:8085/internal/health/timezone
```

#### 2.5 启动验证类（v2.9 Map 注入 + 强制 fail-fast）

**v2.9 关键修正**：
- 改用 `Map<String, DataSource>` 注入（与 health 端点一致）
- 只验证白名单业务 DataSource（过滤非 MySQL DS）
- **去掉 required=false**：白名单 DS 必须存在，否则直接 fail-fast
- 只查 @@session.time_zone，不允许 SYSTEM

**最简硬闸门**：白名单 DS 必须存在 + session 必须显式 +00:00

```java
package com.cloud.onettoo.common.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.TimeZone;

/**
 * Time SSOT - 启动时验证时区配置
 * v2.9：Map 注入 + 强制 fail-fast
 * - 使用 Map<String, DataSource> 注入（更可靠）
 * - 只验证白名单业务 DataSource（过滤非 MySQL DS）
 * - 白名单 DS 必须存在且验证通过，否则 fail-fast
 * - 只查 @@session.time_zone，不允许 SYSTEM
 */
@Component
@Slf4j
public class StartupTimeZoneValidator implements ApplicationRunner {

    // v2.9：白名单 - 必须验证这些业务 DataSource
    private static final List<String> REQUIRED_DS_NAMES = Arrays.asList(
        "dataSourceOne",      // spring.datasource.one
        "druidDataSource"     // spring.datasource.druid
    );

    // v2.9：使用 Map 注入，与 health 端点一致
    @Autowired
    private Map<String, DataSource> dataSources;

    @Override
    public void run(ApplicationArguments args) throws Exception {
        log.info("========== Time SSOT 启动验证 v2.9 ==========");

        // 1. 验证 JVM 时区
        String jvmTz = TimeZone.getDefault().getID();
        log.info("JVM TimeZone: {}", jvmTz);

        if (!"UTC".equals(jvmTz) && !"GMT".equals(jvmTz) && !jvmTz.startsWith("Etc/UTC")) {
            log.error("JVM 时区不是 UTC！当前: {}", jvmTz);
            log.error("请添加启动参数: -Duser.timezone=UTC");
            throw new IllegalStateException("Time SSOT 验证失败：JVM 时区必须是 UTC，当前是 " + jvmTz);
        }
        log.info("JVM 时区验证通过");

        // 2. v2.9：验证白名单业务 DataSource（必须存在且通过）
        log.info("注入的 DataSource: {}", dataSources.keySet());
        int validated = 0;

        for (String dsName : REQUIRED_DS_NAMES) {
            DataSource ds = dataSources.get(dsName);
            if (ds == null) {
                // v2.9：白名单 DS 必须存在，否则 fail-fast
                log.error("必需的 DataSource [{}] 未找到！请检查配置", dsName);
                throw new IllegalStateException(
                    "Time SSOT 验证失败：必需的 DataSource [" + dsName + "] 不存在");
            }
            validateDataSource(dsName, ds);
            validated++;
        }

        log.info("已验证 {} 个业务 DataSource", validated);
        log.info("========== Time SSOT 验证全部通过 ==========");
    }

    private void validateDataSource(String dsName, DataSource dataSource) throws Exception {
        try (Connection conn = dataSource.getConnection();
             Statement stmt = conn.createStatement()) {

            // v2.8：只查 @@session.time_zone（移除 @@global/@@system）
            try (ResultSet rs = stmt.executeQuery("SELECT @@session.time_zone")) {
                if (rs.next()) {
                    String sessionTz = rs.getString(1);
                    log.info("[{}] session.time_zone: {}", dsName, sessionTz);

                    // 允许的值只有 UTC, +00:00, +0:00（不允许 SYSTEM）
                    boolean isExplicitUtc = "UTC".equalsIgnoreCase(sessionTz)
                            || "+00:00".equals(sessionTz)
                            || "+0:00".equals(sessionTz);

                    if ("SYSTEM".equals(sessionTz)) {
                        log.error("[{}] session=SYSTEM 不允许！必须显式设置为 +00:00", dsName);
                        log.error("[{}] 请检查 connection-init-sql 是否配置正确", dsName);
                        throw new IllegalStateException(
                            "Time SSOT 验证失败：[" + dsName + "] session 不能是 SYSTEM");
                    } else if (!isExplicitUtc) {
                        log.error("[{}] session 时区不是 UTC！当前: {}", dsName, sessionTz);
                        throw new IllegalStateException(
                            "Time SSOT 验证失败：[" + dsName + "] session 必须是 +00:00");
                    } else {
                        log.info("[{}] session 时区验证通过", dsName);
                    }
                }
            }

            // 验证 NOW() vs UTC_TIMESTAMP() 一致性
            try (ResultSet rs = stmt.executeQuery(
                    "SELECT NOW(), UTC_TIMESTAMP(), TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), NOW())")) {
                if (rs.next()) {
                    String nowStr = rs.getString(1);
                    String utcStr = rs.getString(2);
                    int diff = rs.getInt(3);
                    log.info("[{}] NOW()={}, UTC_TIMESTAMP()={}, diff={} 秒", dsName, nowStr, utcStr, diff);

                    if (Math.abs(diff) > 1) {
                        log.error("[{}] NOW() vs UTC_TIMESTAMP() 差值过大：{} 秒", dsName, diff);
                        throw new IllegalStateException(
                            "Time SSOT 验证失败：[" + dsName + "] DB 时间与 UTC 差值过大");
                    }
                    log.info("[{}] DB 时间一致性验证通过", dsName);
                }
            }
        }
    }
}
```

---

### Phase 3: TimeProvider 工具类（v2.4 增强）

```java
package com.cloud.onettoo.common.utils;

import org.springframework.stereotype.Component;
import java.time.*;

/**
 * Time SSOT - 时间提供者
 *
 * 唯一的"当前时间"获取入口
 *
 * 语义约定：
 * - 所有时间都是 UTC 语义
 * - nowLocalDateTime() 返回的 LocalDateTime 代表 UTC 时间
 * - 禁止业务代码直接调用 LocalDateTime.now() / new Date() / Instant.now()
 *
 * 例外：
 * - QuotaDayUtil 由调用方传入 now() 的 Instant
 */
@Component
public class TimeProvider {

    private volatile Clock clock = Clock.systemUTC();

    // ========== 获取当前时间 ==========

    /**
     * 获取当前时间瞬间（UTC）
     */
    public Instant now() {
        return Instant.now(clock);
    }

    /**
     * 获取当前时间的 epoch 毫秒（UTC）
     */
    public long nowEpochMs() {
        return now().toEpochMilli();
    }

    /**
     * 获取当前 UTC LocalDateTime
     *
     * 语义约定：返回值代表 UTC 时间，不是本地时间
     * 用于：兼容现有 LocalDateTime 类型的数据库字段
     */
    public LocalDateTime nowLocalDateTime() {
        return LocalDateTime.now(clock.withZone(ZoneOffset.UTC));
    }

    // ========== 转换工具方法（v2.8 null 透传）==========

    /**
     * UTC LocalDateTime 转 epoch 毫秒
     *
     * 用于 VO 转换，避免各处重复写 .toInstant(ZoneOffset.UTC).toEpochMilli()
     *
     * v2.8：null → null（不返回 0，避免前端显示 1970）
     *
     * @param utcLocalDateTime 代表 UTC 时间的 LocalDateTime
     * @return epoch 毫秒，如果输入为 null 则返回 null
     */
    public static Long toEpochMs(LocalDateTime utcLocalDateTime) {
        if (utcLocalDateTime == null) return null;
        return utcLocalDateTime.toInstant(ZoneOffset.UTC).toEpochMilli();
    }

    /**
     * epoch 毫秒转 UTC LocalDateTime
     *
     * 用于某些需要 LocalDateTime 的存储/计算场景
     *
     * @param epochMs epoch 毫秒（可为 null）
     * @return 代表 UTC 时间的 LocalDateTime，如果输入为 null 则返回 null
     */
    public static LocalDateTime fromEpochMs(Long epochMs) {
        if (epochMs == null) return null;
        return LocalDateTime.ofInstant(Instant.ofEpochMilli(epochMs), ZoneOffset.UTC);
    }

    /**
     * java.util.Date 转 epoch 毫秒
     *
     * 用于 GuanzhiDO 等使用 Date 类型的 VO 转换
     *
     * v2.8：null → null（不返回 0，避免前端显示 1970）
     *
     * @param date java.util.Date
     * @return epoch 毫秒，如果输入为 null 则返回 null
     */
    public static Long toEpochMs(java.util.Date date) {
        if (date == null) return null;
        return date.getTime();
    }

    // ========== 测试支持 ==========

    void setClockForTesting(Clock clock) { this.clock = clock; }
    void resetClockForTesting() { this.clock = Clock.systemUTC(); }
}
```

---

### Phase 4: 改造写入点

#### 4.1 常规写入点改造

| 文件 | 当前实现 | 改造 |
|------|----------|------|
| ShareCommentServiceImpl.java | `LocalDateTime.now(ZoneOffset.UTC)` | `timeProvider.nowLocalDateTime()` |
| StickerQuotaServiceImpl.java | 同上 | 同上 |
| ShareViewLogServiceImpl.java | 同上 | 同上 |
| DeviceService.java | 同上 | 同上 |
| AdminOperationLogServiceImpl.java | 同上 | 同上 |
| CommentHotScoreService.java | 同上 | 同上 |
| ApiError.java | 同上 | 同上 |

#### 4.2 QuotaDayUtil 特殊改造（传参方案）

```java
// QuotaDayUtil.java - 改造后

package com.cloud.onettoo.common.utils;

import java.time.*;

/**
 * 配额日期工具类
 * 规则：每天 04:00 (Asia/Shanghai) 为切换时间点
 *
 * Time SSOT 说明：
 * - 这是业务日历例外，允许使用上海时区
 * - 调用方必须传入 TimeProvider.now() 的 Instant
 * - 禁止在本类内部直接调用 LocalDateTime.now()
 */
public class QuotaDayUtil {

    private static final ZoneId ZONE_SHANGHAI = ZoneId.of("Asia/Shanghai");
    private static final int CUTOFF_HOUR = 4;

    /**
     * 获取当前的配额日期
     * @param now 当前 UTC 时间（由调用方通过 TimeProvider.now() 获取）
     */
    public static LocalDate getCurrentQuotaDay(Instant now) {
        ZonedDateTime shanghaiTime = now.atZone(ZONE_SHANGHAI);
        return getQuotaDay(shanghaiTime.toLocalDateTime());
    }

    /**
     * 根据给定时间计算配额日期
     */
    public static LocalDate getQuotaDay(LocalDateTime dateTime) {
        if (dateTime.getHour() < CUTOFF_HOUR) {
            return dateTime.toLocalDate().minusDays(1);
        }
        return dateTime.toLocalDate();
    }

    /**
     * 计算距离下一个 04:00 的秒数（用于 Redis TTL）
     * @param now 当前 UTC 时间（由调用方通过 TimeProvider.now() 获取）
     */
    public static long secondsUntilNextCutoff(Instant now) {
        ZonedDateTime shanghaiTime = now.atZone(ZONE_SHANGHAI);
        LocalDateTime localNow = shanghaiTime.toLocalDateTime();
        LocalDateTime nextCutoff;

        if (localNow.getHour() < CUTOFF_HOUR) {
            nextCutoff = localNow.toLocalDate().atTime(CUTOFF_HOUR, 0);
        } else {
            nextCutoff = localNow.toLocalDate().plusDays(1).atTime(CUTOFF_HOUR, 0);
        }

        return Duration.between(localNow, nextCutoff).getSeconds();
    }

    // ... 其他方法保持不变 ...

    private QuotaDayUtil() {}
}
```

---

### Phase 5: API 输出统一为 epoch ms（通过 VO 显式输出）

**关键原则**：
- **不依赖 Jackson 全局配置**
- **所有时间字段通过 VO 显式转换为 Long (epoch ms)**
- **使用 TimeProvider 的静态工具方法，避免各处重复写转换逻辑**

#### 5.1 ShareVO（观之）- 使用 TimeProvider 工具方法

```java
package com.cloud.onettoo.modules.vo;

import com.cloud.onettoo.common.utils.TimeProvider;
import com.cloud.onettoo.modules.model.GuanzhiDO;
import lombok.Data;
import java.math.BigDecimal;

/**
 * 观之 VO - 对外 API 返回
 * 所有时间字段统一为 epoch ms
 */
@Data
public class ShareVO {
    private Integer id;
    private Integer userId;
    private String data;
    private BigDecimal longitude;
    private BigDecimal latitude;
    private Integer status;
    private Integer fadeScore;
    private Integer agreeCount;
    private Integer neutralCount;

    // 时间字段：统一为 epoch ms
    private Long createDateMs;

    public static ShareVO from(GuanzhiDO entity) {
        if (entity == null) return null;

        ShareVO vo = new ShareVO();
        vo.setId(entity.getId());
        vo.setUserId(entity.getUserId());
        vo.setData(entity.getData());
        vo.setLongitude(entity.getLongitude());
        vo.setLatitude(entity.getLatitude());
        vo.setStatus(entity.getStatus());
        vo.setFadeScore(entity.getFadeScore());
        vo.setAgreeCount(entity.getAgreeCount());
        vo.setNeutralCount(entity.getNeutralCount());

        // 使用 TimeProvider 工具方法
        vo.setCreateDateMs(TimeProvider.toEpochMs(entity.getCreateDate()));

        return vo;
    }
}
```

#### 5.2 CommentVO（评论）- 使用 TimeProvider 工具方法

```java
package com.cloud.onettoo.modules.vo;

import com.cloud.onettoo.common.utils.TimeProvider;
import com.cloud.onettoo.modules.model.ShareCommentDO;
import lombok.Data;

@Data
public class CommentVO {
    private Long id;
    private Long shareId;
    private Long userId;
    private String content;
    private Integer likeCount;

    // 时间字段：统一为 epoch ms
    private Long createdAtMs;

    public static CommentVO from(ShareCommentDO entity) {
        if (entity == null) return null;

        CommentVO vo = new CommentVO();
        vo.setId(entity.getId());
        vo.setShareId(entity.getShareId());
        vo.setUserId(entity.getUserId());
        vo.setContent(entity.getContent());
        vo.setLikeCount(entity.getLikeCount());

        // 使用 TimeProvider 工具方法
        vo.setCreatedAtMs(TimeProvider.toEpochMs(entity.getCreatedAt()));

        return vo;
    }
}
```

#### 5.3 需要改造的 Controller/Service

| 接口 | 当前返回 | 改为 |
|------|----------|------|
| `POST /guan/list` | `Page<GuanzhiDO>` | `Page<ShareVO>` |
| `POST /guan/share/info` | `GuanzhiDO` | `ShareVO` |
| `GET /api/shares/{id}/comments` | `List<CommentVO>` | 确保 CommentVO 只有 `createdAtMs` |
| `GET /api/notifications` | NotificationVO | 确保只有 `createdAtMs` |

#### 5.4 全局时间字段泄漏检查（v2.5 增强）

**目的**：防止其他接口继续返回 DO/DTO 中的 Date/LocalDateTime 字段

##### 5.4.1 静态扫描：DO 类型出现位置（v2.5 扩展到 Service 层）

```bash
# 在项目目录下扫描直接使用 DO 类型的位置
cd /path/to/onettoo/src/main/java

# 扫描 GuanzhiDO 在 Controller 和 Service 中的使用
grep -rn "GuanzhiDO" --include="*Controller.java" --include="*Service*.java"

# 扫描 ShareCommentDO 在 Controller 和 Service 中的使用
grep -rn "ShareCommentDO" --include="*Controller.java" --include="*Service*.java"

# 扫描 NotificationDO 在 Controller 和 Service 中的使用
grep -rn "NotificationDO" --include="*Controller.java" --include="*Service*.java"

# v2.5：扫描可能导致泄漏的返回语句
grep -rn "return.*DO\|RestOut\.success.*DO\|PageResult.*DO" --include="*Controller.java"
```

##### 5.4.2 运行时扫描：日期字符串 + key 名（v2.5 增强 regex）

```bash
# 检查 /guan/list 响应
curl -s http://localhost:8085/guan/list -X POST -H "Content-Type: application/json" \
  -d '{"longitude": 116.4, "latitude": 39.9}' > /tmp/guan_list.json

# v2.5：检查是否包含日期字符串格式（包括 ISO8601 的 T 分隔符）
grep -E "[0-9]{4}-[0-9]{2}-[0-9]{2}(T|\ )" /tmp/guan_list.json
# 期望：无匹配

# 检查是否包含非 *Ms 的时间字段 key
grep -E '"createDate"|"createdAt"|"updatedAt"|"create_date"|"created_at"' /tmp/guan_list.json
# 期望：无匹配（应该只有 createDateMs、createdAtMs）
```

#### 5.5 全局野生时间获取扫描（v2.5 增强）

**目的**：确保没有遗漏的野生时间获取代码

```bash
# 在项目 src 目录下执行
cd /path/to/onettoo/src/main/java

# 扫描 LocalDateTime.now
grep -rn "LocalDateTime\.now(" --include="*.java"
# 期望结果：只有 TimeProvider.java 中有

# 扫描 new Date()
grep -rn "new Date(" --include="*.java"
# 期望结果：无（或仅在不涉及业务时间的地方）

# 扫描 Instant.now
grep -rn "Instant\.now(" --include="*.java"
# 期望结果：只有 TimeProvider.java 中有

# 扫描 ZonedDateTime.now
grep -rn "ZonedDateTime\.now(" --include="*.java"
# 期望结果：无

# v2.5 新增：扫描 System.currentTimeMillis()
grep -rn "System\.currentTimeMillis(" --include="*.java"
# 期望结果：无（或仅在非业务时间场景）

# v2.5 新增：扫描 ZoneId.systemDefault() 在关键层的使用
grep -rn "ZoneId\.systemDefault\|systemDefault()" --include="*VO.java" --include="*Service*.java" --include="*Controller.java"
# 期望结果：无
```

#### 5.6 CI 检查脚本（v2.6 全部 ERROR + 白名单）

**目的**：将禁止项落地为自动化检查，防止回退

**创建脚本** `scripts/time-ssot-check.sh`：

```bash
#!/bin/bash
# Time SSOT CI 检查脚本 v2.9
# 所有禁止项都是 ERROR（会让 CI 失败）
# 白名单：TimeProvider.java、*Test*.java、metrics/trace 包
# v2.9：混用检测改用 grep -Ew 扩展正则（跨平台更稳定）
# v2.9：DO 泄漏检测改为检测返回/签名（避免 import 误杀）

set -e

SRC_DIR="src/main/java"
ERRORS=0

# 白名单路径（这些文件允许使用时间 API）
WHITELIST="TimeProvider.java|Test|/metrics/|/trace/"

# v2.7：关键接口 Controller（iOS 在用的，必须严格检查）
CRITICAL_CONTROLLERS="GuanZhiController|CommentsController|NotificationController"

echo "========== Time SSOT CI 检查 v2.9 =========="

# 1. 检查野生时间获取（全部 ERROR）
echo "检查野生时间获取代码..."

# LocalDateTime.now（排除白名单）
MATCHES=$(grep -rn "LocalDateTime\.now(" --include="*.java" "$SRC_DIR" | grep -Ev "$WHITELIST" || true)
COUNT=$(echo "$MATCHES" | grep -c . || echo 0)
if [ "$COUNT" -gt 0 ]; then
    echo "ERROR: 发现 $COUNT 处 LocalDateTime.now() 调用（应使用 TimeProvider）"
    echo "$MATCHES"
    ERRORS=$((ERRORS + 1))
fi

# Instant.now（排除白名单）- v2.6：补充打印命中位置
MATCHES=$(grep -rn "Instant\.now(" --include="*.java" "$SRC_DIR" | grep -Ev "$WHITELIST" || true)
COUNT=$(echo "$MATCHES" | grep -c . || echo 0)
if [ "$COUNT" -gt 0 ]; then
    echo "ERROR: 发现 $COUNT 处 Instant.now() 调用（应使用 TimeProvider）"
    echo "$MATCHES"
    ERRORS=$((ERRORS + 1))
fi

# new Date() - v2.6：升级为 ERROR（排除白名单）
MATCHES=$(grep -rn "new Date(" --include="*.java" "$SRC_DIR" | grep -Ev "$WHITELIST" || true)
COUNT=$(echo "$MATCHES" | grep -c . || echo 0)
if [ "$COUNT" -gt 0 ]; then
    echo "ERROR: 发现 $COUNT 处 new Date() 调用（应使用 TimeProvider）"
    echo "$MATCHES"
    ERRORS=$((ERRORS + 1))
fi

# System.currentTimeMillis() - v2.6：升级为 ERROR（排除白名单）
MATCHES=$(grep -rn "System\.currentTimeMillis(" --include="*.java" "$SRC_DIR" | grep -Ev "$WHITELIST" || true)
COUNT=$(echo "$MATCHES" | grep -c . || echo 0)
if [ "$COUNT" -gt 0 ]; then
    echo "ERROR: 发现 $COUNT 处 System.currentTimeMillis() 调用（应使用 TimeProvider）"
    echo "$MATCHES"
    ERRORS=$((ERRORS + 1))
fi

# ZonedDateTime.now（排除白名单）
MATCHES=$(grep -rn "ZonedDateTime\.now(" --include="*.java" "$SRC_DIR" | grep -Ev "$WHITELIST" || true)
COUNT=$(echo "$MATCHES" | grep -c . || echo 0)
if [ "$COUNT" -gt 0 ]; then
    echo "ERROR: 发现 $COUNT 处 ZonedDateTime.now() 调用（应使用 TimeProvider）"
    echo "$MATCHES"
    ERRORS=$((ERRORS + 1))
fi

# 2. 检查危险的时区转换
echo "检查危险的时区转换..."

MATCHES=$(grep -rn "ZoneId\.systemDefault\|\.atZone(ZoneId\.systemDefault" --include="*VO.java" --include="*Service*.java" --include="*Controller.java" "$SRC_DIR" || true)
COUNT=$(echo "$MATCHES" | grep -c . || echo 0)
if [ "$COUNT" -gt 0 ]; then
    echo "ERROR: 发现 $COUNT 处 ZoneId.systemDefault() 使用（会破坏 UTC 语义）"
    echo "$MATCHES"
    ERRORS=$((ERRORS + 1))
fi

# 3. v2.8：检查关键接口 Controller DO 泄漏（检测返回/签名，避免 import 误杀）
echo "检查关键接口 Controller 是否泄漏 DO..."

# v2.8：只检测"返回/签名泄漏"，而不是全文出现 DO
# 匹配模式：public.*DO、RestOut<.*DO>、return.*DO
for controller in GuanZhiController CommentsController NotificationController; do
    CONTROLLER_FILE=$(find "$SRC_DIR" -name "${controller}.java" 2>/dev/null | head -1)
    if [ -n "$CONTROLLER_FILE" ]; then
        # 检测返回类型/泛型中直接使用 DO
        MATCHES=$(grep -En "public .*(GuanzhiDO|ShareCommentDO|NotificationDO)|RestOut<.*(GuanzhiDO|ShareCommentDO|NotificationDO)|return .*(GuanzhiDO|ShareCommentDO|NotificationDO)" "$CONTROLLER_FILE" 2>/dev/null || true)
        COUNT=$(echo "$MATCHES" | grep -c . || echo 0)
        if [ "$COUNT" -gt 0 ]; then
            echo "ERROR: 关键接口 ${controller} 返回/签名中泄漏 DO 类型"
            echo "$MATCHES"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# 其他 Controller：仅 WARNING（逐步迁移）
echo "检查其他 Controller 是否泄漏 DO..."
for controller_file in $(find "$SRC_DIR" -name "*Controller.java" 2>/dev/null | grep -Ev "$CRITICAL_CONTROLLERS"); do
    MATCHES=$(grep -En "public .*(GuanzhiDO|ShareCommentDO|NotificationDO)|RestOut<.*(GuanzhiDO|ShareCommentDO|NotificationDO)" "$controller_file" 2>/dev/null || true)
    COUNT=$(echo "$MATCHES" | grep -c . || echo 0)
    if [ "$COUNT" -gt 0 ]; then
        echo "WARNING: $(basename $controller_file) 返回/签名中使用 DO 类型，建议迁移"
        echo "$MATCHES"
    fi
done

# 4. v2.8：检查 VO 中是否混用旧 key（使用 grep -w 完整单词匹配）
echo "检查 VO 中是否混用 createDate/createDateMs..."

# v2.9：使用 grep -Ew 扩展正则 + 完整单词匹配（跨平台更稳定）
for vo_file in $(find "$SRC_DIR" -name "*VO.java" 2>/dev/null); do
    # 检查旧 key：grep -Ew 精确匹配完整单词（ERE 语法）
    HAS_OLD=$(grep -Ew "(createDate|createdAt)" "$vo_file" 2>/dev/null | grep -v "Ms" | wc -l || echo 0)
    # 检查新 key
    HAS_NEW=$(grep -Ewc "(createDateMs|createdAtMs)" "$vo_file" 2>/dev/null || echo 0)

    if [ "$HAS_OLD" -gt 0 ] && [ "$HAS_NEW" -gt 0 ]; then
        echo "ERROR: $vo_file 同时存在旧 key 和新 *Ms key（禁止混用）"
        ERRORS=$((ERRORS + 1))
    fi
done

echo "========================================="

if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: 发现 $ERRORS 处违规"
    exit 1
else
    echo "PASSED: Time SSOT 检查通过"
    exit 0
fi
```

**在 CI 中使用**：
```yaml
# .github/workflows/ci.yml 或类似配置
- name: Time SSOT Check
  run: bash scripts/time-ssot-check.sh
```

---

### Phase 6: 前端适配

**前端只需要**：

```swift
// ServerTime.swift - 唯一解析方式
static func parse(milliseconds: Int64) -> Date {
    return Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000.0)
}

// 使用
let date = ServerTime.parse(milliseconds: share.createDateMs)
let displayText = TimeDisplay.shared.smartTime(from: date)
```

**删除**：
- `LegacyTimeCompat.swift` 中的所有兼容逻辑
- 所有 `+8*3600` 补偿
- 所有字符串时间解析

---

### Phase 7: 部署验证

#### 7.1 修改 start.sh

```bash
#!/bin/bash
# 强制 UTC 时区
nohup java -Duser.timezone=UTC -jar onettoo.jar --spring.profiles.active=prod > app.log 2>&1 &
```

#### 7.2 部署后验证

1. **查看启动日志**，确认（v2.9 格式）：
   ```
   ========== Time SSOT 启动验证 v2.9 ==========
   JVM TimeZone: UTC
   JVM 时区验证通过
   注入的 DataSource: [dataSourceOne, druidDataSource, ...]
   [dataSourceOne] session.time_zone: +00:00
   [dataSourceOne] session 时区验证通过
   [dataSourceOne] NOW()=2026-01-11 12:00:00, UTC_TIMESTAMP()=2026-01-11 12:00:00, diff=0 秒
   [dataSourceOne] DB 时间一致性验证通过
   [druidDataSource] session.time_zone: +00:00
   [druidDataSource] session 时区验证通过
   [druidDataSource] NOW()=2026-01-11 12:00:00, UTC_TIMESTAMP()=2026-01-11 12:00:00, diff=0 秒
   [druidDataSource] DB 时间一致性验证通过
   已验证 2 个业务 DataSource
   ========== Time SSOT 验证全部通过 ==========
   ```

   **v2.9 注意**：不再输出 global.time_zone / system_time_zone（已移除）

2. **测试 API 返回**：见 5.4.2 节

3. **全局泄漏检查**：见 5.4 节

4. **全局 now() 扫描**：见 5.5 节

5. **前端验证**：新发观之、新评论的时间显示正确

#### 7.3 上线前 5 分钟验收（v2.9 必做）

**这三关过了，v2.9 才算真正闭环：**

| 验收项 | 检查方式 | 期望结果 |
|-------|---------|---------|
| 1. 白名单 DS 命中 | 看启动日志 `注入的 DataSource: [...]` | 包含 `dataSourceOne` 和 `druidDataSource` |
| 2. CI 版本一致 | 执行 `bash scripts/time-ssot-check.sh` | 输出 "Time SSOT CI 检查 v2.9" |
| 3. 两路 DS session UTC | 调用 `/internal/health/timezone` | 两个 DS 的 sessionTimeZone 都是 `+00:00` 或 `UTC` |

**如果白名单 DS 名字不一致**：
- 如果实际 key 是 `dataSource`、`dataSource1` 等，需修改 `REQUIRED_DS_NAMES` 为真实名称
- **不要改成模糊匹配**，保持硬闸门

**如果 Druid 没走到**：
- 确认运行时实际连接 DB 的是不是 druidDataSource（有些项目最终只用了 HikariCP）
- health/timezone 输出能确认这一点

---

## 六、实施顺序

| 阶段 | 内容 | 风险 |
|------|------|------|
| Phase 1.1 | DB 字段类型检查 | 低（信息收集） |
| Phase 1.2 | guanzhi 抽样检查 + 修正（带备份） | 低（有安全阀） |
| Phase 1.3 | 清空互动/日志表 | 低（数据可丢弃） |
| Phase 2 | 强制 UTC + JDBC serverTimezone + Fail-Fast 验证 | 低 |
| Phase 3 | 创建 TimeProvider（含工具方法） | 低 |
| Phase 4 | 改造写入点（含 QuotaDayUtil 传参改造） | 低 |
| Phase 5 | VO 改造 + 全局泄漏检查 + now() 扫描 | **中**（接口变更） |
| Phase 6 | 前端适配 | 低 |
| Phase 7 | 部署验证 | - |

---

## 七、验收清单

### 7.1 Phase 1 验收
- [ ] DB 字段类型已确认并记录（3.2 节表格已填写）
- [ ] **v2.8 决策门**：已执行 3.4.1 统计，记录 total/will_fix 数量
- [ ] **v2.8 强默认**：will_fix ≥ 100 则默认清空 guanzhi（除非明确要保留）
- [ ] guanzhi 旧数据处理完成（清空或修正）
- [ ] 修正前已创建备份表（如走修正路径）
- [ ] 互动/日志表已清空

### 7.2 Phase 2-3 验收
- [ ] JDBC URL 包含 `serverTimezone=UTC`
- [ ] start.sh 添加 `-Duser.timezone=UTC`
- [ ] **v2.8**：所有白名单 DataSource 都配置了 connection-init-sql
- [ ] **v2.8**：启动日志显示"Time SSOT 启动验证 v2.8"
- [ ] **v2.8**：启动日志只验证白名单 DS（dataSourceOne、druidDataSource）
- [ ] 启动日志显示 session=+00:00（不允许 SYSTEM）
- [ ] /internal/health/timezone 已配置访问保护
- [ ] **v2.8**：TimeProvider.toEpochMs(null) 返回 null（不是 0）

### 7.3 Phase 4-5 验收
- [ ] QuotaDayUtil 已改为传参方式
- [ ] `POST /guan/list` 返回 `createDateMs` (Long，可为 null)
- [ ] `POST /guan/share/info` 返回 `createDateMs` (Long，可为 null)
- [ ] 评论 API 返回 `createdAtMs` (Long，可为 null)
- [ ] **v2.8**：前端对 null 时间做兜底显示（隐藏或显示"—"）
- [ ] 全局泄漏检查通过（无日期字符串，无非 *Ms 的时间 key）
- [ ] CI 脚本 time-ssot-check.sh 执行通过

### 7.4 Phase 6-7 验收
- [ ] 前端使用 epoch ms 显示时间正确
- [ ] 切换系统时区后，显示跟随变化
- [ ] 前端对 null 时间字段有兜底显示

---

## 八、禁止事项（v2.9 放行版）

| 禁止 | 原因 | CI 级别 |
|------|------|---------|
| 在业务代码中直接调用 `LocalDateTime.now()` | 绕过 TimeProvider | ERROR |
| 在业务代码中直接调用 `new Date()` | 绕过 TimeProvider | ERROR |
| 在业务代码中直接调用 `Instant.now()` | 绕过 TimeProvider | ERROR |
| 在业务代码中直接调用 `System.currentTimeMillis()` | 绕过 TimeProvider | ERROR |
| 在业务代码中直接调用 `ZonedDateTime.now()` | 绕过 TimeProvider | ERROR |
| **后端** VO/Service/Controller 中使用 `ZoneId.systemDefault()` | 破坏 UTC 语义 | ERROR |
| API 返回字符串格式时间 | 统一用 epoch ms | ERROR |
| **关键接口** Controller 返回/签名泄漏 DO | 检测返回/签名，避免 import 误杀 | **ERROR** |
| 其他 Controller 返回/签名泄漏 DO | 建议迁移到 VO | WARNING |
| VO 中同时存在 createDate 和 createDateMs | v2.9：用 grep -Ew 检测 | ERROR |
| session time_zone = SYSTEM | 必须显式 +00:00 | fail-fast |
| TimeProvider.toEpochMs(null) 返回 0 | 必须返回 null，前端兜底 | - |
| 依赖 Jackson 全局配置序列化时间 | 不可控，必须显式转换 | - |
| 前端手动 +8/-8 补偿 | 使用 TimeZone.current 自动处理 | - |
| JVM 不加 `-Duser.timezone=UTC` 启动 | 会被 fail-fast 拦截 | - |

**白名单**：TimeProvider.java、*Test*.java、metrics/trace 包内允许使用时间 API

**v2.9 关键接口列表**：GuanZhiController、CommentsController、NotificationController

**v2.9 validator 白名单**：dataSourceOne、druidDataSource（必须存在，否则 fail-fast）

**v2.9 ZoneId.systemDefault 说明**：
- 禁止范围是**后端时间语义转换**（VO/Service/Controller 中把 UTC 当本地时间解释）
- 前端展示**应跟随系统时区**，使用 `TimeZone.current` 是正确的

---

## 九、业务例外说明

### QuotaDayUtil - 配额日计算

**这不是违规，是明确的业务例外**：
- 配额日按上海时区 + 04:00 规则切换
- **落地方式**：调用方传入 `TimeProvider.now()` 的 Instant
- 禁止在 QuotaDayUtil 内部直接调用 `LocalDateTime.now()`

---

**文档维护**：
- 创建人：后端 CC
- 创建时间：2026-01-11
- v1.0：初版
- v1.1：根据 GPT 审查更新
- v2.0：简化版（清空旧数据 + 只用 epoch ms）
- v2.1：加固版（强制 UTC fail-fast + 显式 VO 输出）
- v2.2：补丁版（FK 安全 + JDBC serverTimezone 明确 + 全局泄漏检查 + 业务例外说明）
- v2.3：最终版（接口路径确认 + QuotaDayUtil 传参方案 + 全局 now() 扫描 + 增强日志）
- v2.4：最终加固版（DB 字段类型确认 + SYSTEM 收紧 + 数据修正安全阀 + TimeProvider 工具方法 + 泄漏检查增强）
- v2.5：多源验证版（多数据源 StartupTimeZoneValidator + 健康检查端点 + 旧数据修正增强 + CI 检查脚本落地 + 禁止 System.currentTimeMillis/ZoneId.systemDefault + 泄漏检查扩展到 Service 层）
- v2.6：终极硬闸门版（CI 脚本全部 ERROR + 白名单机制 + 半开区间 SQL + 抽样 id 列表 + 权限异常明确报错 + 禁止 VO 中混用旧/新 key）
- v2.7：闭环硬闸门版（CI 混用检测 BUG 修复 + session=SYSTEM 收紧 + 多数据源落地清单 + 健康检查端点安全 + 旧数据修正决策门 + 关键接口 DO 泄漏升级 ERROR）
- v2.8：最终落地版（CI 用 grep -w 完整单词匹配 + DO 检测改为返回/签名泄漏 + validator 白名单 + 移除 @@global/@@system 查询 + TimeProvider null 透传 + 决策门强默认清空）
- v2.9：**放行版**（Druid init-sqls 数组写法 + validator Map 注入去掉 required=false + Phase 7 日志对齐 + CI grep -Ew + ZoneId.systemDefault 范围说明）
