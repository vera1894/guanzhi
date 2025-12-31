# APNs Bundle ID 修复日志

**日期**: 2025-12-30
**执行者**: Claude Code
**类型**: Bug 修复

---

## 问题描述

iOS 端无法收到来自后端的推送通知，但通过 Apple 网页控制台发送推送可以正常收到。

### 错误日志

```
Push rejected for token ae5ded893711615b...: TopicDisallowed
```

---

## 问题根因

服务器上存在外部配置文件 `/home/ec2-user/application-prod.yml`，其中 APNs 的 `bundle-id` 配置错误：

**错误配置**:
```yaml
apns:
  bundle-id: com.onetto  # 错误！
```

**正确配置**:
```yaml
apns:
  bundle-id: com.onettoo  # 正确！
```

### 为什么 JAR 内的正确配置没有生效？

Spring Boot 的配置优先级：外部配置文件 > JAR 内配置文件

服务器上的 `/home/ec2-user/application-prod.yml` 覆盖了 JAR 包内 `application.yml` 中的正确默认值。

---

## 修复步骤

### 1. 修复服务器外部配置文件

```bash
sed -i "s/bundle-id: com.onetto/bundle-id: com.onettoo/g" /home/ec2-user/application-prod.yml
```

### 2. 重启服务

```bash
pkill -9 -f 'java.*jar' || true
sleep 2
cd /home/ec2-user
bash start.sh
```

### 3. 验证修复

发送测试推送，日志显示：
```
Sending push via sandbox APNs - topic: com.onettoo, token: ae5ded893711615b...
```

iOS 端成功收到推送通知。

---

## 更新的文档

1. **03_CREDENTIALS.private.md** (v1.3)
   - 修正 Bundle ID 为 `com.onettoo`
   - 添加服务器配置文件位置和内容说明

2. **02_CONNECTIONS.private.md** (v1.4)
   - 添加 `/home/ec2-user/application-prod.yml` 到重要文件列表
   - 添加 `/home/ec2-user/AuthKey_ZV4BR5MCAF.p8` 到重要文件列表

---

## 经验教训

1. **外部配置文件优先级高于 JAR 内配置** - 修改 JAR 内配置后，如果服务器有同名外部配置文件，必须同步修改外部配置

2. **APNs Bundle ID 必须精确匹配** - `com.onetto` vs `com.onettoo` 一个字母之差导致 `TopicDisallowed` 错误

3. **调试 APNs 问题的关键日志**:
   ```bash
   grep -E "Sending push|rejected|accepted|topic" /home/ec2-user/app.log
   ```

---

## 相关文件

| 文件 | 修改内容 |
|------|----------|
| `/home/ec2-user/application-prod.yml` | bundle-id: com.onetto → com.onettoo |
| `projectBasicInfo/02_CONNECTIONS.private.md` | 添加外部配置文件和 APNs 密钥文件 |
| `projectBasicInfo/03_CREDENTIALS.private.md` | 修正 Bundle ID，添加服务器配置说明 |
