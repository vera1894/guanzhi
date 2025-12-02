-- 观之: 分享 & 用户系统升级 V3 - 配置管理表
-- 执行时间: 在部署新版后端代码之前

-- ----------------------------
-- 1. 创建 `level_definition` 表 (等级定义表)
-- ----------------------------
CREATE TABLE `level_definition` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `level_code` VARCHAR(50) NOT NULL COMMENT '等级代码',
  `level_name` VARCHAR(100) NOT NULL COMMENT '等级名称',
  `min_points` BIGINT(20) NOT NULL DEFAULT 0 COMMENT '最低积分要求',
  `min_checkins` INT(11) NOT NULL DEFAULT 0 COMMENT '最低打卡次数要求',
  `min_comments` INT(11) NOT NULL DEFAULT 0 COMMENT '最低评论次数要求',
  `tagging_allowance` INT(11) NOT NULL DEFAULT 0 COMMENT '每日可贴标签数量',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_level_code` (`level_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='等级定义表';

-- ----------------------------
-- 2. 创建 `points_rule` 表 (积分规则表)
-- ----------------------------
CREATE TABLE `points_rule` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `action_type` VARCHAR(50) NOT NULL COMMENT '行为类型 (e.g., POST_SHARE, VOTE)',
  `points_value` INT(11) NOT NULL COMMENT '单次行为分值',
  `daily_limit` INT(11) NOT NULL COMMENT '每日上限次数',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_action_type` (`action_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='积分规则表';

-- ----------------------------
-- 3. 创建 `medal_definition` 表 (奖章定义表)
-- ----------------------------
CREATE TABLE `medal_definition` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `medal_code` VARCHAR(50) NOT NULL COMMENT '奖章代码',
  `medal_name` VARCHAR(100) NOT NULL COMMENT '奖章名称',
  `description` VARCHAR(255) DEFAULT NULL COMMENT '奖章描述',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_medal_code` (`medal_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='奖章定义表';

-- ----------------------------
-- 4. 插入初始数据
-- ----------------------------
-- 等级定义
INSERT INTO `level_definition` (`level_code`, `level_name`, `min_points`, `min_checkins`, `min_comments`, `tagging_allowance`) VALUES
('YOMIN', '游民', 0, 0, 0, 0),
('CHONGLANG', '冲浪', 100, 0, 0, 0),
('QIANSHUI', '潜水', 4000, 20, 10, 0),
('LANDONG', '蓝洞', 10000, 200, 100, 10),
('SHUIMU', '水母', 50000, 1000, 500, 20),
('DENGTA', '灯塔', 999999, 9999, 9999, 50);

-- 积分规则
INSERT INTO `points_rule` (`action_type`, `points_value`, `daily_limit`) VALUES
('POST_SHARE', 2, 10),
('VIEW_SHARE', 1, 10),
('VOTE', 1, 10),
('CHECKIN', 5, 25),
('COMMENT', 5, 25),
('TAG', 5, 25),
('TAGGED', 5, 25),
('ILLEGAL', -100, -1); -- -1 表示无上限

-- 奖章定义
INSERT INTO `medal_definition` (`medal_code`, `medal_name`, `description`) VALUES
('YOMIN_MEDAL', '游民奖章', '加入观之，成为社区游民，一个不错的开始。'),
('SURF_QUALIFIED', '具备冲浪资质', '人在屋中坐，世界天上来。'),
('SURF_EXPERT', '冲浪专家', '已阅，你甚至不需要出门。'),
('STREETS_WALKER', '街溜子', '城市就是你的后花园。'),
('CAT_OBSERVER', '猫猫观察员', '你发现了许多秘密的猫咪据点。');
