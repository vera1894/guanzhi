-- 观之: 分享 & 用户系统升级 V4 - 增强与配置化
-- 执行时间: 在部署新版后端代码之前

-- ----------------------------
-- 1. 创建 `tag_definition` 表 (标签定义表)
-- ----------------------------
CREATE TABLE `tag_definition` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `tag_code` VARCHAR(50) NOT NULL COMMENT '标签代码, e.g., MIJING',
  `tag_name` VARCHAR(100) NOT NULL COMMENT '标签名称, e.g., 秘境',
  `min_level_code` VARCHAR(50) NOT NULL DEFAULT 'LANDONG' COMMENT '使用该标签所需的最低等级代码',
  `is_active` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否启用 (1:是, 0:否)',
  `sort_order` INT(11) NOT NULL DEFAULT 0 COMMENT '排序值',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tag_code` (`tag_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='标签定义表';

-- ----------------------------
-- 2. 创建 `share_report` 表 (分享举报记录表)
-- ----------------------------
CREATE TABLE `share_report` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `share_id` BIGINT(20) NOT NULL COMMENT '被举报的分享ID',
  `reporter_user_id` BIGINT(20) NOT NULL COMMENT '举报人ID',
  `reason` VARCHAR(255) DEFAULT NULL COMMENT '举报原因',
  `status` TINYINT(4) NOT NULL DEFAULT 0 COMMENT '处理状态 (0:待处理, 1:已处理-有效, 2:已处理-无效)',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_share_id` (`share_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='分享举报记录表';

-- ----------------------------
-- 3. 创建 `fade_config` 表 (褪色规则配置表)
-- ----------------------------
CREATE TABLE `fade_config` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `config_key` VARCHAR(100) NOT NULL COMMENT '配置键',
  `config_value` VARCHAR(255) NOT NULL COMMENT '配置值',
  `description` VARCHAR(255) DEFAULT NULL COMMENT '描述',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_config_key` (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='褪色规则配置表';

-- ----------------------------
-- 4. 为 `level_definition` 表添加 `extra_conditions` 字段
-- ----------------------------
ALTER TABLE `level_definition`
ADD COLUMN `extra_conditions` JSON DEFAULT NULL COMMENT '升级所需的额外JSON格式条件';

-- ----------------------------
-- 5. 插入初始配置数据
-- ----------------------------
-- 标签定义
INSERT INTO `tag_definition` (`tag_code`, `tag_name`, `min_level_code`) VALUES
('MIJING', '秘境', 'SHUIMU'),
('ZHENXIU', '珍馐', 'LANDONG'),
('WANQU', '玩趣', 'LANDONG'),
('CAIKENG', '踩坑预警', 'LANDONG'),
('MAOMAO', '猫猫出没', 'LANDONG'),
('CHAOSHENG', '朝圣', 'SHUIMU'),
('RICHU', '日出', 'LANDONG'),
('JISHI', '集市', 'LANDONG');

-- 褪色规则配置
INSERT INTO `fade_config` (`config_key`, `config_value`, `description`) VALUES
('VIEW_COUNT_FADE_TIER_1', '5:2', '浏览人数小于等于5人时，每日基础褪色值+2'),
('VIEW_COUNT_FADE_TIER_2', '20:4', '浏览人数小于等于20人时，每日基础褪色值+4'),
('VIEW_COUNT_FADE_TIER_3', '50:6', '浏览人数小于等于50人时，每日基础褪色值+6'),
('VIEW_COUNT_FADE_TIER_4', '100:8', '浏览人数小于等于100人时，每日基础褪色值+8'),
('VIEW_COUNT_FADE_TIER_MAX', '10', '浏览人数超过100人时，每日基础褪色值+10'),
('TAG_USER_BONUS', '-0.5', '每个有权限用户贴标签，每日褪色减速值'),
('AGREE_BONUS', '-2', '每次赞同，褪色度-2'),
('NEUTRAL_PENALTY', '2', '每次无感，褪色度+2'),
('CHECKIN_BONUS', '-5', '每次打卡，褪色度-5'),
('COMMENT_BONUS', '-5', '每次评论，褪色度-5');

-- 为“水母”等级增加复合条件
UPDATE `level_definition`
SET `extra_conditions` = '{"checkin_tag_min": {"tag_code": "MAOMAO", "count": 100}}'
WHERE `level_code` = 'SHUIMU';
