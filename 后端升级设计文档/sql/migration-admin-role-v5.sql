-- 观之: 分享 & 用户系统升级 V5 - 管理员权限修复
-- 执行时间: 在部署新版后端代码之前

-- ----------------------------
-- 1. 为 `userlist` 表添加 `role` 字段
-- ----------------------------
ALTER TABLE `userlist`
ADD COLUMN `role` VARCHAR(50) NOT NULL DEFAULT 'USER' COMMENT '用户角色, e.g., USER, ADMIN';

-- ----------------------------
-- 2. 为测试用户分配管理员角色 (请根据实际用户情况修改)
-- ----------------------------
-- 假设手机号为 13810269627 的用户是管理员
UPDATE `userlist`
SET `role` = 'ADMIN'
WHERE `phone` = '13810269627';
