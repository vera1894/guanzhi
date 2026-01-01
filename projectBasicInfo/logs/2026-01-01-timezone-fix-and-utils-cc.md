# 时区问题修复与统一时间工具创建

**日期**: 2026-01-01
**操作者**: Claude Code (cc)
**类型**: Bug修复 + 工具创建
**最后更新**: 2026-01-01

---

## 问题描述

iOS 端通知和评论的时间显示比实际早 8 小时。例如刚发送的通知显示为"8小时前"。

## 根因分析

| 组件 | 问题 |
|-----|------|
| 后端 `NotificationVO.java` | `createdAt` 字段缺少 `@JsonFormat` 注解，返回 UTC 时间数组 |
| iOS `NotificationModels.swift` | 把 UTC 时间数组当作北京时间解析 |

**数据流**：
```
后端存储: UTC 08:00
后端返回: [2026, 1, 1, 8, 0, 0]（UTC 时间）
iOS 解析: 认为是北京时间 08:00，转换为 UTC 00:00
实际时间: UTC 08:00
时间差: 8 小时
```

## 解决方案

### 1. 创建模块内时间格式化工具

**最终方案**：在 `NotificationModels.swift` 中创建内联的 `NotificationDateHelper` 枚举

```swift
private enum NotificationDateHelper {
    /// 格式化为相对时间显示
    static func formatRelativeTime(_ date: Date) -> String { ... }

    /// 格式化为北京时间字符串（用于编码）
    static func formatToShanghaiString(_ date: Date) -> String { ... }
}
```

**说明**：最初创建了独立的 `DateTimeUtils.swift` 文件，但由于该文件未自动添加到 Xcode 项目导致编译错误。最终采用内联方案，在 `NotificationModels.swift` 中直接定义所需的时间处理方法。

### 2. 更新 NotificationModels.swift

修复时间解析逻辑，将时区从 "Asia/Shanghai" 改为 "UTC"：

```swift
// 修改前（错误）
components.timeZone = TimeZone(identifier: "Asia/Shanghai")

// 修改后（正确）
components.timeZone = TimeZone(identifier: "UTC")
```

时间格式化调用：
```swift
// 格式化相对时间
var formattedTime: String {
    NotificationDateHelper.formatRelativeTime(date)
}

// 编码为字符串
let dateString = NotificationDateHelper.formatToShanghaiString(createdAtDate)
```

### 3. 更新项目文档

在 `00_AGENT_RULES.md` 第5节添加了完整的前后端时间处理规范。

## 修改文件清单

| 文件 | 操作 |
|-----|------|
| `guanzhi/ModelsForNetwork/NotificationModels.swift` | 修改 - 添加 `NotificationDateHelper`，修复时区解析 |
| `guanzhi/ModelsForNetwork/DateTimeUtils.swift` | 新建 - 统一时间解析工具（参考文档，未集成到项目） |
| `projectBasicInfo/00_AGENT_RULES.md` | 修改 - 添加时间处理规范 |

## 验证结果

修复后通知时间显示正确，"刚刚"发送的通知显示为"刚刚"。

## 关键代码位置

- **时间解析**：`NotificationModels.swift` 第 200-244 行 `parseCreatedAt()` 和 `parseLocalDateTimeArray()`
- **时间格式化**：`NotificationModels.swift` 第 125-162 行 `NotificationDateHelper` 枚举
- **相对时间显示**：`NotificationMessage.formattedTime` 和 `AggregatedStickerNotification.formattedTime`

## 后续建议

1. 后端应统一在所有 VO/DTO 的 `LocalDateTime` 字段添加 `@JsonFormat` 注解
2. iOS 端评论模块 (`CommentModels.swift`) 也应参考此模式处理时间
3. 新增时间相关功能时，必须参考 `00_AGENT_RULES.md` 第5节规范
4. 如需统一工具类，可手动将 `DateTimeUtils.swift` 添加到 Xcode 项目
