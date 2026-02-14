# 褪色度动态系数驱动系统 — 实施记录

**日期**：2026-02-14
**类型**：架构重构（褪色系统）

---

## 背景

旧褪色系统的每日增量只看单条观之的浏览人数（分 5 档，2-10/天），不考虑服务器活跃用户数。投票/签到/评论通过实时加减 fadeScore 影响褪色，难以追溯和调参。

## 新公式

```
每日褪色增量 = BASE_RATE × activityFactor × interactionFactor
activityFactor = clamp(ln(WAU+1) / ln(TARGET_WAU+1), MIN_FACTOR, 1.0)
interactionFactor = max(0, 1.0 - posW*pos/WAU - ckW*ck/WAU - cmW*cm/WAU + negW*neg/WAU)
```

## 修改的文件

| 文件 | 操作 |
|------|------|
| `db/migration/V20260214__fade_dynamic_factor.sql` | 新建 — tag_type 更新、新配置项、废弃旧配置、索引 |
| `mapper/FadeScoreMapper.java` | 新建 — WAU 统计、贴纸/签到/评论用户数查询 |
| `service/TagDefinitionService.java` | 新增 `getTagCodesByType()` 方法签名 |
| `service/impl/TagDefinitionServiceImpl.java` | 新增按 tagType 分组缓存 + `getTagCodesByType()` 实现 |
| `service/impl/GuanzhiServiceImpl.java` | vote/checkin/addComment 删除 fadeScore 实时加减，移除 fadeConfigService 依赖 |
| `tasks/FadeScoreTask.java` | 完全重写 — 新公式，注入 FadeScoreMapper + TagDefinitionService |
| `dto/FadeSimulationRequest.java` | 字段替换为 wau/positiveUsers/negativeUsers/checkinUsers/commentUsers |
| `dto/FadeSimulationResponse.java` | 新增 activityFactor/interactionFactor 字段 |
| `rest/AdminController.java` | simulateFadeScore 用新公式重写，删除旧 calculateBaseFade |

## 构建验证

- `mvn clean package -DskipTests` — BUILD SUCCESS（需要 JDK 17）

## 部署注意事项

1. 步骤 4（删除实时加减）和步骤 5（新算法）必须**同一次部署**
2. 部署后手动执行 `V20260214__fade_dynamic_factor.sql`（Flyway 未启用）
3. 执行 SQL 后必须 `systemctl restart onettoo` 刷新配置缓存
4. 验证：凌晨 3 点后检查 `journalctl -u onettoo | grep "WAU="` 确认全局参数
5. 回滚：设 `BASE_RATE=0` + 重启即可停止褪色

## 关键设计决策

- **互动计数全量统计**（不限时间窗口）：正向贴纸保护持久有效
- **WAU 用 7 天窗口**：反映当前活跃度
- **interactionFactor 下限为 0**：正向互动足够多时每日增量为 0（永不褪色）
- **effectiveWau = max(1, wau)**：避免除零
