# 服务器部署指南：Java 17 升级与代码部署

## 服务器信息

| 项目 | 值 |
|------|-----|
| IP | 52.83.127.15 |
| 系统 | Amazon Linux 2023 |
| 用户 | ec2-user (SSH) / root (服务) |
| 部署目录 | /root/onettoo/back/ |
| JAR 文件名 | onettoo-0.0.1-SNAPSHOT.jar |
| 服务端口 | 8085 |

## SSH 连接方式

```bash
cd /Users/zaptain/Library/Mobile\ Documents/com~apple~CloudDocs/DarkForce/OnettoO/服务器代码备份
ssh -i ./wanto2.pem ec2-user@52.83.127.15
```

---

## 已完成的环境升级 (2025-11-24)

### 1. Java 17 已安装

```bash
# Java 17 路径
/usr/lib/jvm/java-17-amazon-corretto/bin/java

# 版本
openjdk version "17.0.11" 2024-04-16 LTS
OpenJDK Runtime Environment Corretto-17.0.11.9.1
```

### 2. start.sh 已更新

```bash
#!/bin/bash
JAVA17=/usr/lib/jvm/java-17-amazon-corretto/bin/java
JAR=onettoo-0.0.1-SNAPSHOT.jar
nohup "$JAVA17" -jar "$JAR" --spring.profiles.active=prod >/dev/null 2>&1 &
```

### 3. 备份文件

| 文件 | 备份名 |
|------|--------|
| JAR | onettoo-0.0.1-SNAPSHOT.jar.bak-20251124 |
| start.sh | start.sh.bak-20251124 |

### 4. 兼容性验证

- 旧 JAR (Java 8 编译) 在 Java 17 上运行正常 ✓
- 服务响应正常 (HTTP 401) ✓

---

## 新版本部署步骤

### 前置条件
- 已执行数据库迁移脚本（见下方）
- 已准备好新的 JAR 文件

### 部署流程

```bash
# 1. 连接服务器
ssh -i ./wanto2.pem ec2-user@52.83.127.15

# 2. 切换到 root
sudo -i

# 3. 进入部署目录
cd /root/onettoo/back

# 4. 备份当前 JAR（可选，已有备份）
cp onettoo-0.0.1-SNAPSHOT.jar onettoo-0.0.1-SNAPSHOT.jar.bak-$(date +%Y%m%d%H%M)

# 5. 停止当前服务
ps aux | grep 'java.*onettoo' | grep -v grep
kill <PID>

# 6. 上传新 JAR（从本地执行）
scp -i ./wanto2.pem /path/to/onettoo-0.0.1-SNAPSHOT.jar ec2-user@52.83.127.15:/tmp/
# 在服务器上移动
sudo mv /tmp/onettoo-0.0.1-SNAPSHOT.jar /root/onettoo/back/

# 7. 启动新服务
./start.sh

# 8. 验证
sleep 10
ps aux | grep 'java.*onettoo' | grep -v grep
curl -s -o /dev/null -w '%{http_code}' http://localhost:8085/api/auth/login -X POST
# 应返回 401 (正常)
```

---

## 数据库迁移（部署新代码前必须执行）

### 迁移脚本执行顺序

```bash
# 按顺序执行以下 SQL 脚本：
1. sql/migration-guan-share-upgrade-v1.sql
2. sql/migration-add-view-log-v2.sql
3. sql/migration-config-tables-v3.sql
4. sql/migration-enhancements-v4.sql
```

### 执行方式

```bash
mysql -u <user> -p <database> < sql/migration-xxx.sql
```

---

## 回滚方案

### 场景 A：仅回滚 JAR（最常见）

```bash
# 1. 连接服务器
ssh -i ./wanto2.pem ec2-user@52.83.127.15
sudo -i
cd /root/onettoo/back

# 2. 停止服务
ps aux | grep 'java.*onettoo' | grep -v grep
kill <PID>

# 3. 恢复旧 JAR
cp onettoo-0.0.1-SNAPSHOT.jar.bak-20251124 onettoo-0.0.1-SNAPSHOT.jar

# 4. 重启
./start.sh

# 5. 验证
sleep 10 && ps aux | grep 'java.*onettoo' | grep -v grep
```

**注意**：旧 JAR (Java 8 编译) 在 Java 17 上可以正常运行，无需切换 Java 版本。

### 场景 B：回滚 start.sh（如果脚本有问题）

```bash
cp start.sh.bak-20251124 start.sh
```

### 场景 C：回退到 Java 8（极端情况，不推荐）

```bash
# 修改 start.sh 使用 Java 8
cat > /root/onettoo/back/start.sh << 'EOF'
#!/bin/bash
nohup /usr/local/jdk1.8.0_351/bin/java -jar onettoo-0.0.1-SNAPSHOT.jar >/dev/null 2>&1 &
EOF
```

---

## 监控与日志

### 查看进程状态
```bash
ps aux | grep 'java.*onettoo' | grep -v grep
```

### 查看端口监听
```bash
sudo ss -tlnp | grep 8085
```

### 查看日志（如果有输出重定向）
```bash
# 当前配置是 >/dev/null，如需日志可修改 start.sh：
nohup "$JAVA17" -jar "$JAR" --spring.profiles.active=prod > /root/onettoo/back/app.log 2>&1 &
```

---

## 验证记录

**2025-11-24 Java 17 升级验证**：
- [x] Java 17 安装成功 (17.0.11)
- [x] 旧 JAR 在 Java 17 上兼容运行
- [x] start.sh 更新为使用 Java 17
- [x] 服务正常响应 (HTTP 401)
- [x] 备份文件已创建
