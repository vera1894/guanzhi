# SSM 特殊字符转义问题及部署方案优化

**日期**: 2025-12-25
**执行者**: Claude Code
**类型**: 故障修复 + 流程优化

---

## 问题描述

部署评论删除行为修改后，服务出现 502 错误，管理后台和 iOS App 均无法访问。

### 症状
- 管理后台登录返回 502
- iOS App 分享详情评论消失
- 服务器日志显示 `Access denied for user 'root'@'localhost'`

---

## 根本原因

**AWS SSM 自动转义特殊字符**

通过 SSM `send-command` 传递的 shell 命令中，特殊字符会被自动转义：

| 原始值 | 转义后 |
|--------|--------|
| `oneAa123123!.` | `oneAa123123\!.` |
| `#!/bin/bash` | `#\!/bin/bash` |

导致数据库密码错误，应用无法连接数据库。

### 触发条件

```bash
# 这种方式会导致特殊字符被转义
aws ssm send-command --parameters 'commands=["export DB_PWD='\''oneAa123123!.'\''"]'
# SSM 实际执行的是: export DB_PWD='oneAa123123\!.'
```

---

## 解决方法

### 临时修复

在服务器上用 `sed` 修复被转义的脚本：

```bash
cd /home/ec2-user
sed -i 's/\\!/!/g' start.sh
bash start.sh
```

### 长期方案（已实施）

**方案1: 服务器上预置启动脚本**

1. 启动脚本 `/home/ec2-user/start.sh` 作为服务器固定文件
2. 部署时只下载 JAR 文件，然后执行 `bash start.sh`
3. **永远不要通过 SSM 重新生成脚本**

**标准部署流程**:

```bash
# 1. 本地：上传 JAR 到 S3
aws s3 cp target/onettoo-0.0.1-SNAPSHOT.jar s3://bucket/onettoo.jar --profile onettoo-cn

# 2. 本地：生成 presigned URL
PRESIGNED_URL=$(aws s3 presign s3://bucket/onettoo.jar --expires-in 3600 --profile onettoo-cn)

# 3. SSM：下载并重启（不重新生成脚本）
aws ssm send-command --parameters 'commands=[
  "pkill -9 -f '\''java.*jar'\'' || true",
  "sleep 2",
  "cd /home/ec2-user",
  "curl -o onettoo.jar '\''<PRESIGNED_URL>'\''",
  "bash start.sh",
  "sleep 10",
  "ps aux | grep java | grep -v grep"
]' --instance-ids "i-0f6e22ef4fb2d13df" ...
```

---

## 文档更新

已更新 `02_CONNECTIONS.private.md`:
- 版本 v1.2 → v1.3
- 新增推荐部署方式（方案1）
- 旧方式标记为"历史遗留"
- 添加 SSM 特殊字符转义警告
- 预留 systemd 服务方案（方案4）

---

## 经验教训

| 问题 | 教训 |
|------|------|
| SSM 转义特殊字符 | 不要通过 SSM 传递包含特殊字符的配置 |
| 每次重新生成脚本 | 固定配置应预置在服务器上，部署只更新代码 |
| 密码包含 `!` | 生产环境密码尽量避免 shell 特殊字符 |

---

## 后续优化建议

1. **短期**: 使用环境变量文件 `.env`，脚本中 `source .env`
2. **中期**: 将应用注册为 systemd 服务，环境变量配置在 service 文件
3. **长期**: 使用 AWS Secrets Manager 或 Parameter Store 管理敏感配置
