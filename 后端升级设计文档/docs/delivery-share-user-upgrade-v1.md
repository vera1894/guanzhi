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

---

## 2. 技术实现概要

### 新增/修改的 DB 表与字段
- **数据库迁移脚本**:
  - `sql/migration-guan-share-upgrade-v1.sql`
  - `sql/migration-add-view-log-v2.sql`
- **主要变更**:
  - `guanzhi` 表: 增加了 `view_user_count`, `agree_count`, `neutral_count`, `checkin_count`, `comment_count`, `fade_score`, `status`, `official_mark` 等字段。
  - `userlist` 表: 增加了 `points_total`, `level_code`, `status`, `warned_until` 字段。
  - **新增了以下表**:
    - `share_vote` (投票记录)
    - `share_checkin` (打卡记录)
    - `share_comment` (评论记录)
    - `share_tag_user` (标签记录)
    - `user_points_log` (积分流水)
    - `user_medal` (用户奖章)
    - `share_view_log` (分享查看记录，为奖章系统补充)

### 核心 Service / Controller 类
- **核心服务**:
  - `GuanzhiServiceImpl`: 实现了所有分享相关的核心业务逻辑（投票、打卡、评论等）。
  - `UserPointsServiceImpl`: 实现了积分的增减、每日上限控制（通过Redis）和记录。
  - `UserLevelServiceImpl`: 实现了用户等级的计算逻辑。
  - `UserMedalServiceImpl`: 实现了奖章的判断与授予逻辑。
  - `DistanceService`: 提供了统一的地理位置距离计算方法。
- **核心控制器**:
  - `GuanZhiController`: 新增了分享互动的相关API端点。
  - `AdminController`: 新增了用于管理用户状态和分享标记的API端点，需要管理员权限。
- **工具类**:
  - `SecurityUtils`: 用于从Spring Security上下文中安全地获取当前登录用户的ID。
  - `RedisUtils`: 扩展了 `incr` 方法，用于实现原子计数。

### fadeScore 计算逻辑说明
- **事件驱动**: 在 `GuanzhiServiceImpl` 的 `vote`, `checkin`, `addComment` 方法中，`fade_score` 会被即时调整。
- **定时任务**:
  - `FadeScoreTask`: 一个 `@Scheduled` 定时任务（当前为每5分钟用于测试，建议生产调整为每日 `cron = "0 0 3 * * ?"`）。
  - 任务会分页处理所有未被官方标记的分享，根据**查看人数**和**标签用户数**计算每日的自然褪色值，并更新 `fade_score` 和 `status`。

### 用户状态（冻结）实现
- **AOP切面**:
  - `@BlockFrozenUser` 注解：用于标记需要拦截的写操作方法。
  - `UserStatusAspect`: 切面类，拦截所有标记了 `@BlockFrozenUser` 的方法。在方法执行前，检查当前用户状态，若为“冻结”，则直接抛出异常，阻止操作。

---

## 3. 部署与迁移步骤

1.  **执行 DB 迁移脚本**:
    - 在部署新版代码**之前**，请务必按顺序执行以下SQL脚本：
      1. `sql/migration-guan-share-upgrade-v1.sql`
      2. `sql/migration-add-view-log-v2.sql`
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
  - “打卡”和“评论”接口现在会进行服务器端距离校验，超出200米会返回失败。建议前端在发起请求前也进行一次预校验，以优化用户体验。
