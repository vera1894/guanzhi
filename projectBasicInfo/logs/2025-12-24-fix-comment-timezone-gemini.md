# 修复评论时间显示偏差问题

**日期**: 2025-12-24
**执行者**: Gemini
**相关文件**:
- `guanzhi/Server/onettoo/src/main/java/com/cloud/onettoo/modules/service/impl/ShareCommentServiceImpl.java`

## 问题描述

新发表的评论在前端显示为“8小时以前”，而实际上应该是“刚刚”。
这通常是因为服务器（可能运行在 UTC 时区）生成的时间与前端期望的北京时间（Asia/Shanghai）存在时区偏差。

原因分析：
1. 后端使用 `LocalDateTime.now()` 生成 `createdAt` 时间。
2. `LocalDateTime.now()` 默认使用服务器的系统时区。如果服务器是 UTC，生成的当前时间数值上比北京时间慢 8 小时（例如北京 20:00，UTC 12:00）。
3. 数据库和 JSON 序列化（`CommentVO`）虽然标记了 `Asia/Shanghai`，但对于 `LocalDateTime` 类型，Jackson 通常直接传输数值。
4. 前端接收到 JSON（如 `...T12:00:00`）后，默认按本地设备时区（北京）解析，得到“北京时间 12:00”。
5. 前端计算相对时间：`当前北京时间(20:00) - 评论时间(12:00) = 8小时`。

## 修改内容

### 修改 `ShareCommentServiceImpl.java`

在 `createComment` 方法中，强制指定时区生成时间：

```java
// 旧代码
// comment.setCreatedAt(LocalDateTime.now());

// 新代码
comment.setCreatedAt(LocalDateTime.now(java.time.ZoneId.of("Asia/Shanghai")));
```

## 结果

现在，无论服务器运行在哪个时区，生成的时间数值都将是标准的北京时间。
- 存入数据库：北京时间数值。
- 返回前端：北京时间数值。
- 前端解析：按北京时间解析 -> 得到正确的时间点。
- 显示结果：应该显示“刚刚”。
