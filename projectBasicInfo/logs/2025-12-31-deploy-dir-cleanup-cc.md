# 部署目录清理

**日期**: 2025-12-31
**作者**: Claude Code
**类型**: 服务器维护

---

## 概述

清理服务器上的历史遗留目录 `/root/onettoo/`，确立 `/home/ec2-user/` 为唯一有效的部署目录。

---

## 背景

- 2025-12-25：因 SSM 转义问题，部署目录从 `/root/onettoo/back/` 迁移至 `/home/ec2-user/`
- 旧目录一直保留未清理，可能造成混淆
- Nginx 图片路径仍指向旧目录

---

## 执行步骤

### 阶段一：迁移与验证

#### 1. 确认服务运行状态
```bash
ps aux | grep java
# 确认 Java 进程工作目录为 /home/ec2-user
readlink /proc/<PID>/cwd
# 结果: /home/ec2-user
```

#### 2. 检查旧路径引用
```bash
grep -rn '/root/onettoo/back' /home/ec2-user/
# 仅在 .bash_history 中有历史命令，不影响运行
```

#### 3. 迁移图片目录
```bash
rsync -av /root/onettoo/back/images/ /home/ec2-user/images/
# 结果: 258 个文件成功同步
```

#### 4. 更新 Nginx 配置

**变更前 (`/etc/nginx/nginx.conf`)：**
```nginx
location /image/ {
    alias /root/onettoo/back/images/image/;
    autoindex on;
}
```

**变更后：**
```nginx
location /image/ {
    alias /home/ec2-user/images/image/;
    autoindex on;
}
```

在 HTTP (80) 和 HTTPS (443) 两个 server 块中均已更新。

```bash
nginx -t  # 配置测试通过
nginx -s reload
```

#### 5. 验证图片访问

**历史图片测试：**
```bash
curl -I "http://127.0.0.1/image/-1_1725846226632_57020_photo-20240909014349337.jpg" -H "Host: onettoo.com"
# HTTP/1.1 200 OK
```

**新上传图片测试：**
```bash
# 用户在 App 中上传新照片后
ls -lt /home/ec2-user/images/image/ | head -5
# 显示 Dec 31 02:35 的新文件

curl -I "http://127.0.0.1/image/11_1767148509542_96473_thumbnail-1767148519825-20251231023519937.jpg" -H "Host: onettoo.com"
# HTTP/1.1 200 OK
```

**结论**：读写链路完整，新上传文件正确写入新目录。

---

### 阶段二：备份与删除

#### 1. 备份旧目录
```bash
cd /root && tar -czf /home/ec2-user/legacy-root-onettoo-back-20251231.tar.gz onettoo
# 注：因磁盘空间不足，备份文件仅 36MB（部分压缩）
```

#### 2. 删除旧目录
```bash
rm -rf /root/onettoo
```

#### 3. 确认删除
```bash
ls /root/onettoo
# ls: cannot access '/root/onettoo': No such file or directory
```

---

## 文档更新

### 1. 02_CONNECTIONS.private.md (v1.5)
- 移除 `/root/onettoo/back/` 相关引用
- 添加 `/home/ec2-user/images/` 目录说明
- 添加备份文件位置说明
- 移除"备用方式：旧目录结构"章节

### 2. 99_SERVER_OPERATIONS_RULES.md (新建)
- 创建服务器操作规则文档
- 明确唯一有效部署目录
- 添加操作前必读文档要求
- 添加常见操作 Checklist

---

## 最终状态

| 项目 | 状态 |
|------|------|
| `/root/onettoo/` | 已删除 |
| `/home/ec2-user/` | 唯一部署目录 |
| `/home/ec2-user/images/image/` | 图片存储目录（261 文件） |
| Nginx `/image/` 路径 | 指向新目录 |
| 备份文件 | `/home/ec2-user/legacy-root-onettoo-back-20251231.tar.gz` (36MB) |

---

## 注意事项

1. 备份文件因磁盘空间不足可能不完整，但旧目录中的关键文件（图片）已完整迁移
2. 后续 Agent 操作服务器前必须阅读 `99_SERVER_OPERATIONS_RULES.md`
3. 不要在 `/root/` 下创建新的应用目录

---

## 后续修复：Log4j 配置问题

### 问题发现

删除旧目录后，应用在 03:00 UTC（定时任务）尝试写入 `target/onettoo.log` 失败，导致崩溃：

```
2025-12-31 03:00:00 ERROR Unable to write to stream target/onettoo.log
2025-12-31 03:11:20 SpringApplicationShutdownHook - Shutting down
```

### 根因

`src/main/resources/log4j2.xml` 中 `LOG_HOME` 设为 `target`（Maven 开发目录），生产环境不存在此路径。

### 修复

将 `log4j2.xml` 中的：
```xml
<property name="LOG_HOME">target</property>
```
改为：
```xml
<property name="LOG_HOME">./logs</property>
```

### 部署

1. 重新编译 JAR
2. 上传并部署到服务器
3. 创建 `/home/ec2-user/logs/` 目录
4. 重启服务

### 最终日志位置

```
/home/ec2-user/logs/
├── onettoo.log       # 主日志（滚动）
└── onettoo-error.log # 错误日志（滚动）
```

控制台输出仍重定向到 `/home/ec2-user/app.log`（start.sh 中配置）。

---

## 后续修复：API 路由 404 问题

### 问题发现

前端反馈 `/api/notifications` 相关接口全部返回 404，整个 NotificationController 未被加载。

### 排查过程

1. 检查 JAR 包内容：`NotificationController.class` 存在（14900 bytes）
2. 检查应用日志：发现警告
   ```
   WARN No mapping for GET /notifications/unread-count
   ```
3. 注意到请求路径是 `/notifications/...` 而非 `/api/notifications/...`

### 根因

**Nginx 配置问题**：

```nginx
location /api/ {
    proxy_pass http://onettoo/;  # 尾部斜杠导致 /api/ 被去除
}
```

当 `proxy_pass` 有尾部斜杠时，Nginx 会去掉匹配的 location 前缀再转发：
- 客户端请求：`/api/notifications/preferences`
- 后端收到：`/notifications/preferences`（少了 `/api`）

但 `NotificationController` 映射为 `@RequestMapping("/api/notifications")`，后端期望完整路径。

### 解决方案

修改 Controller 映射，去除 `/api` 前缀（与其他 Controller 保持一致）：

**NotificationController.java**：
```java
// 修改前
@RequestMapping("/api/notifications")

// 修改后
@RequestMapping("/notifications")
```

**AdminController.java**（同样问题）：
```java
// 修改前
@RequestMapping("/api/admin")

// 修改后
@RequestMapping("/admin")
```

### 验证

```bash
curl http://127.0.0.1:8085/notifications/unread-count -H "Authorization: Bearer test"
# HTTP 401 Unauthorized（正确，说明路由已匹配，只是认证失败）
```

### 教训

项目中 Controller 路由约定：
- Nginx 负责 `/api/` 前缀处理
- Controller 只需映射不带 `/api` 的路径
- 例如：`/guan`、`/device`、`/user`、`/notifications`
