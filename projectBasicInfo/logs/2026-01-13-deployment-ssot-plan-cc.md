# 部署 SSOT 实施计划（v3.4 - 全部完成）

**创建日期**: 2026-01-13
**创建者**: Claude Code
**状态**: ✅ 全部完成
**版本**: v3.4（阶段 2 文档化完成）
**阶段 0 完成时间**: 2026-01-14 07:16 CST
**阶段 1 完成时间**: 2026-01-14 10:00 CST
**阶段 2 完成时间**: 2026-01-14 10:15 CST

---

## 问题背景

### 反复出现的问题

1. **部署连接不稳定**：SSM 命令经常断开，需要反复尝试
2. **运行旧版本**：上传了新 JAR，但服务器实际运行旧版本
3. **双进程问题**：pkill 后启动，出现两个 Java 进程同时运行

### 根因分析

| 问题 | 根因 |
|------|------|
| 连接不稳定 | AWS 中国区 SSM endpoint 需要绕过代理，未写入规范 |
| 运行旧版本 | `start.sh` 运行 `onettoo-0.0.1-SNAPSHOT.jar`，但部署上传 `onettoo.jar` |
| 双进程 | `nohup` + `pkill` 组合不可靠，缺少单实例保证 |

---

## 实施计划（v3.1）

### v3.1 改进点

| 问题 | 旧版本 | v3.1 |
|------|--------|------|
| 顺序冲突 | systemd 用 current/app.jar，但 current 在阶段1创建 | **current 前置到阶段 0.2** |
| MySQL/Redis 依赖 | After=mysql.service redis.service（名称可能不对） | **简化为 After=network.target** |
| 日志双份 | app.log + journald 同时写 | **只用 journald** |
| 抓 JAR 路径 | ps aux + grep（易抓错） | **用端口 8085 + awk** |
| grep -P 兼容性 | `grep -oP`（部分系统不支持） | **改用 awk（全系统兼容）** |
| 版本接口路径 | /version 或 /actuator/info（不明确） | **固定为 /version** |

### 执行顺序（v3 调整后）

| 顺序 | 任务 | 说明 |
|------|------|------|
| 0.1 | 密钥剥离到 .env | 安全基础 |
| **0.2** | **创建 releases/current 结构** | **前置！systemd 依赖它** |
| 0.3 | 创建 systemd 服务 | 现在可以安全引用 current/app.jar |
| 0.4 | 停旧进程 + 启动 systemd | 切换到 systemd 管理 |
| 1.x | build-info + 版本接口 | 版本可观测 |
| 2.x | DEPLOYMENT_SSOT.md | 文档固化 |

---

### 阶段 0：基础设施（一次性完成）

#### 0.1 密钥剥离到 .env 文件

**服务器执行**：

```bash
# 1. 从现有 start.sh 提取密钥值并创建 .env
# 注意：以下命令在服务器上执行，密钥值从 start.sh 中获取
cat > /home/ec2-user/.env << 'EOF'
DB_HOST=localhost
DB_PORT=3306
DB_NAME=ONETTOO
DB_USER=root
DB_PWD=<从 start.sh 中的 DB_PWD 值>
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0
REDIS_PWD=<从 start.sh 中的 REDIS_PWD 值>
JWT_SECRET=<从 start.sh 中的 JWT_SECRET 值>
EOF

# 2. 设置权限（仅 root 可读）
chmod 600 /home/ec2-user/.env
chown root:root /home/ec2-user/.env

# 3. 验证
ls -la /home/ec2-user/.env
# 应显示：-rw------- 1 root root ... .env
```

**安全规则**：
- `.env` 文件只存在于服务器本地
- 文档只写变量名清单，**禁止写密钥值**
- 任何涉及 `.env` 的读取/编辑都必须以 root 执行

#### 0.2 创建 releases/current 结构（前置！）

**必须在 systemd 之前完成**，因为 systemd 服务文件引用 `current/app.jar`。

```bash
# 1. 创建 releases 目录
mkdir -p /home/ec2-user/releases

# 2. 精确获取当前运行的 JAR（用端口 8085 匹配，避免误伤其他 Java 进程）
CURRENT_PID=$(lsof -ti:8085 2>/dev/null | head -1)
if [ -z "$CURRENT_PID" ]; then
    echo "错误：端口 8085 没有进程"
    exit 1
fi
# 使用 awk 提取 -jar 后的路径（兼容所有系统，不依赖 grep -P）
CURRENT_JAR=$(ps -p $CURRENT_PID -o args= | awk -F'-jar ' '{print $2}' | awk '{print $1}')
echo "当前运行的 JAR: $CURRENT_JAR"

# 3. 创建 v0-bootstrap 版本
mkdir -p /home/ec2-user/releases/v0-bootstrap
cp "$CURRENT_JAR" /home/ec2-user/releases/v0-bootstrap/app.jar

# 4. 创建 current 软链接
ln -sfn /home/ec2-user/releases/v0-bootstrap /home/ec2-user/current

# 5. 验证
ls -la /home/ec2-user/current
ls -la /home/ec2-user/current/app.jar
# current -> releases/v0-bootstrap
# app.jar 存在且大小正确
```

#### 0.3 创建 systemd 服务

现在可以安全引用 `current/app.jar`，因为 0.2 已经创建。

```bash
# 1. 创建 systemd 服务文件
cat > /etc/systemd/system/onettoo.service << 'EOF'
[Unit]
Description=Onettoo Spring Boot Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ec2-user
EnvironmentFile=/home/ec2-user/.env
ExecStart=/usr/bin/java -Duser.timezone=UTC -jar /home/ec2-user/current/app.jar --spring.profiles.active=prod
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 2. 重载 systemd 配置
systemctl daemon-reload

# 3. 启用服务（开机自启）
systemctl enable onettoo

# 4. 验证配置
systemctl cat onettoo
```

**说明**：
- `After=network.target`：简化依赖，应用层面处理 DB/Redis 连接重试
- 日志通过 `journalctl -u onettoo` 查看
- 不再写 `app.log`（避免双份日志 + 无轮转问题）

#### 0.4 切换到 systemd 管理

```bash
# 1. 停止旧的 nohup 进程
pkill -9 -f 'java.*jar' || true

# 2. 等待进程完全退出
sleep 3
while pgrep -f 'java.*jar' > /dev/null; do
    echo "等待旧进程退出..."
    sleep 2
done
echo "旧进程已退出"

# 3. 启动 systemd 服务
systemctl start onettoo

# 4. 验证
systemctl status onettoo
```

#### 0.5 配置日志轮转（可选但推荐）

如果需要保留 `app.log` 文件日志（便于 `tail -f`），添加 logrotate：

```bash
cat > /etc/logrotate.d/onettoo << 'EOF'
/home/ec2-user/app.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF
```

---

### 阶段 0 验收（必须全部通过）

```bash
# 1. .env 权限验证
ls -la /home/ec2-user/.env
# 期望：-rw------- 1 root root

# 2. current 软链接验证
ls -la /home/ec2-user/current
# 期望：current -> releases/v0-bootstrap

# 3. current/app.jar 存在
ls -la /home/ec2-user/current/app.jar
# 期望：文件存在，大小约 120MB

# 4. systemd 服务状态
systemctl status onettoo
# 期望：active (running)

# 5. 进程验证（命令行必须包含 current/app.jar）
ps aux | grep java | grep -v grep
# 期望：... -jar /home/ec2-user/current/app.jar ...

# 6. 本地接口验证
curl -s http://localhost:8085/notifications/unread-count
# 期望：返回 401 或正常数据（不是 404/502）

# 7. 外部域名验证（带 /api 前缀）
curl -sk https://onettoo.com/api/notifications/unread-count
# 期望：返回 401 或正常数据（不是 404/502/405）
```

---

### 阶段 1：版本可观测

#### 1.1 pom.xml 添加 build-info

```xml
<plugin>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-maven-plugin</artifactId>
    <executions>
        <execution>
            <id>build-info</id>
            <goals>
                <goal>build-info</goal>
            </goals>
        </execution>
    </executions>
</plugin>
```

#### 1.2 版本接口

```java
@RestController
@RequestMapping("/version")
public class VersionController {

    @Autowired(required = false)
    private BuildProperties buildProperties;

    @GetMapping
    public RestOut getVersion() {
        Map<String, Object> info = new HashMap<>();
        if (buildProperties != null) {
            info.put("artifact", buildProperties.getArtifact());
            info.put("version", buildProperties.getVersion());
            info.put("buildTime", buildProperties.getTime().toString());
        } else {
            info.put("version", "unknown");
        }
        return RestOut.success(info);
    }
}
```

---

### 阶段 2：DEPLOYMENT_SSOT.md + 强制验收

#### 2.1 SSM 命令固定模板

```bash
# AWS 中国区 SSM 命令必须绕过代理
NO_PROXY="*" no_proxy="*" AWS_PROFILE=onettoo-cn aws ssm send-command \
  --instance-ids i-0f6e22ef4fb2d13df \
  --region cn-northwest-1 \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["<命令>"]'

# 获取命令结果
NO_PROXY="*" no_proxy="*" AWS_PROFILE=onettoo-cn aws ssm get-command-invocation \
  --command-id <command-id> \
  --instance-id i-0f6e22ef4fb2d13df \
  --region cn-northwest-1
```

#### 2.2 发布流程（使用 systemd 后）

```bash
# 1. 上传新版本
VERSION="v3.6.1"
mkdir -p /home/ec2-user/releases/$VERSION
cp /tmp/new-app.jar /home/ec2-user/releases/$VERSION/app.jar

# 2. 原子切换
ln -sfn /home/ec2-user/releases/$VERSION /home/ec2-user/current

# 3. 重启服务（systemd 保证单实例）
systemctl restart onettoo

# 4. 验收（见下方模板）
```

#### 2.3 验收输出模板（强制）

CC 每次部署必须输出以下验收报告：

```markdown
### 部署验收报告

**部署时间**: YYYY-MM-DD HH:MM CST
**版本号**: vX.Y.Z

#### 1. 服务状态验证
```
$ systemctl status onettoo
● onettoo.service - Onettoo Spring Boot Application
   Active: active (running) since ...
   Main PID: 12345 (java)
```
- [ ] 服务状态为 active (running)
- [ ] 只有一个 Main PID

#### 2. 入口路径验证
```
$ ls -la /home/ec2-user/current
current -> releases/vX.Y.Z
```
- [ ] current 指向预期版本目录

#### 3. 进程命令行验证
```
$ ps aux | grep java | grep -v grep
root 12345 ... java ... -jar /home/ec2-user/current/app.jar ...
```
- [ ] 命令行包含 `/home/ec2-user/current/app.jar`（**一票否决项**）

#### 4. 版本接口验证（本地）
```
$ curl -s http://localhost:8085/version
{"respCode":0,"datas":{"version":"X.Y.Z","buildTime":"2026-01-13T09:00:00Z"}}
```
- [ ] 版本号符合预期
- [ ] buildTime 为本次构建时间

#### 5. 外部域名验证（带 /api 前缀）
```
$ curl -sk -X DELETE https://onettoo.com/api/notifications/999999
{"timestamp":...,"status":401,"error":"Unauthorized",...}
```
- [ ] 返回 401（接口存在）而非 404/405（路由问题）

#### 6. 日志验证
```
$ journalctl -u onettoo -n 20 --no-pager
... Started OnettooApplication in X.XX seconds ...
```
- [ ] 无启动错误
- [ ] 显示 "Started ... in X seconds"
```

---

## 目录结构（最终状态）

```
/home/ec2-user/
├── .env                      # 环境变量（权限 600，仅 root 可读）
├── releases/
│   ├── v0-bootstrap/app.jar  # 初始版本
│   ├── v3.6.0/app.jar
│   └── v3.6.1/app.jar
├── current -> releases/v3.6.1/  # 软链接，原子切换
├── application-prod.yml      # 外部配置文件
└── start.sh                  # 备用启动脚本（仅应急使用）
```

---

## 执行 Checklist

### 阶段 0（当天完成，顺序不可调）✅

- [x] 0.1 创建 `/home/ec2-user/.env`，权限 600
- [x] **0.2 创建 releases/v0-bootstrap + current 软链接**（必须在 0.3 之前）
- [x] 0.3 创建 `/etc/systemd/system/onettoo.service`
- [x] 0.4 停旧进程 + `systemctl start onettoo`
- [x] 0.5 验收（7 项全部通过）

### 阶段 1 ✅

- [x] 1.1 pom.xml 添加 build-info
- [x] 1.2 添加 `/version` 接口（含 `@AnonymousAccess`）
- [x] 1.3 构建并部署（v3.6.2）

### 阶段 2 ✅

- [x] 2.1 创建 `05_DEPLOYMENT_SSOT.md`
- [x] 2.2 更新 `00_AGENT_RULES.md`（v1.5，添加必读）
- [x] 2.3 精简 `99_SERVER_OPERATIONS_RULES.md`（v2.0）

---

## 待确认项（已决定）

| 项目 | 决定 | 理由 |
|------|------|------|
| 版本号策略 | **语义化版本 + 构建元信息** | `v3.6.1`（对外） + `buildTime`（追溯） |
| releases 保留数量 | **10 个** | 足够回滚 + 不占太多空间 |
| 服务用户 | **root** | 简化权限管理，未来可切 ec2-user |
| 日志策略 | **journald 为主** | 避免双份日志，统一查看方式 |

---

## start.sh 降级为备用

systemd 上线后，`start.sh` 仅作为应急备用（systemd 不可用时）：

```bash
#!/bin/bash
# 备用启动脚本（仅在 systemd 不可用时使用）
source /home/ec2-user/.env
nohup java -Duser.timezone=UTC -jar /home/ec2-user/current/app.jar --spring.profiles.active=prod >> /home/ec2-user/app.log 2>&1 &
```

---

## 安全规则（硬约束）

1. **禁止在文档中写密钥值**（DB_PWD、REDIS_PWD、JWT_SECRET）
2. **密钥只存在于服务器 `.env` 文件**，权限 600
3. **任何涉及 `.env` 的操作必须以 root 执行**
4. **日志文件禁止包含密钥**

---

## 回滚流程

如需回滚到之前版本：

```bash
# 1. 切换 current 到旧版本
ln -sfn /home/ec2-user/releases/v3.6.0 /home/ec2-user/current

# 2. 重启服务
systemctl restart onettoo

# 3. 验收
systemctl status onettoo
curl -s http://localhost:8085/version
```

---

## ⚠️ 阶段 0 实施经验（待固化到操作指导）

> **重要**：以下经验来自 2026-01-14 阶段 0 实际执行过程，需要在整体完成后固化到 `99_SERVER_OPERATIONS_RULES.md` 和 `05_DEPLOYMENT_SSOT.md`。

### 卡点 1：SSM 传输复杂内容必须用 base64 编码

**问题**：使用 heredoc 创建 .env 文件时，内容被 SSM 转义导致错误。

**原因**：SSM 对特殊字符（`!`、`'`、`=`、`$`）自动转义。

**解决方案**：
```bash
# 错误方式（会被转义）
aws ssm send-command --parameters 'commands=["cat > /file << EOF\nDB_PWD=xxx!.\nEOF"]'

# 正确方式（base64 编码）
CONTENT=$(cat << 'EOF' | base64
DB_HOST=localhost
DB_PWD=<密码>
EOF
)
aws ssm send-command --parameters "commands=[\"echo $CONTENT | base64 -d > /file\"]"
```

### 卡点 2：获取当前 JAR 路径可能返回相对路径

**问题**：从 `ps` 输出提取的 JAR 路径是相对路径（如 `onettoo-0.0.1-SNAPSHOT.jar`），导致 `cp` 失败。

**原因**：Java 进程启动时使用相对路径，`ps` 原样输出。

**解决方案**：
```bash
# 方案 A：使用已知的固定路径（推荐）
JAR_PATH=/home/ec2-user/onettoo-0.0.1-SNAPSHOT.jar

# 方案 B：加 fallback
CURRENT_JAR=$(ps -p $PID -o args= | awk -F'-jar ' '{print $2}' | awk '{print $1}')
if [[ ! "$CURRENT_JAR" = /* ]]; then
    CURRENT_JAR="/home/ec2-user/$CURRENT_JAR"
fi
```

### 卡点 3：部署过程中密钥泄露到临时文件

**问题**：读取 `start.sh` 获取密钥时，输出被保存到临时任务文件。

**原因**：SSM 命令结果会被写入本地临时文件供后续读取。

**解决方案**：
```bash
# 错误方式（会泄露密钥）
aws ssm send-command --parameters 'commands=["cat /home/ec2-user/start.sh"]'

# 正确方式（直接在服务器上提取并创建，不回显）
# 1. 在服务器上执行 grep 提取 + 写入 .env，不输出到终端
# 2. 或者：事先知道密钥结构，直接用 base64 编码整个 .env 内容传输

# 事后清理
rm -f /tmp/claude/.../tasks/*.output
```

### 卡点 4：SSM 命令需要统一前缀

**问题**：SSM 命令经常因代理问题超时或失败。

**解决方案**：所有 SSM 命令必须使用统一前缀：
```bash
NO_PROXY="*" no_proxy="*" AWS_PROFILE=onettoo-cn aws ssm send-command \
  --instance-ids i-0f6e22ef4fb2d13df \
  --region cn-northwest-1 \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["<命令>"]'
```

### 待固化清单 ✅ 已固化到 05_DEPLOYMENT_SSOT.md

- [x] 将 base64 编码方式写入部署模板
- [x] 更新 JAR 路径获取命令，增加 fallback
- [x] 添加"部署后清理临时文件"步骤
- [x] 强调"禁止在部署过程中输出密钥到终端"

---

## ⚠️ 阶段 1 实施经验（待固化到操作指导）

> **重要**：以下经验来自 2026-01-14 阶段 1 实际执行过程，需要在整体完成后固化到操作文档。

### 卡点 1：新接口默认需要认证

**问题**：部署 `/version` 接口后返回 `401 Unauthorized`。

**原因**：项目 Spring Security 配置默认拦截所有请求，新接口未添加白名单。

**解决方案**：
```java
// 在方法上添加 @AnonymousAccess 注解
@AnonymousAccess  // ← 添加此注解
@GetMapping
public RestOut getVersion() {
    // ...
}
```

**经验**：部署验证类接口（健康检查、版本信息）必须添加 `@AnonymousAccess`。

### 卡点 2：S3 大文件上传超时

**问题**：115MB JAR 上传到 100% 后报 `SSL: UNEXPECTED_EOF_WHILE_READING` 或 `Read timeout`。

**原因**：AWS China S3 endpoint multipart upload 完成步骤网络不稳定，默认超时时间不足。

**解决方案**：
```bash
# 错误方式（默认超时）
aws s3 cp local.jar s3://bucket/key

# 正确方式（延长超时）
aws s3 cp local.jar s3://bucket/key --cli-read-timeout 300 --cli-connect-timeout 60
```

**经验**：S3 大文件上传（>50MB）始终使用 `--cli-read-timeout 300`。

### 卡点 3：SSM 交互会话下载大文件中断

**问题**：使用 `aws ssm start-session` 下载 JAR 时，会话在下载完成前 EOF。

**原因**：`start-session` 是交互式会话，有默认闲置超时，长时间无交互（如 curl 下载中）会断开。

**解决方案**：
```bash
# 错误方式（交互式会话）
aws ssm start-session --document-name AWS-StartInteractiveCommand --parameters command='curl -o file $URL'

# 正确方式（异步命令）
aws ssm send-command --document-name AWS-RunShellScript --parameters 'commands=["curl -o file $URL"]'
# 然后用 get-command-invocation 获取结果
```

**经验**：长时间任务（下载、构建）必须使用 `send-command`，不要用 `start-session`。

### 卡点 4：EC2 IAM Role 无 S3 权限

**问题**：服务器直接执行 `aws s3 cp` 报 `403 Forbidden`。

**原因**：EC2 实例的 IAM Role 没有访问部署用 S3 bucket 的权限。

**解决方案**：
```bash
# 方案 A（推荐）：本地生成 presigned URL，服务器用 curl 下载
URL=$(aws s3 presign s3://bucket/key --expires-in 3600)
# 服务器执行
curl -o /path/to/file "$URL"

# 方案 B：给 EC2 IAM Role 添加 S3 权限（需要 AWS 控制台操作）
```

**经验**：文件传输统一走「本地 presigned URL + 服务器 curl」模式。

### 卡点 5：SSM 参数引号解析错误

**问题**：`--parameters command='...'` 中含双引号时报 `Error parsing parameter`。

**原因**：SSM CLI 参数解析器对引号嵌套敏感。

**解决方案**：
```bash
# 错误方式（key=value 格式）
--parameters command='echo "hello"'

# 正确方式（JSON 格式）
--parameters '{"command":["echo \"hello\""]}'
```

**经验**：SSM 命令参数统一使用 JSON 格式 `'{"command":["..."]}'`。

### 待固化清单（阶段 1）✅ 已固化到 05_DEPLOYMENT_SSOT.md

- [x] 部署验证接口（/version、/health）模板中预置 `@AnonymousAccess`
- [x] S3 上传命令模板增加 `--cli-read-timeout 300`
- [x] SSM 长时间任务模板使用 `send-command` 而非 `start-session`
- [x] 文件传输流程固化为 presigned URL + curl 模式
- [x] SSM 参数格式固化为 JSON 格式

---

## 参考资料

- [Spring Boot Build Info](https://docs.spring.io/spring-boot/docs/current/maven-plugin/reference/htmlsingle/#goals-build-info)
- [systemd Service Configuration](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [AWS Systems Manager - China Region](https://docs.amazonaws.cn/systems-manager/latest/userguide/)
