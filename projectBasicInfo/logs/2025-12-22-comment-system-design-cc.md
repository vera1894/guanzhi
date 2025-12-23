# 评论系统调研与设计方案

**文档版本**: v1.3
**日期**: 2025-12-22
**更新**: 2025-12-23
**作者**: Claude Code (后端 CC)
**类型**: 调研 + 设计方案

---

## 已确认的业务规则（2025-12-23）

| 事项 | 决策 |
|------|------|
| 地理位置限制 | **移除**，评论不再需要在分享位置附近 |
| 删除后的回复 | 一级评论删除后，其二级回复**继续展示** |
| 热度参数 | **可配置**，存入配置表 |
| 积分规则 | 回复、点赞**对分享产生积分**，提供接口接入后台配置 |
| 通知跳转定位 | **第一期实现**精准定位，提供 context API 支持客户端高亮 |
| 定位索引计算 | countCommentsBefore 排序规则**必须**与列表 API 完全一致（created_at + id） |
| 一级评论定位 | 一级评论也计算 `index`，表示在分享顶层列表的位置 |
| 评论状态展示 | DELETED→"该评论已删除"，BLOCKED→"该评论已违规"，隐藏用户信息和内容 |

---

# 第一部分：现状调研

## 一、代码层调研

### 1.1 评论相关代码结构

项目中存在 **两套评论系统**：

#### 1.1.1 旧涂鸦评论系统（废弃）

| 文件 | 路径 | 说明 |
|------|------|------|
| CommentsDO | `modules/model/CommentsDO.java` | 对应 `comments` 表 |
| CommentsMapper | `modules/mapper/CommentsMapper.java` | Mapper 接口 |
| CommentsService | `modules/service/CommentsService.java` | Service 接口 |
| CommentsServiceImpl | `modules/service/impl/CommentsServiceImpl.java` | Service 实现 |
| CommentsController | `modules/rest/CommentsController.java` | API 控制器 |

**特点**：
- 关联字段为 `doodleId`（涂鸦ID），非分享ID
- API 路径：`/comments/query`, `/comments/publish`
- **状态：废弃，不建议复用**

#### 1.1.2 新分享评论系统（半成品）

| 文件 | 路径 | 说明 |
|------|------|------|
| ShareCommentDO | `modules/model/ShareCommentDO.java` | 对应 `share_comment` 表 |
| ShareCommentMapper | `modules/mapper/ShareCommentMapper.java` | 仅继承 BaseMapper |
| ShareCommentService | `modules/service/ShareCommentService.java` | 仅有 countByUserId 方法 |
| ShareCommentServiceImpl | `modules/service/impl/ShareCommentServiceImpl.java` | 实现 countByUserId |

**现有字段（ShareCommentDO）**：
```java
private Long id;
private Long shareId;         // 所属分享 ID
private Long userId;          // 发表评论的用户 ID
private Long parentId;        // 父评论 ID（但目前未使用）
private String content;       // 评论内容
private BigDecimal latitude;  // 纬度
private BigDecimal longitude; // 经度
private Integer status;       // 状态
private LocalDateTime createdAt;
```

**缺少字段**：
- `replyToUserId` - 被回复的用户 ID
- `likeCount` - 点赞数
- `updatedAt` - 更新时间

**现有 API（集成在 GuanZhiController）**：

| API | 方法 | 说明 |
|-----|------|------|
| `/guan/share/comment/add` | POST | 添加评论 |
| `/guan/share/comment/list` | GET | 获取评论列表 |

**现有限制**：
- 距离校验：需在分享位置 200 米内才能评论
- 简单查询：按 createdAt 倒序，无分页参数

**状态：半成品，可在此基础上扩展**

### 1.2 GuanzhiDO（Share 实体）评论相关字段

```java
@ApiModelProperty(value = "评论人数")
private Integer commentCount;
```

**状态：已存在，可复用**

### 1.3 积分系统对评论的引用

位置：`UserPointsServiceImpl.java:94`

```java
case "COMMENT":
    // 同一用户对同一分享只能获得一次评论积分
    return this.lambdaQuery()
            .eq(UserPointsLogDO::getUserId, userId)
            .eq(UserPointsLogDO::getReasonType, reasonType)
            .eq(UserPointsLogDO::getRelatedId, relatedId)
            .count() == 0;
```

**当前行为**：
- 支持 `COMMENT` 类型积分
- 同一用户对同一分享只能获得一次评论积分

**状态：已存在，可复用**

---

## 二、数据库调研

### 2.1 评论相关表

#### 2.1.1 share_comment 表（已存在）

从代码分析的字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT | 主键，自增 |
| share_id | BIGINT | 所属分享 ID |
| user_id | BIGINT | 发表用户 ID |
| parent_id | BIGINT | 父评论 ID |
| content | TEXT | 评论内容 |
| latitude | DECIMAL | 纬度 |
| longitude | DECIMAL | 经度 |
| status | INT | 状态 |
| created_at | DATETIME | 创建时间 |

**缺少字段**：
- `reply_to_user_id` - 被回复用户 ID
- `like_count` - 点赞数
- `updated_at` - 更新时间

**索引情况**：未从代码中明确，需验证数据库

#### 2.1.2 comment_like 表（不存在）

**需要新建**

#### 2.1.3 guanzhi 表（分享主表）

相关字段：
- `comment_count` - 评论数（已存在）

### 2.2 通知相关表

#### 2.2.1 user_message 表（已存在）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT | 主键 |
| user_id | INT | 接收用户 ID |
| jpush_id | VARCHAR | 极光推送 ID |
| message | VARCHAR | 消息内容 |
| msg_id | VARCHAR | 极光消息 ID |
| status | VARCHAR | 送达状态 |
| readed | INT | 已读状态 |
| push_type | VARCHAR | 消息类型 |
| doodle_id | INT | **涂鸦 ID（非分享 ID）** |
| action | VARCHAR | 具体行为 |

**问题**：
- 关联的是 `doodle_id`，不是 `share_id`
- 数据结构设计用于旧涂鸦系统

**状态：不建议复用，建议新建 notification 表**

---

## 三、通知 & 推送体系调研

### 3.1 极光推送（JPush）集成情况

**状态：已完整集成**

#### 3.1.1 核心文件

| 文件 | 路径 | 说明 |
|------|------|------|
| JPushUtil | `common/jpush/api/push/JPushUtil.java` | 推送工具类 |
| JPushClient | `common/jpush/api/JPushClient.java` | JPush 客户端 |
| PushPayload | `common/jpush/api/push/model/PushPayload.java` | 推送载荷构建器 |

#### 3.1.2 现有封装

```java
// JPushUtil.java
public static PushResult sendPush(PushPayload payload);

public static PushPayload buildPushObject(
    Platform platform,
    List<String> registrationIds,
    long timeToLive,
    String alert,
    String title,
    Map<String, String> extras
);
```

**支持能力**：
- Android + iOS 双平台
- 按 registrationId（jpushId）定向推送
- 自定义 extras 参数

### 3.2 站内消息服务

**状态：已存在，但需适配**

#### 3.2.1 UserMessageServiceImpl

```java
// 当前实现
public RestOut push(UserMessageDO messageDO) {
    // 1. 获取用户的 jpushId
    // 2. 构建推送消息（目前仅支持涂鸦场景）
    // 3. 发送 JPush
    // 4. 保存消息记录
}
```

**现有推送场景**：
- `DOODLE` + `COMMENT` = "XXX 贴贴了你的涂鸦"
- `DOODLE` + `FIND` = "XXX 发现了你的涂鸦"

### 3.3 用户推送标识

UserDO 中已有字段：
```java
@ApiModelProperty(value = "极光推送Id")
String jpushId;
```

---

## 四、调研结论

### 4.1 评论模块状态：半成品

| 能力 | 状态 | 说明 |
|------|------|------|
| 基础评论 CRUD | 部分实现 | 仅有添加和简单列表 |
| 二级回复 | 表结构预留 | parentId 字段存在但未使用 |
| "回复 B"语义 | 缺失 | 缺少 replyToUserId |
| 评论点赞 | 缺失 | 无相关表和代码 |
| 排序功能 | 缺失 | 仅按时间倒序 |
| 频率限制 | 缺失 | 无限制逻辑 |
| 内容长度限制 | 缺失 | 无校验 |

### 4.2 通知推送状态：已有实现可复用

| 能力 | 状态 | 说明 |
|------|------|------|
| JPush SDK | 已集成 | 完整的发送能力 |
| 定向推送 | 已实现 | 按 jpushId 推送 |
| 站内消息记录 | 部分可用 | user_message 表结构需适配 |

### 4.3 复用与重做建议

| 模块 | 建议 | 原因 |
|------|------|------|
| ShareCommentDO | **复用并扩展** | 已有基础结构，新增字段即可 |
| share_comment 表 | **复用并扩展** | 新增列：reply_to_user_id, like_count, updated_at |
| CommentsDO / comments 表 | **废弃** | 用于旧涂鸦系统，不适用 |
| comment_like 表 | **新建** | 不存在 |
| notification 表 | **新建** | user_message 不适用于分享系统 |
| JPushUtil | **复用** | 完整可用 |
| UserMessageService | **参考后重写** | 需新增针对评论回复的推送逻辑 |

---

# 第二部分：设计方案

## 一、数据模型设计

### 1.1 share_comment 表（演进方案）

基于现有 `share_comment` 表进行扩展：

```sql
-- 新增字段 DDL
ALTER TABLE share_comment
    ADD COLUMN reply_to_user_id BIGINT NULL COMMENT '被回复的用户 ID' AFTER parent_id,
    ADD COLUMN like_count INT NOT NULL DEFAULT 0 COMMENT '点赞数量' AFTER status,
    ADD COLUMN updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间' AFTER created_at;

-- 新增索引
CREATE INDEX idx_share_comment_share_created ON share_comment(share_id, created_at DESC);
CREATE INDEX idx_share_comment_parent_created ON share_comment(parent_id, created_at ASC);
CREATE INDEX idx_share_comment_user_created ON share_comment(user_id, created_at DESC);
CREATE INDEX idx_share_comment_share_likes ON share_comment(share_id, like_count DESC);
```

**完整字段说明**：

| 字段 | 类型 | 说明 | 状态 |
|------|------|------|------|
| id | BIGINT AUTO_INCREMENT | 主键 | 已存在 |
| share_id | BIGINT NOT NULL | 所属分享 ID | 已存在 |
| user_id | BIGINT NOT NULL | 发表评论的用户 ID | 已存在 |
| parent_id | BIGINT NULL | 父评论 ID，NULL=一级评论 | 已存在 |
| reply_to_user_id | BIGINT NULL | 被回复的用户 ID | **新增** |
| content | TEXT NOT NULL | 评论内容 | 已存在 |
| latitude | DECIMAL(10,7) | 纬度 | 已存在 |
| longitude | DECIMAL(10,7) | 经度 | 已存在 |
| status | TINYINT DEFAULT 0 | 0=NORMAL, 1=DELETED, 2=BLOCKED | 已存在 |
| like_count | INT DEFAULT 0 | 点赞数量 | **新增** |
| created_at | DATETIME | 创建时间 | 已存在 |
| updated_at | DATETIME | 更新时间 | **新增** |

### 1.2 comment_like 表（新建）

```sql
CREATE TABLE comment_like (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    comment_id BIGINT NOT NULL COMMENT '评论 ID',
    user_id BIGINT NOT NULL COMMENT '点赞用户 ID',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

    UNIQUE KEY uk_comment_user (comment_id, user_id),
    INDEX idx_comment_like_user (user_id, created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评论点赞表';
```

### 1.3 notification 表（新建）

```sql
CREATE TABLE notification (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL COMMENT '被通知用户 ID',
    type VARCHAR(32) NOT NULL COMMENT '通知类型：COMMENT_REPLY, COMMENT_MENTION',
    share_id BIGINT NULL COMMENT '关联分享 ID',
    comment_id BIGINT NULL COMMENT '关联评论 ID',
    from_user_id BIGINT NOT NULL COMMENT '行为发起人 ID',
    content VARCHAR(500) NULL COMMENT '通知内容摘要',
    status TINYINT DEFAULT 0 COMMENT '0=UNREAD, 1=READ',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

    INDEX idx_notification_user_status (user_id, status, created_at DESC),
    INDEX idx_notification_user_created (user_id, created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='站内通知表';
```

### 1.4 guanzhi 表 comment_count 字段

**已存在，无需修改**。

初始化策略：老数据已有评论计数，新评论操作会自动维护。

---

## 二、业务规则实现方案

### 2.1 评论权限 & 频率限制

#### 2.1.1 权限校验

- **登录校验**：所有评论/回复接口需登录，使用现有 `SecurityUtils.getUserId()` 获取用户
- **内容长度**：1-230 字符
  - 校验位置：`CommentDTO` 使用 `@Size(min=1, max=230)` + Controller 层校验
  - 异常返回：`{"respCode": 1, "respMsg": "评论内容长度需在1-230字符之间"}`

```java
// CommentDTO
@NotBlank(message = "评论内容不能为空")
@Size(min = 1, max = 230, message = "评论内容长度需在1-230字符之间")
private String content;
```

#### 2.1.2 频率限制方案（Redis 实现）

| 限制类型 | 规则 | Redis Key | 过期时间 |
|----------|------|-----------|----------|
| 同分享限流 | 同一用户同一分享 10秒内最多1条 | `comment:rate:share:{userId}:{shareId}` | 10秒 |
| 全局日限 | 同一用户每天最多200条 | `comment:daily:{userId}:{yyyyMMdd}` | 25小时 |

**实现代码示意**：

```java
@Service
public class CommentRateLimitService {

    @Autowired
    private RedisUtils redisUtils;

    private static final int SHARE_INTERVAL_SECONDS = 10;
    private static final int DAILY_LIMIT = 200;

    /**
     * 检查是否可以评论
     * @return null=可以评论, 非null=限制原因
     */
    public String checkRateLimit(Long userId, Long shareId) {
        // 1. 同分享频率限制
        String shareKey = "comment:rate:share:" + userId + ":" + shareId;
        if (redisUtils.hasKey(shareKey)) {
            return "评论太频繁，请10秒后再试";
        }

        // 2. 全局日限
        String today = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
        String dailyKey = "comment:daily:" + userId + ":" + today;
        Long count = redisUtils.get(dailyKey);
        if (count != null && count >= DAILY_LIMIT) {
            return "今日评论数已达上限（200条）";
        }

        return null;
    }

    /**
     * 记录评论行为
     */
    public void recordComment(Long userId, Long shareId) {
        // 同分享限流标记
        String shareKey = "comment:rate:share:" + userId + ":" + shareId;
        redisUtils.set(shareKey, "1", SHARE_INTERVAL_SECONDS);

        // 日计数
        String today = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
        String dailyKey = "comment:daily:" + userId + ":" + today;
        Long newCount = redisUtils.incr(dailyKey, 1);
        if (newCount == 1) {
            redisUtils.expire(dailyKey, 25 * 3600); // 25小时过期
        }
    }
}
```

### 2.2 层级与"回复 B"语义

#### 2.2.1 层级规则

- **一级评论**：`parentId = null`
- **二级回复**：`parentId = 被回复的评论 ID`
- **replyToUserId**：标记被回复的人，用于前端展示"回复 @B"

#### 2.2.2 防止第三层方案

采用**收敛到同一 parent 下**的策略：

```java
public ShareCommentDO createComment(Long userId, Long shareId, Long parentId, Long replyToUserId, String content) {
    ShareCommentDO comment = new ShareCommentDO();
    comment.setUserId(userId);
    comment.setShareId(shareId);
    comment.setContent(content);

    if (parentId != null) {
        ShareCommentDO parentComment = shareCommentMapper.selectById(parentId);
        if (parentComment == null) {
            throw new BusinessException("被回复的评论不存在");
        }

        // 如果 parent 已经是二级评论，则收敛到它的 parent 下
        if (parentComment.getParentId() != null) {
            comment.setParentId(parentComment.getParentId());
            comment.setReplyToUserId(parentComment.getUserId()); // 回复的是那条二级评论的作者
        } else {
            comment.setParentId(parentId);
            comment.setReplyToUserId(replyToUserId != null ? replyToUserId : parentComment.getUserId());
        }
    }

    shareCommentMapper.insert(comment);
    return comment;
}
```

**规则说明**：
- 回复一级评论：`parentId = 一级评论ID`，`replyToUserId = 一级评论作者`
- 回复二级评论：`parentId = 该二级评论的parentId（即一级评论ID）`，`replyToUserId = 被回复的二级评论作者`

### 2.3 删除规则

#### 2.3.1 用户删除

- 用户只能删除自己的评论
- 软删除：`status = 1 (DELETED)`
- 前端展示：显示"该评论已删除"占位
- 子回复保留，不级联删除

```java
public void deleteComment(Long userId, Long commentId) {
    ShareCommentDO comment = shareCommentMapper.selectById(commentId);
    if (comment == null) {
        throw new BusinessException("评论不存在");
    }
    if (!comment.getUserId().equals(userId)) {
        throw new BusinessException("只能删除自己的评论");
    }

    comment.setStatus(1); // DELETED
    shareCommentMapper.updateById(comment);

    // 更新分享的 commentCount（减1）
    guanzhiMapper.decrementCommentCount(comment.getShareId());
}
```

#### 2.3.2 管理员删除

- 管理后台可删除任意评论
- 同样软删除：`status = 1 (DELETED)`

### 2.4 评论点赞

#### 2.4.1 点赞/取消点赞

```java
@Transactional
public void likeComment(Long userId, Long commentId) {
    // 检查是否已点赞
    CommentLikeDO existing = commentLikeMapper.selectOne(
        new LambdaQueryWrapper<CommentLikeDO>()
            .eq(CommentLikeDO::getCommentId, commentId)
            .eq(CommentLikeDO::getUserId, userId)
    );

    if (existing != null) {
        throw new BusinessException("已点赞过该评论");
    }

    // 插入点赞记录
    CommentLikeDO like = new CommentLikeDO();
    like.setCommentId(commentId);
    like.setUserId(userId);
    commentLikeMapper.insert(like);

    // 原子更新 like_count
    shareCommentMapper.incrementLikeCount(commentId);
}

@Transactional
public void unlikeComment(Long userId, Long commentId) {
    int deleted = commentLikeMapper.delete(
        new LambdaQueryWrapper<CommentLikeDO>()
            .eq(CommentLikeDO::getCommentId, commentId)
            .eq(CommentLikeDO::getUserId, userId)
    );

    if (deleted > 0) {
        shareCommentMapper.decrementLikeCount(commentId);
    }
}
```

#### 2.4.2 防并发方案

使用 SQL 原子操作：

```java
// ShareCommentMapper.java
@Update("UPDATE share_comment SET like_count = like_count + 1 WHERE id = #{commentId}")
void incrementLikeCount(@Param("commentId") Long commentId);

@Update("UPDATE share_comment SET like_count = GREATEST(like_count - 1, 0) WHERE id = #{commentId}")
void decrementLikeCount(@Param("commentId") Long commentId);
```

### 2.5 排序规则

#### 2.5.1 排序模式

| 模式 | 参数值 | SQL |
|------|--------|-----|
| 默认热度 | `order=default` | 按 hotScore DESC |
| 最新 | `order=latest` | 按 created_at DESC |
| 最多点赞 | `order=likes` | 按 like_count DESC, created_at DESC |

#### 2.5.2 热度计算方案

```java
public class CommentHotScoreCalculator {

    // 可配置参数（可放入 fade_config 表或常量类）
    private static final double WEIGHT_LIKE = 3.0;        // a: 点赞权重
    private static final double WEIGHT_REPLY = 5.0;       // b: 回复权重
    private static final double WEIGHT_AUTHOR = 20.0;     // c: 作者评论加权
    private static final double FRESHNESS_DECAY = 0.1;    // d: 新鲜度衰减系数

    /**
     * 计算评论热度分
     * hotScore = a * likeCount + b * replyCount + c * isAuthorComment + d * freshnessFactor
     */
    public double calculateHotScore(ShareCommentDO comment, int replyCount, Long shareAuthorId) {
        double score = 0;

        // 点赞分
        score += WEIGHT_LIKE * comment.getLikeCount();

        // 回复分
        score += WEIGHT_REPLY * replyCount;

        // 作者评论加权
        if (comment.getUserId().equals(shareAuthorId)) {
            score += WEIGHT_AUTHOR;
        }

        // 新鲜度因子（24小时内的评论有额外加分，随时间衰减）
        long hoursAgo = ChronoUnit.HOURS.between(comment.getCreatedAt(), LocalDateTime.now());
        if (hoursAgo < 24) {
            score += (24 - hoursAgo) * FRESHNESS_DECAY;
        }

        return score;
    }
}
```

**实现方式**：查询时计算排序，不持久化 hotScore。

```sql
-- 热度排序 SQL 示例（一级评论）
SELECT c.*,
       (3 * c.like_count + 5 * (SELECT COUNT(*) FROM share_comment r WHERE r.parent_id = c.id AND r.status = 0)
        + IF(c.user_id = #{shareAuthorId}, 20, 0)
        + GREATEST(0, (24 - TIMESTAMPDIFF(HOUR, c.created_at, NOW())) * 0.1)) AS hot_score
FROM share_comment c
WHERE c.share_id = #{shareId} AND c.parent_id IS NULL AND c.status = 0
ORDER BY hot_score DESC
LIMIT #{offset}, #{limit}
```

### 2.6 二级回复折叠 & 分页策略

#### 2.6.1 一级评论列表返回结构

```java
public class CommentVO {
    private Long id;
    private Long shareId;
    private Long userId;
    private String userNickname;        // status != NORMAL 时为 null
    private String userAvatar;          // status != NORMAL 时为 null
    private String content;             // status != NORMAL 时为 null
    private Integer likeCount;
    private Integer replyCount;         // 该评论的总回复数
    private Boolean isAuthor;           // 是否是分享作者的评论
    private Boolean liked;              // 当前用户是否已点赞
    private Integer status;             // 0=NORMAL, 1=DELETED, 2=BLOCKED
    private String statusText;          // "该评论已删除" / "该评论已违规" / null
    private LocalDateTime createdAt;

    // 预览回复（默认展示2条）
    private List<ReplyVO> repliesPreview;
}

public class ReplyVO {
    private Long id;
    private Long userId;
    private String userNickname;
    private String userAvatar;
    private Long replyToUserId;
    private String replyToUserNickname;  // "回复 @xxx"
    private String content;
    private Integer likeCount;
    private Boolean liked;
    private LocalDateTime createdAt;
}
```

#### 2.6.2 预览策略

默认展示 2 条回复，按以下优先级：
1. 作者的回复
2. 最热的回复（like_count 最高）

#### 2.6.3 回复分页接口

`GET /api/comments/{commentId}/replies?offset=0&limit=10`

返回指定一级评论下的二级回复，按时间正序（早的在前）。

### 2.7 通知 & 极光推送

#### 2.7.1 触发时机

| 场景 | 通知类型 | 接收人 | 推送文案 |
|------|----------|--------|----------|
| 回复一级评论 | COMMENT_REPLY | 一级评论作者 | "XXX 回复了你的评论" |
| 回复二级评论 | COMMENT_REPLY | 二级评论作者 | "XXX 回复了你" |

**注意**：不给自己发通知（回复自己的评论时跳过）

#### 2.7.2 推送实现方案

复用现有 `JPushUtil`，新建 `CommentNotificationService`：

```java
@Service
public class CommentNotificationService {

    @Autowired
    private NotificationMapper notificationMapper;
    @Autowired
    private UserMapper userMapper;

    /**
     * 发送评论回复通知
     */
    public void sendReplyNotification(Long toUserId, Long fromUserId, Long shareId, Long commentId) {
        // 不给自己发通知
        if (toUserId.equals(fromUserId)) {
            return;
        }

        UserDO fromUser = userMapper.selectById(fromUserId);
        UserDO toUser = userMapper.selectById(toUserId);

        // 1. 保存站内通知
        NotificationDO notification = new NotificationDO();
        notification.setUserId(toUserId);
        notification.setType("COMMENT_REPLY");
        notification.setShareId(shareId);
        notification.setCommentId(commentId);
        notification.setFromUserId(fromUserId);
        notification.setContent(fromUser.getNickname() + " 回复了你的评论");
        notification.setStatus(0); // UNREAD
        notificationMapper.insert(notification);

        // 2. 发送极光推送
        if (StringUtils.hasText(toUser.getJpushId())) {
            Map<String, String> extras = new HashMap<>();
            extras.put("type", "comment_reply");
            extras.put("shareId", shareId.toString());
            extras.put("commentId", commentId.toString());

            PushPayload payload = JPushUtil.buildPushObject(
                Platform.android_ios(),
                Collections.singletonList(toUser.getJpushId()),
                86400,
                fromUser.getNickname() + " 回复了你的评论",
                "观之",
                extras
            );

            JPushUtil.sendPush(payload);
        }
    }
}
```

#### 2.7.3 推送 Payload 模板

```json
{
  "platform": ["android", "ios"],
  "audience": {
    "registration_id": ["用户的 jpushId"]
  },
  "notification": {
    "alert": "张三 回复了你的评论",
    "android": {
      "title": "观之",
      "extras": {
        "type": "comment_reply",
        "shareId": "12345",
        "commentId": "67890"
      }
    },
    "ios": {
      "sound": "default",
      "badge": 1,
      "extras": {
        "type": "comment_reply",
        "shareId": "12345",
        "commentId": "67890"
      }
    }
  },
  "options": {
    "apns_production": true,
    "time_to_live": 86400
  }
}
```

#### 2.7.4 通知跳转精准定位（第一期实现）

**问题说明**：
推送 Payload 提供了 `shareId` 和 `commentId`，但客户端难以知道该评论在列表的第几页。

**解决方案**：
后端提供**评论上下文接口**，支持客户端精准定位并高亮目标评论：

```
GET /api/comments/{commentId}/context
```

**响应**：
```json
{
  "respCode": 0,
  "datas": {
    "comment": {
      "id": 67890,
      "shareId": 456,
      "userId": 111,
      "userNickname": "回复者昵称",
      "userAvatar": "头像URL",
      "parentId": 123,
      "replyToUserId": 222,
      "replyToUserNickname": "被回复者昵称",
      "content": "评论内容",
      "likeCount": 5,
      "liked": false,
      "status": 0,
      "statusText": null,
      "createdAt": "2025-12-22 10:30:00"
    },
    "parentComment": {
      "id": 123,
      "shareId": 456,
      "userId": 333,
      "userNickname": null,
      "userAvatar": null,
      "content": null,
      "likeCount": 10,
      "replyCount": 8,
      "liked": true,
      "status": 1,
      "statusText": "该评论已删除",
      "createdAt": "2025-12-22 09:00:00"
    },
    "shareId": 456,
    "position": {
      "isFirstLevel": false,
      "parentId": 123,
      "index": 5
    }
  }
}
```

**字段说明**：
| 字段 | 说明 |
|------|------|
| comment | 目标评论详情 |
| parentComment | 如果是二级回复，返回其所属的一级评论；一级评论时为 null |
| shareId | 所属分享 ID |
| position.isFirstLevel | 是否为一级评论 |
| position.parentId | 父评论 ID（一级评论时为 null） |
| position.index | **精准定位索引**（0-based）：一级评论时为在分享顶层列表的位置，二级回复时为在父评论回复列表的位置 |

**评论状态与展示规则**：

| status | statusText | 展示规则 |
|--------|------------|----------|
| 0 (NORMAL) | null | 正常展示 content、userNickname、userAvatar |
| 1 (DELETED) | "该评论已删除" | content/userNickname/userAvatar 置 null，前端显示灰色占位 |
| 2 (BLOCKED) | "该评论已违规" | content/userNickname/userAvatar 置 null，前端显示灰色占位 |

**iOS 端处理流程**：
1. 点击推送通知 → 提取 `commentId`
2. 调用 `GET /api/comments/{commentId}/context` 获取上下文
3. 跳转到 `shareId` 对应的分享详情页
4. 如果 `isFirstLevel = true`：
   - 根据 `index` 计算页码：`page = index / pageSize`
   - 请求对应页的一级评论列表
   - 定位并高亮目标评论
5. 如果 `isFirstLevel = false`：
   - 定位到 `parentComment` 对应的一级评论（若 `statusText` 非空则显示占位）
   - 展开其回复列表，根据 `index` 计算页码
   - 滚动到目标位置并高亮

**后端实现逻辑**：
```java
public CommentContextVO getCommentContext(Long commentId, Long currentUserId) {
    ShareCommentDO comment = shareCommentMapper.selectById(commentId);
    if (comment == null) {
        throw new BusinessException("评论不存在");
    }

    CommentContextVO vo = new CommentContextVO();
    vo.setComment(buildCommentVO(comment, currentUserId));
    vo.setShareId(comment.getShareId());

    CommentPositionVO position = new CommentPositionVO();

    if (comment.getParentId() == null) {
        // 一级评论：计算在分享顶层评论列表中的位置
        position.setIsFirstLevel(true);
        position.setParentId(null);

        // 计算在分享一级评论列表中的位置（按时间正序）
        Long index = shareCommentMapper.countCommentsBefore(
            comment.getShareId(),
            null,  // parentId = null 表示一级评论
            comment.getCreatedAt(),
            comment.getId()
        );
        position.setIndex(index.intValue());
        vo.setParentComment(null);
    } else {
        // 二级回复
        position.setIsFirstLevel(false);
        position.setParentId(comment.getParentId());

        // 计算在父评论回复列表中的位置（按时间正序）
        Long index = shareCommentMapper.countCommentsBefore(
            comment.getShareId(),
            comment.getParentId(),
            comment.getCreatedAt(),
            comment.getId()
        );
        position.setIndex(index.intValue());

        // 获取父评论（含状态处理）
        ShareCommentDO parent = shareCommentMapper.selectById(comment.getParentId());
        vo.setParentComment(buildCommentVOWithStatus(parent, currentUserId));
    }

    vo.setPosition(position);
    return vo;
}

/**
 * 构建评论 VO，处理不同状态的展示
 */
private CommentVO buildCommentVOWithStatus(ShareCommentDO comment, Long currentUserId) {
    CommentVO vo = new CommentVO();
    vo.setId(comment.getId());
    vo.setShareId(comment.getShareId());
    vo.setUserId(comment.getUserId());
    vo.setParentId(comment.getParentId());
    vo.setLikeCount(comment.getLikeCount());
    vo.setCreatedAt(comment.getCreatedAt());
    vo.setStatus(comment.getStatus());

    // 根据状态决定展示内容
    switch (comment.getStatus()) {
        case 0: // NORMAL
            vo.setStatusText(null);
            vo.setContent(comment.getContent());
            // 填充用户信息
            UserDO user = userMapper.selectById(comment.getUserId());
            vo.setUserNickname(user.getNickname());
            vo.setUserAvatar(user.getAvatar());
            break;
        case 1: // DELETED
            vo.setStatusText("该评论已删除");
            vo.setContent(null);
            vo.setUserNickname(null);
            vo.setUserAvatar(null);
            break;
        case 2: // BLOCKED
            vo.setStatusText("该评论已违规");
            vo.setContent(null);
            vo.setUserNickname(null);
            vo.setUserAvatar(null);
            break;
    }

    // 检查当前用户是否已点赞
    if (currentUserId != null) {
        vo.setLiked(commentLikeMapper.existsByCommentIdAndUserId(comment.getId(), currentUserId));
    }

    return vo;
}
```

**Mapper 方法定义（关键）**：

```java
// ShareCommentMapper.java

/**
 * 计算目标评论之前有多少条评论（用于精准定位）
 *
 * 【重要】排序规则必须与查询列表 API 完全一致：
 * - 排序字段：created_at ASC, id ASC
 * - 过滤条件：status = 0 (NORMAL)
 *
 * @param shareId 分享 ID
 * @param parentId 父评论 ID（null 表示一级评论）
 * @param createdAt 目标评论的创建时间
 * @param commentId 目标评论的 ID（处理同一时间戳多条评论）
 */
@Select({
    "<script>",
    "SELECT COUNT(*) FROM share_comment",
    "WHERE share_id = #{shareId}",
    "  AND status = 0",
    "  <if test='parentId == null'>AND parent_id IS NULL</if>",
    "  <if test='parentId != null'>AND parent_id = #{parentId}</if>",
    "  AND (",
    "    created_at &lt; #{createdAt}",
    "    OR (created_at = #{createdAt} AND id &lt; #{commentId})",
    "  )",
    "</script>"
})
Long countCommentsBefore(
    @Param("shareId") Long shareId,
    @Param("parentId") Long parentId,
    @Param("createdAt") LocalDateTime createdAt,
    @Param("commentId") Long commentId
);
```

**性能优化 - 索引要求**：

```sql
-- 必须建立复合索引以支持 countCommentsBefore 高效查询
-- 索引字段顺序与查询条件匹配：share_id, parent_id, status, created_at, id

CREATE INDEX idx_share_comment_position ON share_comment(
    share_id,
    parent_id,
    status,
    created_at,
    id
);
```

**排序一致性约束**：

> ⚠️ **硬性约束**：`countCommentsBefore` 的 WHERE 条件和排序规则，必须与以下 API 的查询逻辑**完全一致**：
> - `GET /api/shares/{shareId}/comments`（一级评论列表）
> - `GET /api/comments/{commentId}/replies`（二级回复列表）
>
> 包括：
> - 过滤条件：`status = 0`（只统计 NORMAL 状态）
> - 排序规则：`ORDER BY created_at ASC, id ASC`
>
> 否则客户端根据 `index` 计算的页码会与实际列表不匹配。

---

## 三、API 设计

### 3.1 新增评论/回复

**POST** `/api/shares/{shareId}/comments`

**请求体**：
```json
{
  "content": "评论内容，1-230字符",
  "parentId": null,           // null=一级评论，非null=回复
  "replyToUserId": null,      // 被回复的用户ID（回复二级评论时需要）
  "latitude": 39.9042,        // 可选，评论位置
  "longitude": 116.4074       // 可选，评论位置
}
```

**成功响应** (200):
```json
{
  "respCode": 0,
  "respMsg": "success",
  "datas": {
    "id": 123,
    "shareId": 456,
    "userId": 789,
    "userNickname": "用户昵称",
    "userAvatar": "头像URL",
    "parentId": null,
    "replyToUserId": null,
    "replyToUserNickname": null,
    "content": "评论内容",
    "likeCount": 0,
    "createdAt": "2025-12-22 10:30:00"
  }
}
```

### 3.2 获取评论列表

**GET** `/api/shares/{shareId}/comments`

**请求参数**：
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| order | String | 否 | 排序方式：default(默认热度), latest(最新), likes(最多点赞) |
| offset | Integer | 否 | 偏移量，默认 0 |
| limit | Integer | 否 | 每页数量，默认 20，最大 50 |

### 3.3 获取评论回复列表

**GET** `/api/comments/{commentId}/replies`

**请求参数**：
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| offset | Integer | 否 | 偏移量，默认 0 |
| limit | Integer | 否 | 每页数量，默认 10，最大 50 |

### 3.4 删除评论

**DELETE** `/api/comments/{commentId}`

### 3.5 点赞评论

**POST** `/api/comments/{commentId}/like`

### 3.6 取消点赞

**DELETE** `/api/comments/{commentId}/like`

### 3.7 获取评论上下文（精准定位）

**GET** `/api/comments/{commentId}/context`

**用途**：通知跳转时获取评论的完整上下文信息，用于客户端精准定位和高亮显示。

**成功响应** (200):
```json
{
  "respCode": 0,
  "respMsg": "success",
  "datas": {
    "comment": { /* 目标评论详情 */ },
    "parentComment": { /* 父评论详情，一级评论时为 null */ },
    "shareId": 456,
    "position": {
      "isFirstLevel": false,
      "parentId": 123,
      "indexInParent": 5
    }
  }
}
```

**错误响应**：
- 评论不存在：`{"respCode": 1, "respMsg": "评论不存在"}`

---

## 四、实现清单

### 4.1 数据库变更

1. `share_comment` 表新增字段
2. 新建 `comment_like` 表
3. 新建 `notification` 表
4. 新建精准定位索引 `idx_share_comment_position`

### 4.2 新增文件

| 类型 | 文件 | 说明 |
|------|------|------|
| DO | CommentLikeDO | 评论点赞实体 |
| DO | NotificationDO | 通知实体 |
| Mapper | CommentLikeMapper | 评论点赞 Mapper |
| Mapper | NotificationMapper | 通知 Mapper |
| DTO | CreateCommentDTO | 创建评论请求 |
| VO | CommentVO | 评论响应 |
| VO | ReplyVO | 回复响应 |
| VO | CommentContextVO | 评论上下文响应（精准定位） |
| VO | CommentPositionVO | 评论位置信息 |
| Service | CommentRateLimitService | 频率限制服务 |
| Service | CommentNotificationService | 评论通知服务 |
| Controller | CommentController | 评论 API |

### 4.3 修改文件

| 文件 | 修改内容 |
|------|----------|
| ShareCommentDO | 新增 replyToUserId, likeCount, updatedAt 字段 |
| ShareCommentMapper | 新增热度排序查询、批量查询、countCommentsBefore（精准定位）等方法 |
| ShareCommentService | 扩展评论业务方法 |
| ShareCommentServiceImpl | 实现完整评论逻辑 |
| GuanzhiServiceImpl | 移除旧的 addComment 方法调用 |

---

## 五、已确认规则详细设计

### 5.1 地理位置限制（已移除）

**变更说明**：
- 旧规则：评论需在分享位置 200 米内
- 新规则：**无地理位置限制**，任何位置均可评论
- 影响代码：`GuanZhiController.addComment()` 中移除距离校验逻辑
- `share_comment` 表的 `latitude`/`longitude` 字段保留，但改为可选记录

### 5.2 删除后的回复处理

**规则**：
- 一级评论被删除（`status=DELETED`）后，其二级回复**继续展示**
- 前端展示时：
  - 一级评论根据 `statusText` 显示占位（"该评论已删除" / "该评论已违规"）
  - 其下的二级回复正常展示
- 查询逻辑：查询一级评论时不过滤 DELETED/BLOCKED 状态，通过 `status` 和 `statusText` 标记

**状态展示规则**（已在 2.7.4 节定义）：

| status | statusText | 展示规则 |
|--------|------------|----------|
| 0 (NORMAL) | null | 正常展示 |
| 1 (DELETED) | "该评论已删除" | 灰色占位，隐藏用户信息和内容 |
| 2 (BLOCKED) | "该评论已违规" | 灰色占位，隐藏用户信息和内容 |

### 5.3 热度参数可配置

**存储位置**：使用现有 `fade_config` 表

```sql
-- 新增热度参数配置
INSERT INTO fade_config (config_key, config_value, description) VALUES
('COMMENT_HOT_WEIGHT_LIKE', '3', '评论热度-点赞权重'),
('COMMENT_HOT_WEIGHT_REPLY', '5', '评论热度-回复权重'),
('COMMENT_HOT_WEIGHT_AUTHOR', '20', '评论热度-作者评论加权'),
('COMMENT_HOT_FRESHNESS_DECAY', '0.1', '评论热度-新鲜度衰减系数');
```

**实现方式**：
```java
@Service
public class CommentHotScoreService {

    @Autowired
    private FadeConfigService fadeConfigService;

    public double calculateHotScore(ShareCommentDO comment, int replyCount, Long shareAuthorId) {
        Map<String, String> configs = fadeConfigService.getAllFadeConfigs();

        double weightLike = Double.parseDouble(configs.getOrDefault("COMMENT_HOT_WEIGHT_LIKE", "3"));
        double weightReply = Double.parseDouble(configs.getOrDefault("COMMENT_HOT_WEIGHT_REPLY", "5"));
        double weightAuthor = Double.parseDouble(configs.getOrDefault("COMMENT_HOT_WEIGHT_AUTHOR", "20"));
        double freshnessDecay = Double.parseDouble(configs.getOrDefault("COMMENT_HOT_FRESHNESS_DECAY", "0.1"));

        double score = weightLike * comment.getLikeCount()
                     + weightReply * replyCount;

        if (comment.getUserId().equals(shareAuthorId)) {
            score += weightAuthor;
        }

        long hoursAgo = ChronoUnit.HOURS.between(comment.getCreatedAt(), LocalDateTime.now());
        if (hoursAgo < 24) {
            score += (24 - hoursAgo) * freshnessDecay;
        }

        return score;
    }
}
```

### 5.4 积分规则（接入后台配置）

**新增积分类型**：

| 积分类型 | 说明 | 获得者 | 接入后台配置 |
|----------|------|--------|--------------|
| COMMENT_REPLY | 回复评论 | 分享作者 | 是 |
| COMMENT_LIKE | 点赞评论 | 分享作者 | 是 |

**积分规则接口设计**：

复用现有 `points_rule` 表，新增配置项：

```sql
-- 新增评论相关积分规则
INSERT INTO points_rule (action_type, points_value, daily_limit, description) VALUES
('COMMENT_REPLY', 1, 50, '分享被回复获得积分'),
('COMMENT_LIKE', 1, 100, '评论被点赞获得积分');
```

**后台管理 API**（复用现有积分规则管理接口）：

| API | 方法 | 说明 |
|-----|------|------|
| GET `/api/admin/points-rules` | GET | 获取积分规则列表 |
| PUT `/api/admin/points-rules/{actionType}` | PUT | 更新积分规则 |

**积分触发逻辑**：

```java
// 评论/回复时给分享作者加积分
public void addComment(...) {
    // ... 创建评论逻辑 ...

    // 给分享作者加积分（如果不是自己评论自己的分享）
    GuanzhiDO share = guanzhiMapper.selectById(shareId);
    if (!share.getUserId().equals(userId)) {
        userPointsService.addPoints(share.getUserId().longValue(), "COMMENT_REPLY", commentId);
    }
}

// 点赞评论时给分享作者加积分
public void likeComment(...) {
    // ... 点赞逻辑 ...

    // 给分享作者加积分
    ShareCommentDO comment = shareCommentMapper.selectById(commentId);
    GuanzhiDO share = guanzhiMapper.selectById(comment.getShareId());
    if (!share.getUserId().equals(userId)) {
        userPointsService.addPoints(share.getUserId().longValue(), "COMMENT_LIKE", commentId);
    }
}
```

---

## 六、实现清单（更新）

### 6.1 代码变更

| 文件 | 变更内容 |
|------|----------|
| GuanZhiController | 移除 `/guan/share/comment/add` 的距离校验 |
| fade_config 表 | 新增热度参数配置项 |
| points_rule 表 | 新增 COMMENT_REPLY、COMMENT_LIKE 规则 |
| CommentHotScoreService | 新建，从配置表读取热度参数 |
| ShareCommentServiceImpl | 实现评论/回复/点赞时的积分触发 |

### 6.2 后台管理页面接入

积分规则配置页面需新增以下规则展示：
- COMMENT_REPLY - 分享被回复获得积分
- COMMENT_LIKE - 评论被点赞获得积分

---

**设计方案已更新，待实施。**
