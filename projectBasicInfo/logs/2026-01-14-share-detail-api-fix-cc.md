# 分享详情 API 路径修复

**日期**: 2026-01-14
**作者**: Claude Code
**状态**: ✅ 已完成

---

## 问题描述

分享详情页加载时出现 404 错误：
```
❌ 服务器返回非 200 状态码
❌ 错误响应: ["error": Not Found, "status": 404, "path": /guan/share/detail]
```

---

## 根本原因

前端和后端的 API 路径不匹配：

| 位置 | 路径 |
|------|------|
| 前端调用 | `/api/guan/share/detail` ❌ |
| 后端定义 | `/guan/share/info` ✅ |

---

## 修复内容

**文件**: `guanzhi/ModelsForNetwork/OTORequests.swift:287`

```swift
// 修改前
case .fetchShareDetail(let id):
    return .init(
        path: "/api/guan/share/detail",  // ❌ 错误路径
        method: .post,
        param: ["id": id]
    )

// 修改后
case .fetchShareDetail(let id):
    return .init(
        path: "/api/guan/share/info",    // ✅ 正确路径
        method: .post,
        param: ["id": id]
    )
```

---

## 验证

修复后，分享详情页应该能正常加载数据，不再出现 404 错误。
