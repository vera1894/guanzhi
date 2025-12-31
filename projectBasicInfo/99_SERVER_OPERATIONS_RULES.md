# 服务器操作规则

**创建日期**: 2025-12-31
**适用对象**: Claude Code / AI Agent

---

## 核心规则

### 规则 1：操作前必读文档

**在执行任何服务器操作之前，必须先阅读以下文档：**

1. `projectBasicInfo/02_CONNECTIONS.private.md` - 服务器连接信息
2. `projectBasicInfo/03_CREDENTIALS.private.md` - 凭证信息（如需要）
3. `projectBasicInfo/logs/` - 最近的操作日志（了解服务器当前状态）

### 规则 2：唯一有效的部署目录

**服务器上唯一有效的部署目录是：**

```
/home/ec2-user/
```

**禁止使用的路径：**
- `/root/onettoo/` - 已于 2025-12-31 清理删除
- `/root/onettoo/back/` - 已于 2025-12-31 清理删除
- 任何其他 `/root/` 下的应用目录

### 规则 3：启动服务的正确方式

```bash
cd /home/ec2-user
bash start.sh
```

**禁止操作：**
- 直接执行 `java -jar onettoo.jar`（缺少环境变量）
- 通过 SSM 重新创建 `start.sh`（会破坏特殊字符）
- 在其他目录执行启动脚本

### 规则 4：图片目录

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

### 规则 5：操作日志记录

每次重要的服务器操作（部署、配置变更、故障排查等），必须在 `projectBasicInfo/logs/` 目录下创建日志文件：

**命名格式：**
```
YYYY-MM-DD-<操作描述>-cc.md
```

**示例：**
- `2025-12-31-deploy-dir-cleanup-cc.md`
- `2025-12-30-notification-center-v1.5-complete-cc.md`

---

## 常见操作 Checklist

### 部署新版本

- [ ] 阅读 `02_CONNECTIONS.private.md`
- [ ] 确认当前服务状态：`ps aux | grep java`
- [ ] 上传新 JAR 到 `/home/ec2-user/onettoo.jar`
- [ ] 停止旧服务：`pkill -9 -f 'java.*jar'`
- [ ] 启动新服务：`cd /home/ec2-user && bash start.sh`
- [ ] 验证启动：`tail -f app.log`
- [ ] 记录操作日志

### 修改 Nginx 配置

- [ ] 阅读当前配置：`cat /etc/nginx/nginx.conf`
- [ ] 修改配置
- [ ] 测试配置：`nginx -t`
- [ ] 重载配置：`nginx -s reload`
- [ ] 验证生效
- [ ] 记录操作日志

### 排查问题

- [ ] 阅读 `projectBasicInfo/logs/` 了解最近变更
- [ ] 检查应用日志：`tail -100 /home/ec2-user/app.log`
- [ ] 检查 Nginx 日志：`tail -100 /var/log/nginx/error.log`
- [ ] 检查服务状态：`ps aux | grep -E 'java|nginx|mysql|redis'`
- [ ] 记录排查过程和结论

---

## 历史变更记录

| 日期 | 变更内容 |
|------|----------|
| 2025-12-31 | 清理 `/root/onettoo/` 目录，确立 `/home/ec2-user/` 为唯一部署目录 |
| 2025-12-25 | 部署目录从 `/root/onettoo/back/` 迁移至 `/home/ec2-user/`（解决 SSM 转义问题） |
