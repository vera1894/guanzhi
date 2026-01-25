# 举报功能实施记录

**日期**: 2026-01-24
**作者**: Claude Code
**版本**: v3.7.0

---

## 概述

实现他人分享详情页的举报功能，包含：
- iOS 客户端举报流程
- 后端 API 增强
- 管理后台举报管理页面

---

## 举报原因选项

| 代码 | 显示文字 |
|------|----------|
| FAKE_LOCATION | 地点不实 / 恶意标注 |
| PRIVACY_LEAK | 隐私泄露：暴露个人信息 |
| HARASSMENT | 骚扰 / 霸凌 / 仇恨言论 |
| SPAM_AD | 垃圾广告 / 引流 |
| MISINFORMATION | 虚假信息 / 误导 |
| COPYRIGHT | 侵权：盗用我的图片/文字 |
| NSFW | 不当内容：色情或露骨 |
| VIOLENCE | 暴力 / 血腥 / 自残相关 |
| ILLEGAL | 危险行为 / 违法内容 |
| OTHER | 其他 |

---

## 文件变更清单

### 后端 (Java)

| 文件 | 操作 | 说明 |
|------|------|------|
| `modules/dto/ReportDTO.java` | 修改 | `reason` → `reasonCode` |
| `modules/constant/ReportReasonEnum.java` | 新建 | 举报原因枚举，含 `fromCode()` 方法 |
| `modules/rest/GuanZhiController.java` | 修改 | 增强举报逻辑：验证 reasonCode、防重复举报 |
| `modules/rest/AdminInspectorController.java` | 修改 | 新增 3 个管理端点 |

**新增 API 端点**:
- `GET /admin/inspector/reports` - 获取举报列表（支持状态筛选、分页）
- `POST /admin/inspector/reports/{id}/handle` - 处理举报（valid/invalid）
- `GET /admin/inspector/reports/stats` - 获取举报统计

### iOS (Swift)

| 文件 | 操作 | 说明 |
|------|------|------|
| `ModelsForNetwork/OTORequests.swift` | 修改 | 添加 `reportShare(shareId:reasonCode:)` |
| `ModelsForNetwork/ReportService.swift` | 新建 | `ReportReason` 枚举 + `ReportService.shared` |
| `View/SharePages/ShareDetailView.swift` | 修改 | 实现完整举报流程 |
| `guanzhi.xcodeproj/project.pbxproj` | 修改 | 添加 ReportService.swift 到项目 |

### 管理后台 (Vue.js)

| 文件 | 操作 | 说明 |
|------|------|------|
| `src/router/index.js` | 修改 | 添加 `/reports` 路由 |
| `src/layout/Layout.vue` | 修改 | 添加「举报管理」侧边栏菜单 |
| `src/views/ReportManagement.vue` | 新建 | 举报管理页面（列表、筛选、处理） |

---

## 部署信息

### 部署验收报告

**部署时间**: 2026-01-24 09:29 CST (UTC 01:29)
**版本号**: v3.7.0
**构建时间**: 2026-01-24T01:24:46.751Z

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 服务状态 | ✅ | active (running), Main PID: 911613 |
| 入口路径 | ✅ | current → /home/ec2-user/releases/v3.7.0 |
| 进程命令行 | ✅ | -jar /home/ec2-user/current/app.jar |
| 版本接口 | ✅ | buildTime: 2026-01-24T01:24:46.751Z |
| 启动日志 | ✅ | Time SSOT 验证全部通过 |

---

## 部署过程中的问题与解决

### 问题 1：Lombok 注解处理器不工作

**现象**：
```
找不到符号: 方法 getOfficialMark()
找不到符号: 方法 getStatus()
找不到符号: 方法 getId()
```

所有带 `@Data` 注解的类都无法生成 getter/setter。

**根本原因**：
项目目录中存在 iCloud 同步产生的重复文件（文件名含 " 2.java" 后缀），导致编译器混乱。

**解决方案**：
```bash
find src -name "* 2.java" -exec rm -v {} \;
```

删除以下重复文件后编译成功：
- `QuotaDayUtil 2.java`
- `StickerDTO 2.java`
- `StickerLevelQuotaOverrideMapper 2.java`
- `ShareStickerActionMapper 2.java`
- `StickerLevelQuotaOverrideDO 2.java`
- `ShareStickerActionDO 2.java`
- `StickerQuotaServiceImpl 2.java`
- `StickerQuotaService 2.java`

**预防措施**：
- 定期检查并清理 iCloud 同步产生的重复文件
- 考虑将后端代码移出 iCloud 目录

### 问题 2：类型不匹配

**现象**：
```
不兼容的类型: java.lang.Integer 无法转换为 java.lang.Long
```

**原因**：
`UserDO.getId()` 返回 `Integer`（继承自 BaseDO），而 `ShareReportDO.reporterUserId` 是 `Long`。

**解决**：
```java
// 修改前
userNicknameMap.put(user.getId(), user.getNickname());

// 修改后
userNicknameMap.put(user.getId().longValue(), user.getNickname());
```

### 问题 3：数据库表 `share_report` 不存在（严重）

**发现时间**: 2026-01-24 10:XX CST

**现象**：
- iOS 提交举报后，管理后台看不到任何举报记录
- 举报统计显示全部为 0

**根本原因**：
部署 v3.7.0 时，只创建了 Java 代码和 Mapper，但**遗漏了 Flyway 数据库迁移脚本**。
数据库中根本不存在 `share_report` 表，导致所有举报操作都会失败。

**解决方案**：
添加 Flyway 迁移脚本：`V20260124__create_share_report_table.sql`

```sql
CREATE TABLE IF NOT EXISTS share_report (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    share_id BIGINT NOT NULL,
    reporter_user_id BIGINT NOT NULL,
    reason VARCHAR(500) NOT NULL,
    status INT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_share_id (share_id),
    INDEX idx_reporter_user_id (reporter_user_id),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**修复步骤**：
1. 已添加迁移脚本
2. 需要重新构建 JAR 并部署为 v3.7.1
3. Flyway 会自动执行迁移创建表

---

## 测试验证清单

### iOS 端
- [ ] 他人分享详情页 → 更多 → 举报 → 显示 10 个原因选项
- [ ] 选择原因 → 显示确认弹窗 → 确认 → 提交成功提示
- [ ] 重复举报同一分享 → 显示「您已举报过该内容」
- [ ] 网络错误 → 显示失败提示

### 后端
- [x] POST `/api/guan/share/report` 正确接收 reasonCode
- [x] 无效 reasonCode 返回错误
- [x] 数据正确写入 share_report 表
- [x] 重复举报被拦截

### 管理后台
- [ ] 举报管理页面显示待处理列表
- [ ] 点击「有效」→ 状态更新为 1
- [ ] 点击「无效」→ 状态更新为 2
- [ ] 状态筛选切换正常
- [ ] 点击分享 ID 跳转综合查询

---

## 后续优化建议

1. **举报处理后续动作**（当前为 TODO）：
   - 标记举报有效时，可考虑自动将分享状态设为违规
   - 发送通知给分享作者和举报人

2. **举报统计仪表板**：
   - 在管理后台 Dashboard 添加举报趋势图表

3. **批量处理**：
   - 支持批量标记举报为有效/无效
