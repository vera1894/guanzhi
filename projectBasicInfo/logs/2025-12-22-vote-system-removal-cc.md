# 旧投票系统移除日志

**日期**: 2025-12-22
**操作者**: Claude Code
**部署版本**: 移除投票系统后的统一贴纸版本

---

## 背景

在贴纸系统实现过程中，发现新旧两个系统并存导致数据混乱：
- **旧系统**：`share_vote` 表 + `guanzhi.agree_count/neutral_count` 字段
- **新系统**：`share_sticker_action` 表

问题表现：
1. 贴纸看板显示错误（所有贴纸都显示为已使用）
2. 同一分享可能有两个贴纸（一个来自旧投票，一个来自新贴纸）
3. 贴纸统计混合了两个系统的数据

---

## 修改内容

### 文件修改

**`StickerQuotaServiceImpl.java`**

1. **`applySticker()` 方法**
   - 移除：检查旧 `share_vote` 表的代码
   - 现在只检查 `share_sticker_action` 表

2. **`getCurrentUserSticker()` 方法**
   - 移除：从旧投票系统返回用户贴纸的逻辑
   - 现在只从 `share_sticker_action` 表获取

3. **`getStickerAvailability()` 方法**
   - 移除：检查旧投票系统判断用户是否已使用贴纸
   - 简化为只检查 `share_sticker_action` 表

4. **`getStickerSummaries()` 方法**
   - 移除：累加 `guanzhi.agree_count/neutral_count` 到贴纸统计
   - 现在贴纸统计完全来自 `share_sticker_action` 表

5. **依赖移除**
   - 移除了 `ShareVoteService` 的 `@Autowired` 注入

---

## 数据库影响

### 废弃表/字段（不再读取，但保留数据）

| 表/字段 | 说明 |
|---------|------|
| `share_vote` | 整表废弃 |
| `guanzhi.agree_count` | 字段不再使用 |
| `guanzhi.neutral_count` | 字段不再使用 |

### 当前事实来源

| 表 | 用途 |
|----|------|
| `share_sticker_action` | 所有贴纸使用记录的唯一来源 |
| `tag_definition` | 贴纸定义 |

---

## 部署记录

```
时间: 2025-12-22 15:44 CST (07:44 UTC)
实例: i-0f6e22ef4fb2d13df
方式: AWS SSM + S3 presigned URL
S3 Bucket: guanzhi-deploy-temp-20251222 (已清理)
```

### 部署命令

```bash
# 1. 打包
mvn clean package -DskipTests

# 2. 上传到 S3
aws s3 cp target/onettoo-0.0.1-SNAPSHOT.jar s3://guanzhi-deploy-temp-20251222/onettoo.jar

# 3. 生成预签名 URL
aws s3 presign s3://guanzhi-deploy-temp-20251222/onettoo.jar --expires-in 3600

# 4. 通过 SSM 部署
aws ssm send-command --instance-ids "i-0f6e22ef4fb2d13df" ...

# 5. 清理 S3
aws s3 rb s3://guanzhi-deploy-temp-20251222 --force
```

---

## 验证

- [x] 编译成功
- [x] 服务启动正常（端口 8085）
- [x] API 端点响应正常（401 for unauthorized）
- [ ] iOS 客户端功能测试（待用户验证）

---

## 后续建议

1. **数据清理**（可选）：
   - 可以考虑在确认新系统稳定后，清理 `share_vote` 表的历史数据
   - 可以将 `guanzhi.agree_count/neutral_count` 字段设为 NULL 或删除

2. **代码清理**（可选）：
   - 可以移除 `ShareVoteService` 和 `ShareVoteDO` 相关代码
   - 可以移除 `ShareVoteMapper` 接口

3. **监控**：
   - 关注 iOS 客户端反馈
   - 检查是否有其他地方仍在使用旧投票系统

---

## 相关文档更新

- `01_PROJECT_OVERVIEW.md` - 更新贴纸系统说明和数据库表状态
