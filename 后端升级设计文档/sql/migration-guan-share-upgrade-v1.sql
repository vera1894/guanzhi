-- 观之: 分享 & 用户系统升级 V1 - DB 迁移脚本
-- 执行时间: 在部署新版后端代码之前

-- ----------------------------
-- 1. 修改 `guanzhi` 表 (分享表)
-- ----------------------------
ALTER TABLE `guanzhi`
ADD COLUMN `view_user_count` INT(11) NOT NULL DEFAULT 0 COMMENT '历史去重查看人数',
ADD COLUMN `agree_count` INT(11) NOT NULL DEFAULT 0 COMMENT '赞同数',
ADD COLUMN `neutral_count` INT(11) NOT NULL DEFAULT 0 COMMENT '无感数',
ADD COLUMN `checkin_count` INT(11) NOT NULL DEFAULT 0 COMMENT '打卡人数',
ADD COLUMN `comment_count` INT(11) NOT NULL DEFAULT 0 COMMENT '评论人数',
ADD COLUMN `fade_score` INT(11) NOT NULL DEFAULT 0 COMMENT '褪色度 (0-100)',
ADD COLUMN `status` TINYINT(4) NOT NULL DEFAULT 0 COMMENT '分享状态 (0: NORMAL, 1: FADED, 2: HIDDEN, 3: ILLEGAL)',
ADD COLUMN `official_mark` TINYINT(4) NOT NULL DEFAULT 0 COMMENT '官方标记 (0: None, 1: Good, 2: Bad)';

-- ----------------------------
-- 2. 修改 `userlist` 表 (用户表)
-- ----------------------------
ALTER TABLE `userlist`
ADD COLUMN `points_total` BIGINT(20) NOT NULL DEFAULT 0 COMMENT '累计总积分',
ADD COLUMN `level_code` VARCHAR(50) NOT NULL DEFAULT 'YOMIN' COMMENT '等级代码 (e.g., YOMIN, CHONGLANG)',
ADD COLUMN `status` TINYINT(4) NOT NULL DEFAULT 0 COMMENT '用户状态 (0: NORMAL, 1: WARNED, 2: FROZEN)',
ADD COLUMN `warned_until` DATETIME DEFAULT NULL COMMENT '警告状态截止时间';

-- ----------------------------
-- 3. 创建 `share_vote` 表 (分享投票表)
-- ----------------------------
CREATE TABLE `share_vote` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `share_id` BIGINT(20) NOT NULL COMMENT '分享ID',
  `user_id` BIGINT(20) NOT NULL COMMENT '用户ID',
  `vote_type` TINYINT(4) NOT NULL COMMENT '投票类型 (1: 赞同, 0: 无感)',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_share_user` (`share_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='分享投票表';

-- ----------------------------
-- 4. 创建 `share_checkin` 表 (分享打卡表)
-- ----------------------------
CREATE TABLE `share_checkin` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `share_id` BIGINT(20) NOT NULL COMMENT '分享ID',
  `user_id` BIGINT(20) NOT NULL COMMENT '用户ID',
  `latitude` DECIMAL(10, 8) NOT NULL COMMENT '纬度',
  `longitude` DECIMAL(11, 8) NOT NULL COMMENT '经度',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_share_user` (`share_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='分享打卡表';

-- ----------------------------
-- 5. 创建 `share_comment` 表 (分享评论表)
-- ----------------------------
CREATE TABLE `share_comment` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `share_id` BIGINT(20) NOT NULL COMMENT '分享ID',
  `user_id` BIGINT(20) NOT NULL COMMENT '用户ID',
  `parent_id` BIGINT(20) NOT NULL DEFAULT 0 COMMENT '父评论ID (为二级评论预留)',
  `content` TEXT NOT NULL COMMENT '评论内容',
  `latitude` DECIMAL(10, 8) DEFAULT NULL COMMENT '评论时纬度',
  `longitude` DECIMAL(11, 8) DEFAULT NULL COMMENT '评论时经度',
  `status` TINYINT(4) NOT NULL DEFAULT 0 COMMENT '评论状态 (0: NORMAL, 1: HIDDEN)',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_share_id` (`share_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='分享评论表';

-- ----------------------------
-- 6. 创建 `share_tag_user` 表 (分享标签关系表)
-- ----------------------------
CREATE TABLE `share_tag_user` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `share_id` BIGINT(20) NOT NULL COMMENT '分享ID',
  `user_id` BIGINT(20) NOT NULL COMMENT '贴标签的用户ID',
  `tag_code` VARCHAR(50) NOT NULL COMMENT '标签代码 (e.g., MIJING)',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_share_user_tag` (`share_id`, `user_id`, `tag_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='分享标签关系表';

-- ----------------------------
-- 7. 创建 `user_points_log` 表 (用户积分记录表)
-- ----------------------------
CREATE TABLE `user_points_log` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT(20) NOT NULL COMMENT '用户ID',
  `points` INT(11) NOT NULL COMMENT '获得的积分（可正可负）',
  `reason_type` VARCHAR(50) NOT NULL COMMENT '积分原因 (e.g., POST_SHARE, VOTE)',
  `related_id` BIGINT(20) DEFAULT NULL COMMENT '相关ID (例如 share_id)',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_reason` (`user_id`, `reason_type`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户积分记录表';

-- ----------------------------
-- 8. 创建 `user_medal` 表 (用户奖章表)
-- ----------------------------
CREATE TABLE `user_medal` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT(20) NOT NULL COMMENT '用户ID',
  `medal_code` VARCHAR(50) NOT NULL COMMENT '奖章代码',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_medal` (`user_id`, `medal_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户奖章表';

-- ----------------------------
-- 迁移完成
-- ----------------------------
