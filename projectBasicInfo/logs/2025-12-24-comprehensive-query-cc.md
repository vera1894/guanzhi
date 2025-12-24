# 综合查询功能实现

**日期**: 2025-12-24
**作者**: Claude Code
**类型**: 新功能

---

## 概述

创建综合查询功能，替换原有的 `UserDetail.vue` 和 `ShareDetail.vue` 页面，支持输入用户ID或分享ID查询所有关联数据明细（表格形式）。

---

## 实现内容

### 后端新增文件

1. **`ShareInspectorDetailDTO.java`**
   - 路径: `Server/onettoo/src/main/java/com/cloud/onettoo/modules/dto/`
   - 内容: 分享详情 DTO，包含基本信息统计 + 明细列表
   - 内部类:
     - `CommentItem` - 评论明细
     - `StickerActionItem` - 贴纸使用明细
     - `CheckinItem` - 打卡明细
     - `ViewLogItem` - 浏览记录
     - `ReportItem` - 举报记录

2. **`UserInspectorDetailDTO.java`**
   - 路径: `Server/onettoo/src/main/java/com/cloud/onettoo/modules/dto/`
   - 内容: 用户详情 DTO，包含基本信息统计 + 明细列表
   - 内部类:
     - `ShareBriefItem` - 发布的分享
     - `CommentItem` - 用户评论
     - `StickerActionItem` - 贴纸使用记录
     - `CheckinItem` - 打卡记录
     - `MedalItem` - 奖章列表

### 后端修改文件

1. **`InspectorService.java`** - 新增接口方法:
   ```java
   ShareInspectorDetailDTO getShareFullDetail(Long shareId);
   UserInspectorDetailDTO getUserFullDetail(Long userId);
   ```

2. **`InspectorServiceImpl.java`** - 实现明细查询逻辑:
   - 查询 `share_comment` 表获取评论明细
   - 查询 `share_sticker_action` 表获取贴纸使用明细
   - 查询 `share_checkin` 表获取打卡明细
   - 查询 `share_view_log` 表获取浏览记录
   - 查询 `share_report` 表获取举报记录
   - 查询 `guanzhi` 表获取用户发布的分享
   - 查询 `user_medal` 表获取奖章列表

3. **`AdminInspectorController.java`** - 新增 API 接口:
   ```java
   @GetMapping("/share/{shareId}/detail")
   public RestOut<ShareInspectorDetailDTO> getShareFullDetail(@PathVariable String shareId);

   @GetMapping("/user/{userId}/detail")
   public RestOut<UserInspectorDetailDTO> getUserFullDetail(@PathVariable String userId);
   ```

### 前端新增文件

1. **`ComprehensiveQuery.vue`**
   - 路径: `admin-web/src/views/inspector/`
   - 功能:
     - 查询类型选择（分享/用户）
     - ID 输入查询
     - `el-descriptions` 展示基本信息
     - `el-statistic` 展示统计数据
     - 多个 `el-table` 展示各类明细列表

### 前端修改文件

1. **`router/index.js`** - 新增路由:
   ```javascript
   {
     path: '/inspector/query',
     component: () => import('@/views/inspector/ComprehensiveQuery.vue')
   }
   ```

2. **`layout/Layout.vue`** - 新增侧边栏菜单项:
   ```html
   <el-menu-item index="/inspector/query">
     <el-icon><Search /></el-icon>
     <span>综合查询</span>
   </el-menu-item>
   ```

---

## 数据展示

### 分享查询返回

| 类型 | 展示方式 |
|------|---------|
| 基本信息 | el-descriptions |
| 统计数据 | el-statistic |
| 评论列表 | el-table (评论者ID、内容、时间) |
| 贴纸使用记录 | el-table (使用者ID、贴纸类型、时间) |
| 打卡记录 | el-table (打卡者ID、时间) |
| 浏览记录 | el-table (浏览者ID、时间) |
| 举报记录 | el-table (举报者ID、原因、时间) |

### 用户查询返回

| 类型 | 展示方式 |
|------|---------|
| 基本信息 | el-descriptions |
| 统计数据 | el-statistic |
| 发布的分享 | el-table (ID、内容、位置、时间、状态) |
| 评论列表 | el-table (内容、所属分享ID、时间) |
| 贴纸使用记录 | el-table (分享ID、贴纸类型、时间) |
| 打卡记录 | el-table (分享ID、时间) |
| 奖章列表 | el-tag |

---

## 技术要点

1. **类型转换**: `BaseDO.id` 是 `Integer` 类型，DTO 字段使用 `Long`，需用 `Long.valueOf()` 转换

2. **嵌套 DTO 模式**: 使用内部类定义明细项，保持代码组织清晰

3. **统一查询入口**: 一个页面支持两种查询类型，通过 radio 切换

---

## 部署

- 后端 JAR 部署到 `/root/onettoo/back/`
- 前端 dist 部署到 `/var/www/guanzhi-admin/`
- 通过 AWS SSM 执行远程部署命令
