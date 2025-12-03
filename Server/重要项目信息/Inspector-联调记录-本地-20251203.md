# Inspector 模块 - 本地联调记录

**日期**: 2025年12月3日
**目的**: Phase A - 本地实现 Inspector 接口 + 前后端联调
**状态**: ✅ 后端实现完成，⏳ 等待浏览器端测试验证

---

## 一、后端实现概述

### 1.1 新增后端类

#### DTO类（数据传输对象）

1. **ShareInspectorDTO.java**
   - 位置: `/Server/onettoo/src/main/java/com/cloud/onettoo/modules/dto/ShareInspectorDTO.java`
   - 用途: 分享查询详情的响应数据结构
   - 包含嵌套类:
     - `LocationInfo` - 位置信息
     - `TagInfo` - 标签信息

2. **UserInspectorDTO.java**
   - 位置: `/Server/onettoo/src/main/java/com/cloud/onettoo/modules/dto/UserInspectorDTO.java`
   - 用途: 用户查询详情的响应数据结构
   - 包含嵌套类:
     - `MedalInfo` - 奖章信息

#### 控制器更新

**AdminController.java** (已修改)
- 位置: `/Server/onettoo/src/main/java/com/cloud/onettoo/modules/rest/AdminController.java`
- 新增两个Inspector接口 (在文件末尾添加)

---

## 二、新增接口详情

### 2.1 分享查询接口

**接口路径**: `GET /api/admin/inspector/share/{shareId}`

**权限要求**: `@PreAuthorize("hasAnyRole('ROLE_ADMIN')")` (继承自类级别注解)

**请求示例**:
```bash
GET http://localhost:8085/api/admin/inspector/share/1
Authorization: Bearer {admin_token}
```

**成功响应** (HTTP 200):
```json
{
  "respCode": 0,
  "respMsg": "成功",
  "datas": {
    "shareId": "1",
    "userId": "2",
    "createdAt": "2025-12-01T10:30:00",
    "status": 0,
    "location": {
      "lat": 39.9042,
      "lng": 116.4074,
      "address": "北京市海淀区"
    },
    "viewUserCount": 120,
    "recentViewUserCount": null,
    "agreeCount": 45,
    "neutralCount": 5,
    "commentCount": 10,
    "checkinCount": 3,
    "tags": [],
    "fadeScore": 50,
    "isFaded": false,
    "officialMark": 0,
    "illegalFlag": false,
    "reportCount": 0
  }
}
```

**错误响应 - 数据不存在** (HTTP 200, business code 1001):
```json
{
  "respCode": 1001,
  "respMsg": "分享不存在",
  "datas": null
}
```

**错误响应 - 无效ID** (HTTP 200):
```json
{
  "respCode": -1,
  "respMsg": "无效的分享ID",
  "datas": null
}
```

### 2.2 用户查询接口

**接口路径**: `GET /api/admin/inspector/user/{userId}`

**权限要求**: `@PreAuthorize("hasAnyRole('ROLE_ADMIN')")` (继承自类级别注解)

**请求示例**:
```bash
GET http://localhost:8085/api/admin/inspector/user/2
Authorization: Bearer {admin_token}
```

**成功响应** (HTTP 200):
```json
{
  "respCode": 0,
  "respMsg": "成功",
  "datas": {
    "userId": "2",
    "nickname": "TestAdmin",
    "createdAt": "2025-01-15T08:00:00",
    "status": 0,
    "pointsTotal": 5000,
    "levelCode": "CHONGLANG",
    "levelName": "冲浪",
    "shareCount": 0,
    "viewCount": 0,
    "likeCount": 0,
    "dislikeCount": 0,
    "checkinCount": 0,
    "commentCount": 0,
    "taggedShareCount": 0,
    "medals": []
  }
}
```

**错误响应 - 数据不存在** (HTTP 200, business code 1001):
```json
{
  "respCode": 1001,
  "respMsg": "用户不存在",
  "datas": null
}
```

---

## 三、数据聚合来源

### 3.1 分享Inspector数据源

| 字段 | 数据来源 | 状态 |
|-----|---------|------|
| shareId, userId, createdAt, status | `guanzhi` 表主记录 | ✅ 已实现 |
| location (lat, lng, address) | `guanzhi.latitude`, `guanzhi.longitude`, `guanzhi.address` | ✅ 已实现 |
| viewUserCount | `guanzhi.view_user_count` | ✅ 已实现 |
| recentViewUserCount | `share_view_log` 表（最近7天） | ⏳ TODO |
| agreeCount, neutralCount | `guanzhi.agree_count`, `guanzhi.neutral_count` | ✅ 已实现 |
| commentCount, checkinCount | `guanzhi.comment_count`, `guanzhi.checkin_count` | ✅ 已实现 |
| tags | `share_tag_user` 表 + `tag_definition` 表 JOIN | ⏳ TODO |
| fadeScore, isFaded | `guanzhi.fade_score` (褪色判定: score >= 100) | ✅ 已实现 |
| officialMark | `guanzhi.official_mark` | ✅ 已实现 |
| illegalFlag | `guanzhi.status == 3` | ✅ 已实现 |
| reportCount | `share_report` 表统计 | ⏳ TODO |

### 3.2 用户Inspector数据源

| 字段 | 数据来源 | 状态 |
|-----|---------|------|
| userId, nickname, createdAt, status | `userlist` 表主记录 | ✅ 已实现 |
| pointsTotal | `userlist.points_total` | ✅ 已实现 |
| levelCode, levelName | `userlist.level_code` + `level_definition` 表 | ✅ 已实现 |
| shareCount | `guanzhi` 表 WHERE `user_id = ?` | ⏳ TODO |
| viewCount | `share_view_log` 表统计 | ⏳ TODO |
| likeCount | `share_vote` 表 WHERE `vote_type = 'AGREE'` | ⏳ TODO |
| dislikeCount | `share_vote` 表 WHERE `vote_type = 'NEUTRAL'` | ⏳ TODO |
| checkinCount | `share_checkin` 表统计 | ⏳ TODO |
| commentCount | `share_comment` 表统计 | ⏳ TODO |
| taggedShareCount | `share_tag_user` 表统计（按operator_user_id） | ⏳ TODO |
| medals | `user_medal` 表 + `medal_definition` 表 JOIN | ⏳ TODO |

**说明**:
- ✅ 已实现的字段可以直接从主表读取
- ⏳ TODO 的字段需要复杂查询或跨表聚合，当前返回默认值（0或空数组）
- 所有 TODO 字段已在代码中标注注释，便于后续补充实现

---

## 四、本地测试说明

### 4.1 测试环境

- **后端服务**: http://localhost:8085
- **前端服务**: http://localhost:5173
- **数据库**: 本地 MySQL (guanzhi数据库)

### 4.2 测试数据

从数据库查询到的测试数据：

**测试分享**:
```sql
SELECT id, user_id, create_date, status FROM guanzhi WHERE id = 1;
-- 结果: id=1, user_id=2, create_date=..., status=0
```

**测试用户**:
```sql
SELECT id, nickname, status, points_total, level_code FROM userlist WHERE id = 2;
-- 结果: id=2, nickname='TestAdmin', status=0, points_total=..., level_code='...'
```

### 4.3 浏览器端测试步骤

由于后端使用 JWT + Spring Security 认证，建议通过前端 admin-panel 进行测试：

1. **启动服务**:
   ```bash
   # 后端 (已运行)
   cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/DarkForce/Seee/guanzhi/Server/onettoo
   mvn spring-boot:run

   # 前端 (已运行)
   cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/DarkForce/Seee/guanzhi/admin-panel
   npm run dev
   ```

2. **登录管理后台**:
   - 访问: http://localhost:5173/login
   - 使用管理员账号登录
   - 系统会自动保存 admin token 到 localStorage

3. **测试分享查询**:
   - 访问: http://localhost:5173/inspector/share
   - 输入分享ID: `1`
   - 点击「查询」按钮
   - 验证:
     - ✅ 页面正常显示所有基本信息
     - ✅ status 显示为"正常"（绿色标签）
     - ✅ agreeCount 和 neutralCount 显示正确数值
     - ✅ officialMark 显示为"无标记"
     - ⚠️ tags 列表为空（预期，TODO实现）
     - ⚠️ 行为统计字段部分为0（预期，TODO实现）

4. **测试用户查询**:
   - 访问: http://localhost:5173/inspector/user
   - 输入用户ID: `2`
   - 点击「查询」按钮
   - 验证:
     - ✅ 页面正常显示基本信息
     - ✅ status 显示为"正常"（绿色标签）
     - ✅ pointsTotal 显示正确积分值
     - ✅ levelCode 和 levelName 显示正确等级
     - ⚠️ 行为统计字段全为0（预期，TODO实现）
     - ⚠️ medals 列表为空（预期，TODO实现）

5. **测试错误处理**:
   - 输入不存在的ID（如 `99999`）
   - 验证:
     - ✅ 前端显示"未找到该分享/用户"提示
     - ✅ 不会出现白屏或未捕获异常
     - ✅ 控制台无报错

### 4.4 curl测试（需要有效token）

如果需要通过 curl 测试，需要先获取有效的 admin JWT token：

```bash
# 1. 获取token (需要通过admin-panel UI登录后从localStorage复制)
TOKEN="eyJhbGci..."

# 2. 测试分享查询
curl -X GET http://localhost:8085/api/admin/inspector/share/1 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"

# 3. 测试用户查询
curl -X GET http://localhost:8085/api/admin/inspector/user/2 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"

# 4. 测试不存在的数据
curl -X GET http://localhost:8085/api/admin/inspector/share/99999 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

---

## 五、已知问题与待实现功能

### 5.1 待实现的复杂聚合字段

以下字段当前返回默认值，需要后续补充SQL查询逻辑：

**分享Inspector**:
- `recentViewUserCount`: 需要从 `share_view_log` 表计算最近N天的浏览人数
- `tags`: 需要 JOIN `share_tag_user` 和 `tag_definition` 表
- `reportCount`: 需要从 `share_report` 表统计举报次数

**用户Inspector**:
- `shareCount`: 统计用户的分享总数
- `viewCount`: 统计用户分享被浏览的总次数
- `likeCount`/`dislikeCount`: 从 `share_vote` 表聚合
- `checkinCount`/`commentCount`: 从对应表聚合
- `taggedShareCount`: 统计用户打标签的分享数
- `medals`: JOIN `user_medal` 和 `medal_definition` 表

所有待实现逻辑已在代码中用 `// TODO:` 标注。

### 5.2 已解决的问题

**问题1**: 编译错误 - `LevelDefinitionService.getByLevelCode()` 方法不存在
- **原因**: Service类中未定义该方法
- **解决**: 改用 `levelDefinitionService.list()` 遍历查找匹配的level

**问题2**: 前后端字段类型不一致
- **原因**: 前端使用字符串枚举，后端使用Integer
- **解决**: 前端已在 Phase 数据对齐中修正为 number 类型

---

## 六、编译与启动记录

### 6.1 编译日志

```bash
[INFO] Compiling 192 source files with javac [forked debug deprecation target 17] to target/classes
[WARNING] 部分警告（@EqualsAndHashCode, deprecated API调用）- 不影响功能
[INFO] BUILD SUCCESS
```

### 6.2 启动日志

```
2025-12-03 11:20:07,546 main  INFO  [org.springframework.boot.web.embedded.tomcat.TomcatWebServer]220
Tomcat started on port(s): 8085 (http) with context path ''
```

**状态**: ✅ 后端服务启动成功

---

## 七、前端对接确认

### 7.1 TypeScript接口定义

前端已定义完整的接口类型 (`/admin-panel/src/api/inspector.ts`):

```typescript
export interface ShareInspectorDetail {
  shareId: string
  userId: string
  createdAt: string
  status: 0 | 1 | 2 | 3  // 数字类型 ✅
  // ... 其他字段
}

export interface UserInspectorDetail {
  userId: string
  nickname?: string
  status: 0 | 1 | 2  // 数字类型 ✅
  pointsTotal?: number  // 正确字段名 ✅
  // ... 其他字段
}
```

### 7.2 前端API调用

```typescript
// 分享查询
export function fetchShareInspectorDetail(shareId: string) {
  return request.get<any, { datas: ShareInspectorDetail }>(
    `/admin/inspector/share/${shareId}`
  )
}

// 用户查询
export function fetchUserInspectorDetail(userId: string) {
  return request.get<any, { datas: UserInspectorDetail }>(
    `/admin/inspector/user/${userId}`
  )
}
```

### 7.3 前端错误处理

前端已实现完整的错误处理逻辑：
- 404错误 → "后端接口尚未实现"提示 (已实现后应改为"未找到数据")
- 401错误 → 清除token并跳转登录页
- 其他错误 → 友好错误提示

---

## 八、测试结论

### 8.1 当前状态

| 测试项 | 状态 | 备注 |
|-------|------|------|
| 后端编译 | ✅ 通过 | 无错误 |
| 后端启动 | ✅ 成功 | Tomcat运行在8085端口 |
| 接口定义 | ✅ 完成 | ShareInspector & UserInspector |
| DTO类创建 | ✅ 完成 | 已对齐前端TypeScript接口 |
| 基础字段聚合 | ✅ 完成 | 主表字段可正常返回 |
| 复杂字段聚合 | ⏳ 待实现 | 跨表统计字段返回默认值 |
| 错误码设计 | ✅ 实现 | 使用业务码1001表示数据不存在 |
| 前端联调 | ⏳ 待浏览器测试 | 需要管理员登录后手动验证 |

### 8.2 下一步工作

1. **立即测试** (Phase A):
   - [ ] 通过 admin-panel 登录管理后台
   - [ ] 测试分享查询页面（shareId=1）
   - [ ] 测试用户查询页面（userId=2）
   - [ ] 验证错误提示（无效ID）
   - [ ] 截图记录测试结果

2. **后续优化** (Phase B):
   - [ ] 实现所有 TODO 标记的复杂聚合字段
   - [ ] 添加单元测试
   - [ ] 性能优化（如果查询耗时过长）
   - [ ] 添加更多边界情况处理

---

## 九、参考文档

- **枚举对齐文档**: `Server/重要项目信息/Inspector-枚举对齐说明.md`
- **前端接口定义**: `admin-panel/src/api/inspector.ts`
- **前端页面组件**:
  - `admin-panel/src/views/inspector/ShareInspectorPage.vue`
  - `admin-panel/src/views/inspector/UserInspectorPage.vue`
- **后端DTO**:
  - `Server/onettoo/src/main/java/com/cloud/onettoo/modules/dto/ShareInspectorDTO.java`
  - `Server/onettoo/src/main/java/com/cloud/onettoo/modules/dto/UserInspectorDTO.java`
- **后端Controller**: `Server/onettoo/src/main/java/com/cloud/onettoo/modules/rest/AdminController.java`

---

**文档最后更新**: 2025年12月3日
**实现人员**: Claude Code
**审核状态**: 等待浏览器端测试验证
