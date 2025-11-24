# 交付说明文档：观之分享 & 用户系统升级 v1

## 1. 功能概述

本次升级为“观之”项目后端实现了一套完整的分享互动与用户成长体系。

### 分享侧功能
- **查看**: 记录用户对分享的唯一性查看，用于统计和奖励。
- **赞同/无感**: 用户可对分享进行“赞同”或“无感”投票，此行为影响分享的“褪色度”。
- **评论**: 用户可在分享地理位置200米范围内进行评论。
- **打卡**: 用户可在分享地理位置200米范围内进行打卡。
- **标签**: 特定等级的用户（蓝洞、水母）可为分享贴上预设标签。
- **违法处理**: 管理员可将分享标记为违法，使其在公共区域不可见，并扣除作者积分。
- **褪色度 (Fade Score)**:
  - 一个综合评分，用于衡量分享的质量和新鲜度。
  - 受**赞同/无感**、**打卡**、**评论**（事件驱动，即时增减）和**查看人数/标签**（定时任务，每日调整）共同影响。
  - 分数达到100时，分享将“褪色”，在公共地图隐藏。
  - 管理员可设置“好标记”（冻结为0）或“坏标记”（冻结为100）。

### 用户侧功能
- **积分**: 用户通过在应用内的积极行为（如发分享、评论、打卡、贴标签等）获得积分。积分有每日上限，用于防止刷分。
- **等级**: 根据用户的累计积分和行为次数（打卡、评论）自动提升。更高等级解锁更多权限（如贴标签）。
- **奖章**: 用户达成特定隐藏条件（如累计查看分享数、打卡特定标签数）后自动获得，作为荣誉象征。
- **用户状态**:
  - **正常**: 默认状态。
  - **警告**: 管理员设置，持续15天，期间功能正常但有UI提示。登录时自动检测并解除过期警告。
  - **冻结**: 管理员设置，账号只读，无法进行任何写操作（发帖、评论、投票等），通过AOP切面实现。

### 新增：后台可配置性

- **动态规则**: 积分获取规则、每日上限、用户等级门槛、奖章名称、标签权限、褪色参数等核心业务数值，均已从代码中解耦，存入数据库中。

- **管理接口**: `AdminController` 中提供了一套完整的RESTful API，用于对上述规则进行增、删、改、查，方便未来通过后台网页进行可视化管理。



### 新增：举报功能

- **用户侧**: 用户可通过API举报不当分享。

- **管理侧**: 管理员可通过API查看和处理举报，并将被确认的违规分享设为不可见。



---



## 2. 技术实现概要



### 新增/修改的 DB 表与字段

- **数据库迁移脚本**:

  - `sql/migration-guan-share-upgrade-v1.sql`

  - `sql/migration-add-view-log-v2.sql`

  - `sql/migration-config-tables-v3.sql`

  - `sql/migration-enhancements-v4.sql` (新增)

- **主要变更**:

  - `guanzhi` 表: 增加了统计、状态和标记字段。

  - `userlist` 表: 增加了积分、等级、状态字段。

  - `level_definition` 表: (已增强) 增加了 `extra_conditions` JSON字段以支持复合升级条件。

  - **新增了以下表**:

    - `share_vote`, `share_checkin`, `share_comment`, `share_tag_user`, `user_points_log`, `user_medal`, `share_view_log`

    - `level_definition`, `points_rule`, `medal_definition` (配置表)

    - `tag_definition` (标签定义与权限配置)

    - `share_report` (举报记录)

    - `fade_config` (褪色参数配置)



### 核心 Service / Controller 类

- **核心服务**:

  - `GuanzhiServiceImpl`: (已重构) 实现了分享的核心业务逻辑，贴标签的权限判断已移至 `TagDefinitionService`。事件型褪色度调整已改为从 `FadeConfigService` 读取配置。

  - `UserPointsServiceImpl`: (已重构) 积分增减和每日上限由 `points_rule` 表动态配置。

  - `UserLevelServiceImpl`: (已重构) 等级计算逻辑完全由 `level_definition` 表驱动，并支持解析JSON格式的复合条件。

  - `TagDefinitionService`: (新增) 实现了基于用户等级和标签定义的高级权限校验逻辑。

  - `ShareReportService`: (新增) 用于处理举报的创建和管理。

  - `FadeConfigService`: (新增) 用于缓存和提供褪色计算的所有相关参数。

  - `DistanceService`: (已重构) 封装了 `isWithinRange` 方法，使距离校验逻辑更清晰。

- **核心控制器**:

  - `GuanZhiController`: (已重构) 贴标签和距离校验的逻辑更简洁。新增了 `/share/report` 接口。

  - `AdminController`: (已扩展) 新增了管理 `tag_definition` 和 `share_report` 的接口。

- **工具类**:

  - `SecurityUtils`, `RedisUtils`



### fadeScore 计算逻辑说明

- **事件驱动**: `GuanzhiServiceImpl` 中的 `vote`, `checkin`, `addComment` 方法的褪色调整值，现在从 `fade_config` 表中动态获取。

- **定时任务**: `FadeScoreTask` (已重构)，其计算公式中的所有“魔法数字”（如分档阈值、增量、标签减速值）均从 `fade_config` 表中动态获取。



---



## 3. 部署与迁移步骤



1.  **执行 DB 迁移脚本**:

    - 在部署新版代码**之前**，请务必按顺序执行以下SQL脚本：

      1. `sql/migration-guan-share-upgrade-v1.sql`

      2. `sql/migration-add-view-log-v2.sql`

      3. `sql/migration-config-tables-v3.sql`

      4. `sql/migration-enhancements-v4.sql` (此脚本包含新的初始配置数据)

2.  **配置定时任务**:

    - `FadeScoreTask.java` 中的定时任务cron表达式当前为 `0 */5 * * * ?` (每5分钟)，便于测试。

    - **生产环境**建议修改为每天凌晨执行，例如 `0 0 3 * * ?`。

3.  **Redis Key**:

    - 项目引入了新的Redis Key前缀，用于功能隔离：

      - `share:view:{shareId}`: (Set) 记录单篇分享的查看用户。

      - `user:points:day:{userId}:{yyyyMMdd}:{actionType}`: (String) 记录用户每日行为次数，用于积分上限控制。

4.  **启用定时任务**:

    - 已通过 `SchedulingConfig.java` 全局开启 `@EnableScheduling`，无需额外配置。



---



## 4. 回滚方案



- **数据库**: 本次变更新增了表和字段，没有删除现有数据。如需回滚，旧版代码会忽略这些新表和新字段，不会直接导致启动失败。建议的恢复策略是**暂时不删除**这些新增的结构，待版本稳定后再行清理。

- **代码**: 直接回退到上一个Git版本即可。



---



## 5. 联调建议



- **前端获取分享详情**: 现在的 `guanzhi` (即 `Share`) 对象返回时会包含 `agreeCount`, `neutralCount`, `fadeScore`, `status` 等新字段，前端可直接使用这些字段来渲染UI（例如，根据 `fadeScore` 调整透明度，根据 `status` 判断是否显示为“已下架”）。

- **用户状态**:

  - 当写操作接口返回特定错误（如“账号已被冻结”）时，前端应引导用户到相应页面或给出提示。

  - 用户信息接口返回的 `UserDO` 包含 `status` 和 `levelCode`，前端可根据 `status=1` (警告) 来显示警告提示，根据 `levelCode` 显示用户等级。

- **奖章**:

  - 新增了 `GET /api/guan/user/medals?userId={...}` 和 `GET /api/guan/user/my-medals` 接口，用于展示用户的奖章墙。

- **距离校验**:

  - “打卡”和“评论”接口现在会进行服务器端距离校验，超出配置的距离上限会返回失败。建议前端在发起请求前也进行一次预校验，以优化用户体验。

- **后台管理**:

  - 新增的管理API位于 `AdminController`，可用于构建一个简单的web界面来动态调整系统参数，而无需重新部署后端服务。

- **举报功能**:

  - 用户端可通过 `POST /api/guan/share/report` 接口提交举报。

  - 管理端可通过 `GET /api/admin/reports` 查看举报列表，并通过 `POST /api/admin/report/process` 处理举报。



---

## 验证记录

**2025-11-24**: 管理员权限修复通过本地验证（Claude 测试）
- JWT Token 正确包含 `auth` claim（如 `ROLE_ADMIN`）
- Admin 配置 API 读写正常
- 普通用户被正确拒绝访问 Admin API
- 配置修改（如积分规则）运行时立即生效
- Git Tag: `share-user-upgrade-permissions-ok`
