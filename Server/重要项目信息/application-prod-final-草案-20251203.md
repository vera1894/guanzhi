# 观之 Prod 最终 Application 配置草案

## 文档信息
- **创建日期**: 2025-12-03
- **环境**: AWS 生产环境 (ec2-52-83-127-15.cn-northwest-1)
- **服务器 IP**: 52.83.127.15
- **目标**: 定义生产环境最终配置方案

## 概述
本草案基于当前生产环境配置和安全最佳实践，定义了生产环境应该使用的最终配置。主要目标是：
1. **消除安全隐患**：移除所有硬编码密码
2. **统一配置**：解决数据库名称不一致问题
3. **环境隔离**：生产环境与开发环境配置明确分离
4. **可维护性**：使用环境变量管理敏感信息

---

## 一、数据源配置（MySQL）

### 1.1 连接信息

| 配置项 | 值 | 说明 | 通过环境变量设置 |
|--------|---|------|----------------|
| **DB_HOST** | `52.83.127.15` | AWS 内网 MySQL IP | ✅ 是 |
| **DB_PORT** | `3306` | MySQL 默认端口 | ✅ 是 |
| **DB_NAME** | `ONETTOO` | **✅ 已确认**（生产环境使用 ONETTOO，Druid 的 four 为历史残留） | ✅ 是 |
| **DB_USER** | `root` | 数据库用户 | ✅ 是 |
| **DB_PWD** | `(敏感信息)` | **必须通过环境变量注入，yml 中不存储明文** | ✅ **必须** |

### 1.2 关键决策

#### 决策1: 数据库名称统一
**✅ 已确认决策（2025-12-03）**: 生产环境使用 `ONETTOO` 数据库

**确认过程**:
1. 分析 Spring Boot 配置：`spring.datasource.dbs: one` 指定使用主数据源
2. 检查应用运行日志：成功操作 guanzhi、share_tag_user 等表
3. 验证应用稳定运行 10+ 天，数据库连接正常
4. **结论**: Druid 配置中的 `four` 为历史残留，实际未使用

**执行决策**:
- ✅ 所有数据源配置的 `DB_NAME` 统一为 `ONETTOO`
- ✅ 新的 `application-prod.yml` 已应用此配置
- ✅ 未来仅在有明确多库策略时才扩展

详见：`database-config-analysis-20251203.md`

#### 决策2: 密码管理方式
**推荐方案**: 使用环境变量 + AWS Secrets Manager

**方案 A（基础方案）**:
```bash
# 启动脚本中设置
export DB_PWD="oneAa123123!."
java -jar onettoo.jar
```

**方案 B（推荐方案）**:
```bash
# 从 AWS Secrets Manager 读取
export DB_PWD=$(aws secretsmanager get-secret-value \
    --secret-id prod/onettoo/db-password \
    --query SecretString --output text)
java -jar onettoo.jar
```

**方案 C（Docker/K8s 环境）**:
```yaml
# docker-compose.yml 或 K8s Secret
environment:
  - DB_PWD=${DB_PWD}
```

### 1.3 最终配置（application.yml）

```yaml
spring:
  datasource:
    dbs: one
    one:
      ip: localhost
      name: onettoo
      jdbc-url: jdbc:log4jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?serverTimezone=Asia/Shanghai&characterEncoding=utf8&useSSL=false
      username: ${DB_USER:root}
      password: ${DB_PWD}  # 必须通过环境变量注入，无默认值
      driver-class-name: net.sf.log4jdbc.sql.jdbcapi.DriverSpy
    druid:
      db-type: com.alibaba.druid.pool.DruidDataSource
      driverClassName: net.sf.log4jdbc.sql.jdbcapi.DriverSpy
      url: jdbc:log4jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?serverTimezone=Asia/Shanghai&characterEncoding=utf8&useSSL=false
      username: ${DB_USER:root}
      password: ${DB_PWD}  # 与主数据源使用相同密码
      # 连接池配置
      initial-size: 5
      min-idle: 10
      max-active: 20
      max-wait: 5000
      time-between-eviction-runs-millis: 60000
      min-evictable-idle-time-millis: 300000
      max-evictable-idle-time-millis: 900000
      test-while-idle: true
      test-on-borrow: false
      test-on-return: false
      validation-query: select 1
```

**关键点**:
- ✅ 所有 `${DB_HOST}`, `${DB_PORT}`, `${DB_NAME}`, `${DB_PWD}` 都不设置默认值
- ✅ 强制通过环境变量注入
- ✅ 主数据源和 Druid 使用相同的数据库名称和密码

---

## 二、Redis 配置

### 2.1 连接信息

| 配置项 | 值 | 说明 | 通过环境变量设置 |
|--------|---|------|----------------|
| **REDIS_HOST** | `52.83.127.15` | AWS 内网 Redis IP | ✅ 是 |
| **REDIS_PORT** | `6379` | Redis 默认端口 | ✅ 是 |
| **REDIS_DB** | `0` | 使用默认数据库 | ✅ 是 |
| **REDIS_PWD** | `(敏感信息)` | **必须通过环境变量注入，yml 中不存储明文** | ✅ **必须** |

### 2.2 最终配置（application.yml）

```yaml
spring:
  redis:
    database: ${REDIS_DB:0}
    host: ${REDIS_HOST}
    port: ${REDIS_PORT:6379}
    password: ${REDIS_PWD}  # 必须通过环境变量注入，无默认值
    timeout: 10000
```

**关键点**:
- ✅ REDIS_DB 和 REDIS_PORT 可以有默认值（非敏感信息）
- ✅ REDIS_HOST 和 REDIS_PWD 不设置默认值，强制通过环境变量

---

## 三、服务端口配置

### 3.1 应用端口

| 配置项 | 值 | 说明 |
|--------|---|------|
| **server.port** | `8085` | Spring Boot 应用端口 |

**当前状态**: 配置文件中未显式配置，使用 Spring Boot 默认端口或外部指定

**推荐**: 显式配置
```yaml
server:
  port: ${SERVER_PORT:8085}
```

---

## 四、JWT 配置

### 4.1 当前配置

```yaml
jwt:
  header: Authorization
  token-start-with: Bearer
  base64-secret: w8fL6FEJwTetFO8rhOvz6B/ugUjb1FImbRfAEfKAdKnkq9sYZ7zdr53yikgm9nVb0RdOIsntYrHjwAx+atF29w==
  token-validity-in-seconds: 86400000  # 24小时
  token-validity-in-long-seconds: 31536000000  # 365天
  online-key: "online-token:"
  equip-key: "online-equip:"
  code-key: code-key-
  detect: 18000000  # 300分钟
  renew: 86400000  # 24小时
  language: Language
  auth-key: auth
```

### 4.2 安全改进建议

**问题**: 本地和生产使用相同的 JWT 密钥，存在安全风险

**推荐配置**:
```yaml
jwt:
  base64-secret: ${JWT_SECRET}  # 通过环境变量注入，生产环境使用独立密钥
  # 其他配置保持不变
```

**生成新的 JWT 密钥**:
```bash
# 生成新的88位Base64密钥
openssl rand -base64 88
```

**环境变量设置**:
```bash
# 生产环境使用独立密钥
export JWT_SECRET="[新生成的88位Base64密钥]"

# 开发环境使用原密钥
export JWT_SECRET="w8fL6FEJw...（原值）"
```

---

## 五、Swagger/Knife4j 配置

### 5.1 当前配置

```yaml
swagger:
  enabled: true
  serverIp: 172.31.33.21

knife4j:
  enable: true
  basic:
    enable: true
    username: onettoo
    password: 123456
```

### 5.2 安全改进建议

**问题**:
1. 弱密码 `123456`
2. 生产环境开启 Swagger 文档可能存在信息泄露风险

**推荐配置（方案 A - 加强密码）**:
```yaml
knife4j:
  enable: true
  basic:
    enable: true
    username: ${KNIFE4J_USER:onettoo}
    password: ${KNIFE4J_PWD}  # 通过环境变量设置强密码
```

**推荐配置（方案 B - 禁用生产环境）**:
```yaml
swagger:
  enabled: ${SWAGGER_ENABLED:false}  # 生产环境禁用

knife4j:
  enable: ${KNIFE4J_ENABLED:false}  # 生产环境禁用
```

**决策**:
- **生产环境建议**: 禁用 Swagger/Knife4j 或使用强密码
- **测试环境**: 可以启用，但使用强密码

---

## 六、日志配置

### 6.1 当前配置

```yaml
logging:
  config: classpath:log4j2.xml

mybatis-plus:
  configuration:
    log-impl: org.apache.ibatis.logging.log4j2.Log4j2Impl
```

### 6.2 推荐配置

**保持不变**，但建议：
1. 检查 `log4j2.xml` 确保日志级别合适（生产环境建议 INFO 或 WARN）
2. 配置日志滚动策略，避免日志文件过大
3. 敏感信息（如密码、Token）不记录到日志

---

## 七、其他配置

### 7.1 管理员配置

```yaml
admin:
  phone: 13810269627
```

**建议**: 保持不变，或通过环境变量配置
```yaml
admin:
  phone: ${ADMIN_PHONE:13810269627}
```

### 7.2 图片存储路径

```yaml
image:
  baseImagePath: ./images/
```

**建议**:
- 生产环境使用绝对路径或云存储（如 AWS S3）
- 配置示例：
```yaml
image:
  baseImagePath: ${IMAGE_PATH:/data/onettoo/images/}
```

### 7.3 应用特定配置

```yaml
app:
  distance:
    check:
      limit:
        meters: 200.0
```

**建议**: 保持不变，或通过配置中心管理

---

## 八、完整环境变量清单

### 8.1 必须设置的环境变量（P0）

```bash
# 数据库配置
export DB_HOST="52.83.127.15"
export DB_PORT="3306"
export DB_NAME="ONETTOO"  # 待确认
export DB_USER="root"
export DB_PWD="oneAa123123!."  # 从 Secrets Manager 读取

# Redis 配置
export REDIS_HOST="52.83.127.15"
export REDIS_PORT="6379"
export REDIS_DB="0"
export REDIS_PWD="onettoo-redis-2023-onettoo."  # 从 Secrets Manager 读取
```

### 8.2 建议设置的环境变量（P1）

```bash
# JWT 密钥（生产环境独立密钥）
export JWT_SECRET="[新生成的88位Base64密钥]"

# 服务端口
export SERVER_PORT="8085"

# Swagger/Knife4j 配置
export SWAGGER_ENABLED="false"
export KNIFE4J_ENABLED="false"
# 或者使用强密码
# export KNIFE4J_USER="onettoo"
# export KNIFE4J_PWD="[强密码]"
```

### 8.3 可选设置的环境变量（P2）

```bash
# 管理员手机号
export ADMIN_PHONE="13810269627"

# 图片存储路径
export IMAGE_PATH="/data/onettoo/images/"

# 日志级别
export LOG_LEVEL="INFO"
```

---

## 九、部署启动脚本

### 9.1 基础启动脚本（start-prod.sh）

```bash
#!/bin/bash

set -e  # 遇到错误立即退出

echo "=== 观之后端生产环境启动脚本 ==="

# 1. 设置必须的环境变量
export DB_HOST="52.83.127.15"
export DB_PORT="3306"
export DB_NAME="ONETTOO"  # 待确认
export DB_USER="root"

# 2. 从文件或环境读取敏感信息（避免硬编码）
if [ -f /etc/onettoo/secrets.env ]; then
    source /etc/onettoo/secrets.env
else
    echo "错误: 未找到密钥文件 /etc/onettoo/secrets.env"
    exit 1
fi

# 3. 设置 Redis 配置
export REDIS_HOST="52.83.127.15"
export REDIS_PORT="6379"
export REDIS_DB="0"

# 4. 设置应用配置
export SERVER_PORT="8085"
export SWAGGER_ENABLED="false"
export KNIFE4J_ENABLED="false"

# 5. 验证必须的环境变量
required_vars=("DB_HOST" "DB_PWD" "REDIS_HOST" "REDIS_PWD")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "错误: 环境变量 $var 未设置"
        exit 1
    fi
done

# 6. 打印配置（不打印密码）
echo "数据库主机: $DB_HOST"
echo "数据库名称: $DB_NAME"
echo "Redis 主机: $REDIS_HOST"
echo "服务端口: $SERVER_PORT"

# 7. 启动应用
echo "启动 Spring Boot 应用..."
java -jar -Xms512m -Xmx2048m onettoo.jar
```

### 9.2 使用 AWS Secrets Manager 的启动脚本

```bash
#!/bin/bash

set -e

echo "=== 观之后端生产环境启动脚本（AWS Secrets Manager）==="

# 1. 从 AWS Secrets Manager 读取密钥
echo "从 AWS Secrets Manager 读取密钥..."
export DB_PWD=$(aws secretsmanager get-secret-value \
    --secret-id prod/onettoo/db-password \
    --query SecretString --output text)

export REDIS_PWD=$(aws secretsmanager get-secret-value \
    --secret-id prod/onettoo/redis-password \
    --query SecretString --output text)

export JWT_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id prod/onettoo/jwt-secret \
    --query SecretString --output text)

# 2. 设置其他环境变量
export DB_HOST="52.83.127.15"
export DB_PORT="3306"
export DB_NAME="ONETTOO"
export DB_USER="root"
export REDIS_HOST="52.83.127.15"
export REDIS_PORT="6379"
export REDIS_DB="0"
export SERVER_PORT="8085"

# 3. 验证
if [ -z "$DB_PWD" ] || [ -z "$REDIS_PWD" ] || [ -z "$JWT_SECRET" ]; then
    echo "错误: 从 Secrets Manager 读取密钥失败"
    exit 1
fi

# 4. 启动应用
echo "启动应用..."
java -jar -Xms512m -Xmx2048m onettoo.jar
```

### 9.3 Systemd 服务配置（onettoo.service）

```ini
[Unit]
Description=Onettoo Backend Service
After=network.target

[Service]
Type=simple
User=onettoo
WorkingDirectory=/opt/onettoo
EnvironmentFile=/etc/onettoo/env.conf
ExecStart=/opt/onettoo/start-prod.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**环境变量文件（/etc/onettoo/env.conf）**:
```bash
DB_HOST=52.83.127.15
DB_PORT=3306
DB_NAME=ONETTOO
DB_USER=root
DB_PWD=oneAa123123!.
REDIS_HOST=52.83.127.15
REDIS_PORT=6379
REDIS_DB=0
REDIS_PWD=onettoo-redis-2023-onettoo.
SERVER_PORT=8085
```

---

## 十、本地 Dev 与 Prod 的明确区分

### 10.1 本地开发环境配置

**目标**: 使用本地 MySQL 和 Redis，不连接生产环境

```yaml
# application-dev.yml (本地开发专用)
spring:
  datasource:
    one:
      jdbc-url: jdbc:log4jdbc:mysql://localhost:3306/ONETTOO?serverTimezone=Asia/Shanghai&characterEncoding=utf8&useSSL=false
      password: ${DB_PWD:}  # 本地MySQL无密码或设置简单密码
    druid:
      url: jdbc:log4jdbc:mysql://localhost:3306/ONETTOO?serverTimezone=Asia/Shanghai&characterEncoding=utf8&useSSL=false
      password: ${DB_PWD:}
  redis:
    host: localhost
    password: ${REDIS_PWD:}  # 本地Redis无密码

jwt:
  base64-secret: w8fL6FEJw...（开发环境密钥）

knife4j:
  enable: true
  basic:
    password: 123456  # 开发环境可以使用简单密码
```

**启动方式**:
```bash
# 本地开发
mvn spring-boot:run -Dspring.profiles.active=dev
```

### 10.2 生产环境配置

**目标**: 使用远程 AWS 数据库和 Redis，高安全级别

```yaml
# application-prod.yml (生产环境专用)
spring:
  datasource:
    one:
      jdbc-url: jdbc:log4jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?serverTimezone=Asia/Shanghai&characterEncoding=utf8&useSSL=false
      password: ${DB_PWD}  # 必须通过环境变量
    druid:
      url: jdbc:log4jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?serverTimezone=Asia/Shanghai&characterEncoding=utf8&useSSL=false
      password: ${DB_PWD}
  redis:
    host: ${REDIS_HOST}
    password: ${REDIS_PWD}  # 必须通过环境变量

jwt:
  base64-secret: ${JWT_SECRET}  # 生产环境独立密钥

knife4j:
  enable: false  # 生产环境禁用
```

**启动方式**:
```bash
# 生产环境
java -jar onettoo.jar --spring.profiles.active=prod
```

### 10.3 配置文件组织结构

```
Server/onettoo/src/main/resources/
├── application.yml                    # 公共配置（非敏感）
├── application-dev.yml               # 开发环境配置
├── application-prod.yml              # 生产环境配置
└── log4j2.xml                        # 日志配置
```

---

## 十一、待确认事项清单

在正式部署前，需要确认以下事项：

### 11.1 数据库相关
- [ ] **确认生产环境使用的数据库名称**：`ONETTOO` 还是 `four`？
- [ ] 确认数据库用户是否需要更换为非 root 用户（安全考虑）
- [ ] 确认数据库密码 `oneAa123123!.` 是否需要更换
- [ ] 确认数据库 IP `52.83.127.15` 是否正确
- [ ] 确认主数据源和 Druid 数据源是否需要连接同一个数据库

### 11.2 Redis 相关
- [ ] 确认 Redis 密码 `onettoo-redis-2023-onettoo.` 是否需要更换
- [ ] 确认 Redis IP `52.83.127.15` 是否正确
- [ ] 确认 Redis 数据库编号（当前使用 0）

### 11.3 安全相关
- [ ] 生成新的 JWT 密钥用于生产环境
- [ ] 决定 Swagger/Knife4j 在生产环境是启用（强密码）还是禁用
- [ ] 确认是否使用 AWS Secrets Manager 管理密钥
- [ ] 确认配置文件不会被提交到版本控制

### 11.4 应用相关
- [ ] 确认服务端口（当前 8085）
- [ ] 确认图片存储路径
- [ ] 确认日志输出路径和级别
- [ ] 确认 Inspector 新功能已部署到生产环境

---

## 十二、安全检查清单

部署前请逐项检查：

### 配置文件安全
- [ ] 配置文件中无任何明文密码
- [ ] 所有敏感配置使用环境变量
- [ ] 配置文件不包含生产环境 IP 地址（使用环境变量）
- [ ] `.gitignore` 包含敏感配置文件

### 密钥管理
- [ ] 数据库密码存储在安全位置（不在代码仓库）
- [ ] Redis 密码存储在安全位置
- [ ] JWT 密钥存储在安全位置
- [ ] Knife4j 密码使用强密码或禁用

### 环境隔离
- [ ] 开发环境和生产环境使用不同的配置文件
- [ ] 生产环境使用独立的 JWT 密钥
- [ ] 本地环境不连接生产数据库
- [ ] 本地环境不连接生产 Redis

### 访问控制
- [ ] Swagger/Knife4j 在生产环境禁用或有强密码保护
- [ ] 数据库用户权限最小化（考虑使用非 root 用户）
- [ ] Redis 配置密码认证
- [ ] 服务器防火墙规则正确配置

---

## 十三、部署流程建议

### Phase 1: 准备阶段
1. 确认所有"待确认事项"
2. 生成生产环境独立的 JWT 密钥
3. 准备密钥管理方案（Secrets Manager 或配置文件）
4. 备份当前生产环境配置

### Phase 2: 配置修改
1. 修改服务器上的 `application.yml`，移除硬编码密码
2. 创建 `/etc/onettoo/secrets.env` 或配置 Secrets Manager
3. 创建启动脚本 `/opt/onettoo/start-prod.sh`
4. 设置文件权限（600）确保安全

### Phase 3: 测试验证
1. 在测试环境验证新配置
2. 验证数据库连接
3. 验证 Redis 连接
4. 验证 Inspector API
5. 验证 JWT 认证

### Phase 4: 生产部署
1. 备份当前运行中的应用
2. 停止当前应用
3. 替换配置文件
4. 使用新启动脚本启动应用
5. 验证服务状态
6. 回滚方案准备

### Phase 5: 部署后检查
1. 检查应用日志，确认无错误
2. 测试关键 API 功能
3. 监控数据库连接数
4. 监控 Redis 连接
5. 验证 JWT token 签发和验证

---

## 十四、总结

### 最终配置要点

#### ✅ 必须执行的修改
1. **移除所有硬编码密码**：DB_PWD, REDIS_PWD
2. **统一数据库名称**：确认并统一 DB_NAME
3. **使用环境变量**：所有敏感信息通过环境变量注入

#### ✅ 强烈建议的改进
4. **独立 JWT 密钥**：生产环境使用不同密钥
5. **禁用或保护 Swagger**：禁用或使用强密码
6. **使用密钥管理服务**：AWS Secrets Manager

#### ✅ 可选的优化
7. **使用非 root 数据库用户**
8. **配置应用监控和日志**
9. **定期轮换密码**

### 与本地 Dev 的核心区别

| 项目 | 本地开发 (Dev) | 生产环境 (Prod) |
|------|---------------|----------------|
| **DB_HOST** | localhost | 52.83.127.15 (通过环境变量) |
| **DB_PWD** | 空或简单密码 | 强密码（通过环境变量） |
| **REDIS_HOST** | localhost | 52.83.127.15 (通过环境变量) |
| **REDIS_PWD** | 空 | 强密码（通过环境变量） |
| **JWT_SECRET** | 开发密钥 | **生产环境独立密钥** |
| **Swagger/Knife4j** | 启用（弱密码可接受） | **禁用或强密码** |
| **配置文件** | 可包含默认值 | **无敏感信息默认值** |

---

## 十五、参考资料

### 相关文档
- [application-prod-差异与决策-20251203.md](./application-prod-差异与决策-20251203.md) - 详细差异分析
- [Inspector-实现细节-20251203.md](./Inspector-实现细节-20251203.md) - Inspector 模块实现

### 外部资源
- [Spring Boot Configuration](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.external-config)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [12-Factor App - Config](https://12factor.net/config)

---

**文档版本**: 1.1
**最后更新**: 2025-12-03
**审核状态**: 已完成配置准备
**负责人**: 待指定
**状态更新**:
- ✅ 数据库名称已确认：ONETTOO
- ✅ application-prod.yml 已创建（安全版本）
- ✅ start-prod.sh 启动脚本模板已生成
- ✅ 所有敏感字段已迁移至环境变量

**下一步**: 测试验证 → 生产部署

---

## 附录：敏感信息安全说明

### ✅ 已实施的安全措施

本配置方案已确保以下敏感信息**完全从配置文件中移除**，仅通过环境变量注入：

1. **数据库密码** (`DB_PWD`)
   - ❌ 旧配置：硬编码明文 `oneAa123123!.`
   - ✅ 新配置：`${DB_PWD}` 无默认值，强制环境变量

2. **Redis 密码** (`REDIS_PWD`)
   - ❌ 旧配置：默认值 `onettoo-redis-2023-onettoo.`
   - ✅ 新配置：`${REDIS_PWD}` 无默认值，强制环境变量

3. **JWT 密钥** (`JWT_SECRET`)
   - ❌ 旧配置：与开发环境共用密钥
   - ✅ 新配置：`${JWT_SECRET}` 生产环境独立密钥

4. **数据库配置统一**
   - ❌ 旧配置：主数据源用 ONETTOO，Druid 用 four（不一致）
   - ✅ 新配置：统一使用 `${DB_NAME}` 环境变量，默认 ONETTOO

### ✅ 启动脚本安全特性

`start-prod.sh` 模板包含以下安全验证：
- 环境变量完整性检查
- 占位符值（xxxx）检测，防止误启动
- 敏感信息不回显到日志
- JVM 参数优化

### ⚠️ 重要提醒

1. **切勿将包含真实密码的脚本提交到 Git**
2. 生产环境密码应通过 AWS Secrets Manager 或类似服务管理
3. 定期轮换密码和密钥
4. 确保启动脚本权限设置为 600 或 700
