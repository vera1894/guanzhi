# 服务器操作规则

**文档版本**: v2.1
**最后更新**: 2026-01-24
**适用对象**: Claude Code / AI Agent

---

## 核心规则

### 规则 1：操作前必读文档

**在执行任何服务器操作之前，必须先阅读以下文档：**

1. `02_CONNECTIONS.private.md` - 服务器连接信息
2. `05_DEPLOYMENT_SSOT.md` - **部署操作 SSOT**（如需部署）
3. `logs/` - 最近的操作日志（了解服务器当前状态）

### 规则 2：部署操作

**后端部署请参阅 `05_DEPLOYMENT_SSOT.md`**，包含：
- 目录结构（releases/current 架构）
- SSM 命令模板（含代理绕过、超时设置）
- S3 上传最佳实践
- 部署验收清单

### 规则 3：服务管理（systemd）

```bash
# 查看状态
systemctl status onettoo

# 重启服务
systemctl restart onettoo

# 查看日志
journalctl -u onettoo -f

# 查看最近 100 行日志
journalctl -u onettoo -n 100 --no-pager
```

**禁止操作：**
- 直接执行 `java -jar` 或 `nohup`（必须通过 systemd）
- 使用 `pkill` 停止服务（使用 `systemctl stop onettoo`）

---

## Nginx 配置

### API 代理规则

**重要**：管理后台前端（admin-web）使用 `/api` 前缀发送请求，但后端 Controller 没有 `/api` 前缀。

**正确的 Nginx 代理配置**：
```nginx
# 正确：去掉 /api 前缀
location /api/admin/ {
    proxy_pass http://127.0.0.1:8085/admin/;
}

location /api/user/ {
    proxy_pass http://127.0.0.1:8085/user/;
}

# 错误：保留 /api 前缀（会导致 404）
location /api/admin/ {
    proxy_pass http://127.0.0.1:8085/api/admin/;  # 错误！
}
```

**后端 Controller 路径与 Nginx 代理对应关系**：
| 后端路径 | 前端请求 | Nginx 代理目标 |
|---------|---------|---------------|
| `/admin/**` | `/api/admin/**` | `http://127.0.0.1:8085/admin/` |
| `/user/**` | `/api/user/**` | `http://127.0.0.1:8085/user/` |

**常见错误排查**：
- 如果前端报 404 错误，首先检查 Nginx 代理配置是否正确去掉了 `/api` 前缀
- 查看后端日志：`No mapping for POST /api/xxx` 说明 Nginx 没有正确去掉 `/api`

### 图片目录

**当前图片存储路径：**
```
/home/ec2-user/images/image/
```

**Nginx 配置：**
```nginx
location /image/ {
    alias /home/ec2-user/images/image/;
    autoindex on;
}
```

---

## 操作日志记录

每次重要的服务器操作（部署、配置变更、故障排查等），必须在 `projectBasicInfo/logs/` 目录下创建日志文件：

**命名格式：**
```
YYYY-MM-DD-<操作描述>-cc.md
```

**示例：**
- `2025-12-31-deploy-dir-cleanup-cc.md`
- `2026-01-14-deployment-ssot-plan-cc.md`

---

## 常见操作 Checklist

### 修改 Nginx 配置

- [ ] 阅读当前配置：`cat /etc/nginx/nginx.conf`
- [ ] 修改配置
- [ ] 测试配置：`nginx -t`
- [ ] 重载配置：`nginx -s reload`
- [ ] 验证生效
- [ ] 记录操作日志

### 排查问题（按优先级顺序）

**重要**：按以下顺序排查，避免在错误的层面浪费时间。

#### 步骤 1：确认数据层状态（最优先）

```bash
# 检查数据库表是否存在
export $(cat /home/ec2-user/.env | xargs) && mysql -u$DB_USER -p$DB_PWD $DB_NAME -e "SHOW TABLES LIKE 'xxx';"

# 检查数据是否存在
export $(cat /home/ec2-user/.env | xargs) && mysql -u$DB_USER -p$DB_PWD $DB_NAME -e "SELECT * FROM xxx ORDER BY created_at DESC LIMIT 5;"
```

如果数据存在 → 问题在前端显示层，跳到步骤 3

#### 步骤 2：确认后端状态

```bash
# 检查服务状态
systemctl status onettoo

# 检查最近日志（寻找错误）
journalctl -u onettoo -n 100 --no-pager | grep -i error

# 检查版本（确认部署是否生效）
curl -s http://localhost:8085/api/version | jq .
```

#### 步骤 3：确认前端部署状态

```bash
# 检查管理后台部署时间
ls -la /var/www/guanzhi-admin/

# 如果时间早于功能开发日期 → 需要重新部署管理后台
```

#### 步骤 4：检查 Nginx 配置

```bash
# 检查 Nginx 错误日志
tail -100 /var/log/nginx/error.log

# 检查代理配置
cat /etc/nginx/conf.d/*.conf | grep -A5 "location.*api"
```

#### Checklist 总结

- [ ] **数据层**：表存在？数据存在？
- [ ] **后端**：服务运行？版本正确？日志有错误？
- [ ] **前端**：部署时间？版本正确？
- [ ] **Nginx**：代理配置正确？
- [ ] 记录排查过程和结论到 `logs/`

---

## 多端功能部署验证

当一个功能涉及多个端（iOS + 后端 + 管理后台）时，**必须验证所有端都已部署**：

| 端 | 验证方法 | 示例命令 |
|----|----------|----------|
| 后端 | 检查 buildTime | `curl -s http://52.83.127.15/api/version` |
| 管理后台 | 检查文件时间戳 | `ls -la /var/www/guanzhi-admin/` |
| iOS | 检查 Xcode 构建版本 | 在设备上查看"关于"页面 |

**常见遗漏**：后端部署了但忘记部署管理后台，导致新功能在管理后台不可用。

---

## 技术栈说明

| 组件 | 说明 |
|------|------|
| 数据库迁移 | **不使用 Flyway**。`db/migration/*.sql` 仅作备份/文档用途，需手动执行 |
| ORM | MyBatis-Plus，不会自动创建表 |
| 服务管理 | systemd（`onettoo.service`） |

---

## 历史变更记录

| 日期 | 变更内容 |
|------|----------|
| 2026-01-24 | v2.1 - 增加排查问题优先级流程、多端部署验证、技术栈说明（不使用 Flyway） |
| 2026-01-14 | v2.0 - 部署相关内容迁移至 `05_DEPLOYMENT_SSOT.md`，服务管理改用 systemd |
| 2025-12-31 | 清理 `/root/onettoo/` 目录，确立 `/home/ec2-user/` 为唯一部署目录 |
| 2025-12-25 | 部署目录从 `/root/onettoo/back/` 迁移至 `/home/ec2-user/` |
