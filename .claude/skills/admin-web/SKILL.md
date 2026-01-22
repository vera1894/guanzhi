---
name: admin-web
description: 管理后台（Vue 3 + Vite）开发指南，进入前端代码前的必读清单。
---

# Admin-Web 前端技能

当用户进行后台前端开发时，按以下顺序执行：

## 先读文档（必做）
1. `projectBasicInfo/00_AGENT_RULES.md` - 通用规则、术语与日志要求
2. `projectBasicInfo/01_PROJECT_OVERVIEW.md` - Monorepo 结构、admin-web 入口
3. `admin-web/README.md` - 本项目快速开始与目录说明

## 环境与命令
- Node.js ≥ 16，使用 npm
- 开发：`cd admin-web && npm run dev`（默认后端 `http://localhost:8085`）
- 构建：`npm run build`，产物在 `admin-web/dist/`

## 目录与关键文件
- `src/views/`：业务页面（登录、仪表盘、褪色模拟器、配置管理等）
- `src/router/index.js`：路由和守卫
- `src/utils/request.js`：Axios 封装，注意基地址/拦截器
- `vite.config.js`：构建与代理配置

## 术语与接口约束
- UI 文案用「观之」，代码模型保持 `Share`/`share` 命名，不随意改字段/路径
- 涉及后端交互时对照 00/04 术语规范，避免命名漂移

## 操作规范
- 先阅读现有实现再改动，保持最小侵入
- 配置变更/接口调整需要验证 dev/build 通过
- 重大改动需在 `projectBasicInfo/logs/` 记录，命名 `YYYY-MM-DD-主题-角色.md`
