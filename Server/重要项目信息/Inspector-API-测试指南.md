# Inspector API 测试指南

## 文档信息
- **创建日期**: 2025-12-04
- **版本**: 1.0
- **状态**: 待完成最终测试

---

## 一、当前部署状态

### 1.1 服务部署情况
- ✅ Inspector 服务已部署到生产服务器
- ✅ 服务端口：8086（测试端口，避免与生产 8085 冲突）
- ✅ Spring Profile: prod
- ✅ 配置：使用生产环境数据库和 Redis

### 1.2 用户权限配置
- ✅ 用户手机号：15810349766
- ✅ 用户 ID：11
- ✅ 数据库中角色已提升为：ROLE_ADMIN

### 1.3 Token 生成
- ✅ 已生成包含 ROLE_ADMIN 权限的新 JWT token
- ⚠️ 旧 token 不包含角色信息，**必须使用新生成的 token**

---

## 二、JWT Token 详解

### 2.1 Token 生成原理

根据 `TokenProvider.java` 代码分析：

```java
// TokenProvider.java:66-83
public String createToken(Authentication authentication) {
    JwtUserDTO jwtUserDto = (JwtUserDTO) authentication.getPrincipal();
    String authorities = authentication.getAuthorities().stream()
        .map(GrantedAuthority::getAuthority)
        .collect(Collectors.joining(","));

    return jwtBuilder
        .setId(IdUtil.simpleUUID())
        .claim(properties.getAuthKey(), authorities)  // ← "auth" 字段
        .claim(USER_KEY, jwtUserDto.getUser().getId())
        .claim(NAME_KEY, jwtUserDto.getUser().getName())
        .claim(NICKNAME_KEY, jwtUserDto.getUser().getNickname())
        .claim(PHONE_KEY, jwtUserDto.getUser().getPhone())
        .setSubject(jwtUserDto.getUser().getId().toString())
        .compact();
}
```

**关键点**：
- 第 76 行：使用 `properties.getAuthKey()` 存储角色信息
- `authKey` 配置值为：`"auth"`（来自 application.yml）
- 旧 token 生成时用户还不是管理员，所以没有 ROLE_ADMIN

### 2.2 新生成的 ROLE_ADMIN Token

```
eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiIzMjFkYzliNmYwMzA0ZjdiYWZmZjc5MmY3ZDJjMjY4NCIsImF1dGgiOiJST0xFX0FETUlOIiwidXNlciI6MTEsIm5hbWUiOiIxNTgxMDM0OTc2NiIsIm5pY2tuYW1lIjoiNDQ0NCIsInBob25lIjoiMTU4MTAzNDk3NjYiLCJzdWIiOiIxMSJ9.ayWCngLQXMr5HDbC3YayuQbvQonwp5I-bjASLW7mOyd_wzF9VkCHzoXSS1DZXJ38s6X0B4c3viJW-vhJb-T5Bg
```

**Payload 内容**：
```json
{
  "jti": "321dc9b6f0304f7bafff792f7d2c2684",
  "auth": "ROLE_ADMIN",    // ← 关键：管理员权限
  "user": 11,
  "name": "15810349766",
  "nickname": "4444",
  "phone": "15810349766",
  "sub": "11"
}
```

### 2.3 Token 生成工具

**位置**：`/tmp/generate_admin_token.py`

**使用方法**：
```bash
python3 /tmp/generate_admin_token.py
```

---

## 三、网络访问配置

### 3.1 当前问题

端口 8086 **未在 AWS 安全组中对外开放**，导致无法从外部访问。

### 3.2 解决方案

#### 方案 A：开放 8086 端口（推荐用于测试）

在 AWS EC2 安全组中添加入站规则：
- **类型**：自定义 TCP
- **端口范围**：8086
- **源**：
  - 测试阶段：您的 IP（更安全）
  - 或：0.0.0.0/0（允许所有，仅用于临时测试）

#### 方案 B：SSH 隧道（无需修改安全组）

```bash
# 建立 SSH 隧道，将本地 8086 映射到服务器 8086
ssh -i "/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/wanto2.pem" \
    -L 8086:127.0.0.1:8086 \
    ec2-user@52.83.127.15 \
    -N -f

# 然后使用 localhost:8086 访问
curl "http://localhost:8086/admin/inspector/share/1" \
  -H "Authorization: Bearer <TOKEN>"
```

---

## 四、API 测试步骤

### 4.1 服务器本地测试（SSH 登录后执行）

```bash
# 设置 Admin Token
export ADMIN_TOKEN="eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiIzMjFkYzliNmYwMzA0ZjdiYWZmZjc5MmY3ZDJjMjY4NCIsImF1dGgiOiJST0xFX0FETUlOIiwidXNlciI6MTEsIm5hbWUiOiIxNTgxMDM0OTc2NiIsIm5pY2tuYW1lIjoiNDQ0NCIsInBob25lIjoiMTU4MTAzNDk3NjYiLCJzdWIiOiIxMSJ9.ayWCngLQXMr5HDbC3YayuQbvQonwp5I-bjASLW7mOyd_wzF9VkCHzoXSS1DZXJ38s6X0B4c3viJW-vhJb-T5Bg"

# 测试 1: 健康检查
echo "=== 健康检查 ==="
curl -s "http://127.0.0.1:8086/actuator/health" | python3 -m json.tool

# 测试 2: Inspector 分享详情 API
echo "=== Inspector 分享详情 API ==="
curl -s "http://127.0.0.1:8086/admin/inspector/share/1" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  | python3 -m json.tool

# 测试 3: Inspector 用户详情 API
echo "=== Inspector 用户详情 API ==="
curl -s "http://127.0.0.1:8086/admin/inspector/user/11" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  | python3 -m json.tool
```

### 4.2 外部测试（配置安全组后）

```bash
# 替换为新生成的 ADMIN_TOKEN
export ADMIN_TOKEN="eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiIzMjFkYzliNmYwMzA0ZjdiYWZmZjc5MmY3ZDJjMjY4NCIsImF1dGgiOiJST0xFX0FETUlOIiwidXNlciI6MTEsIm5hbWUiOiIxNTgxMDM0OTc2NiIsIm5pY2tuYW1lIjoiNDQ0NCIsInBob25lIjoiMTU4MTAzNDk3NjYiLCJzdWIiOiIxMSJ9.ayWCngLQXMr5HDbC3YayuQbvQonwp5I-bjASLW7mOyd_wzF9VkCHzoXSS1DZXJ38s6X0B4c3viJW-vhJb-T5Bg"

# 使用公网 IP 测试
curl -s "http://52.83.127.15:8086/admin/inspector/share/1" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  | python3 -m json.tool
```

---

## 五、Inspector API 说明

### 5.1 分享详情 API

**路由**：`GET /admin/inspector/share/{shareId}`

**权限要求**：`ROLE_ADMIN`

**返回数据**（预期）：
```json
{
  "code": 0,
  "data": {
    "shareId": "1",
    "shareContent": "...",
    "publishTime": "2024-01-01 00:00:00",
    "userName": "...",
    "userNickname": "...",
    "userPhone": "...",
    "likeCount": 0,
    "commentCount": 0,
    "collectCount": 0,
    "checkinCount": 0,
    "location": {...},
    "media": [...],
    "comments": [...]
  }
}
```

**设计特点**：
- 使用聚合查询，一次性加载所有关联数据
- 避免 N+1 查询问题
- 完整的分享信息、媒体、评论、点赞等统计

### 5.2 用户详情 API

**路由**：`GET /admin/inspector/user/{userId}`

**权限要求**：`ROLE_ADMIN`

**返回数据**（预期）：
```json
{
  "code": 0,
  "data": {
    "userId": 11,
    "name": "15810349766",
    "nickname": "4444",
    "phone": "15810349766",
    "role": "ROLE_ADMIN",
    "shareCount": 0,
    "likeCount": 0,
    "commentCount": 0,
    "collectCount": 0,
    "checkinCount": 0,
    "shares": [...],
    "behaviors": [...]
  }
}
```

---

## 六、测试完整脚本

### 6.1 脚本位置

服务器端：
- `/tmp/test-inspector-api.sh`（来自部署记录）
- `/root/onettoo/infra/test-inspector-simple.sh`（简化版启动脚本）

本地端：
- `/tmp/test-inspector-api-complete.sh`（完整测试脚本）
- `/tmp/generate_admin_token.py`（Token 生成工具）

### 6.2 快速测试命令

```bash
# 方式 1：SSH 登录后执行
ssh -i "/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/wanto2.pem" ec2-user@52.83.127.15
# 然后粘贴 4.1 节中的测试命令

# 方式 2：一行命令远程执行（需先上传脚本）
ssh -i "/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/wanto2.pem" \
  ec2-user@52.83.127.15 \
  'bash /tmp/test-inspector-api.sh'
```

---

## 七、常见问题

### 7.1 "Access is denied" 错误

**原因**：Token 中没有 `"auth":"ROLE_ADMIN"` 字段

**解决**：
1. 使用本文档提供的新生成的 token
2. 或重新运行 `/tmp/generate_admin_token.py` 生成

### 7.2 连接超时

**原因**：端口 8086 未在安全组中开放

**解决**：
1. 在 AWS 控制台配置安全组（见 3.2 节）
2. 或使用 SSH 隧道（见方案 B）

### 7.3 服务未启动

**检查服务状态**：
```bash
ssh -i "/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/wanto2.pem" \
  ec2-user@52.83.127.15 \
  "lsof -i :8086"
```

**查看服务日志**：
```bash
ssh -i "/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/wanto2.pem" \
  ec2-user@52.83.127.15 \
  "tail -100 /root/onettoo/logs/inspector-test.log"
```

---

## 八、后续工作

### 8.1 当前待办
- [ ] 配置 AWS 安全组开放 8086 端口（或使用 SSH 隧道）
- [ ] 执行完整的 API 测试
- [ ] 验证数据返回正确性
- [ ] 测试错误处理（无效 ID、权限不足等）

### 8.2 生产部署准备
- [ ] 将 Inspector 功能合并到主服务（8085 端口）
- [ ] 或：配置 Nginx 反向代理 8086 端口
- [ ] 更新前端管理面板接入 Inspector API
- [ ] 编写 API 文档（Swagger/Knife4j）
- [ ] 性能测试和优化

---

## 九、相关文档

- [部署记录-Inspector-20251204.md](./部署记录-Inspector-20251204.md)
- [Inspector 模块设计文档](../onettoo/src/main/java/com/cloud/onettoo/modules/guan/adminInspector/README.md)
- AdminInspectorController.java:9
- TokenProvider.java:1

---

## 十、联系信息

如有问题，请参考以下资源：
- 部署记录文档
- 项目 Git 提交历史
- Claude 对话记录

---

**最后更新**: 2025-12-04
**状态**: Inspector 服务已部署，待配置网络访问后完成最终测试
