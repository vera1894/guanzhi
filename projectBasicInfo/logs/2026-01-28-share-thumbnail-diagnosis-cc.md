# Share 缩略图诊断与文档更新

**日期**: 2026-01-28
**操作者**: Claude Code
**类型**: 问题诊断 + 文档更新

---

## 任务描述

用户报告 share id=106 没有缩略图，需要诊断原因。

## 诊断过程

### 1. 数据库检查

查询 `guanzhi` 表确认记录存在：

```sql
SELECT id, image_path FROM guanzhi WHERE id=106;
```

结果：记录存在，`image_path` 包含缩略图路径：
```
image/11_1769590340752_89412_thumbnail-1769590345319-20260128085225478.jpg
```

### 2. 文件系统检查

确认文件存在：
```bash
ls -la /home/ec2-user/images/image/11_1769590340752_89412_thumbnail-1769590345319-20260128085225478.jpg
# 结果：文件存在，大小 633647 字节（约 619KB）
```

### 3. HTTP 访问测试

**问题发现**：localhost 请求返回 404

```bash
# 返回 404
curl -I http://localhost/image/xxx.jpg

# 返回 200
curl -I -H "Host: onettoo.com" http://localhost/image/xxx.jpg
```

**根本原因**：Nginx server block 配置了 `server_name onettoo.com`，localhost 请求不匹配该 server block。

### 4. 外部访问验证

```bash
curl -sI "https://onettoo.com/image/11_1769590340752_89412_thumbnail-1769590345319-20260128085225478.jpg"
# HTTP/1.1 200 OK
# Content-Type: image/jpeg
# Content-Length: 633647
```

## 结论

**缩略图正常工作**。之前的 404 问题是测试方法错误（localhost 不带 Host 头）。

## 文档更新

### 99_SERVER_OPERATIONS_RULES.md (v2.1 → v2.2)

新增内容：
1. **Nginx Host 头问题说明**：测试静态文件时必须带正确的 Host 头
2. **SSM MySQL 命令转义示例**：通过 SSM send-command 执行 MySQL 查询的正确转义方式
3. **常用表名列表**：guanzhi、user、share_comment、share_vote
4. **EBS 扩容步骤**：growpart + xfs_growfs

### 02_CONNECTIONS.private.md (v1.8 → v1.9)

更新内容：
1. 服务端口表添加 HTTPS 443 端口
2. 添加域名说明（onettoo.com，已配置 SSL）

---

## 经验总结

| 问题 | 解决方案 |
|------|----------|
| 静态文件 404 | 检查是否使用正确的 Host 头 |
| SSM MySQL 命令失败 | 使用 `sudo bash -c "export $(cat ...) && mysql -u\$DB_USER..."` 格式 |
| 表名混淆 | 观之主表是 `guanzhi`，不是 `share` |

---

## 相关文件

- `99_SERVER_OPERATIONS_RULES.md` - 已更新
- `02_CONNECTIONS.private.md` - 已更新
