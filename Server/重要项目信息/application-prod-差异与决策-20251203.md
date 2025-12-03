# Application.yml 生产环境差异分析与决策

## 文档信息
- **创建日期**: 2025-12-03
- **对比范围**: 本地开发配置 vs AWS 生产服务器配置
- **本地文件**: `Server/onettoo/src/main/resources/application.yml`
- **生产文件**: `Server/infra/remote-application-prod-aws.yml` (来自 AWS: ec2-52-83-127-15.cn-northwest-1)

## 概述
对比发现，本地和生产环境的配置文件在数据库连接和 Redis 配置上存在差异，其他配置（JWT、Swagger、Knife4j、日志等）完全一致。**关键发现：生产环境配置中存在硬编码的明文密码，这是严重的安全隐患。**

---

## 一、数据源配置差异

### 1.1 主数据源（spring.datasource.one）

| 配置项 | 本地开发 | 生产服务器 | 差异说明 |
|--------|---------|-----------|---------|
| `jdbc-url (DB_HOST)` | `localhost` | `52.83.127.15` | 生产使用远程数据库 IP |
| `jdbc-url (DB_NAME)` | `ONETTOO` | `ONETTOO` | ✅ 相同 |
| `username` | `root` | `root` | ✅ 相同 |
| `password` | `${DB_PWD:}` (空默认值) | **`oneAa123123!.`** (硬编码明文) | ⚠️ **安全风险** |

**具体代码行差异**：
```diff
- jdbc-url: jdbc:log4jdbc:mysql://${DB_HOST:localhost}:${DB_PORT:3306}/${DB_NAME:ONETTOO}
+ jdbc-url: jdbc:log4jdbc:mysql://${DB_HOST:52.83.127.15}:${DB_PORT:3306}/${DB_NAME:ONETTOO}

- password: ${DB_PWD:}
+ password: oneAa123123!.
```

**问题分析**：
1. ❌ **生产环境密码硬编码**：`oneAa123123!.` 直接写在配置文件中，没有使用环境变量
2. ❌ **明文存储**：密码未加密
3. ❌ **版本控制风险**：如果配置文件被提交到 Git，密码会泄露

**建议决策**：
- ✅ **必须修改**：生产环境应使用 `${DB_PWD:}` 格式，通过环境变量注入密码
- ✅ 启动脚本中设置：`export DB_PWD='oneAa123123!.'` 或使用 Kubernetes Secret
- ✅ 如果密码已泄露，应立即更换数据库密码

### 1.2 Druid 连接池配置

| 配置项 | 本地开发 | 生产服务器 | 差异说明 |
|--------|---------|-----------|---------|
| `url (DB_HOST)` | `localhost` | `52.83.127.15` | 生产使用远程 IP |
| `url (DB_NAME)` | `ONETTOO` | **`four`** | ⚠️ 数据库名称不一致 |
| `username` | `${DB_USER:root}` | `${DB_USER:root}` | ✅ 相同 |
| `password` | `${DB_PWD:}` | `${DB_PWD:112233}` | 默认值不同 |

**具体代码行差异**：
```diff
- url: jdbc:log4jdbc:mysql://${DB_HOST:localhost}:${DB_PORT:3306}/${DB_NAME:ONETTOO}
+ url: jdbc:log4jdbc:mysql://${DB_HOST:52.83.127.15}:${DB_PORT:3306}/${DB_NAME:four}

- password: ${DB_PWD:}
+ password: ${DB_PWD:112233}
```

**问题分析**：
1. ⚠️ **数据库名称不一致**：主数据源用 `ONETTOO`，Druid 用 `four`
2. ❓ **疑似冲突**：如果两个数据源都生效，会连接不同的数据库
3. ⚠️ 默认密码 `112233` 太简单，存在安全风险

**✅ 已确认结论（2025-12-03）**：
**生产环境实际使用数据库名称：ONETTOO**（经配置分析和运行状态确认，Druid 的 `four` 视为历史残留，不再使用）

详见：`database-config-analysis-20251203.md`

**已执行决策**：
- ✅ **已统一配置**：新的 `application-prod.yml` 已将所有数据源的 `DB_NAME` 统一为 `ONETTOO`
- ✅ **已移除默认密码**：新配置已改为 `${DB_PWD}`（无默认值，强制使用环境变量）
- ✅ **已创建启动脚本模板**：`Server/infra/start-prod.sh` 提供环境变量配置示例

---

## 二、Redis 配置差异

| 配置项 | 本地开发 | 生产服务器 | 差异说明 |
|--------|---------|-----------|---------|
| `database` | `${REDIS_DB:0}` | `${REDIS_DB:0}` | ✅ 相同 |
| `host` | `${REDIS_HOST:localhost}` | `${REDIS_HOST:52.83.127.15}` | 生产使用远程 Redis IP |
| `port` | `${REDIS_PORT:6379}` | `${REDIS_PORT:6379}` | ✅ 相同 |
| `password` | `${REDIS_PWD:}` | `${REDIS_PWD:onettoo-redis-2023-onettoo.}` | 默认值不同 |
| `timeout` | `10000` | `10000` | ✅ 相同 |

**具体代码行差异**：
```diff
- host: ${REDIS_HOST:localhost}
+ host: ${REDIS_HOST:52.83.127.15}

- password: ${REDIS_PWD:}
+ password: ${REDIS_PWD:onettoo-redis-2023-onettoo.}
```

**问题分析**：
1. ✅ **使用环境变量**：虽然有默认值，但可以通过环境变量覆盖，相对安全
2. ⚠️ **默认值有密码**：如果忘记设置环境变量，会暴露默认密码
3. ✅ **密码强度**：`onettoo-redis-2023-onettoo.` 比数据库密码强度高

**建议决策**：
- ✅ **保持当前格式**：使用 `${REDIS_PWD:}` 格式，但移除默认值
- ✅ 改为：`password: ${REDIS_PWD:}` （空默认值，强制设置环境变量）
- ✅ 启动脚本中设置：`export REDIS_PWD='onettoo-redis-2023-onettoo.'`

---

## 三、其他配置（无差异）

以下配置在本地和生产环境**完全一致**，无需调整：

### 3.1 Spring 框架配置
- ✅ `spring.main.allow-bean-definition-overriding: true`
- ✅ `spring.jackson.date-format: yyyy-MM-dd HH:mm:ss`
- ✅ `spring.servlet.multipart` (文件上传 10MB 限制)

### 3.2 MyBatis-Plus 配置
- ✅ `mapper-locations: classpath:mapping/*.xml`
- ✅ `type-aliases-package: com.cloud.onettoo.modules`
- ✅ `log-impl: org.apache.ibatis.logging.log4j2.Log4j2Impl`

### 3.3 日志配置
- ✅ `logging.config: classpath:log4j2.xml`

### 3.4 Swagger 配置
- ✅ `swagger.enabled: true`
- ✅ `swagger.serverIp: 172.31.33.21`

### 3.5 JWT 配置
- ✅ `jwt.header: Authorization`
- ✅ `jwt.token-start-with: Bearer`
- ✅ `jwt.base64-secret: w8fL6FEJw...` (88位 Base64 密钥)
- ✅ `jwt.token-validity-in-seconds: 86400000` (24小时)
- ✅ `jwt.token-validity-in-long-seconds: 31536000000` (365天)

**JWT 密钥安全性评估**：
- ✅ 使用 Base64 编码的 88 位密钥，强度较高
- ⚠️ 本地和生产使用相同密钥，如果本地泄露会影响生产环境
- 建议：生产环境使用独立的 JWT 密钥

### 3.6 Knife4j 配置
- ✅ `knife4j.enable: true`
- ✅ `knife4j.basic.username: onettoo`
- ✅ `knife4j.basic.password: 123456`

**Knife4j 密码安全性评估**：
- ⚠️ 弱密码 `123456`，存在安全风险
- ✅ 建议：生产环境使用强密码或禁用 Swagger 文档

### 3.7 应用特定配置
- ✅ `admin.phone: 13810269627`
- ✅ `image.baseImagePath: ./images/`
- ✅ `app.distance.check.limit.meters: 200.0`

---

## 四、安全风险汇总

### 🔴 高危风险

1. **数据库主数据源密码硬编码**
   - 位置：`spring.datasource.one.password`
   - 风险：明文密码 `oneAa123123!.` 直接写在配置文件
   - 影响：如果文件泄露，数据库完全暴露
   - 处理：**立即修改**，使用环境变量

2. **数据库名称不一致**
   - 位置：主数据源用 `ONETTOO`，Druid 用 `four`
   - 风险：可能导致连接错误的数据库
   - 影响：数据一致性问题
   - 处理：**确认并统一**

### 🟡 中危风险

3. **Druid 数据源弱默认密码**
   - 位置：`spring.datasource.druid.password`
   - 风险：默认密码 `112233` 太简单
   - 影响：如果环境变量未设置，会使用弱密码
   - 处理：移除默认值，强制使用环境变量

4. **Redis 密码默认值**
   - 位置：`spring.redis.password`
   - 风险：默认密码 `onettoo-redis-2023-onettoo.` 暴露
   - 影响：如果环境变量未设置，密码泄露
   - 处理：移除默认值

5. **JWT 密钥相同**
   - 位置：`jwt.base64-secret`
   - 风险：本地和生产使用相同密钥
   - 影响：本地泄露影响生产环境
   - 处理：生产环境使用独立密钥

6. **Knife4j 弱密码**
   - 位置：`knife4j.basic.password`
   - 风险：密码 `123456` 太简单
   - 影响：Swagger 文档可能被未授权访问
   - 处理：使用强密码或禁用

---

## 五、决策建议矩阵

| 配置项 | 本地开发 | 生产环境建议 | 优先级 | 处理方式 |
|--------|---------|------------|--------|---------|
| **DB_HOST (主数据源)** | localhost | 通过环境变量设置 | P0 | 使用 `${DB_HOST:}` |
| **DB_PWD (主数据源)** | 空 | **通过环境变量设置** | **P0** | **改为 `${DB_PWD:}`，移除硬编码** |
| **DB_NAME (Druid)** | ONETTOO | **确认后统一** | **P0** | **确认是 ONETTOO 还是 four** |
| **DB_PWD (Druid)** | 空 | 通过环境变量设置 | P0 | 改为 `${DB_PWD:}` |
| **REDIS_HOST** | localhost | 通过环境变量设置 | P1 | 使用 `${REDIS_HOST:}` |
| **REDIS_PWD** | 空 | 通过环境变量设置 | P1 | 改为 `${REDIS_PWD:}` |
| **JWT Secret** | (当前值) | 使用独立密钥 | P2 | 生产环境使用不同值 |
| **Knife4j 密码** | 123456 | 使用强密码或禁用 | P2 | 改为强密码或 `enable: false` |

**优先级说明**：
- **P0（立即处理）**: 严重安全风险，必须在部署前修复
- **P1（高优先级）**: 重要安全改进，应尽快处理
- **P2（建议改进）**: 最佳实践建议，可计划处理

---

## 六、具体修改建议

### 6.1 生产环境配置文件修改方案

**修改后的 application.yml（生产环境）**：

```yaml
spring:
  datasource:
    one:
      jdbc-url: jdbc:log4jdbc:mysql://${DB_HOST:}:${DB_PORT:3306}/${DB_NAME:ONETTOO}?serverTimezone=Asia/Shanghai&characterEncoding=utf8&useSSL=false
      username: ${DB_USER:root}
      password: ${DB_PWD:}  # 移除硬编码密码
    druid:
      url: jdbc:log4jdbc:mysql://${DB_HOST:}:${DB_PORT:3306}/${DB_NAME:ONETTOO}?serverTimezone=Asia/Shanghai&characterEncoding=utf8&useSSL=false
      username: ${DB_USER:root}
      password: ${DB_PWD:}  # 移除默认密码
  redis:
    host: ${REDIS_HOST:}
    password: ${REDIS_PWD:}  # 移除默认密码

# JWT 使用独立密钥
jwt:
  base64-secret: ${JWT_SECRET:w8fL6FEJw...}  # 生产环境使用环境变量

# Knife4j 使用强密码
knife4j:
  basic:
    password: ${KNIFE4J_PWD:}  # 使用环境变量
```

### 6.2 环境变量设置（启动脚本）

**创建 `start-prod.sh`**：

```bash
#!/bin/bash

# 数据库配置
export DB_HOST="52.83.127.15"
export DB_PORT="3306"
export DB_NAME="ONETTOO"  # 或 "four"，需要确认
export DB_USER="root"
export DB_PWD="oneAa123123!."  # 从安全存储（如 AWS Secrets Manager）读取

# Redis 配置
export REDIS_HOST="52.83.127.15"
export REDIS_PORT="6379"
export REDIS_DB="0"
export REDIS_PWD="onettoo-redis-2023-onettoo."  # 从安全存储读取

# JWT 密钥（生产环境独立密钥）
export JWT_SECRET="[生产环境专用的88位Base64密钥]"

# Knife4j 密码
export KNIFE4J_PWD="[强密码]"

# 启动应用
java -jar onettoo.jar
```

**更安全的方式（使用 AWS Secrets Manager）**：

```bash
#!/bin/bash

# 从 AWS Secrets Manager 读取密码
export DB_PWD=$(aws secretsmanager get-secret-value --secret-id prod/db/password --query SecretString --output text)
export REDIS_PWD=$(aws secretsmanager get-secret-value --secret-id prod/redis/password --query SecretString --output text)
export JWT_SECRET=$(aws secretsmanager get-secret-value --secret-id prod/jwt/secret --query SecretString --output text)

# 启动应用
java -jar onettoo.jar
```

---

## 七、验证清单

部署前请确认以下事项：

### 配置验证
- [ ] 数据库主数据源密码已从配置文件移除
- [ ] 数据库 Druid 数据源密码已从配置文件移除
- [ ] Redis 密码默认值已移除
- [ ] DB_NAME 已确认并统一（ONETTOO 或 four）
- [ ] 所有敏感配置使用环境变量

### 环境变量验证
- [ ] DB_HOST 已设置
- [ ] DB_PWD 已设置
- [ ] DB_NAME 已设置
- [ ] REDIS_HOST 已设置
- [ ] REDIS_PWD 已设置
- [ ] JWT_SECRET 已设置（独立于开发环境）
- [ ] KNIFE4J_PWD 已设置

### 安全验证
- [ ] 配置文件不包含任何明文密码
- [ ] 密码存储在安全位置（如 AWS Secrets Manager）
- [ ] JWT 密钥生产环境独立
- [ ] Knife4j 使用强密码或已禁用
- [ ] 确认配置文件不会被提交到版本控制

### 功能验证
- [ ] 数据库连接成功
- [ ] Redis 连接成功
- [ ] JWT 认证正常
- [ ] Inspector API 正常工作
- [ ] 日志输出正常

---

## 八、风险提示

### 已识别风险
1. ⚠️ **当前生产环境配置存在明文密码**，强烈建议立即修改
2. ⚠️ **数据库名称不一致**，可能导致连接错误数据库
3. ⚠️ **如果配置文件已被提交到 Git**，所有密码应视为已泄露，需立即更换

### 建议行动
1. **立即更换所有泄露的密码**
2. **检查 Git 历史**，确认配置文件是否被提交
3. **如果已提交**，考虑清理 Git 历史或将仓库设为私有
4. **启用审计日志**，监控数据库和 Redis 的异常访问
5. **定期轮换密码**，建立密码管理策略

---

## 九、总结

### 关键差异
- 生产环境和本地环境的配置差异主要集中在**数据库连接**和 **Redis 连接**
- 其他配置（JWT、Swagger、日志等）完全一致

### 主要问题
1. **严重安全隐患**：生产环境存在硬编码明文密码
2. **配置不一致**：数据库名称存在冲突（ONETTOO vs four）
3. **弱密码问题**：Knife4j 等使用弱密码

### 推荐方案
1. **立即修改**：移除所有硬编码密码，使用环境变量
2. **确认数据库名**：统一 DB_NAME 配置
3. **加强安全**：使用密钥管理服务存储敏感信息
4. **定期审计**：建立配置审计机制，防止密码泄露

---

**文档版本**: 1.0
**最后更新**: 2025-12-03
**审核状态**: 待审核
**负责人**: 待指定
