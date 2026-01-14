# 后端操作指南

本指南帮助你快速定位后端相关操作需要阅读的文档。

## 任务专用文档索引

根据你要执行的任务，阅读对应的文档：

### 后端开发（写 Java 代码）

**必读文档**：
- `Server/onettoo/重要项目信息/项目结构说明.md` - 后端项目结构、包组织、命名规范
- `projectBasicInfo/01_PROJECT_OVERVIEW.md` - 技术栈和整体架构

**关键目录**：
- `Server/onettoo/src/main/java/com/cloud/onettoo/` - 主代码目录
- `Server/onettoo/src/main/resources/` - 配置文件

---

### 后端部署（部署 JAR 到服务器）

**必读文档**：
- `projectBasicInfo/05_DEPLOYMENT_SSOT.md` - **部署操作 SSOT**（单一信源）
- `projectBasicInfo/02_CONNECTIONS.private.md` - 服务器连接信息

**核心流程**：
1. 本地构建：`mvn clean package -DskipTests`
2. S3 上传：使用 `--cli-read-timeout 300`
3. SSM 部署：使用 `send-command`（非 `start-session`）
4. 版本切换：`ln -sfn releases/vX.Y.Z current`
5. 重启服务：`systemctl restart onettoo`
6. 验收：检查 `/version` 接口

**禁止操作**：
- 禁止使用 `start.sh` 或 `pkill`
- 禁止使用 `nohup` 启动
- 必须通过 systemd 管理服务

---

### 服务器操作（Nginx/MySQL/排查问题）

**必读文档**：
- `projectBasicInfo/99_SERVER_OPERATIONS_RULES.md` - 服务器操作规则
- `projectBasicInfo/02_CONNECTIONS.private.md` - 连接信息

**常用命令**：
```bash
# 服务状态
systemctl status onettoo

# 查看日志
journalctl -u onettoo -f

# Nginx 配置
nginx -t && nginx -s reload
```

---

## 安全规则

1. **禁止在文档中写密钥**（DB_PWD、REDIS_PWD、JWT_SECRET）
2. **密钥只存在于服务器 `.env` 文件**
3. **SSM 命令使用 JSON 格式参数**
4. **S3 上传必须绕过代理 + 延长超时**
