# Inspector 模块 - 后端枚举对齐说明

**创建日期**: 2025年12月3日
**目的**: 记录Inspector模块前端与后端数据类型的对齐结果
**涉及文件**:
- 前端: `/admin-panel/src/api/inspector.ts`
- 前端: `/admin-panel/src/views/inspector/ShareInspectorPage.vue`
- 前端: `/admin-panel/src/views/inspector/UserInspectorPage.vue`
- 后端: `/Server/onettoo/src/main/java/com/cloud/onettoo/modules/model/GuanzhiDO.java`
- 后端: `/Server/onettoo/src/main/java/com/cloud/onettoo/modules/model/UserDO.java`
- 后端: `/Server/onettoo/src/main/java/com/cloud/onettoo/modules/model/TagDefinitionDO.java`

---

## 1. 分享状态 (Share Status)

### 后端定义

**来源**: `GuanzhiDO.java:70-71`

```java
@ApiModelProperty(value = "分享状态 (0: NORMAL, 1: FADED, 2: HIDDEN, 3: ILLEGAL)")
private Integer status;
```

**数据库字段**: `guanzhi.status` (tinyint, NOT NULL, DEFAULT 0)

### 枚举值映射

| 数值 | 含义 | 前端显示文本 | Element Plus Tag类型 |
|-----|------|------------|---------------------|
| 0   | NORMAL (正常) | 正常 | success (绿色) |
| 1   | FADED (已褪色) | 已褪色 | warning (橙色) |
| 2   | HIDDEN (已隐藏) | 已隐藏 | info (灰色) |
| 3   | ILLEGAL (违法内容) | 违法内容 | danger (红色) |

### 前端TypeScript定义

```typescript
export interface ShareInspectorDetail {
  status: 0 | 1 | 2 | 3  // 0=NORMAL, 1=FADED, 2=HIDDEN, 3=ILLEGAL
  // ...
}
```

### 前端映射函数

```typescript
const getStatusText = (status?: number) => {
  const statusMap: Record<number, string> = {
    0: '正常',
    1: '已褪色',
    2: '已隐藏',
    3: '违法内容'
  }
  return status !== undefined ? (statusMap[status] || `未知状态(${status})`) : '-'
}

const getStatusType = (status?: number) => {
  const typeMap: Record<number, string> = {
    0: 'success',
    1: 'warning',
    2: 'info',
    3: 'danger'
  }
  return status !== undefined ? (typeMap[status] || 'info') : 'info'
}
```

---

## 2. 官方标记 (Official Mark)

### 后端定义

**来源**: `GuanzhiDO.java:73-74`

```java
@ApiModelProperty(value = "官方标记 (0: None, 1: Good, 2: Bad)")
private Integer officialMark;
```

**数据库字段**: `guanzhi.official_mark` (tinyint, NOT NULL, DEFAULT 0)

### 枚举值映射

| 数值 | 含义 | 前端显示文本 | Element Plus Tag类型 |
|-----|------|------------|---------------------|
| 0   | None (无标记) | 无标记 | info (灰色) |
| 1   | Good (官方推荐) | 官方推荐 | success (绿色) |
| 2   | Bad (官方警告) | 官方警告 | danger (红色) |

### 前端TypeScript定义

```typescript
export interface ShareInspectorDetail {
  officialMark?: 0 | 1 | 2  // 0=None, 1=Good, 2=Bad
  // ...
}
```

### 前端映射函数

```typescript
const getOfficialMarkText = (mark?: number) => {
  const markMap: Record<number, string> = {
    0: '无标记',
    1: '官方推荐',
    2: '官方警告'
  }
  return mark !== undefined ? (markMap[mark] || `未知标记(${mark})`) : '-'
}

const getOfficialMarkType = (mark?: number) => {
  const typeMap: Record<number, string> = {
    0: 'info',
    1: 'success',
    2: 'danger'
  }
  return mark !== undefined ? (typeMap[mark] || 'info') : 'info'
}
```

---

## 3. 用户状态 (User Status)

### 后端定义

**来源**: `UserDO.java:62-63`

```java
@ApiModelProperty(value = "用户状态 (0: NORMAL, 1: WARNED, 2: FROZEN)")
private Integer status;
```

**数据库字段**: `userlist.status` (tinyint, NOT NULL, DEFAULT 0)

### 枚举值映射

| 数值 | 含义 | 前端显示文本 | Element Plus Tag类型 |
|-----|------|------------|---------------------|
| 0   | NORMAL (正常) | 正常 | success (绿色) |
| 1   | WARNED (警告中) | 警告中 | warning (橙色) |
| 2   | FROZEN (已冻结) | 已冻结 | danger (红色) |

### 前端TypeScript定义

```typescript
export interface UserInspectorDetail {
  status: 0 | 1 | 2  // 0=NORMAL, 1=WARNED, 2=FROZEN
  // ...
}
```

### 前端映射函数

```typescript
const getStatusText = (status?: number) => {
  const statusMap: Record<number, string> = {
    0: '正常',
    1: '警告中',
    2: '已冻结'
  }
  return status !== undefined ? (statusMap[status] || `未知状态(${status})`) : '-'
}

const getStatusType = (status?: number) => {
  const typeMap: Record<number, string> = {
    0: 'success',
    1: 'warning',
    2: 'danger'
  }
  return status !== undefined ? (typeMap[status] || 'info') : 'info'
}
```

---

## 4. 标签类型 (Tag Type)

### 后端定义

**来源**: `TagDefinitionDO.java:29-32`

```java
/**
 * 标签类型：POSITIVE（正面标签）或 NEGATIVE（负面标签）
 * 默认值：NEGATIVE
 */
private String tagType;
```

**数据库字段**: `tag_definition.tag_type` (VARCHAR(20), DEFAULT 'NEGATIVE')

### 枚举值映射

| 字符串值 | 含义 | 前端显示文本 | Element Plus Tag类型 |
|---------|------|------------|---------------------|
| POSITIVE | 正面标签 | 正面 | success (绿色) |
| NEGATIVE | 负面标签 | 负面 | warning (橙色) |

### 前端TypeScript定义

```typescript
export interface ShareInspectorDetail {
  tags?: Array<{
    tagCode: string
    tagName: string
    tagType: 'POSITIVE' | 'NEGATIVE'  // 字符串类型
    operatorUserId?: string
  }>
  // ...
}
```

### 注意事项

⚠️ **标签类型使用字符串存储，不是数字！** 与status和officialMark不同。

---

## 5. 等级代码 (Level Code)

### 后端定义

**来源**: `UserDO.java:59-60`

```java
@ApiModelProperty(value = "等级代码 (e.g., YOMIN, CHONGLANG)")
private String levelCode;
```

**数据库字段**: `userlist.level_code` (VARCHAR(50), NOT NULL, DEFAULT 'YOMIN')

### 数据库实际值（从level_definition表）

```sql
SELECT level_code, level_name, min_points
FROM level_definition
ORDER BY min_points ASC;
```

| level_code | level_name | min_points | 备注 |
|-----------|-----------|-----------|------|
| YOMIN | 游民 | 0 | 默认等级 |
| CHONGLANG | 冲浪 | 100 | |
| QIANSHUI | 潜水 | 4000 | |
| LANDONG | 蓝洞 | 10000 | |
| SHUIMU | 水母 | 50000 | |
| DENGTA | 灯塔 | 999999 | 最高等级 |

### 前端TypeScript定义

```typescript
export interface UserInspectorDetail {
  levelCode?: string    // YOMIN, CHONGLANG, QIANSHUI, LANDONG, SHUIMU, DENGTA
  levelName?: string
  // ...
}
```

### 前端映射函数

```typescript
const getLevelName = (levelCode?: string, levelName?: string) => {
  if (levelName) return levelName

  const levelMap: Record<string, string> = {
    'YOMIN': '游民',
    'CHONGLANG': '冲浪',
    'QIANSHUI': '潜水',
    'LANDONG': '蓝洞',
    'SHUIMU': '水母',
    'DENGTA': '灯塔'
  }
  return levelMap[levelCode || ''] || levelCode || '-'
}
```

---

## 6. 字段名对齐

### 分享相关字段

| 后端数据库字段名 | 后端DO字段名 | 前端接口字段名 | 说明 |
|---------------|------------|--------------|------|
| agree_count | agreeCount | agreeCount ✅ | 赞同数 |
| neutral_count | neutralCount | neutralCount ✅ | 无感数 |
| fade_score | fadeScore | fadeScore ✅ | 褪色分数 |
| official_mark | officialMark | officialMark ✅ | 官方标记 |

**修改记录**:
- ❌ 之前错误使用 `likeCount` 和 `dislikeCount`
- ✅ 已修正为 `agreeCount` 和 `neutralCount`

### 用户相关字段

| 后端数据库字段名 | 后端DO字段名 | 前端接口字段名 | 说明 |
|---------------|------------|--------------|------|
| points_total | pointsTotal | pointsTotal ✅ | 累计总积分 |
| level_code | levelCode | levelCode ✅ | 等级代码 |
| status | status | status ✅ | 用户状态 |

**修改记录**:
- ❌ 之前错误使用 `points`
- ✅ 已修正为 `pointsTotal`

---

## 7. 前后端对接注意事项

### 7.1 错误码区分

当前前端将所有404错误都视为"接口未实现"。后端实现时需要区分：

```typescript
// TODO: 后端实现后，需要区分两种404情况：
// 1. 接口未实现（路由不存在） → 提示"功能开发中"
// 2. 业务数据不存在（shareId/userId无效） → 提示"未找到该分享/用户"
// 建议：后端返回统一错误码，如 code=404 表示接口未实现，code=1001 表示数据不存在
```

**建议方案**:

接口未实现（404 Not Found）:
```json
{
  "code": 404,
  "message": "接口未实现"
}
```

数据不存在（200 OK，业务code表示错误）:
```json
{
  "code": 1001,
  "message": "未找到该分享"
}
```

### 7.2 响应格式

所有Inspector接口应遵循统一的响应格式：

```json
{
  "code": 0,
  "message": "success",
  "datas": {
    // ShareInspectorDetail 或 UserInspectorDetail
  }
}
```

### 7.3 必需字段vs可选字段

前端TypeScript接口中：
- 必需字段（没有`?`）: shareId, userId, createdAt, status
- 可选字段（有`?`）: 其他所有字段

后端应确保必需字段始终返回，可选字段可以为null或不返回。

---

## 8. 后端实现检查清单

后端开发Inspector API时，请对照此清单：

### ShareInspector接口 (`GET /api/admin/inspector/share/{shareId}`)

- [ ] status返回Integer (0/1/2/3)，不是String
- [ ] officialMark返回Integer (0/1/2)，不是String
- [ ] 字段名使用 agreeCount, neutralCount（不是likeCount, dislikeCount）
- [ ] tags数组中tagType使用String ("POSITIVE"/"NEGATIVE")
- [ ] 返回格式为 `{ code, message, datas: {...} }`
- [ ] 数据不存在时返回code=1001（不是404）
- [ ] 需要ROLE_ADMIN权限

### UserInspector接口 (`GET /api/admin/inspector/user/{userId}`)

- [ ] status返回Integer (0/1/2)，不是String
- [ ] 字段名使用 pointsTotal（不是points）
- [ ] levelCode返回String（YOMIN/CHONGLANG等）
- [ ] 返回格式为 `{ code, message, datas: {...} }`
- [ ] 数据不存在时返回code=1001（不是404）
- [ ] 需要ROLE_ADMIN权限

---

## 9. 自测记录

### 前端编译状态

✅ 所有文件成功通过TypeScript类型检查
✅ Vite HMR热更新成功，无编译错误
✅ 前端开发服务器运行正常 (http://localhost:5173)

### 页面可访问性测试

由于后端接口尚未实现，当前只能测试：
- ✅ 路由可访问（/inspector/share, /inspector/user）
- ✅ 菜单显示正常
- ✅ 输入框、查询按钮渲染正常
- ✅ 空输入提示正常
- ✅ 404错误提示"后端接口尚未实现"

### 待后端实现后的完整测试

- [ ] 查询真实shareId，验证所有字段正确显示
- [ ] 验证status数字映射为中文文本（0→正常，1→已褪色等）
- [ ] 验证officialMark数字映射正确
- [ ] 验证agreeCount/neutralCount正确显示
- [ ] 查询真实userId，验证所有字段正确显示
- [ ] 验证pointsTotal正确显示
- [ ] 验证levelCode映射为中文等级名称
- [ ] 验证无效ID返回code=1001的错误提示

---

## 10. 参考资料

- **后端模型文件**:
  - `GuanzhiDO.java` - 分享数据模型
  - `UserDO.java` - 用户数据模型
  - `TagDefinitionDO.java` - 标签定义模型

- **数据库表**:
  - `guanzhi` - 分享表
  - `userlist` - 用户表
  - `tag_definition` - 标签定义表
  - `level_definition` - 等级定义表

- **前端文件**:
  - `src/api/inspector.ts` - API接口定义
  - `src/views/inspector/ShareInspectorPage.vue` - 分享查询页
  - `src/views/inspector/UserInspectorPage.vue` - 用户查询页

---

**最后更新**: 2025年12月3日
**更新人**: Claude Code
**状态**: ✅ 前端已对齐后端，等待后端API实现
