# 贴纸 API 接口实现日志

**日期**: 2025-12-15
**作者**: Claude Code
**类型**: 后端功能实现

---

## 背景

iOS App 在尝试使用贴纸功能时遇到 404 错误，原因是后端缺少对应的 API 接口实现。

**问题日志**：
```
请求路径: /api/stickers/availability → 404 Not Found
请求路径: /api/shares/87/stickers/use → 404 Not Found
```

---

## 实现内容

### 1. 创建 StickerController.java

**文件路径**: `src/main/java/com/cloud/onettoo/modules/rest/StickerController.java`

实现了两个 API 接口：

#### GET /stickers/availability

获取用户对某分享可用的所有贴纸及其状态。

**请求参数**：
- `shareId` (Long): 分享 ID

**响应字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| stickerId | String | 贴纸代码（如 ZHENXIU） |
| stickerName | String | 贴纸名称（如 珍馐） |
| group | String | 分组：vote/tag/fun |
| unlocked | Boolean | 是否已解锁（等级够用） |
| dailyLimit | Integer | 每日限额，null 表示无限 |
| usedToday | Integer | 今日已使用次数 |
| remainingToday | Integer | 今日剩余次数 |
| alreadyApplied | Boolean | 是否已对此分享使用过 |
| minLevelCode | String | 解锁等级代码 |
| minLevelName | String | 解锁等级名称 |

#### POST /shares/{shareId}/stickers/use

使用贴纸，扣减配额并记录使用。

**请求体**：
```json
{
  "stickerId": "ZHENXIU",
  "clientActionId": "可选的幂等ID"
}
```

**成功响应**：
```json
{
  "respCode": 0,
  "datas": {
    "success": true,
    "remainingToday": 19,
    "usedToday": 1
  }
}
```

**失败响应（错误码）**：
| errorCode | 说明 |
|-----------|------|
| STICKER_NOT_FOUND | 贴纸不存在 |
| STICKER_INACTIVE | 贴纸已停用 |
| LEVEL_NOT_ENOUGH | 用户等级不足 |
| QUOTA_EXCEEDED | 今日配额已用完 |
| ALREADY_APPLIED | 已对该分享使用过此贴纸 |
| VOTE_CONFLICT | 已对该分享投过票（vote 类互斥） |
| SHARE_NOT_FOUND | 分享不存在 |
| USER_NOT_FOUND | 用户不存在 |

### 2. 实现 StickerQuotaServiceImpl.getStickerAvailability()

**文件路径**: `src/main/java/com/cloud/onettoo/modules/service/impl/StickerQuotaServiceImpl.java`

实现逻辑：
1. 获取所有激活的贴纸定义
2. 获取用户信息和等级
3. 检查用户是否已对该分享投过票（vote 类互斥）
4. 对每个贴纸：
   - 检查等级权限
   - 计算有效限额（基础限额 × 等级倍率）
   - 获取今日已使用次数（优先 Redis，降级 DB）
   - 检查是否已对此分享使用过
   - vote 类特殊处理：如果已投过票，另一种也标记为 alreadyApplied

### 3. 添加 StickerAvailability 内部类

**文件路径**: `src/main/java/com/cloud/onettoo/modules/service/StickerQuotaService.java`

新增内部类用于封装贴纸可用性信息。

---

## Nginx 路由说明

前端请求 `/api/xxx` 会被 nginx 转发到后端 `/xxx`（去掉 `/api` 前缀）：

```nginx
location /api/ {
    proxy_pass http://onettoo/;
    ...
}
```

因此：
- `/api/stickers/availability` → 后端 `/stickers/availability` ✅
- `/api/shares/{id}/stickers/use` → 后端 `/shares/{id}/stickers/use` ✅

---

## 部署记录

1. 编译后端：`mvn clean package -DskipTests`
2. 上传到 S3：`aws s3 cp target/onettoo-0.0.1-SNAPSHOT.jar s3://guanzhi-deploy-temp-xxx/`
3. 通过 SSM 部署到服务器
4. 验证接口返回 401（需要认证），说明路由正常

---

## 验证结果

```bash
# 在服务器上测试
curl -s http://localhost:8085/stickers/availability?shareId=87
# 返回: {"status":401,"error":"Unauthorized"} ✅

curl -s -X POST http://localhost:8085/shares/87/stickers/use \
  -H "Content-Type: application/json" \
  -d '{"stickerId": "LIKE"}'
# 返回: {"status":401,"error":"Unauthorized"} ✅
```

接口已正确注册，401 表示需要登录认证，不再是 404。

---

## 关联文件

| 文件 | 改动 |
|------|------|
| `StickerController.java` | 新建，实现两个 API 接口 |
| `StickerQuotaService.java` | 新增 StickerAvailability 类和 getStickerAvailability 方法签名 |
| `StickerQuotaServiceImpl.java` | 实现 getStickerAvailability 方法 |

---

## 后续待办

- [ ] iOS App 端测试完整贴纸流程
- [ ] 集成测试：去重、互斥、配额扣减
