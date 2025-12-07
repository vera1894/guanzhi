# Inspector API 404 问题解决方案

**日期**: 2025-12-07
**问题**: 8086端口Inspector API返回404 Not Found
**根本原因**: 服务器上的jar文件不包含Inspector控制器

---

## 一、问题分析

### 1.1 已完成的工作

✅ **用户权限升级**：
- 用户15810349766已成功升级为ADMIN角色
- 数据库role字段：`ADMIN`（正确，系统会自动添加ROLE_前缀）

✅ **管理员Token获取**：
```
eyJhbGciOiJIUzUxMiJ9.eyJqdGkiOiJlMTc4ZDRkOTEzNjk0ZDM2YTQzNmMzNTg1ZTIwM2E5OSIsImF1dGgiOiJST0xFX0FETUlOIiwidXNlciI6MTEsIm5hbWUiOiJaYXB0YWluIiwibmlja25hbWUiOiLll7fll7fll7ciLCJwaG9uZSI6IjE1ODEwMzQ5NzY2Iiwic3ViIjoiMTEifQ.qpivxzENLOjQCRS3vWEH7LhKpdxm_zpBvfTLzLZjeZOCDIZBdkzXHUaJpc60E87vks1X74rNqF3qhyDz9N-Vgg
```

✅ **Token验证**：
- 包含正确的 `"auth": "ROLE_ADMIN"` 权限
- 可以通过鉴权验证

✅ **8085生产服务**：
- 运行正常（端口8085）
- 正在对外服务用户

✅ **8086测试服务**：
- 已重启，端口8086正在监听
- 服务进程正常运行（PID 6933）

### 1.2 当前问题

❌ **Inspector API返回404**：
```json
{
    "timestamp": 1765084608097,
    "status": 404,
    "error": "Not Found",
    "path": "/admin/inspector/share/1"
}
```

❌ **根本原因**：
- 服务器 `/root/onettoo/back/onettoo-0.0.1-SNAPSHOT.jar` 不包含Inspector控制器
- 该jar是旧版本，未编译进`AdminInspectorController`

✅ **解决方案已准备**：
- 本地已重新编译包含Inspector的jar文件
- 位置：`/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/guanzhi/Server/onettoo/target/onettoo-0.0.1-SNAPSHOT.jar`
- 已验证包含：`AdminInspectorController.class`

---

## 二、部署步骤（通过SSM）

### 准备工作

**新jar文件信息**：
- 本地路径：`/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/guanzhi/Server/onettoo/target/onettoo-0.0.1-SNAPSHOT.jar`
- 大小：约50MB
- 包含的关键类：
  ```
  BOOT-INF/classes/com/cloud/onettoo/modules/rest/AdminInspectorController.class
  BOOT-INF/classes/com/cloud/onettoo/modules/service/InspectorService.class
  BOOT-INF/classes/com/cloud/onettoo/modules/service/impl/InspectorServiceImpl.class
  BOOT-INF/classes/com/cloud/onettoo/modules/dto/ShareInspectorDTO.class
  BOOT-INF/classes/com/cloud/onettoo/modules/dto/UserInspectorDTO.class
  ```

### 步骤1: 上传新jar到服务器

**方法A：使用SCP（推荐）**
```bash
# 上传到临时目录
scp -i "/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/wanto2.pem" \
  "/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/guanzhi/Server/onettoo/target/onettoo-0.0.1-SNAPSHOT.jar" \
  ec2-user@52.83.127.15:/tmp/onettoo-new.jar

# SSH到服务器
ssh -i "/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/wanto2.pem" \
  ec2-user@52.83.127.15

# 移动到部署目录
sudo mv /tmp/onettoo-new.jar /root/onettoo/back/onettoo-new-with-inspector.jar
```

**方法B：使用AWS SSM（如果SCP失败）**
```bash
# 通过SSM Send File（需要AWS CLI配置）
aws ssm send-command \
  --region cn-northwest-1 \
  --instance-ids i-0f6e22ef4fb2d13df \
  --document-name "AWS-SendFile" \
  --parameters '{
    "sourceFile": "/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/guanzhi/Server/onettoo/target/onettoo-0.0.1-SNAPSHOT.jar",
    "destinationPath": "/tmp/onettoo-new.jar"
  }'
```

### 步骤2: 停止8086服务并备份旧jar

**使用SSM执行**：
```bash
aws ssm send-command \
  --region cn-northwest-1 \
  --instance-ids i-0f6e22ef4fb2d13df \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "echo \"=== 停止8086服务 ===\"",
    "sudo pkill -9 -f \"server.port=8086\"",
    "sleep 2",
    "sudo lsof -i :8086 || echo \"端口8086已释放\"",
    "echo \"\"",
    "echo \"=== 备份旧jar ===\"",
    "sudo cp /root/onettoo/back/onettoo-0.0.1-SNAPSHOT.jar /root/onettoo/back/onettoo-old-$(date +%Y%m%d-%H%M%S).jar",
    "echo \"备份完成\"",
    "ls -lh /root/onettoo/back/*.jar"
  ]'
```

### 步骤3: 部署新jar并启动8086服务

**使用SSM执行**：
```bash
aws ssm send-command \
  --region cn-northwest-1 \
  --instance-ids i-0f6e22ef4fb2d13df \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "echo \"=== 替换jar文件 ===\"",
    "sudo cp /root/onettoo/back/onettoo-new-with-inspector.jar /root/onettoo/back/onettoo-0.0.1-SNAPSHOT.jar",
    "echo \"\"",
    "echo \"=== 验证新jar包含Inspector ===\"",
    "sudo unzip -l /root/onettoo/back/onettoo-0.0.1-SNAPSHOT.jar | grep AdminInspectorController",
    "echo \"\"",
    "echo \"=== 启动8086服务 ===\"",
    "cd /root/onettoo/back",
    "sudo nohup /usr/lib/jvm/java-17-amazon-corretto/bin/java -Xms256m -Xmx512m -XX:+UseG1GC -Dserver.port=8086 -DDB_HOST=52.83.127.15 -DDB_PORT=3306 -DDB_NAME=ONETTOO -DDB_USER=root -DDB_PWD=\"oneAa123123!.\" -DREDIS_HOST=52.83.127.15 -DREDIS_PORT=6379 -DREDIS_DB=0 -DREDIS_PWD=\"onettoo-redis-2023-onettoo.\" -DJWT_SECRET=\"w8fL6FEJwTetFO8rhOvz6B/ugUjb1FImbRfAEfKAdKnkq9sYZ7zdr53yikgm9nVb0RdOIsntYrHjwAx+atF29w==\" -jar onettoo-0.0.1-SNAPSHOT.jar --spring.profiles.active=prod > /root/onettoo/logs/inspector-8086-$(date +%Y%m%d-%H%M%S).log 2>&1 &",
    "PID=$!",
    "echo \"服务已启动，PID: $PID\"",
    "sleep 15",
    "echo \"\"",
    "echo \"=== 验证服务状态 ===\"",
    "sudo lsof -i :8086",
    "echo \"\"",
    "echo \"=== 查看启动日志 ===\"",
    "sudo tail -50 /root/onettoo/logs/inspector-8086-*.log | tail -50"
  ]'
```

### 步骤4: 测试Inspector API

**使用管理员Token测试**：
```bash
# 设置管理员Token
ADMIN_TOKEN="eyJhbGciOiJIUzUxMiJ9.eyJqdGkiOiJlMTc4ZDRkOTEzNjk0ZDM2YTQzNmMzNTg1ZTIwM2E5OSIsImF1dGgiOiJST0xFX0FETUlOIiwidXNlciI6MTEsIm5hbWUiOiJaYXB0YWluIiwibmlja25hbWUiOiLll7fll7fll7ciLCJwaG9uZSI6IjE1ODEwMzQ5NzY2Iiwic3ViIjoiMTEifQ.qpivxzENLOjQCRS3vWEH7LhKpdxm_zpBvfTLzLZjeZOCDIZBdkzXHUaJpc60E87vks1X74rNqF3qhyDz9N-Vgg"

# 测试1: 分享详情API
echo "=== 测试分享详情 API ==="
curl -s "http://52.83.127.15:8086/admin/inspector/share/1" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | python3 -m json.tool

echo ""
echo "=== 测试用户详情 API ==="
# 测试2: 用户详情API
curl -s "http://52.83.127.15:8086/admin/inspector/user/11" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | python3 -m json.tool
```

**预期成功响应**：
```json
{
  "code": 0,
  "data": {
    "shareId": 1,
    "shareContent": "...",
    "userName": "...",
    "likeCount": 0,
    "commentCount": 1,
    "comments": [...]
  },
  "msg": "成功"
}
```

---

## 三、快速部署脚本（一键执行）

保存为 `/tmp/deploy-inspector.sh`：

```bash
#!/usr/bin/env bash
set -e

ADMIN_TOKEN="eyJhbGciOiJIUzUxMiJ9.eyJqdGkiOiJlMTc4ZDRkOTEzNjk0ZDM2YTQzNmMzNTg1ZTIwM2E5OSIsImF1dGgiOiJST0xFX0FETUlOIiwidXNlciI6MTEsIm5hbWUiOiJaYXB0YWluIiwibmlja25hbWUiOiLll7fll7fll7ciLCJwaG9uZSI6IjE1ODEwMzQ5NzY2Iiwic3ViIjoiMTEifQ.qpivxzENLOjQCRS3vWEH7LhKpdxm_zpBvfTLzLZjeZOCDIZBdkzXHUaJpc60E87vks1X74rNqF3qhyDz9N-Vgg"

echo "=========================================="
echo "Inspector API 部署和测试"
echo "=========================================="
echo ""

# 步骤1: 上传jar
echo "[1/5] 上传新jar到服务器..."
scp -i "/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/wanto2.pem" \
  "/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/guanzhi/Server/onettoo/target/onettoo-0.0.1-SNAPSHOT.jar" \
  ec2-user@52.83.127.15:/tmp/onettoo-new.jar

echo ""
echo "[2/5] 通过SSH部署到服务器..."
ssh -i "/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/wanto2.pem" \
  ec2-user@52.83.127.15 "sudo bash -s" << 'REMOTE_SCRIPT'

echo "=== 停止8086服务 ==="
pkill -9 -f "server.port=8086" || echo "没有运行的服务"
sleep 2

echo ""
echo "=== 备份并替换jar ==="
cp /root/onettoo/back/onettoo-0.0.1-SNAPSHOT.jar /root/onettoo/back/onettoo-old-$(date +%Y%m%d-%H%M%S).jar 2>/dev/null || echo "无旧jar"
cp /tmp/onettoo-new.jar /root/onettoo/back/onettoo-0.0.1-SNAPSHOT.jar

echo ""
echo "=== 验证Inspector控制器 ==="
unzip -l /root/onettoo/back/onettoo-0.0.1-SNAPSHOT.jar | grep AdminInspectorController

echo ""
echo "=== 启动8086服务 ==="
cd /root/onettoo/back
nohup /usr/lib/jvm/java-17-amazon-corretto/bin/java \
  -Xms256m -Xmx512m -XX:+UseG1GC \
  -Dserver.port=8086 \
  -DDB_HOST=52.83.127.15 -DDB_PORT=3306 -DDB_NAME=ONETTOO \
  -DDB_USER=root -DDB_PWD='oneAa123123!.' \
  -DREDIS_HOST=52.83.127.15 -DREDIS_PORT=6379 -DREDIS_DB=0 \
  -DREDIS_PWD='onettoo-redis-2023-onettoo.' \
  -DJWT_SECRET='w8fL6FEJwTetFO8rhOvz6B/ugUjb1FImbRfAEfKAdKnkq9sYZ7zdr53yikgm9nVb0RdOIsntYrHjwAx+atF29w==' \
  -jar onettoo-0.0.1-SNAPSHOT.jar --spring.profiles.active=prod \
  > /root/onettoo/logs/inspector-8086-$(date +%Y%m%d-%H%M%S).log 2>&1 &

PID=$!
echo "服务已启动，PID: $PID"

sleep 15

echo ""
echo "=== 验证端口 ==="
lsof -i :8086 || echo "端口未监听"

REMOTE_SCRIPT

echo ""
echo "[3/5] 等待服务完全启动..."
sleep 10

echo ""
echo "[4/5] 测试分享详情 API..."
curl -s "http://52.83.127.15:8086/admin/inspector/share/1" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | python3 -m json.tool

echo ""
echo "[5/5] 测试用户详情 API..."
curl -s "http://52.83.127.15:8086/admin/inspector/user/11" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | python3 -m json.tool

echo ""
echo "=========================================="
echo "部署和测试完成"
echo "=========================================="
```

**执行脚本**：
```bash
chmod +x /tmp/deploy-inspector.sh
bash /tmp/deploy-inspector.sh
```

---

## 四、验证清单

部署完成后，验证以下内容：

- [ ] 8086端口正在监听
- [ ] jar文件包含`AdminInspectorController.class`
- [ ] `/admin/inspector/share/1` 返回200和正确数据
- [ ] `/admin/inspector/user/11` 返回200和正确数据
- [ ] 日志中无错误信息
- [ ] 8085生产服务未受影响

---

## 五、故障排查

### 问题1: 上传失败

**症状**：SCP连接被关闭
**解决**：
```bash
# 检查SSH连接
ssh -i "/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/wanto2.pem" \
  ec2-user@52.83.127.15 "echo '连接成功'"

# 如果SSH正常，重试SCP
# 如果SSH失败，检查安全组规则和实例状态
```

### 问题2: 服务启动失败

**症状**：端口未监听
**检查日志**：
```bash
ssh -i "..." ec2-user@52.83.127.15 \
  "sudo tail -100 /root/onettoo/logs/inspector-8086-*.log"
```

**常见原因**：
- 内存不足：减少堆大小`-Xmx384m`
- 端口被占用：`sudo lsof -i :8086`
- 数据库连接失败：检查MySQL状态

### 问题3: API仍返回404

**排查步骤**：
```bash
# 1. 确认jar包含Inspector
ssh ... "sudo unzip -l /root/onettoo/back/onettoo-0.0.1-SNAPSHOT.jar | grep AdminInspector"

# 2. 检查启动日志中的Controller注册
ssh ... "sudo grep -i 'inspector' /root/onettoo/logs/inspector-8086-*.log"

# 3. 检查路径映射
ssh ... "sudo grep -i 'RequestMappingHandlerMapping' /root/onettoo/logs/inspector-8086-*.log"
```

---

## 六、后续建议

1. **配置自动部署**：
   - 使用CI/CD流水线自动编译和部署
   - 避免手动上传jar文件

2. **添加健康检查**：
   ```java
   @GetMapping("/admin/inspector/health")
   public RestOut health() {
       return RestOut.success("Inspector module is running");
   }
   ```

3. **使用版本化jar**：
   - 命名格式：`onettoo-inspector-v1.0.0.jar`
   - 方便回滚和追踪

---

**文档状态**: ✅ 已完成
**最后更新**: 2025-12-07
**下一步**: 执行部署脚本 `/tmp/deploy-inspector.sh`
