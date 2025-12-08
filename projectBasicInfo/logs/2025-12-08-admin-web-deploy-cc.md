# 操作日志：admin-web 部署到生产环境

**日期**: 2025-12-08
**操作人**: Claude Code (Opus 4.5)
**协作者**: Zaptain

---

## 任务目标

将 `admin-web/` 管理后台前端部署到生产服务器，通过 Nginx 提供静态文件服务，并配置 API 反向代理。

---

## 操作步骤

### 1. 修改前端配置

**文件**: `admin-web/.env.production`
```
# 设为空，让前端使用相对路径
VITE_API_BASE_URL=
```

**文件**: `admin-web/vite.config.js`
```javascript
base: mode === 'production' ? '/guanzhi-admin/' : '/',
```

**文件**: `admin-web/src/router/index.js`
```javascript
history: createWebHistory(import.meta.env.BASE_URL),
```

### 2. 构建前端

```bash
cd admin-web
npm install
npm run build
```

构建产物：`admin-web/dist/`

### 3. 复制到 Server 目录

```bash
cp -r admin-web/dist Server/onettoo/admin-web-dist
```

### 4. 提交到 Gitee

```bash
git add .
git commit -m "部署 admin-web 到生产环境：配置 /guanzhi-admin/ 路径"
git push origin Zaptain
```

### 5. 传输到服务器

由于 SSH 端口关闭，使用 S3 presigned URL：

```bash
# 本地打包
cd Server/onettoo
tar -czvf admin-web-dist.tar.gz admin-web-dist/

# 上传到 S3
aws s3 cp admin-web-dist.tar.gz s3://guanzhi-deploy-temp-20251208/ --profile onettoo-cn

# 生成 presigned URL
aws s3 presign s3://guanzhi-deploy-temp-20251208/admin-web-dist.tar.gz --expires-in 3600 --profile onettoo-cn --region cn-northwest-1

# 服务器下载
curl -o /tmp/admin-web-dist.tar.gz '<presigned-url>'
```

### 6. 服务器部署

```bash
# SSM 连接服务器
aws ssm start-session --target i-0f6e22ef4fb2d13df --region cn-northwest-1 --profile onettoo-cn

# 切换 root
sudo -i

# 解压到部署目录
cd /var/www
tar -xzvf /tmp/admin-web-dist.tar.gz
mv admin-web-dist guanzhi-admin
```

### 7. 配置 Nginx

创建 `/etc/nginx/conf.d/guanzhi-admin.conf`：

```nginx
server {
    listen 80;
    server_name _;

    # 管理后台静态文件
    location /guanzhi-admin/ {
        alias /var/www/guanzhi-admin/;
        index index.html;
        try_files $uri $uri/ /guanzhi-admin/index.html;
    }

    # 用户 API（登录、验证码）
    location /api/user/ {
        proxy_pass http://127.0.0.1:8085/user/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # 管理 API
    location /api/admin/ {
        proxy_pass http://127.0.0.1:8085/api/admin/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # 查询工具 API
    location /admin/inspector/ {
        proxy_pass http://127.0.0.1:8085/admin/inspector/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

重载 Nginx：
```bash
nginx -t
nginx -s reload
```

---

## 遇到的问题与解决

### 问题 1：SSH 端口关闭

**现象**: `scp` 和 `ssh` 命令无法连接
**解决**: 使用 AWS SSM 连接 + S3 presigned URL 传输文件

### 问题 2：登录失败 "无效的响应"

**现象**: 输入正确手机号和验证码后提示登录失败
**原因**: 后端返回 `{ datas: "token字符串" }` 而前端期望 `{ datas: { token: "..." } }`
**解决**: 修改 `Login.vue`：

```javascript
const token = typeof res.datas === 'string' ? res.datas : res.datas?.token
```

---

## 结果验证

- 访问地址：http://52.83.127.15/guanzhi-admin/
- 登录功能：正常（测试后门 admin/123456 可用）
- API 代理：正常（配置页面可加载数据）

---

## 相关 Git 提交

- `a6c6aa7` - 部署 admin-web 到生产环境：配置 /guanzhi-admin/ 路径
- `4329172` - 修复登录：适配后端 token 直接返回字符串的格式

---

## 后续待办

- [ ] 配置 HTTPS 证书
- [ ] 设置正式的管理员账号（替代测试后门）
- [ ] 添加访问日志监控
