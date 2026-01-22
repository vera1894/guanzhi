---
name: backend-ops
description: 后端操作指南。在进行后端开发、部署或服务器操作前，指导你阅读正确的文档。
---

# 后端操作指南技能

当用户需要进行后端相关操作时，根据任务类型指导其阅读正确的文档，并遵循项目统一规则。

## 先读文档（必做）
1. `projectBasicInfo/00_AGENT_RULES.md` - 通用规则、术语与日志要求
2. `projectBasicInfo/01_PROJECT_OVERVIEW.md` - Monorepo 结构与后端定位
3. `projectBasicInfo/04_TERMINOLOGY.md` - 观之/Share/share 术语规范
4. 任务对应的专用文档（见下表）

## 任务类型识别

识别用户的任务类型并指向对应文档：

| 任务类型 | 关键词 | 必读文档 |
|----------|--------|----------|
| 后端开发 | Java、Controller、Service、接口开发 | `Server/onettoo/重要项目信息/项目结构说明.md` |
| 后端部署 | 部署、发布、JAR、上线 | `projectBasicInfo/05_DEPLOYMENT_SSOT.md` |
| 服务器操作 | Nginx、MySQL、日志、排查 | `projectBasicInfo/99_SERVER_OPERATIONS_RULES.md` |

## 后端开发指引

当用户要写 Java 代码时：

1. **先阅读** `Server/onettoo/重要项目信息/项目结构说明.md`
2. 了解包结构和命名规范
3. 遵循现有的代码风格
4. 术语保持：UI「观之」、代码 `Share`、接口/DB `share`

## 后端部署指引

当用户要部署后端时，**必须遵循 `05_DEPLOYMENT_SSOT.md`**：

### 标准流程
1. 本地构建：`mvn clean package -DskipTests`
2. S3 上传（必须加 `--cli-read-timeout 300`）
3. 生成 presigned URL
4. SSM `send-command` 下载到服务器
5. 切换版本：`ln -sfn releases/vX.Y.Z current`
6. 重启：`systemctl restart onettoo`
7. 验收：检查 `/version` 返回正确的 buildTime

### 禁止操作
- ❌ 使用 `start.sh` 启动
- ❌ 使用 `pkill` 停止
- ❌ 使用 `nohup` 运行
- ❌ 使用 `start-session` 执行长时间任务

### 必须操作
- ✅ 使用 systemd 管理服务
- ✅ 使用 `send-command` 执行 SSM 命令
- ✅ 使用 presigned URL + curl 下载文件
- ✅ 使用 base64 编码传输复杂内容

## 服务器操作指引

当用户要操作服务器时：

1. **先阅读** `projectBasicInfo/99_SERVER_OPERATIONS_RULES.md`
2. 连接信息在 `projectBasicInfo/02_CONNECTIONS.private.md`

### 常用命令
```bash
# 服务管理
systemctl status onettoo
systemctl restart onettoo
journalctl -u onettoo -f

# Nginx
nginx -t
nginx -s reload

# SSM 连接
AWS_PROFILE=onettoo-cn NO_PROXY="*" aws ssm start-session --target i-0f6e22ef4fb2d13df --region cn-northwest-1
```

## 安全规则（硬约束）

1. 禁止在文档/代码中写密钥值
2. 密钥只存在于服务器 `/home/ec2-user/.env`
3. SSM 命令输出可能泄露密钥，避免执行 `cat .env`

## 日志与记录
- 重大操作（部署、配置调整、复杂 Bug 修复）完成后，在 `projectBasicInfo/logs/` 记录，命名 `YYYY-MM-DD-主题-角色.md`
