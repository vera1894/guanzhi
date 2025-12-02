# 对话压缩后必读 - 项目上下文

**创建时间**: 2025-12-02
**用途**: 对话压缩后，Claude Code 必须先阅读此文件以获取完整上下文

---

## 🚨 关键理解（避免偏差）

### 当前项目状态
- **后端代码**: ✅ 已完成（2025-11-24完成验证）
- **前端代码**: ✅ 已完成基础开发（2025-12-01）
- **当前任务**: 前后端联调测试 + 文档整理

### 项目定位
**这是一个「管理后台 V1」项目，不是核心业务后端升级！**

- **项目名称**: 观之管理后台（Admin Panel）
- **版本**: V1
- **定位**: 面向工程师的参数调试工具（配置管理 + 算法模拟）
- **前端路径**: `/guanzhi/admin-panel` (Vue 3 + Vite + Element Plus)
- **后端路径**: `/guanzhi/Server/onettoo` (Spring Boot，已完成)
- **访问方式**: 本地开发 http://localhost:5173，生产环境 https://onettoo.com/admin

### ⚠️ 常见误解（必须避免）

❌ **错误理解**: 需要修改后端添加新字段/新表
✅ **正确理解**: 后端已完成所有开发，V1任务是**基于现有后端API构建Web管理界面**

❌ **错误理解**: 需要实现用户系统、分享系统等核心功能
✅ **正确理解**: 核心业务功能已在后端实现，V1只做**配置管理 + 数据可视化**

❌ **错误理解**: 前端字段和后端不一致需要改后端
✅ **正确理解**: 前端必须适配后端现有字段，不改后端

---

## 📋 V1 功能范围（精确定义）

### 已完成的功能模块

1. **登录认证** ✅
   - JWT Token 认证（Bearer Token）
   - 测试账号：admin/123456（本地）
   - 测试 ADMIN Token 已提供

2. **褪色曲线模拟器** ✅
   - 输入：viewCount, tagCount, simulateDays
   - 输出：ECharts 折线图 + 褪色分数时间轴
   - 后端接口：`POST /api/admin/fade/simulate`

3. **4个配置管理页面** ✅
   - 褪色规则配置（fade_config）
   - 积分规则配置（points_rule）
   - 等级定义管理（level_definition）
   - 标签定义管理（tag_definition）

### V1 不做的功能（留给V2+）
- ❌ 用户管理（冻结/解冻用户）
- ❌ 分享内容审核
- ❌ 举报处理流程
- ❌ 统计看板与数据导出

---

## 🔧 后端API模型（必须遵守）

### 当前后端表结构

```java
// TagDefinitionDO - 标签定义
{
  Long id;
  String tagCode;        // ⚠️ 前端用的是 tagKey，需要映射
  String tagName;
  String minLevelCode;
  Boolean isActive;
  Integer sortOrder;
  // ❌ 没有 tagType 字段（GPT误以为有）
  // ❌ 没有 description 字段（GPT误以为有）
}

// PointsRuleDO - 积分规则
{
  Long id;
  String actionType;
  Integer pointsValue;
  Integer dailyLimit;
  // ❌ 没有 description 字段
}

// LevelDefinitionDO - 等级定义
{
  Long id;
  String levelCode;
  String levelName;
  Long minPoints;
  Integer minCheckins;
  Integer minComments;
  Integer taggingAllowance;
  String extraConditions;
  // ❌ 没有 maxPoints 字段（GPT误以为有）
  // ❌ 没有 description 字段（GPT误以为有）
}

// FadeConfigDO - 褪色规则
{
  Long id;
  String configKey;
  String configValue;
  String description;  // ✅ 这个有
}
```

### 关键API接口

**褪色模拟**:
```
POST /api/admin/fade/simulate
Authorization: Bearer {token}
{
  "viewCount": 50,
  "tagCount": 2,
  "simulateDays": 90
}
```

**配置管理**（4套CRUD）:
```
GET    /api/admin/config/fade-configs
POST   /api/admin/config/fade-config
DELETE /api/admin/config/fade-config/{id}

GET    /api/admin/config/points-rules
POST   /api/admin/config/points-rule
DELETE /api/admin/config/points-rule/{id}

GET    /api/admin/config/levels
POST   /api/admin/config/level
DELETE /api/admin/config/level/{id}

GET    /api/admin/config/tags
POST   /api/admin/config/tag
DELETE /api/admin/config/tag/{id}
```

---

## 📂 项目结构

```
/guanzhi/
├── admin-panel/              # 前端项目（Vue 3）✅ 已完成基础开发
│   ├── src/
│   │   ├── views/
│   │   │   ├── login/index.vue
│   │   │   ├── fade-simulator/index.vue
│   │   │   └── configs/
│   │   │       ├── FadeConfig.vue
│   │   │       ├── PointsConfig.vue
│   │   │       ├── LevelsConfig.vue
│   │   │       └── TagsConfig.vue
│   │   ├── api/
│   │   │   ├── request.ts    # Axios 封装
│   │   │   └── admin.ts      # API 定义
│   │   ├── router/index.ts
│   │   └── utils/auth.ts
│   ├── .env.development      # API_BASE_URL=http://localhost:8085/api
│   └── package.json
│
├── Server/
│   ├── onettoo/              # 后端项目（Spring Boot）✅ 已完成
│   │   ├── src/main/java/.../
│   │   │   ├── rest/AdminController.java
│   │   │   ├── model/
│   │   │   │   ├── TagDefinitionDO.java
│   │   │   │   ├── FadeConfigDO.java
│   │   │   │   ├── PointsRuleDO.java
│   │   │   │   └── LevelDefinitionDO.java
│   │   │   └── service/
│   │   │       ├── TagDefinitionService.java
│   │   │       ├── FadeConfigService.java
│   │   │       └── ...
│   │   └── src/main/resources/application.yml
│   │
│   ├── BACKEND_API_MODELS.md         # ✅ 我创建的API文档
│   └── CONTEXT_FOR_NEXT_SESSION.md   # 本文件
│
├── 重要项目信息/            # 历史文档（待归档）
│   ├── 后台管理工具 V1 实施计划（精简版）.md
│   ├── V1项目进度总结.md
│   └── ...
│
└── 后端升级设计文档/        # 历史文档（待归档）
    ├── docs/
    │   └── delivery-share-user-upgrade-v1.md
    └── sql/
        └── migration-*.sql
```

---

## 🎯 当前任务状态（2025-12-02）

### 已完成
1. ✅ 后端编译通过（BUILD SUCCESS）
2. ✅ 后端服务运行（localhost:8085）
3. ✅ 前端项目搭建（Vue 3 + Vite）
4. ✅ 登录功能（JWT认证）
5. ✅ 褪色模拟器（ECharts图表）
6. ✅ 4个配置管理页面（CRUD）
7. ✅ 登录问题修复（自动去除Bearer前缀）

### 当前问题（待确认）
1. ⚠️ 前端字段与后端不一致：
   - TagsConfig: `tagKey` vs `tagCode`
   - TagsConfig: 前端有 `tagType`, 后端没有
   - PointsConfig: 前端有 `description`, 后端没有
   - LevelsConfig: 前端有 `maxPoints`, 后端没有

2. ⚠️ GPT建议的Phase 2-5可能不适用：
   - Phase 2（标签键补全）：后端已有tagCode，只需前端映射
   - Phase 3（配置对齐）：前端需移除后端不存在的字段
   - Phase 4（线上数据导出）：暂无线上环境
   - Phase 5（联调测试）：可以执行

### 下一步行动（优先级排序）
1. 🔥 **验证当前功能可用性**
   - 测试4个配置页面的CRUD是否正常
   - 测试褪色模拟器是否正常
   - 查看Network请求是否有400/500错误

2. 🔥 **前后端字段对齐**
   - 修改前端TypeScript接口定义，匹配后端模型
   - 移除后端不存在的字段（tagType, description, maxPoints等）
   - 或者只在前端UI显示时使用，不发送给后端

3. 📝 **文档整理归档**
   - 将"重要项目信息"归档到Server/文档归档/
   - 将"后端升级设计文档"归档到Server/文档归档/
   - 创建Server/README.md 作为总索引

4. 📊 **生成交付文档**
   - 更新V1项目进度总结
   - 创建前后端联调测试报告
   - 列出已知问题和待办事项

---

## 🔑 测试凭证

**本地测试 ADMIN Token**:
```
eyJhbGciOiJIUzUxMiJ9.eyJqdGkiOiI1ZTYwYzJlMjBlZTc0ZjMzOTk5MmRmZDFiNTVkNWUyNyIsImF1dGgiOiJST0xFX0FETUlOIiwidXNlciI6MiwibmFtZSI6IjEzODEwMjY5NjI3Iiwibmlja25hbWUiOiJUZXN0QWRtaW4iLCJwaG9uZSI6IjEzODEwMjY5NjI3Iiwic3ViIjoiMiJ9.cfIGo-00EKb1YqYjcYiauLZ1oPozNxzDM4KsFXXvRPJ1IModMl1kYqotBj7A0Dct7r6GmpMOEd8ngrRQSmyIrw
```

**登录页提示文本**:
```
请输入 Admin Token

测试 Token (ROLE_ADMIN):
eyJhbGciOiJIUzUxMiJ9...
```

---

## 📚 关键文档路径

**必读**:
1. `/Server/CONTEXT_FOR_NEXT_SESSION.md`（本文件）
2. `/Server/BACKEND_API_MODELS.md`（后端API完整说明）
3. `/重要项目信息/后台管理工具 V1 实施计划（精简版）.md`

**参考**:
1. `/重要项目信息/V1项目进度总结.md`
2. `/后端升级设计文档/docs/delivery-share-user-upgrade-v1.md`
3. `/重要项目信息/后端完整验证报告.md`

---

## ⚠️ 对话压缩后的第一句话

**请Claude Code在新对话开始时说**:

"我已阅读 `/Server/CONTEXT_FOR_NEXT_SESSION.md`，理解当前项目状态：
- 后端已完成，不需要修改
- 当前是管理后台V1前端项目
- 登录功能已正常工作
- 需要完成前后端字段对齐和功能测试

请问现在需要我继续哪个任务？"

---

**文档版本**: v1.0
**最后更新**: 2025-12-02
**更新人**: Claude Code
**Token剩余**: 9%（对话即将压缩）
