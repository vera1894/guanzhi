# Guanzhi 后台管理工具 - 部署与接入8085生产环境指南

## 📋 项目现状总结（2025-12-07）

### 前端项目信息
- **项目路径**: `/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/guanzhi/admin-web`
- **技术栈**: Vue 3 + Vite + Element Plus + Axios
- **Node版本要求**: >= 20.19.0
- **当前状态**: ✅ V1已完成，已配置支持8085生产环境

### 后端服务信息
- **生产环境**: http://52.83.127.15:8085
- **本地开发**: http://localhost:8085
- **Inspector API**: ✅ 已部署并验证
- **管理员账号**: 15810349766 (role: ADMIN)

---

## 🚀 本地开发快速开始

### 1. 安装依赖

```bash
cd "/Users/zaptain/Library/Mobile Documents/com~apple~CloudDocs/DarkForce/Seee/guanzhi/admin-web"
npm install
```

### 2. 启动开发服务器

**连接本地后端（默认）**:
```bash
npm run dev
```
访问: http://localhost:5173

**连接8085生产后端**:
```bash
# 方式1: 修改 .env.development 文件
# 将 VITE_API_BASE_URL 改为 http://52.83.127.15:8085

# 方式2: 临时指定环境变量启动
VITE_API_BASE_URL=http://52.83.127.15:8085 npm run dev
```

### 3. 管理员登录

**手机号**: `15810349766`
**验证码**: 登录时发送到该手机号

> ⚠️ 注意：当前版本登录页还保留了测试后门（admin/123456），仅用于前端演示。生产环境请使用手机号+验证码登录。

---

## 🔧 环境配置说明

### 环境变量文件

#### `.env.development` (开发环境)
```bash
VITE_API_BASE_URL=http://localhost:8085
```

#### `.env.production` (生产环境)
```bash
VITE_API_BASE_URL=http://52.83.127.15:8085
```

### vite.config.js 代理配置

开发环境使用代理解决CORS问题：
```javascript
server: {
  proxy: {
    '/api': {
      target: 'http://localhost:8085',  // 或 http://52.83.127.15:8085
      changeOrigin: true
    }
  }
}
```

---

## 📦 Inspector API 接入清单

### 当前前端已使用的API

#### 1. 登录相关
- `POST /user/sendCode` - 发送短信验证码
- `POST /user/checkCodeOrLogin` - 验证码登录
- `POST /user/info` - 获取用户信息

#### 2. 配置管理
- `GET /admin/config/fade-configs` - 获取褪色配置
- `GET /admin/config/points-rules` - 获取积分规则
- `GET /admin/config/levels` - 获取等级定义
- `POST /admin/fade/simulate` - 褪色曲线模拟

#### 3. Inspector API（新增）

**用户详情查询**:
```
GET /admin/inspector/user/{userId}
Authorization: Bearer {admin_token}

响应示例:
{
  "respCode": 0,
  "respMsg": "请求成功",
  "datas": {
    "userId": "11",
    "nickname": "嗷嗷嗷",
    "pointsTotal": 14,
    "levelCode": "YOMIN",
    "shareCount": 76,
    ...
  }
}
```

**分享详情查询**:
```
GET /admin/inspector/share/{shareId}
Authorization: Bearer {admin_token}

响应示例:
{
  "respCode": 0 | 1001,
  "respMsg": "请求成功" | "分享不存在",
  "datas": { ... }
}
```

### Inspector前端页面状态

✅ **已完成**: Inspector页面已实现并配置路由
- `src/views/inspector/UserDetail.vue` - 用户详情查询 (路由: `/inspector/user`)
- `src/views/inspector/ShareDetail.vue` - 分享详情查询 (路由: `/inspector/share`)
- `src/utils/inspectorRequest.js` - Inspector专用请求工具 (处理 `/admin` 路径)

---

## 🏗️ 生产构建与部署

### 1. 构建生产版本

```bash
npm run build
```

构建产物位于 `dist/` 目录

### 2. 部署建议方案（Nginx）

#### Nginx配置示例

```nginx
server {
    listen 80;
    server_name admin.onettoo.com;  # 或使用IP

    # 前端静态文件
    location / {
        root /var/www/admin-web/dist;
        try_files $uri $uri/ /index.html;
        index index.html;
    }

    # 后端API反向代理
    location /api/ {
        proxy_pass http://52.83.127.15:8085/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Inspector API反向代理
    location /admin/ {
        proxy_pass http://52.83.127.15:8085/admin/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Authorization $http_authorization;
    }
}
```

#### 部署步骤

1. 本地构建：
```bash
npm run build
```

2. 上传到服务器：
```bash
scp -r dist/* user@server:/var/www/admin-web/dist/
```

3. 配置并重启Nginx：
```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 🔒 CORS配置说明

### 当前状态
- **开发环境**: 使用Vite代理，无CORS问题
- **生产环境**: 建议使用Nginx反向代理统一域名

### 如需在8085上配置CORS

⚠️ **变更前提醒**:
1. 仅针对后台管理域名开放CORS
2. 不要使用 `*` 通配符
3. 确保不影响iOS App的正常使用

**Spring Boot配置示例** (仅作参考，需确认后再修改):
```java
@Configuration
public class CorsConfig implements WebMvcConfigurer {
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/admin/**")
                .allowedOrigins("http://admin.onettoo.com")  // 仅允许后台域名
                .allowedMethods("GET", "POST", "PUT", "DELETE")
                .allowedHeaders("*")
                .allowCredentials(true);
    }
}
```

---

## 📱 功能清单

### ✅ 已实现功能
- 🔐 手机号+验证码登录（测试后门：admin/123456）
- ⭐ 褪色曲线模拟器
- ⚙️ 配置管理（褪色、积分、等级、标签）
- 📊 ECharts数据可视化
- 👤 Inspector - 用户详情查询
- 📄 Inspector - 分享详情查询
- 🔄 支持本地开发/生产环境切换

### 💡 后续优化建议
- 🔍 添加批量查询功能
- 📝 添加查询历史记录
- 📊 Inspector查询结果可视化
- 🎨 优化Inspector页面UI/UX

---

## 🐛 常见问题

### Q1: 前端连接8085生产环境时出现CORS错误

**解决方案**:
1. 检查vite.config.js中的proxy配置是否指向正确的后端地址
2. 确认8085服务是否正常运行：`curl http://52.83.127.15:8085/api/guan/user/info`
3. 如确需CORS，按上述配置说明修改后端（需确认）

### Q2: 登录后Inspector API返回401

**原因**: Token无ADMIN权限

**解决方案**:
1. 确认使用管理员账号登录（15810349766）
2. 检查数据库 `userlist` 表中该用户的 `role` 字段是否为 `ADMIN`
3. 重新登录获取新token

### Q3: 打包后部署到服务器，API请求失败

**原因**: 生产环境API地址配置不正确

**解决方案**:
1. 检查 `.env.production` 文件
2. 确保使用 `npm run build` 而不是 `npm run dev` 构建
3. 检查Nginx配置中的proxy_pass地址

---

## 📊 项目文件结构

```
admin-web/
├── .env.development          # 开发环境变量
├── .env.production           # 生产环境变量
├── src/
│   ├── views/
│   │   ├── Login.vue        # 登录页
│   │   ├── Dashboard.vue    # 仪表盘
│   │   ├── FadeSimulation.vue # 褪色模拟器
│   │   └── config/          # 配置管理页面
│   ├── utils/
│   │   └── request.js       # Axios封装 + JWT自动添加
│   └── router/
│       └── index.js         # 路由配置 + 登录守卫
├── vite.config.js           # Vite配置 + 代理
└── DEPLOYMENT.md            # 本文档
```

---

## 🔑 关键代码说明

### Token管理 (src/utils/request.js)

```javascript
// 自动为所有请求添加JWT Token
service.interceptors.request.use(config => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers['Authorization'] = 'Bearer ' + token
  }
  return config
})

// 401自动跳转登录
service.interceptors.response.use(
  response => response.data,
  error => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token')
      router.push('/login')
    }
    return Promise.reject(error)
  }
)
```

---

## 📝 下一步开发建议

### 1. 添加Inspector页面

创建 `src/views/inspector/` 目录，添加：

**UserDetail.vue** - 用户详情查询:
```vue
<template>
  <el-form inline>
    <el-form-item label="用户ID">
      <el-input v-model="userId" placeholder="输入用户ID" />
    </el-form-item>
    <el-button @click="queryUser">查询</el-button>
  </el-form>

  <el-card v-if="userDetail">
    <el-descriptions :column="2">
      <el-descriptions-item label="昵称">{{ userDetail.nickname }}</el-descriptions-item>
      <el-descriptions-item label="积分">{{ userDetail.pointsTotal }}</el-descriptions-item>
      <!-- 更多字段 -->
    </el-descriptions>
  </el-card>
</template>

<script setup>
import { ref } from 'vue'
import request from '@/utils/request'

const userId = ref('')
const userDetail = ref(null)

const queryUser = async () => {
  const res = await request.get(`/admin/inspector/user/${userId.value}`)
  userDetail.value = res.datas
}
</script>
```

### 2. 更新路由

在 `src/router/index.js` 添加：
```javascript
{
  path: '/inspector/user',
  component: () => import('../views/inspector/UserDetail.vue'),
  meta: { requiresAuth: true }
}
```

---

## 📞 联系方式

- **项目负责人**: Zaptain
- **前端开发**: Claude Code (Anthropic)
- **最后更新**: 2025-12-07

---

**本文档状态**: ✅ 完成配置接入8085生产环境
**Inspector页面**: ✅ 已完成开发并配置路由
**部署状态**: 📦 待部署（可本地启动测试）
**最后更新**: 2025-12-07
