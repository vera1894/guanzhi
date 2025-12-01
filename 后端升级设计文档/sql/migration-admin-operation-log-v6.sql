-- 观之: 管理后台操作日志表 V6
-- 执行时间: 在部署管理后台工具之前
-- 用途: 记录所有管理后台的配置修改操作，支持审计追踪和手动回滚

-- ----------------------------
-- 创建 `admin_operation_log` 表 (管理后台操作日志表)
-- ----------------------------
CREATE TABLE `admin_operation_log` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` BIGINT(20) NOT NULL COMMENT '操作人用户ID',
  `username` VARCHAR(64) NOT NULL COMMENT '操作人用户名',
  `module` VARCHAR(32) NOT NULL COMMENT '模块名称（points_rules/levels/tags/fade_config/shares/users/reports）',
  `action` VARCHAR(16) NOT NULL COMMENT '操作类型（create/update/delete）',
  `record_id` BIGINT(20) DEFAULT NULL COMMENT '被操作记录的ID（如果是批量操作则为NULL）',
  `before_value` JSON DEFAULT NULL COMMENT '修改前的值（JSON格式，用于回滚）',
  `after_value` JSON DEFAULT NULL COMMENT '修改后的值（JSON格式）',
  `ip_address` VARCHAR(64) DEFAULT NULL COMMENT '操作人IP地址',
  `user_agent` VARCHAR(255) DEFAULT NULL COMMENT '操作人浏览器信息',
  `remark` VARCHAR(255) DEFAULT NULL COMMENT '备注说明',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
  PRIMARY KEY (`id`),
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_module_action` (`module`, `action`),
  INDEX `idx_created_at` (`created_at`),
  INDEX `idx_record_id` (`record_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='管理后台操作日志表';

-- ----------------------------
-- 使用示例说明
-- ----------------------------
-- 1. 记录褪色配置修改:
-- INSERT INTO admin_operation_log
--   (user_id, username, module, action, record_id, before_value, after_value, ip_address)
-- VALUES
--   (2, 'admin', 'fade_config', 'update', 123,
--    '{"viewWeight": 0.3, "agreeWeight": 0.5}',
--    '{"viewWeight": 0.5, "agreeWeight": 0.6}',
--    '192.168.1.100');

-- 2. 查询某个模块的所有修改记录:
-- SELECT * FROM admin_operation_log
-- WHERE module = 'fade_config'
-- ORDER BY created_at DESC
-- LIMIT 50;

-- 3. 查询某个用户的所有操作:
-- SELECT * FROM admin_operation_log
-- WHERE user_id = 2
-- ORDER BY created_at DESC
-- LIMIT 50;

-- 4. 查看某条记录的修改历史:
-- SELECT * FROM admin_operation_log
-- WHERE module = 'points_rules' AND record_id = 5
-- ORDER BY created_at DESC;
