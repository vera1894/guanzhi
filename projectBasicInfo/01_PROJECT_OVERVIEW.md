# 观之（Guanzhi）项目概述

**文档版本**: v1.3
**最后更新**: 2025-12-19

---

## 项目简介

**观之**是一个基于位置的社交分享平台，用户可以在地图上分享和发现内容。项目采用 Monorepo 结构，包含 iOS 客户端、Java 后端服务和 Vue 管理后台。

---

## 项目结构

```
guanzhi/                          # 项目根目录
│
├── guanzhi/                      # iOS 客户端
│   ├── View/                     # SwiftUI 视图
│   ├── Data/                     # 数据模型
│   ├── ModelsForNetwork/         # 网络请求模型
│   ├── ModelsForMap/             # 地图相关模型
│   ├── CameraViews/              # 相机视图
│   └── CaptureFunctions/         # 拍摄功能
│
├── Server/onettoo/               # Java 后端
│   ├── src/main/java/            # Java 源码
│   │   └── com/example/onettoo/
│   │       ├── controller/       # 控制器
│   │       ├── service/          # 服务层
│   │       ├── mapper/           # MyBatis Mapper
│   │       ├── model/            # 数据模型
│   │       └── dto/              # 数据传输对象
│   └── src/main/resources/       # 配置文件
│
├── admin-web/                    # 管理后台（Vue 3）
│   ├── src/views/                # 页面组件
│   ├── src/router/               # 路由配置
│   ├── src/utils/                # 工具函数
│   └── dist/                     # 构建产物
│
├── projectBasicInfo/             # 项目基础信息（本目录）
├── 重要项目信息/                  # 开发文档
└── 后端升级设计文档/              # 设计文档
```

---

## 技术栈

### iOS 客户端 (`guanzhi/`)

| 项目 | 技术 |
|------|------|
| 框架 | SwiftUI |
| 最低版本 | iOS 17.0 |
| 架构模式 | MVVM |
| 网络请求 | Alamofire |
| 包管理 | CocoaPods |
| 状态管理 | ObservableObject + Environment |

**打开方式**：
```bash
open guanzhi.xcworkspace
```

### Java 后端 (`Server/onettoo/`)

| 项目 | 技术 |
|------|------|
| 框架 | Spring Boot 2.6.3 |
| JDK | Java 17 |
| ORM | MyBatis-Plus 3.5.1 |
| 安全 | Spring Security + JWT |
| 数据库 | MySQL 9.x |
| 缓存 | Redis |
| 连接池 | Druid 1.2.20 |

**本地启动**：
```bash
cd Server/onettoo
./mvnw spring-boot:run
# 服务端口: 8085
```

### 管理后台 (`admin-web/`)

| 项目 | 技术 |
|------|------|
| 框架 | Vue 3 |
| 构建工具 | Vite |
| UI 库 | Element Plus |
| 图表 | ECharts |
| HTTP | Axios |
| 路由 | Vue Router |
| 状态管理 | Pinia |

**本地开发**：
```bash
cd admin-web
npm install
npm run dev
# 访问: http://localhost:5173
```

**生产构建**：
```bash
npm run build
# 产物目录: dist/
# 部署路径: /guanzhi-admin/
```

---

## 核心功能模块

### 1. 分享系统（Share）

- 用户在地图上发布分享（文字、图片、Live Photo）
- 分享可被查看、点赞、评论
- 分享有"褪色"机制（随时间衰减）

### 2. 褪色系统（Fade）

- 分享发布后，随时间逐渐"褪色"
- 褪色速度受阅读量、标签、互动影响
- 管理后台提供褪色曲线模拟器

### 3. 积分与等级系统

- 用户行为产生积分（发布、点赞、评论等）
- 积分累计可升级等级
- 等级影响贴标签额度等权益

### 4. 贴纸配额系统（Sticker Quota）

统一的贴纸（Sticker）概念，包含 vote（赞同/无感）和 tag（秘境/珍馐等）：

**核心规则**：
- 任何贴纸对同一条分享、同一用户，只允许使用一次，不可撤回
- vote 类贴纸（LIKE/NEUTRAL）互斥，tag 类贴纸独立

**iOS 客户端实现**：
- 贴纸定义位于 `guanzhi/View/Features/StickerKit/Models/StickerDefinition.swift`
- **贴纸名称（displayName）目前是前端硬编码**，未从服务器获取
- 当前所有贴纸名称均为 2 个中文字符（赞同、无感、秘境、珍馐、玩趣、踩坑、猫猫、朝圣、日出、集市）
- TODO：后续可改为从服务器 API 获取贴纸名称（API 已返回 `stickerName` 字段）

**配额计算**：
```
用户每日可用次数 = 贴纸的「基础限额」 × 用户等级的「配额倍率」
```

**等级解锁**：
- 每个贴纸可配置「解锁等级」（minLevelCode）
- 只有达到该等级的用户才能使用该贴纸
- 留空表示全员可用

**日切规则**：
- 时区：Asia/Shanghai
- 日切点：每天 04:00
- 配额重置时间：每天 04:00

**技术实现**：
- Redis Lua 脚本实现原子配额扣减
- 数据库唯一约束保证去重和互斥
- 04:00 定时任务应用待生效配置

### 5. 管理后台

- 褪色曲线模拟器（核心功能）
- 褪色规则配置
- 积分规则配置
- 等级定义管理（配额倍率、待生效配置）
- 贴纸定义管理（解锁等级、基础限额、待生效配置）
- 用户/分享查询工具

---

## 环境与部署

### 开发环境

| 组件 | 地址 |
|------|------|
| 前端 | http://localhost:5173 |
| 后端 | http://localhost:8085 |
| MySQL | localhost:3306/ONETTOO |
| Redis | localhost:6379 |

### 生产环境

| 组件 | 地址 |
|------|------|
| 服务器 | 52.83.127.15 (AWS 宁夏) |
| 管理后台 | http://52.83.127.15/guanzhi-admin/ |
| 后端 API | http://52.83.127.15:8085 |
| 连接方式 | AWS SSM (非 SSH) |

详细连接信息见 `02_CONNECTIONS.private.md`

---

## API 路由说明

### 后端 API 路由模式

```
/user/**            # 用户相关（登录、验证码等）
/guan/**            # 分享业务 API（需登录）
/stickers/**        # 贴纸 API（需登录）
/shares/**          # 分享操作 API（需登录）
/api/admin/**       # 管理后台 API（需 ADMIN 权限）
/admin/inspector/** # 查询工具 API
```

### iOS App 贴纸相关 API

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 获取贴纸可用性 | GET | `/api/stickers/availability?shareId=X` | 返回所有贴纸的可用状态 |
| 使用贴纸 | POST | `/api/shares/{shareId}/stickers/use` | 使用贴纸，扣减配额 |

**获取贴纸可用性响应**：
```json
{
  "respCode": 0,
  "datas": {
    "stickers": [
      {
        "stickerId": "ZHENXIU",
        "stickerName": "珍馐",
        "group": "tag",
        "unlocked": true,
        "dailyLimit": 20,
        "usedToday": 5,
        "remainingToday": 15,
        "alreadyApplied": false,
        "minLevelCode": "YOMIN",
        "minLevelName": "游民"
      }
    ]
  }
}
```

**使用贴纸请求**：
```json
{ "stickerId": "ZHENXIU" }
```

**使用贴纸成功响应**：
```json
{
  "respCode": 0,
  "datas": {
    "success": true,
    "remainingToday": 14,
    "usedToday": 6
  }
}
```

**使用贴纸失败响应**：
```json
{
  "respCode": 0,
  "datas": {
    "success": false,
    "remainingToday": 0,
    "errorCode": "QUOTA_EXCEEDED",
    "errorMessage": "今日「珍馐」使用次数已用完"
  }
}
```

### Nginx 代理规则（生产环境）

```
/guanzhi-admin/   → 静态文件 (/var/www/guanzhi-admin/)
/api/user/        → http://127.0.0.1:8085/user/
/api/admin/       → http://127.0.0.1:8085/api/admin/
/api/             → http://127.0.0.1:8085/ (去掉 /api 前缀)
/admin/inspector/ → http://127.0.0.1:8085/admin/inspector/
```

---

## 数据库核心表

| 表名 | 用途 |
|------|------|
| `user` | 用户信息 |
| `share` / `guanzhi` | 分享内容 |
| `fade_config` | 褪色配置 |
| `points_rule` | 积分规则 |
| `level_definition` | 等级定义（含 daily_multiplier 配额倍率）|
| `tag_definition` | 贴纸定义（含 min_level_code、base_daily_limit）|
| `share_sticker_action` | 贴纸使用记录（事实来源表）|
| `sticker_level_quota_override` | 等级-贴纸限额覆盖配置 |
| `admin_operation_log` | 管理操作日志 |

---

## Git 仓库

### 远程仓库

- **Gitee**: https://gitee.com/cxy1992/onettoo/tree/Zaptain/

### 分支策略

- `master`: 生产环境
- `Zaptain`: 开发分支（当前工作分支）

### 注意事项

- 服务器无法直接 `git clone`（需认证）
- 部署文件通过 S3 presigned URL 传输

---

## 相关文档索引

| 文档 | 路径 | 说明 |
|------|------|------|
| 项目结构说明 | `重要项目信息/项目结构说明.md` | 详细的代码结构说明 |
| V1进度总结 | `重要项目信息/V1项目进度总结.md` | 管理后台开发进度 |
| 部署指南 | `后端升级设计文档/docs/server-deployment-guide.md` | 服务器部署步骤 |
| 后端API文档 | `Server/onettoo/BACKEND_API_MODELS.md` | API 接口说明 |

---

## 开发团队

- **项目负责人**: Zaptain
- **AI 协作**: Claude Code, Gemini, GPT
