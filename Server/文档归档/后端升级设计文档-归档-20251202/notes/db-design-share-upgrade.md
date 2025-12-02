### 观之 · 分享 & 用户系统升级 · 数据库设计

本文档定义了为支持分享互动、用户积分等级系统所需的新增及修改的数据库表结构。
由于项目未使用自动迁移工具，这些变更将通过手动执行 SQL 脚本来应用。

---

### 1. 表结构变更概览

#### 1.1 `guanzhi` (分享表)
向现有 `guanzhi` 表中添加字段，用于存储核心统计数据和状态。这比创建新表的 JOIN 开销更小。

- **`ALTER TABLE guanzhi`**
  - `view_user_count INT DEFAULT 0` - 历史去重查看人数
  - `agree_count INT DEFAULT 0` - 赞同数
  - `neutral_count INT DEFAULT 0` - 无感数
  - `checkin_count INT DEFAULT 0` - 打卡人数
  - `comment_count INT DEFAULT 0` - 评论人数
  - `fade_score INT DEFAULT 0` - 褪色度 (0-100)
  - `status TINYINT DEFAULT 0` - 分享状态 (0: NORMAL, 1: FADED, 2: HIDDEN, 3: ILLEGAL)
  - `official_mark TINYINT DEFAULT 0` - 官方标记 (0: None, 1: Good, 2: Bad)

#### 1.2 `user` (用户表)
向现有 `user` 表中添加字段，用于支持用户等级、积分和状态。

- **`ALTER TABLE user`**
  - `points_total BIGINT DEFAULT 0` - 累计总积分
  - `level_code VARCHAR(50) DEFAULT 'YOMIN'` - 等级代码
  - `status TINYINT DEFAULT 0` - 用户状态 (0: NORMAL, 1: WARNED, 2: FROZEN)
  - `warned_until DATETIME` - 警告状态截止时间

#### 1.3 `share_vote` (分享投票表)
新表，记录用户对分享的“赞同”或“无感”操作。

- **`CREATE TABLE share_vote`**
  - `id BIGINT PRIMARY KEY AUTO_INCREMENT`
  - `share_id BIGINT`
  - `user_id BIGINT`
  - `vote_type TINYINT` - 投票类型 (1: 赞同, 0: 无感)
  - `created_at DATETIME`
  - `updated_at DATETIME`
  - `UNIQUE KEY uk_share_user (share_id, user_id)`

#### 1.4 `share_checkin` (分享打卡表)
新表，记录用户的打卡行为。

- **`CREATE TABLE share_checkin`**
  - `id BIGINT PRIMARY KEY AUTO_INCREMENT`
  - `share_id BIGINT`
  - `user_id BIGINT`
  - `latitude DECIMAL(10, 8)`
  - `longitude DECIMAL(11, 8)`
  - `created_at DATETIME`
  - `UNIQUE KEY uk_share_user (share_id, user_id)`

#### 1.5 `share_comment` (分享评论表)
新表，记录用户评论。

- **`CREATE TABLE share_comment`**
  - `id BIGINT PRIMARY KEY AUTO_INCREMENT`
  - `share_id BIGINT`
  - `user_id BIGINT`
  - `parent_id BIGINT DEFAULT 0` - 父评论ID (为二级评论预留)
  - `content TEXT`
  - `latitude DECIMAL(10, 8)`
  - `longitude DECIMAL(11, 8)`
  - `status TINYINT DEFAULT 0` - 评论状态 (0: NORMAL, 1: HIDDEN)
  - `created_at DATETIME`

#### 1.6 `share_tag_user` (分享标签关系表)
新表，记录有权限的用户为分享贴标签的行为。

- **`CREATE TABLE share_tag_user`**
  - `id BIGINT PRIMARY KEY AUTO_INCREMENT`
  - `share_id BIGINT`
  - `user_id BIGINT`
  - `tag_code VARCHAR(50)` - 标签代码 (e.g., 'MIJING')
  - `created_at DATETIME`
  - `UNIQUE KEY uk_share_user_tag (share_id, user_id, tag_code)`

#### 1.7 `user_points_log` (用户积分记录表)
新表，用于审计用户的积分增减。

- **`CREATE TABLE user_points_log`**
  - `id BIGINT PRIMARY KEY AUTO_INCREMENT`
  - `user_id BIGINT`
  - `points INT` - 获得的积分（可正可负）
  - `reason_type VARCHAR(50)` - 积分原因 (e.g., 'POST_SHARE', 'VOTE')
  - `related_id BIGINT` - 相关ID (例如 share_id)
  - `created_at DATETIME`
  - `KEY idx_user_reason (user_id, reason_type, created_at)`

#### 1.8 `user_medal` (用户奖章表)
新表，记录用户获得的奖章。

- **`CREATE TABLE user_medal`**
  - `id BIGINT PRIMARY KEY AUTO_INCREMENT`
  - `user_id BIGINT`
  - `medal_code VARCHAR(50)` - 奖章代码
  - `created_at DATETIME`
  - `UNIQUE KEY uk_user_medal (user_id, medal_code)`

---

### 2. Redis 键设计 (用于去重和计数)

- **分享去重查看**: `Set` -> `share:view:{shareId}` - 存储查看过的 `userId`
- **用户行为每日上限**: `String` -> `user:action:{userId}:{yyyyMMdd}:{actionType}` - 使用 `INCR` 和 `EXPIRE` 限制每日次数

---
### 3. 查看记录统计方案

采用 **方案 B：使用 Redis Set**。
- **原因**: 性能高，避免对DB进行高频写操作。`view_user_count` 可以在需要时通过 `SCARD` 计算，或通过定时任务定期从 Redis 回写到 `guanzhi` 表中，这在“褪色度”计算中尤为重要。
