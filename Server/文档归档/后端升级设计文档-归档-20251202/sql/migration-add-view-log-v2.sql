-- 观之: 分享 & 用户系统升级 V2 - DB 迁移脚本 (补充)
-- 执行时间: 在部署新版后端代码之前

-- ----------------------------
-- 1. 创建 `share_view_log` 表 (分享查看记录表)
-- ----------------------------
CREATE TABLE `share_view_log` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `share_id` BIGINT(20) NOT NULL COMMENT '分享ID',
  `user_id` BIGINT(20) NOT NULL COMMENT '用户ID',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_share_user` (`share_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='分享查看记录表';
