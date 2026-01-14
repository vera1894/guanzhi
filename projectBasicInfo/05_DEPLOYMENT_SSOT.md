# 部署操作 SSOT（Single Source of Truth）

**文档版本**: v1.0
**创建日期**: 2026-01-14
**适用对象**: Claude Code / AI Agent
**前置文档**: `02_CONNECTIONS.private.md`（服务器连接信息）

---

## 核心架构

### 目录结构

```
/home/ec2-user/
├── .env                         # 环境变量（权限 600，仅 root 可读）
├── releases/                    # 版本目录
│   ├── v0-bootstrap/app.jar     # 初始版本
│   ├── v3.6.1/app.jar
│   └── v3.6.2/app.jar
├── current -> releases/v3.6.2/  # 软链接，原子切换
├── application-prod.yml         # 外部配置文件
└── start.sh                     # 备用启动脚本（仅应急使用）
```

### 服务管理

| 操作 | 命令 |
|------|------|
| 查看状态 | `systemctl status onettoo` |
| 重启服务 | `systemctl restart onettoo` |
| 查看日志 | `journalctl -u onettoo -f` |
| 查看最近日志 | `journalctl -u onettoo -n 100 --no-pager` |

---

## 发布流程

### 标准发布步骤

```bash
# 1. 本地构建
cd Server/onettoo
mvn clean package -DskipTests

# 2. 上传到 S3（必须绕过代理 + 延长超时）
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy
AWS_PROFILE=onettoo-cn aws s3 cp target/onettoo-0.0.1-SNAPSHOT.jar \
  s3://guanzhi-deploy-temp-20260108/onettoo-vX.Y.Z.jar \
  --region cn-northwest-1 \
  --cli-read-timeout 300

# 3. 生成 presigned URL
AWS_PROFILE=onettoo-cn aws s3 presign \
  s3://guanzhi-deploy-temp-20260108/onettoo-vX.Y.Z.jar \
  --expires-in 3600 --region cn-northwest-1

# 4. 服务器下载（使用 SSM send-command）
# 见下方 SSM 命令模板
```

### SSM 命令模板（所有 SSM 命令必须使用此前缀）

```bash
# 发送命令
AWS_PROFILE=onettoo-cn NO_PROXY="*" aws ssm send-command \
  --instance-ids i-0f6e22ef4fb2d13df \
  --document-name AWS-RunShellScript \
  --parameters '{"command":["<命令>"]}' \
  --region cn-northwest-1 \
  --query 'Command.CommandId' \
  --output text

# 获取结果
AWS_PROFILE=onettoo-cn NO_PROXY="*" aws ssm get-command-invocation \
  --command-id <COMMAND_ID> \
  --instance-id i-0f6e22ef4fb2d13df \
  --region cn-northwest-1
```

### 服务器部署命令

```bash
# 1. 创建版本目录并下载（URL 用 base64 编码避免转义问题）
URL_B64=$(echo -n '<presigned-url>' | base64)
aws ssm send-command --parameters '{"command":[
  "mkdir -p /home/ec2-user/releases/vX.Y.Z",
  "URL=$(echo <URL_B64> | base64 -d)",
  "curl -o /home/ec2-user/releases/vX.Y.Z/app.jar $URL",
  "ls -la /home/ec2-user/releases/vX.Y.Z/"
]}'

# 2. 切换版本并重启
aws ssm send-command --parameters '{"command":[
  "ln -sfn /home/ec2-user/releases/vX.Y.Z /home/ec2-user/current",
  "systemctl restart onettoo",
  "sleep 15",
  "systemctl status onettoo --no-pager"
]}'
```

---

## 部署验收（必须全部通过）

### 验收 Checklist

```bash
# 1. 服务状态
systemctl status onettoo
# 期望：active (running)，只有一个 Main PID

# 2. 入口路径验证
ls -la /home/ec2-user/current
# 期望：current -> releases/vX.Y.Z

# 3. 进程命令行验证（一票否决项）
ps aux | grep java | grep -v grep
# 期望：-jar /home/ec2-user/current/app.jar

# 4. 版本接口验证
curl -s http://localhost:8085/version
# 期望：返回 buildTime 为本次构建时间

# 5. 日志无错误
journalctl -u onettoo -n 50 --no-pager
# 期望：显示 "Started ... in X seconds"，无启动错误
```

### 验收报告模板

每次部署必须输出：

```markdown
### 部署验收报告

**部署时间**: YYYY-MM-DD HH:MM CST
**版本号**: vX.Y.Z
**构建时间**: <从 /version 接口获取>

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 服务状态 | ✅/❌ | active (running) |
| 入口路径 | ✅/❌ | current -> releases/vX.Y.Z |
| 进程命令行 | ✅/❌ | 包含 current/app.jar |
| 版本接口 | ✅/❌ | buildTime 符合预期 |
| 启动日志 | ✅/❌ | 无错误 |
```

---

## 回滚流程

```bash
# 1. 切换到旧版本
ln -sfn /home/ec2-user/releases/v3.6.1 /home/ec2-user/current

# 2. 重启服务
systemctl restart onettoo

# 3. 验证
systemctl status onettoo
curl -s http://localhost:8085/version
```

---

## 常见问题与解决方案

### 问题 1：S3 上传超时

**现象**：上传到 100% 后报 `SSL: UNEXPECTED_EOF_WHILE_READING` 或 `Read timeout`

**解决**：
```bash
# 添加超时参数
aws s3 cp ... --cli-read-timeout 300 --cli-connect-timeout 60
```

### 问题 2：SSM 交互会话中断

**现象**：`start-session` 执行长时间命令时 EOF

**解决**：使用 `send-command` 替代 `start-session`
```bash
# 错误
aws ssm start-session --document-name AWS-StartInteractiveCommand ...

# 正确
aws ssm send-command --document-name AWS-RunShellScript ...
```

### 问题 3：SSM 传输内容被转义

**现象**：创建文件内容错误（特殊字符 `!`、`$` 被转义）

**解决**：使用 base64 编码
```bash
CONTENT_B64=$(echo -n '原始内容' | base64)
aws ssm send-command --parameters '{"command":["echo <B64> | base64 -d > /path/file"]}'
```

### 问题 4：服务器无法直接访问 S3

**现象**：`aws s3 cp` 报 `403 Forbidden`

**解决**：本地生成 presigned URL，服务器用 curl 下载
```bash
# 本地
URL=$(aws s3 presign s3://bucket/key --expires-in 3600)

# 服务器
curl -o /path/file "$URL"
```

### 问题 5：新接口返回 401

**现象**：部署新接口后返回 `Unauthorized`

**解决**：在方法上添加 `@AnonymousAccess` 注解
```java
@AnonymousAccess
@GetMapping
public RestOut publicEndpoint() { ... }
```

### 问题 6：SSM 参数引号解析错误

**现象**：`Error parsing parameter`

**解决**：使用 JSON 格式
```bash
# 错误
--parameters command='echo "hello"'

# 正确
--parameters '{"command":["echo \"hello\""]}'
```

---

## 安全规则（硬约束）

1. **禁止在文档/日志中写密钥值**（DB_PWD、REDIS_PWD、JWT_SECRET）
2. **密钥只存在于服务器 `.env` 文件**，权限 600
3. **SSM 命令输出可能泄露密钥** → 不要执行 `cat .env` 或 `cat start.sh`
4. **部署后清理本地临时文件**（`/tmp/claude/.../tasks/*.output`）

---

## 相关文档

| 文档 | 用途 |
|------|------|
| `02_CONNECTIONS.private.md` | 服务器连接信息、实例 ID |
| `99_SERVER_OPERATIONS_RULES.md` | 服务器操作通用规则 |
| `logs/2026-01-13-deployment-ssot-plan-cc.md` | 本 SSOT 的实施记录 |

---

## 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-01-14 | 初版，整合阶段 0/1 实施经验 |
