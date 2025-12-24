# 贴纸名称配置 API 实现

**日期**: 2025-12-24
**作者**: Claude Code
**类型**: 新功能

---

## 概述

新增公开配置 API，用于 iOS 客户端启动时预加载贴纸显示名称，支持 ETag 缓存优化。

---

## API 规格

### 请求

```
GET /config/sticker-names        (后端路径)
GET /api/config/sticker-names    (前端通过 Nginx 调用)
```

### 请求头（可选）

```
If-None-Match: "版本号"
```

### 成功响应 (200)

```json
{
  "respCode": 0,
  "datas": {
    "version": "202512240123",
    "names": {
      "LIKE": "赞同",
      "NEUTRAL": "无感",
      "MIJING": "秘境",
      "ZHENXIU": "珍馐",
      "WANQU": "玩趣",
      "CAIKENG": "踩坑",
      "MAOMAO": "猫猫",
      "CHAOSHENG": "朝圣",
      "RICHU": "日出",
      "JISHI": "集市"
    }
  }
}
```

### 响应头

```
ETag: "202512240123"
Cache-Control: max-age=86400
```

### 无变化响应 (304)

如果客户端发送的 `If-None-Match` 与当前版本匹配，返回 304 Not Modified。

---

## 实现细节

### 新增文件

**`ConfigController.java`**
- 路径: `Server/onettoo/src/main/java/com/cloud/onettoo/modules/rest/ConfigController.java`

### 关键代码

```java
@AnonymousAccess  // 无需登录
@GetMapping("/sticker-names")
public ResponseEntity<?> getStickerNames(
        @RequestHeader(value = "If-None-Match", required = false) String ifNoneMatch,
        HttpServletResponse response) {

    // 查询所有启用的贴纸
    LambdaQueryWrapper<TagDefinitionDO> wrapper = new LambdaQueryWrapper<>();
    wrapper.eq(TagDefinitionDO::getIsActive, true)
           .orderByAsc(TagDefinitionDO::getSortOrder);
    List<TagDefinitionDO> tags = tagDefinitionService.list(wrapper);

    // 生成版本号和 ETag
    String version = generateVersion(tags);
    String etag = "\"" + version + "\"";

    // 检查 ETag，匹配则返回 304
    if (etag.equals(ifNoneMatch)) {
        return ResponseEntity.status(HttpStatus.NOT_MODIFIED)
                .header("ETag", etag)
                .header("Cache-Control", "max-age=86400")
                .build();
    }

    // 构建名称映射 (tagCode -> tagName)
    Map<String, String> names = new LinkedHashMap<>();
    for (TagDefinitionDO tag : tags) {
        names.put(tag.getTagCode(), tag.getTagName());
    }

    // 返回响应
    // ...
}
```

### 版本号生成策略

```java
private String generateVersion(List<TagDefinitionDO> tags) {
    // 基于贴纸配置内容的哈希
    StringBuilder sb = new StringBuilder();
    for (TagDefinitionDO tag : tags) {
        sb.append(tag.getTagCode()).append(":").append(tag.getTagName()).append(";");
    }

    // 格式: 日期 + 哈希后4位
    String datePrefix = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
    int hash = Math.abs(sb.toString().hashCode());
    String hashSuffix = String.format("%04d", hash % 10000);

    return datePrefix + hashSuffix;
}
```

---

## 特性

| 特性 | 说明 |
|------|------|
| 权限 | 无需登录（`@AnonymousAccess`） |
| 数据来源 | `tag_definition` 表，`is_active=true` |
| 缓存策略 | ETag + 304 Not Modified |
| 缓存时间 | 24小时 (`max-age=86400`) |
| 返回格式 | `Map<tagCode, tagName>` |

---

## 与现有 API 对比

| 对比项 | /stickers/availability | /config/sticker-names |
|--------|------------------------|-----------------------|
| 需要登录 | 是 | 否 |
| 需要 shareId | 是 | 否 |
| 返回数据 | 完整可用性信息 | 仅名称映射 |
| 使用场景 | 进入分享详情页 | App 启动时预加载 |
| 数据量 | 较大 | 极小 |
| 缓存支持 | 无 | ETag + 304 |

---

## iOS 客户端集成

iOS 端可在 App 启动时调用此 API：
1. 缓存 `names` 映射到本地
2. 保存 `ETag` 供下次请求使用
3. `StickerDefinition.swift` 中的硬编码名称可改为从缓存读取

---

## Git 提交

**后端** (`Server/onettoo` - Zaptain 分支):
```
3a73e30 feat: 新增贴纸名称配置 API
```

**主仓库** (`guanzhi` - dev-x 分支):
```
c683a4d chore: 更新后端子模块引用
```
