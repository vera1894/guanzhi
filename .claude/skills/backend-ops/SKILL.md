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
| 管理后台部署 | admin-web、管理后台、Vue | `projectBasicInfo/05_DEPLOYMENT_SSOT.md`（管理后台部署章节） |
| 服务器操作 | Nginx、MySQL、日志、排查 | `projectBasicInfo/99_SERVER_OPERATIONS_RULES.md` |
| **问题排查** | 不工作、没数据、报错、bug | `projectBasicInfo/99_SERVER_OPERATIONS_RULES.md`（排查问题章节） |

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

## 问题排查流程（重要）

当用户报告"某功能不工作"、"数据没显示"等问题时，**按以下优先级排查**：

### 优先级 1：验证数据层

**先确认数据是否存在**，避免在代码层浪费时间。

```bash
# SSM 执行数据库查询
AWS_PROFILE=onettoo-cn NO_PROXY="*" aws ssm send-command \
  --instance-ids i-0f6e22ef4fb2d13df \
  --document-name AWS-RunShellScript \
  --parameters '{"commands":["export $(cat /home/ec2-user/.env | xargs) && mysql -u$DB_USER -p$DB_PWD $DB_NAME -e \"SELECT * FROM <table> ORDER BY created_at DESC LIMIT 5;\""]}' \
  --region cn-northwest-1 \
  --query 'Command.CommandId' \
  --output text
```

- 如果数据存在 → 问题在前端显示层
- 如果数据不存在 → 检查后端 API 或数据库表

### 优先级 2：验证后端状态

```bash
# 检查版本
curl -s http://52.83.127.15/api/version | jq .datas.buildTime

# 检查服务状态（SSM）
# 命令: systemctl status onettoo

# 检查错误日志（SSM）
# 命令: journalctl -u onettoo -n 100 --no-pager | grep -i error
```

### 优先级 3：验证前端部署

```bash
# 检查管理后台部署时间（SSM）
# 命令: ls -la /var/www/guanzhi-admin/
```

如果时间早于功能开发日期 → 需要重新部署管理后台

### 技术栈注意事项

| 组件 | 说明 |
|------|------|
| 数据库迁移 | **不使用 Flyway**。`db/migration/*.sql` 仅作备份/文档用途 |
| ORM | MyBatis-Plus，**不会自动创建表** |
| 新表部署 | 需要手动执行建表 SQL |

### 排查 Checklist

- [ ] 数据库中数据是否存在？
- [ ] 后端版本是否正确？（buildTime）
- [ ] 后端日志是否有错误？
- [ ] 管理后台是否部署了最新版本？
- [ ] 新数据库表是否已创建？

---

## 日志与记录
- 重大操作（部署、配置调整、复杂 Bug 修复）完成后，在 `projectBasicInfo/logs/` 记录，命名 `YYYY-MM-DD-主题-角色.md`
