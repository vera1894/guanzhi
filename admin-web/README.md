# Guanzhi 后台管理工具 - 前端项目

**项目名称**: admin-web
**框架版本**: Vue 3 + Vite
**UI库**: Element Plus
**项目状态**: ✅ V1开发完成

---

## 📋 项目简介

这是 Guanzhi 应用的后台管理工具前端项目，用于管理应用的核心配置和模拟算法行为。

### 核心功能
- 🔐 **JWT认证登录**
- ⭐ **褪色曲线模拟器** - 可视化展示分享内容的褪色趋势（核心创新功能）
- ⚙️ **配置管理**
  - 褪色规则配置
  - 积分规则配置
  - 等级定义管理
  - 标签定义管理
- 📊 **数据可视化** - 基于ECharts的图表展示

---

## 🚀 快速开始

### 前置要求

- Node.js >= 16.x
- npm >= 8.x
- 后端服务运行在 `http://localhost:8085`

### 安装依赖

```bash
npm install
```

### 开发模式运行

```bash
npm run dev
```

访问: http://localhost:5173

### 生产构建

```bash
npm run build
```

构建产物位于 `dist/` 目录

---

## 🏗️ 技术栈

### 核心框架
- **Vue 3** (^3.5.13) - 渐进式JavaScript框架
- **Vite** (^6.0.3) - 下一代前端构建工具
- **Vue Router** (^4.4.5) - Vue官方路由管理器
- **Pinia** (^2.3.0) - Vue官方状态管理库

### UI & 可视化
- **Element Plus** (^2.9.1) - Vue 3组件库
- **@element-plus/icons-vue** (^2.3.1) - Element Plus图标库
- **ECharts** (^5.5.1) - 数据可视化库

### HTTP & 工具
- **Axios** (^1.7.9) - HTTP客户端
- **Sass** (^1.83.0) - CSS预处理器

---

## 📁 项目结构

```
admin-web/
├── src/
│   ├── views/                      # 页面组件
│   │   ├── Login.vue              # 登录页面
│   │   ├── Dashboard.vue          # 仪表盘
│   │   ├── FadeSimulation.vue     # 褪色模拟器（核心功能）
│   │   └── config/                # 配置管理页面
│   │       ├── FadeConfig.vue     # 褪色规则配置
│   │       ├── PointsRule.vue     # 积分规则配置
│   │       ├── LevelDefinition.vue # 等级定义管理
│   │       └── TagDefinition.vue   # 标签定义管理
│   │
│   ├── layout/                    # 布局组件
│   │   └── Layout.vue            # 主布局（侧边栏+Header）
│   │
│   ├── router/                    # 路由配置
│   │   └── index.js              # 路由定义和守卫
│   │
│   ├── utils/                     # 工具函数
│   │   └── request.js            # Axios封装
│   │
│   ├── App.vue                   # 根组件
│   └── main.js                   # 入口文件
│
├── public/                        # 静态资源
├── dist/                          # 构建产物
├── vite.config.js                # Vite配置
└── package.json                  # 项目依赖
```

---

## 🔧 核心配置

### Vite配置 (vite.config.js)

```javascript
export default defineConfig({
  plugins: [
    vue(),
    vueDevTools()
  ],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8085',
        changeOrigin: true
      }
    }
  }
})
```

### 环境变量

开发环境 (`.env.development`):
```bash
VITE_API_BASE_URL=http://localhost:8085/api
```

生产环境 (`.env.production`):
```bash
VITE_API_BASE_URL=https://onettoo.com/api
```

---

## 🛣️ 路由结构

```
/login                    # 登录页面（无需认证）
/                         # 主布局（需要认证）
  ├── /dashboard          # 仪表盘
  ├── /fade-simulation    # 褪色模拟器
  └── /config/            # 配置管理
      ├── fade            # 褪色规则配置
      ├── points          # 积分规则配置
      ├── levels          # 等级定义管理
      └── tags            # 标签定义管理
```

### 路由守卫

所有需要认证的路由都会检查 localStorage 中的 token，未登录用户会自动跳转到登录页。

```javascript
router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('token')
  if (to.path !== '/login' && !token) {
    next('/login')
  } else {
    next()
  }
})
```

---

## 🔌 API集成

### Axios封装 (src/utils/request.js)

#### 请求拦截器
自动为所有请求添加 JWT Token:

```javascript
request.interceptors.request.use(config => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers['Authorization'] = `Bearer ${token}`
  }
  return config
})
```

#### 响应拦截器
统一处理错误和401未授权:

```javascript
request.interceptors.response.use(
  response => {
    const res = response.data
    if (res.respCode !== 0 && res.respCode !== 200) {
      ElMessage.error(res.respMsg || '请求失败')
      return Promise.reject(new Error(res.respMsg))
    }
    return res
  },
  error => {
    if (error.response?.status === 401) {
      ElMessage.error('登录已过期，请重新登录')
      localStorage.removeItem('token')
      router.push('/login')
    }
    return Promise.reject(error)
  }
)
```

---

## 📦 主要功能模块

### 1. 登录模块 (Login.vue)

**功能**:
- 用户名/密码登录
- JWT Token获取和存储
- 自动跳转到仪表盘

**演示后门** (仅用于前端演示):
- 用户名: `admin`
- 密码: `123456`

**API接口**:
```javascript
POST /api/guan/login
{
  "phone": "用户名/手机号",
  "password": "密码"
}
```

---

### 2. 褪色模拟器 (FadeSimulation.vue) ⭐

**功能**:
- 输入测试数据（阅读人数、标签数、模拟天数）
- 调用后端接口计算褪色曲线
- ECharts折线图展示褪色趋势
- 显示配置信息和预计褪色时间

**API接口**:
```javascript
POST /api/admin/fade/simulate
{
  "viewCount": 50,
  "tagCount": 2,
  "simulateDays": 90
}
```

**响应数据**:
```javascript
{
  "respCode": 0,
  "datas": {
    "timeline": [1, 3, 7, 15, 30, 60, 90],      // 时间轴
    "fadeScores": [5, 15, 35, 75, 100, 100, 100], // 褪色分数
    "currentFadeScore": 5,                       // 当前分数
    "estimatedFadeDays": 30,                     // 预计褪色天数
    "dailyFadeIncrement": 5.0,                   // 每日褪色增量
    "configInfo": "基础褪色: 6/天..."           // 配置信息
  }
}
```

**图表配置**:
- 使用 ECharts 的 line 类型
- X轴: 天数
- Y轴: fadeScore (0-100)
- 自动标注关键点

---

### 3. 配置管理模块

#### 褪色规则配置 (FadeConfig.vue)
- 管理褪色计算的各项参数
- 支持CRUD操作
- 表格展示 + 弹窗表单

**字段**:
- `configKey`: 配置键
- `configValue`: 配置值
- `description`: 描述

#### 积分规则配置 (PointsRule.vue)
- 管理各类操作的积分奖励
- 积分值颜色标签（正负不同颜色）

**字段**:
- `actionType`: 操作类型
- `pointsValue`: 积分值
- `dailyLimit`: 每日上限

#### 等级定义管理 (LevelDefinition.vue)
- 管理用户等级体系
- 结构化表单（避免JSON输入）

**字段**:
- `levelCode`: 等级代码
- `levelName`: 等级名称
- `minPoints`: 最低积分
- `minCheckins`: 最低打卡数
- `minComments`: 最低评论数
- `taggingAllowance`: 贴标签额度

#### 标签定义管理 (TagDefinition.vue)
- 管理可贴标签的定义
- 标签类型标签化显示

**字段**:
- `tagName`: 标签名称
- `type`: 标签类型（POSITIVE/NEGATIVE）
- `weight`: 权重
- `description`: 描述

---

## 🎨 UI组件使用

### Element Plus组件

**常用组件**:
- `el-container` / `el-aside` / `el-main` - 布局容器
- `el-menu` - 侧边栏菜单
- `el-table` - 数据表格
- `el-form` - 表单
- `el-dialog` - 弹窗
- `el-button` - 按钮
- `el-input` - 输入框
- `el-message` - 消息提示
- `el-message-box` - 确认框

### ECharts图表

**褪色曲线图配置**:
```javascript
const option = {
  title: { text: '褪色分数变化曲线' },
  tooltip: { trigger: 'axis' },
  xAxis: {
    type: 'category',
    data: timeline,  // [1, 3, 7, 15, 30, 60, 90]
    name: '天数'
  },
  yAxis: {
    type: 'value',
    name: 'fadeScore',
    min: 0,
    max: 100
  },
  series: [{
    type: 'line',
    data: fadeScores,
    smooth: true,
    itemStyle: { color: '#409EFF' }
  }]
}
```

---

## 🔒 安全机制

### JWT Token管理

**存储位置**: localStorage

**Token格式**:
```
Authorization: Bearer eyJhbGc...
```

**Token失效处理**:
1. 后端返回401状态码
2. 前端清除本地Token
3. 自动跳转到登录页
4. 提示用户重新登录

---

## 🐛 调试工具

### Vue DevTools

推荐安装 Vue.js devtools 浏览器扩展:
- Chrome: [Vue.js devtools](https://chromewebstore.google.com/detail/vuejs-devtools/nhdogjmejiglipccpnnnanhbledajbpd)
- Firefox: [Vue.js devtools](https://addons.mozilla.org/en-US/firefox/addon/vue-js-devtools/)

### 开发服务器

Vite提供的热更新功能，修改代码后自动刷新页面。

### 网络请求调试

使用浏览器开发者工具的Network面板查看API请求和响应。

---

## 📝 开发规范

### 代码风格
- 使用ES6+语法
- 组件使用 Composition API
- 异步操作使用 async/await
- 使用ESLint进行代码检查

### 命名规范
- 组件文件: PascalCase (例如: `FadeConfig.vue`)
- 方法名: camelCase (例如: `handleSubmit`)
- 常量: UPPER_CASE (例如: `API_BASE_URL`)

### Git提交规范
```bash
feat: 新功能
fix: 修复bug
docs: 文档更新
style: 代码格式调整
refactor: 重构
test: 测试相关
chore: 构建配置相关
```

---

## 🚀 部署

### 构建命令

```bash
npm run build
```

### 构建产物

```
dist/
├── index.html
├── assets/
│   ├── index-[hash].js
│   ├── index-[hash].css
│   └── ...
└── ...
```

### Nginx配置

```nginx
server {
    listen 443 ssl;
    server_name onettoo.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # 前端静态文件
    location /admin {
        alias /var/www/admin-panel/dist;
        try_files $uri $uri/ /admin/index.html;
        index index.html;
    }

    # 后端API代理
    location /api/ {
        proxy_pass http://localhost:8085;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### 部署步骤

1. 本地构建:
```bash
npm run build
```

2. 上传到服务器:
```bash
scp -r dist/* user@onettoo.com:/var/www/admin-panel/dist/
```

3. 重启Nginx:
```bash
sudo systemctl reload nginx
```

4. 访问:
```
https://onettoo.com/admin
```

---

## 🐞 常见问题

### 1. 代理不工作，API请求失败

**原因**: 后端服务未启动或端口不正确

**解决**:
```bash
# 检查后端服务是否运行
curl http://localhost:8085/api/guan/user/info

# 检查vite.config.js中的proxy配置
```

### 2. 登录后Token未生效

**原因**: localStorage存储失败或Token格式不正确

**解决**:
```javascript
// 检查浏览器控制台
console.log(localStorage.getItem('token'))

// 检查Network面板中的Authorization header
```

### 3. ECharts图表不显示

**原因**: ECharts未正确初始化或数据格式不正确

**解决**:
```javascript
// 确保在DOM挂载后初始化
onMounted(() => {
  const chartDom = document.getElementById('fade-chart')
  const myChart = echarts.init(chartDom)
  myChart.setOption(option)
})
```

### 4. Element Plus组件样式异常

**原因**: 未正确导入Element Plus样式

**解决**:
```javascript
// main.js中确保导入了样式
import 'element-plus/dist/index.css'
```

---

## 📚 相关文档

- [V1项目进度总结](../重要项目信息/V1项目进度总结.md)
- [项目结构说明](../重要项目信息/项目结构说明.md)
- [后端API文档](../Server/onettoo/README.md)
- [Vue 3官方文档](https://cn.vuejs.org/)
- [Vite官方文档](https://cn.vitejs.dev/)
- [Element Plus官方文档](https://element-plus.org/zh-CN/)
- [ECharts官方文档](https://echarts.apache.org/zh/index.html)

---

## 🤝 开发团队

- **需求方**: Zaptain
- **前端开发**: Claude Code (Anthropic)
- **技术栈选型**: Vue 3 + Vite + Element Plus + ECharts

---

## 📄 许可证

本项目仅供内部使用，未开源。

---

**项目版本**: V1
**最后更新**: 2025-12-01
**文档维护**: Claude Code
