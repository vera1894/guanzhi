# 贴纸配额系统前端更新

**日期**: 2025-12-15
**作者**: Claude Code
**类型**: 功能完善 + Bug 修复

---

## 一、背景

贴纸配额系统后端已于 2025-12-14 基本完成，但前端管理界面存在以下问题：

1. **贴纸定义页面**：缺失「解锁等级」字段的显示和编辑
2. **等级定义页面**：旧的 `taggingAllowance` 字段仍在使用，与新系统概念混淆
3. **部署问题**：`StickerQuotaLuaService` 中 RedisTemplate 泛型类型不匹配导致启动失败

---

## 二、修复的 Bug

### 2.1 后端启动失败 (502 错误)

**问题**：
```
Field redisTemplate in StickerQuotaLuaService required a bean of type
'org.springframework.data.redis.core.RedisTemplate<String, Object>' that could not be found.
```

**原因**：项目配置的是 `RedisTemplate<Object, Object>`，而代码中使用了 `RedisTemplate<String, Object>`

**修复** (`StickerQuotaLuaService.java:27`)：
```java
// 修复前
private RedisTemplate<String, Object> redisTemplate;

// 修复后
private RedisTemplate<Object, Object> redisTemplate;
```

---

## 三、前端更新内容

### 3.1 贴纸定义管理 (TagDefinition.vue)

#### 列表新增列
- 新增「解锁等级」列，显示该贴纸需要达到的最低等级
- 如无等级要求，显示「全员」

#### 编辑弹窗新增字段
- 新增「解锁等级」下拉选择框
- 选项动态从 `/admin/config/levels` API 加载
- 留空表示所有等级都可使用此贴纸

#### 文案优化
- 「每日限额」→「基础限额」
- 新增说明：「用户每日限额 = 基础限额 × 用户等级的配额倍率」

### 3.2 等级定义管理 (LevelDefinition.vue)

#### 列表变更
- 「贴条权限」→「旧配额(弃用)」，显示删除线样式

#### 编辑弹窗变更
- 「配额倍率」提升为主要字段
- 更新说明：「该等级用户的每日配额 = 贴纸基础限额 × 此倍率」
- 将旧的「每日贴条配额」字段收进「旧字段（即将弃用）」折叠面板
- 旧字段设为只读 (disabled)，并标注警告说明

#### 新增样式
```css
.legacy-field {
  color: #909399;
  text-decoration: line-through;
}
.legacy-tip {
  color: #e6a23c;
}
```

---

## 四、配额系统工作方式说明

### 4.1 配额计算公式

```
用户每日可用次数 = 贴纸的「基础限额」 × 用户等级的「配额倍率」
```

**示例**：
| 贴纸 | 基础限额 | 等级 | 配额倍率 | 每日可用 |
|------|----------|------|----------|----------|
| 秘境 | 20 | 游民 | 1.0 | 20 次 |
| 秘境 | 20 | 探索者 | 1.5 | 30 次 |
| 秘境 | 20 | 千帆 | 2.0 | 40 次 |

### 4.2 解锁规则

- 如果贴纸设置了「解锁等级」（如 L2）
- 只有 L2 及以上等级的用户才能使用该贴纸
- 低等级用户会收到「需要达到 L2 等级」的提示
- 如果「解锁等级」为空，所有等级用户都可使用

### 4.3 旧字段说明

`taggingAllowance`（每日贴条配额）：
- 这是旧系统的「全局标签总配额」
- 新贴纸系统**不再使用**此字段
- 保留仅为向后兼容
- 新配额由「贴纸基础限额 × 等级倍率」决定

---

## 五、部署记录

### 5.1 后端部署

```bash
# 重新编译
cd Server/onettoo
mvn clean package -DskipTests

# 上传到 S3
aws s3 cp target/onettoo-0.0.1-SNAPSHOT.jar s3://guanzhi-deploy-temp-20251214b/onettoo.jar

# SSM 部署
aws ssm send-command --instance-ids "i-0f6e22ef4fb2d13df" ...
```

**结果**：服务启动成功，耗时 13.893 秒

### 5.2 前端部署

```bash
cd admin-web
npm run build
tar -czvf /tmp/admin-web-dist.tar.gz -C dist .

# 上传到 S3 并 SSM 部署
aws s3 cp /tmp/admin-web-dist.tar.gz s3://guanzhi-deploy-temp-20251214b/
aws ssm send-command --instance-ids "i-0f6e22ef4fb2d13df" ...
```

**结果**：前端部署成功

---

## 六、文件变更清单

### 修改的文件

| 文件 | 变更内容 |
|------|----------|
| `StickerQuotaLuaService.java` | 修复 RedisTemplate 泛型类型 |
| `TagDefinition.vue` | 添加解锁等级字段、调整列宽、优化文案 |
| `LevelDefinition.vue` | 标记旧字段为弃用、添加折叠面板、新增 legacy 样式 |

### 关键代码位置

- **后端修复**: `src/main/java/.../service/impl/StickerQuotaLuaService.java:27`
- **前端-贴纸**: `src/views/config/TagDefinition.vue`
- **前端-等级**: `src/views/config/LevelDefinition.vue`

---

## 七、后端已实现的等级解锁逻辑

值得注意的是，后端已经完整实现了等级解锁逻辑：

**TagDefinitionDO.java:60**
```java
private String minLevelCode;
```

**StickerQuotaServiceImpl.java:189-213**
```java
@Override
public PermissionResult checkPermission(Long userId, String tagCode) {
    TagDefinitionDO sticker = tagDefinitionService.getByTagCode(tagCode);
    if (sticker == null) {
        return PermissionResult.denied("贴纸不存在", null);
    }

    String requiredLevel = sticker.getMinLevelCode();
    if (requiredLevel == null || requiredLevel.isEmpty()) {
        return PermissionResult.allowed(); // 无等级要求
    }

    UserDO user = userService.getById(userId);
    if (user == null || user.getLevelCode() == null) {
        return PermissionResult.denied("用户等级不足", requiredLevel);
    }

    int userWeight = levelWeights.getOrDefault(user.getLevelCode(), 0);
    int requiredWeight = levelWeights.getOrDefault(requiredLevel, Integer.MAX_VALUE);

    if (userWeight >= requiredWeight) {
        return PermissionResult.allowed();
    } else {
        return PermissionResult.denied("需要达到 " + requiredLevel + " 等级", requiredLevel);
    }
}
```

此次更新只是在前端暴露了这个已有功能的配置界面。

---

## 八、验证步骤

1. 访问管理后台 `http://52.83.127.15/guanzhi-admin/`
2. 进入「系统配置」→「贴纸定义管理」
   - 确认列表显示「解锁等级」列
   - 点击编辑，确认可选择解锁等级
3. 进入「系统配置」→「等级定义管理」
   - 确认「旧配额(弃用)」列显示删除线
   - 点击编辑，确认配额倍率为主要字段
   - 展开折叠面板，确认旧字段为只读

---

**更新完成**
