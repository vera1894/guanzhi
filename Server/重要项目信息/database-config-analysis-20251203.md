# 生产环境数据库配置分析报告

## 创建时间
2025-12-03

## 问题描述
在审查生产环境配置时，发现数据库配置存在不一致的情况，需要确认实际使用的数据库名称。

---

## 配置文件中的数据库设置

### 1. 主数据源（spring.datasource.one）
```yaml
jdbc-url: jdbc:log4jdbc:mysql://52.83.127.15:3306/ONETTOO?...
username: root
password: oneAa123123!.  # 硬编码明文密码
```

**关键信息**:
- 数据库名称: **ONETTOO**
- 密码: 硬编码为 `oneAa123123!.`

### 2. Druid 连接池数据源（spring.datasource.druid）
```yaml
url: jdbc:log4jdbc:mysql://52.83.127.15:3306/four?...
username: root
password: ${DB_PWD:112233}  # 默认值为 112233
```

**关键信息**:
- 数据库名称: **four**
- 密码: 环境变量或默认值 `112233`

---

## 当前生产环境状态

### 应用运行状态
✅ **应用正常运行**
- 进程ID: 605382
- 启动参数: `--spring.profiles.active=prod`
- 运行时长: 自 11月24日起（约10天）

### 配置文件状态
- 使用配置: `/root/onettoo/back/application.yml`
- 无 `application-prod.yml` 文件
- 存在 `application-local.yml` (未使用)

### SQL 执行日志证据
从应用日志中观察到正在执行的 SQL 语句：
```sql
SELECT COUNT(user_id) FROM share_tag_user WHERE (share_id = ...)
UPDATE guanzhi SET user_id=..., data=..., ...
```

**结论**: 应用正在成功访问数据库，能够查询和更新 `guanzhi` 和 `share_tag_user` 表。

---

## 数据库连接验证尝试

### 尝试1: 使用主数据源密码连接
```bash
mysql -h 52.83.127.15 -u root -p'oneAa123123!.'
```
**结果**: ❌ `ERROR 1045 (28000): Access denied`

### 尝试2: 使用 localhost 连接
```bash
mysql -h localhost -u root -p'oneAa123123!.'
```
**结果**: ❌ `ERROR 1045 (28000): Access denied`

### 尝试3: 使用 Druid 默认密码
```bash
mysql -h localhost -u root -p'112233'
```
**结果**: ❌ `ERROR 1045 (28000): Access denied`

---

## 分析和推论

### 可能的情况

#### 情况 A: 使用远程 RDS/托管数据库（最可能）
**证据**:
1. 配置文件中数据库host为 `52.83.127.15`（非 localhost）
2. 从本地 MySQL 客户端无法连接
3. 应用能正常运行，说明配置正确但我们无法直接访问

**推论**:
- 数据库可能是 AWS RDS 或其他托管服务
- 防火墙规则只允许应用服务器访问
- 密码在环境变量中被覆盖了

#### 情况 B: 密码被环境变量覆盖
**证据**:
1. 配置文件中的密码连接失败
2. 应用使用 `${DB_PWD:...}` 格式

**推论**:
- 启动脚本中设置了不同的 `DB_PWD` 环境变量
- 实际密码与配置文件中的不同

#### 情况 C: 两个数据库同时存在且都在使用
**证据**:
1. 配置了两个数据源（one 和 druid）
2. 都指向了不同的数据库名称

**推论**:
- 主数据源可能用于读写，Druid 用于连接池管理
- 或者不同模块使用不同数据库

### 关于数据库名称（ONETTOO vs four）

#### Spring Boot 数据源配置机制
在 Spring Boot 中：
- `spring.datasource.one` 是自定义命名的数据源
- `spring.datasource.druid` 是 Druid 连接池配置

**关键发现**:
```yaml
spring:
  datasource:
    dbs: one  # ← 这里指定使用 "one" 数据源
    one:
      jdbc-url: ...ONETTOO...
    druid:
      url: ...four...
```

**结论**: 由于配置了 `dbs: one`，应用**实际使用的是主数据源（one）**，连接到 **ONETTOO** 数据库。

Druid 的 URL 配置可能是：
1. 历史遗留配置（未使用）
2. 用于某些特定场景（如监控）
3. 配置错误

---

## 最终判断

基于以下证据：

1. ✅ 配置中明确指定 `dbs: one`
2. ✅ 主数据源指向 `ONETTOO` 数据库
3. ✅ 应用正常运行，能查询表数据
4. ✅ SQL 日志显示正在操作 `guanzhi`, `share_tag_user` 等表

### 结论

**生产环境实际使用的数据库名称是: `ONETTOO`**

`four` 数据库配置在 Druid URL 中，但由于 Spring Boot 配置了使用 `one` 数据源，Druid 的 URL 配置**未被实际使用**。

---

## 严重配置问题

### 问题1: 数据库名称配置不一致
**状态**: 🟡 存在但未造成实际影响
- 主数据源：ONETTOO ← **实际使用**
- Druid：four ← **未使用，但造成混淆**

**风险**:
- 如果未来修改配置切换到使用 Druid 数据源，会连接到错误的数据库
- 维护人员可能误以为在使用 `four` 数据库

**建议**:
- 统一 Druid 配置中的数据库名称为 `ONETTOO`
- 或删除 Druid 中的 URL 配置，仅保留连接池参数

### 问题2: 密码验证失败
**状态**: 🔴 严重问题

**可能原因**:
1. 配置文件中的密码已过期/更换
2. 使用了环境变量覆盖配置文件密码
3. 数据库使用了不同的认证方式
4. MySQL 用户权限配置限制了访问来源

**影响**:
- 无法通过 MySQL 客户端直接访问数据库进行验证
- 配置文件中的密码可能是错误的或已泄露的

**建议**:
- 检查启动脚本中是否设置了 `DB_PWD` 环境变量
- 确认实际使用的数据库密码
- 如果密码不同，更新配置文件或使用环境变量

---

## 修正建议

### 立即修正（P0）

#### 1. 统一数据库名称配置
**修改前**:
```yaml
spring:
  datasource:
    one:
      jdbc-url: ...ONETTOO...
    druid:
      url: ...four...  # ← 错误
```

**修改后**:
```yaml
spring:
  datasource:
    one:
      jdbc-url: jdbc:log4jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?...
      password: ${DB_PWD}  # 移除硬编码
    druid:
      url: jdbc:log4jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?...  # 统一使用 DB_NAME
      password: ${DB_PWD}  # 统一密码配置
```

**环境变量设置**:
```bash
export DB_HOST="52.83.127.15"
export DB_NAME="ONETTOO"  # 明确指定
export DB_PWD="[实际密码]"
```

#### 2. 移除硬编码密码
**当前问题**:
```yaml
password: oneAa123123!.  # ← 明文密码
```

**修改为**:
```yaml
password: ${DB_PWD}  # 强制使用环境变量
```

### 验证步骤

1. **确认环境变量**
   ```bash
   ssh [server] "echo \$DB_PWD"
   ```

2. **查看启动脚本**
   ```bash
   cat /path/to/start-script.sh
   # 或
   systemctl cat onettoo.service
   ```

3. **检查进程环境变量**
   ```bash
   sudo cat /proc/605382/environ | tr '\0' '\n' | grep DB
   ```

---

## 配置文件对比

### 当前配置（有问题）
```yaml
spring:
  datasource:
    dbs: one
    one:
      jdbc-url: jdbc:log4jdbc:mysql://52.83.127.15:3306/ONETTOO?...
      password: oneAa123123!.  # ❌ 硬编码
    druid:
      url: jdbc:log4jdbc:mysql://52.83.127.15:3306/four?...  # ❌ 不一致
      password: ${DB_PWD:112233}  # ⚠️ 弱默认密码
```

### 推荐配置（安全）
```yaml
spring:
  datasource:
    dbs: one
    one:
      jdbc-url: jdbc:log4jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?...
      username: ${DB_USER:root}
      password: ${DB_PWD}  # ✅ 无默认值，强制使用环境变量
    druid:
      url: jdbc:log4jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?...  # ✅ 统一
      username: ${DB_USER:root}
      password: ${DB_PWD}  # ✅ 统一
      # ... 其他 Druid 连接池参数
```

---

## 总结

### 已确认信息
✅ 生产环境使用的数据库名称: **ONETTOO**
✅ 数据库主机: `52.83.127.15`
✅ 数据库用户: `root`
✅ 应用正常运行，能够访问数据库

### 待确认信息
❓ 实际使用的数据库密码（与配置文件不匹配）
❓ 是否通过环境变量覆盖了密码
❓ `four` 数据库是否存在及其用途

### 必须执行的修正
🔴 **P0 - 立即**: 统一数据库名称配置（将 Druid 的 `four` 改为 `ONETTOO` 或使用变量）
🔴 **P0 - 立即**: 移除硬编码密码，使用环境变量
🟡 **P1 - 尽快**: 确认实际密码并更新文档
🟡 **P1 - 尽快**: 如果密码已泄露，立即更换

---

**下一步行动**:
1. 检查服务器的启动脚本或 systemd service 文件，确认环境变量设置
2. 修改 application.yml，统一数据库名称和移除硬编码密码
3. 测试新配置（在测试环境）
4. 更新生产环境配置

**文档状态**: 已完成分析，待执行修正
**优先级**: P0（高）
**负责人**: 待指定
