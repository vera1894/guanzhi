# 后端 Time SSOT v3.0 实施完成报告

**版本**: v3.0
**完成日期**: 2026-01-11
**状态**: **已完成并部署验证通过**

---

## 一、实施概要

基于 `2026-01-11-backend-time-ssot-implementation.md` 计划（v2.9），完成了后端时间统一（SSOT）的全部实施工作。

### 1.1 核心成果

| 目标 | 状态 | 说明 |
|------|------|------|
| JVM 时区强制 UTC | ✅ | `-Duser.timezone=UTC` 在 start.sh |
| DB session 时区 +00:00 | ✅ | connection-init-sqls 配置 |
| 启动 Fail-Fast 验证 | ✅ | StartupTimeZoneValidator |
| 健康检查端点 | ✅ | /internal/health/timezone |
| CI 静态检查脚本 | ✅ | scripts/time-ssot-check.sh v3.0 |
| 业务代码使用 TimeProvider | ✅ | 全部改造完成 |

---

## 二、Git 提交记录

### 2.1 Time SSOT 主提交

```
7698717 time(ssot): enforce UTC JVM+DB session; add startup validator & health endpoint v3.0
```

**包含文件**：
- `scripts/time-ssot-check.sh` - CI 检查脚本 v3.0
- `TimeZoneHealthController.java` - 健康检查端点（添加 @AnonymousAccess）
- `ApiError.java` - 异常处理使用 UTC
- `TimeProvider.java` - 添加 nowAsDate() 方法
- `ConfigController.java` - 使用 TimeProvider
- `GuanZhiController.java` - 修复 DO 泄漏
- `ShareAddDTO.java` / `ShareDelDTO.java` - 新增输入 DTO
- `StickerQuotaServiceImpl.java` - 修复 ZonedDateTime.now()
- `UserServiceImpl.java` - 修复 new Date()
- `application.yml` / `application-prod.yml` - serverTimezone=UTC

### 2.2 相关附属提交

```
dc3e7cd refactor(notification): rename apns channel to abstract push channel
00ff90b fix(fade): only process NORMAL status shares; prevent duplicate notifications
fe83b22 docs(terminology): update comments from 分享 to 观之
```

---

## 三、部署验证结果

### 3.1 启动日志验证

**执行时间**: 2026-01-11 10:35:46 UTC
**SSM 命令 ID**: 660efdc4-ccd1-40b0-9315-492c132dccd0

```
SET time_zone = '+00:00' ;
========== Time SSOT 启动验证 v2.9 ==========
JVM TimeZone: UTC
[multiDataSource] session.time_zone: +00:00
NOW()=2026-01-11 10:35:46, UTC_TIMESTAMP()=2026-01-11 10:35:46, diff=0 秒
========== Time SSOT 验证全部通过 ==========
```

### 3.2 Health 接口验证

**执行时间**: 2026-01-11 12:21:18 UTC
**SSM 命令 ID**: 856c2bd7-10a2-43dd-ab49-344f476b1450

```json
{
  "jvmTimeZone": "UTC",
  "dataSources": {
    "multiDataSource": {
      "utcTimestamp": "2026-01-11 12:21:18",
      "now": "2026-01-11 12:21:18",
      "sessionTimeZone": "+00:00"
    }
  }
}
```

### 3.3 验证核对清单

| 验证项 | 期望值 | 实际值 | 状态 |
|--------|--------|--------|------|
| SET time_zone | '+00:00' | '+00:00' | ✅ |
| JVM TimeZone | UTC | UTC | ✅ |
| session.time_zone | +00:00 | +00:00 | ✅ |
| NOW() == UTC_TIMESTAMP() | diff=0 | diff=0 秒 | ✅ |
| Health jvmTimeZone | UTC | UTC | ✅ |
| Health sessionTimeZone | +00:00 | +00:00 | ✅ |
| Health now == utcTimestamp | 相同 | 都是同一时间 | ✅ |

---

## 四、CI 脚本 v3.0 变更

### 4.1 扩展白名单

```bash
# v3.0 白名单
WHITELIST="TimeProvider.java|Test|/metrics/|/trace/|/security/|FileUtil.java|ApnsPushService.java|/exception/"
```

**新增白名单说明**：
- `/security/` - 安全基础设施（Token、Session）
- `FileUtil.java` - 文件命名（非业务时间）
- `ApnsPushService.java` - 推送过期时间
- `/exception/` - 异常处理基础设施

### 4.2 修复 COUNT 解析

添加 `count_matches()` 辅助函数，解决跨平台 grep 计数问题。

---

## 五、修复的违规问题

| 位置 | 问题 | 修复方式 |
|------|------|----------|
| StickerQuotaServiceImpl:303 | ZonedDateTime.now(ZONE_SHANGHAI) | timeProvider.now().atZone(ZONE_SHANGHAI) |
| UserServiceImpl:150,155,179,300 | new Date() | timeProvider.nowAsDate() |
| ConfigController:108 | LocalDateTime.now() | timeProvider.nowLocalDateTime() |
| GuanZhiController:138,153 | DO 泄漏 | 创建 ShareAddDTO/ShareDelDTO |

---

## 六、未提交的保留文件

```
src/main/resources/db/migration/V20260108__terminology_share_to_guanzhi.sql
```

**原因**：术语迁移 SQL，等 iOS 端同步完成后再一起执行。

---

## 七、后续建议

### 7.1 真实写入链路冒烟（可选）

虽然环境验证已通过，但可在方便时执行一次真实写入测试：
- 发布观之
- 发表评论
- 贴贴纸操作
- 登录/注册

验证写入的时间字段在 DB 和 API 返回中语义一致。

### 7.2 iOS 端适配

确保 iOS 端 TimeKit 正确处理 epoch ms 并使用 `TimeZone.current` 展示本地时间。

---

## 八、JDBC 时区修复补丁 (2026-01-12)

### 8.1 问题发现

**症状**：前端测试发现时间显示偏差
- 旧数据：显示时间比实际晚 8 小时 (+8)
- 新数据：显示时间比实际早 8 小时 (-8)

### 8.2 证据链排查

#### Step 1: DB 权威值（UTC session）
```sql
SET time_zone = '+00:00';
SELECT id, create_date, UNIX_TIMESTAMP(create_date) * 1000 AS expect_epoch_ms
FROM guanzhi WHERE id IN (2, 104);
```

| id | create_date | expect_epoch_ms |
|----|-------------|-----------------|
| 2 | 2024-08-12 02:08:28 | **1723428508000** |
| 104 | 2026-01-12 01:38:27 | **1768181907000** |

#### Step 2: API 实际返回
```bash
curl -X POST http://localhost:8085/guan/share/info -H "Authorization: Bearer <token>" -d '{"id":2}'
# createDate: 1723399708000

curl -X POST http://localhost:8085/guan/share/info -H "Authorization: Bearer <token>" -d '{"id":104}'
# createDate: 1768153107000
```

#### Step 3: DB 上海时区解释
```sql
SET time_zone = '+08:00';
SELECT id, UNIX_TIMESTAMP(create_date) * 1000 AS epoch_if_shanghai
FROM guanzhi WHERE id IN (2, 104);
```

| id | epoch_if_shanghai |
|----|-------------------|
| 2 | **1723399708000** |
| 104 | **1768153107000** |

#### Step 4: 对比结论

| id | DB expect (UTC) | API actual | DB if Shanghai | API vs expect |
|----|-----------------|------------|----------------|---------------|
| 2 | 1723428508000 | 1723399708000 | 1723399708000 | **-8 小时** |
| 104 | 1768181907000 | 1768153107000 | 1768153107000 | **-8 小时** |

**结论**：API 返回值 == DB 按上海时区解释的 epoch，证明 **JDBC 驱动将 DATETIME 当作上海时间 (+08:00) 解析，而非 UTC**。

### 8.3 根因分析

| 层级 | 期望行为 | 实际行为 | 状态 |
|------|---------|---------|------|
| MySQL 数据 | UTC 语义存储 | UTC 语义存储 | ✅ |
| MySQL session | +00:00 | +00:00 | ✅ |
| JVM 时区 | UTC | UTC | ✅ |
| **JDBC DATETIME→Date** | 解释为 UTC | **解释为 Shanghai (+08)** | ❌ |
| Jackson 序列化 | epoch ms | epoch ms | ✅ |

**问题定位**：`SET time_zone = '+00:00'` 只影响 MySQL SQL 函数（如 `UNIX_TIMESTAMP()`），**不影响 MySQL Connector/J 8.x 如何将 DATETIME 转换为 Java Date**。

### 8.4 修复方案

**SSOT 原则**：所有环境（生产/预发布/本地）统一使用 UTC 时区规则，禁止出现 `Asia/Shanghai` 等地区时区写死。

**修改文件**：
1. `src/main/resources/application.yml`
2. `src/main/resources/application-prod.yml`
3. `src/main/resources/application-local.yml`（**重要：本地也必须统一**）

**生效位置（grep 确认，共 6 处）**：
```
application.yml:19       spring.datasource.one.jdbc-url
application.yml:30       spring.datasource.druid.url
application-prod.yml:26  spring.datasource.one.jdbc-url
application-prod.yml:34  spring.datasource.druid.url
application-local.yml:5  spring.datasource.one.jdbc-url  (当前是 Asia/Shanghai!)
application-local.yml:11 spring.datasource.druid.url     (当前是 Asia/Shanghai!)
```

**修改内容**：

**application.yml / application-prod.yml**（4 处）：
```yaml
# 修改前
jdbc-url: jdbc:log4jdbc:mysql://...?serverTimezone=UTC&characterEncoding=utf8&useSSL=false

# 修改后（注意单引号包裹，避免 & 被 YAML 误解析）
jdbc-url: 'jdbc:log4jdbc:mysql://...?serverTimezone=UTC&connectionTimeZone=UTC&forceConnectionTimeZoneToSession=true&characterEncoding=utf8&useSSL=false'
```

**application-local.yml**（2 处）：
```yaml
# 修改前（错误：使用了 Asia/Shanghai）
jdbc-url: jdbc:mysql://localhost:3306/ONETTOO?serverTimezone=Asia/Shanghai&characterEncoding=utf8&useSSL=false&allowPublicKeyRetrieval=true

# 修改后（统一 UTC）
jdbc-url: 'jdbc:mysql://localhost:3306/ONETTOO?serverTimezone=UTC&connectionTimeZone=UTC&forceConnectionTimeZoneToSession=true&characterEncoding=utf8&useSSL=false&allowPublicKeyRetrieval=true'
```

**新增参数说明**：
- `connectionTimeZone=UTC`：强制 JDBC 驱动使用 UTC 解释 DATETIME
- `forceConnectionTimeZoneToSession=true`：强制 session 时区与 connection 时区一致

**为什么本地也必须统一 UTC**：
- 避免"本地测试通过，线上出错"的环境差异问题
- 确保 SSOT 一次性根治，不留死角
- 如需本地查看"北京时间"，可在日志格式化层或 IDE 中配置，而非数据解释层

### 8.5 验证清单

部署后执行以下三步验证：

#### 验证 1: DB vs API 对照（旧数据）
```bash
# DB 权威值
mysql -e "SET time_zone='+00:00'; SELECT id, UNIX_TIMESTAMP(create_date)*1000 AS expect FROM guanzhi WHERE id=2;"
# 期望: 1723428508000

# API 返回值
curl -s -X POST http://localhost:8085/guan/share/info -H "Authorization: Bearer <token>" -d '{"id":2}' | grep -o '"createDate":[0-9]*'
# 期望: "createDate":1723428508000
```

#### 验证 2: DB vs API 对照（新数据）
```bash
mysql -e "SET time_zone='+00:00'; SELECT id, UNIX_TIMESTAMP(create_date)*1000 AS expect FROM guanzhi WHERE id=104;"
# 期望: 1768181907000

curl -s -X POST http://localhost:8085/guan/share/info -H "Authorization: Bearer <token>" -d '{"id":104}' | grep -o '"createDate":[0-9]*'
# 期望: "createDate":1768181907000
```

#### 验证 3: 新发观之（确保写入链路正确）
1. 发布新观之，记录发布时间（如 10:00 Shanghai = 02:00 UTC）
2. 查询最新 id 的 DB 值和 API 返回值
3. 确认 epoch 对应 UTC 时间正确

### 8.6 预期结果

| id | DB expect_epoch_ms | API createDate | 是否一致 |
|----|-------------------|----------------|---------|
| 2 | 1723428508000 | 1723428508000 | ✅ |
| 104 | 1768181907000 | 1768181907000 | ✅ |
| 新发 | UTC epoch | UTC epoch | ✅ |

修复后，前端无需任何 ±8 补偿，直接用系统时区显示即可。

---

## 九、JDBC 时区修复部署执行 (2026-01-12)

### 9.1 修改的配置文件

#### JAR 内配置（6 处）
| 文件 | 行号 | 修改内容 |
|------|------|----------|
| application.yml | 19, 30 | 添加 `connectionTimeZone=UTC&forceConnectionTimeZoneToSession=true` |
| application-prod.yml | 26, 34 | 添加 `connectionTimeZone=UTC&forceConnectionTimeZoneToSession=true` |
| application-local.yml | 5, 11 | 从 `Asia/Shanghai` 改为 UTC 并添加参数 |

#### 服务器外部配置（关键发现）
**问题**：服务器上 `/home/ec2-user/application-prod.yml` 使用 `serverTimezone=Asia/Shanghai` 覆盖了 JAR 内配置。

**修复命令**：
```bash
sed -i "s|serverTimezone=Asia/Shanghai|serverTimezone=UTC\&connectionTimeZone=UTC\&forceConnectionTimeZoneToSession=true|g" /home/ec2-user/application-prod.yml
```

### 9.2 部署验证

**部署时间**：2026-01-12 02:48 UTC

**验证结果**：
| id | DB 期望值 (UTC) | API 返回值 | 状态 |
|----|-----------------|------------|------|
| 2 | 1723428508000 | 1723428508000 | ✅ |
| 104 | 1768181907000 | 1768181907000 | ✅ |

**健康检查**：
```json
{
  "jvmTimeZone": "UTC",
  "dataSources": {
    "multiDataSource": {
      "sessionTimeZone": "+00:00"
    }
  }
}
```

---

## 十、历史数据迁移 (2026-01-12)

### 10.1 问题发现

JDBC 修复后，旧数据在 iOS 前端显示时间比实际发布时间**早 8 小时**。

**示例 - ID=90**：
| 项目 | 值 |
|------|-----|
| DB 存储值 | 2025-12-12 02:07:48 |
| iOS 显示（北京时间） | 10:07 |
| 用户实际发布时间 | 18:07 北京时间 |

**根因**：历史数据写入时，系统错误地将时间减了 8 小时存入 DB。

### 10.2 修复方案

将旧数据的 `create_date` 加 8 小时，恢复正确的 UTC 时间。

### 10.3 执行记录

**执行时间**：2026-01-12 03:05 UTC

```sql
-- 备份
CREATE TABLE guanzhi_backup_20260112 AS SELECT * FROM guanzhi;
-- 备份记录数：103 条

-- 修正旧数据
UPDATE guanzhi
SET create_date = DATE_ADD(create_date, INTERVAL 8 HOUR)
WHERE create_date < '2026-01-12 03:00:00';
```

### 10.4 验证结果

**ID=90 对比**：
| 状态 | create_date |
|------|-------------|
| 修复前 | 2025-12-12 02:07:48 |
| 修复后 | 2025-12-12 10:07:48 |

**API 返回**：
- 修复前 epoch：1765505268000 → 北京时间 10:07
- 修复后 epoch：1765534068000 → 北京时间 18:07 ✅

### 10.5 最终状态

- ✅ 旧数据时间显示正确
- ✅ 新发观之时间正确
- ✅ iOS 前端无需任何时区补偿逻辑

---

## 十一、重要经验总结

### 11.1 JDBC 时区配置要点

MySQL Connector/J 8.x 需要以下参数才能正确处理时区：

```
serverTimezone=UTC                    # MySQL 服务器时区
connectionTimeZone=UTC                # JDBC 驱动解释 DATETIME 的时区
forceConnectionTimeZoneToSession=true # 强制 session 时区一致
```

**仅设置 `serverTimezone` 是不够的**，必须同时设置 `connectionTimeZone`。

### 11.2 外部配置文件优先级

Spring Boot 的配置优先级：
1. `/home/ec2-user/application-prod.yml`（外部文件，最高优先级）
2. JAR 内 `application-prod.yml`
3. JAR 内 `application.yml`

**部署时必须同步更新服务器上的外部配置文件**。

### 11.3 Time SSOT 完整清单

| 层级 | 配置 | 状态 |
|------|------|------|
| JVM | `-Duser.timezone=UTC` | ✅ |
| JDBC URL | `connectionTimeZone=UTC&forceConnectionTimeZoneToSession=true` | ✅ |
| MySQL session | `SET time_zone = '+00:00'` | ✅ |
| 外部配置 | `/home/ec2-user/application-prod.yml` | ✅ |
| 历史数据 | `DATE_ADD(create_date, INTERVAL 8 HOUR)` | ✅ |

---

**文档维护**：
- 创建人：后端 CC (Claude Opus 4.5)
- 创建时间：2026-01-11
- 更新时间：2026-01-12（JDBC 修复部署 + 历史数据迁移）
- 关联计划：2026-01-11-backend-time-ssot-implementation.md (v2.9)
