# 前端推送中台任务规划

**文档版本**: v2
**创建日期**: 2025-12-29
**角色**: 前端开发 (Claude Code - iOS)
**状态**: 规划完成，待实施

---

## 一、核心约束（开工前必须明确）

| 约束 | 说明 |
|------|------|
| **登录态绑定** | 设备注册/更新/注销必须在有登录态时执行，未登录时只向 APNs 注册获取 token，不调用后端 |
| **账号切换** | 切换账号时先调用 `/device/logout` 注销旧账号绑定，再用新账号注册 |
| **deviceId 缓存** | 注册成功后保存后端返回的 deviceId 到本地，注销时使用 |
| **冷启动延迟导航** | Deep link 先缓存，等主界面 ready 后再执行跳转 |
| **Badge 临时方案** | 当前先简单清零，标记 TODO 后续与未读通知数对齐 |

---

## 二、阶段 1：基础推送能力

| 任务 | 说明 | 备注 |
|------|------|------|
| **1.1 推送权限申请** | 在合适的业务时机请求权限（如首次评论、打开通知设置页） | 不在启动时立即弹窗 |
| **1.2 Device Token 获取** | 实现 `didRegisterForRemoteNotificationsWithDeviceToken`，本地缓存 token | 未登录时只缓存不上报 |
| **1.3 设备注册 API 对接** | 登录后调用 `POST /device/register`，保存返回的 deviceId | 需先检查登录态 |
| **1.4 Token 刷新处理** | Token 变更时调用 `PUT /device/token`，更新本地缓存 | 需已登录 |
| **1.5 登出注销设备** | 用户登出调用 `DELETE /device/logout?deviceToken={token}` | 使用缓存的 deviceToken |
| **1.6 账号切换处理** | 切换账号时：先注销 → 清除本地缓存 → 新账号注册 | 防止推送错乱 |

---

## 三、阶段 2：通知处理

| 任务 | 说明 | 备注 |
|------|------|------|
| **2.1 前台通知处理** | `willPresent` 回调，显示 Banner/Badge/Sound | - |
| **2.2 后台点击处理** | `didReceive` 回调，解析 deepLink 并导航 | - |
| **2.3 冷启动处理** | `launchOptions` 获取通知，缓存到 `pendingDeepLink` | 延迟到主界面 ready 后执行 |
| **2.4 Badge 同步** | 进入前台时清零 Badge | TODO: 后续改为与未读数 API 联动 |

### 冷启动导航流程

```
App 冷启动 → 保存 deepLink 到 pendingDeepLink
          → 等待主界面初始化完成
          → 检查并执行 pendingDeepLink
          → 清空 pendingDeepLink
```

---

## 四、阶段 3：Deep Link 导航

| 任务 | 说明 | 备注 |
|------|------|------|
| **3.1 URL Scheme 注册** | Info.plist 添加 `guanzhi` scheme | - |
| **3.2 统一 URL 处理中心** | 新 deep link 接入现有 `onOpenURL` / Router 系统 | 不另起分支 |
| **3.3 新增路由 Case** | Router 添加 `.shareComment(shareId, commentId)` | 复用现有导航逻辑 |
| **3.4 分享详情导航** | 跳转到分享页并定位/高亮评论 | - |
| **3.5 异常处理** | 分享/评论不存在时的降级策略 | TODO: 提示"原内容已删除" |

### 异常处理策略

| 场景 | 处理方式 |
|------|---------|
| 分享不存在 | 跳转失败，Toast 提示"内容不存在" |
| 评论已删除 | 正常打开分享，TODO: 顶部提示"原评论已删除" |
| 数据未加载完 | 先导航到分享详情页，页面内部加载数据后再定位评论 |

---

## 五、前置调研任务

在开工前需了解现有项目：

| 调研项 | 目的 |
|--------|------|
| 网络层封装 | 确定如何调用后端 API（`APIClient`/`GuanzhiService`） |
| 登录态管理 | 确定如何判断用户已登录、获取 userId |
| 导航系统 | 了解 `NavigationCoordinator` 实现，确定如何新增路由 |
| 现有 URL 处理 | 检查是否已有 `onOpenURL` 或 `SceneDelegate` 处理逻辑 |
| 本地存储方式 | 确定 deviceToken/deviceId 存储位置（UserDefaults/Keychain） |

---

## 六、任务优先级与 TODO 标记

| 任务 | 优先级 | 状态 |
|------|--------|------|
| 阶段 1 全部任务 | P0 | MVP 必须 |
| 阶段 2.1-2.3 | P0 | MVP 必须 |
| 阶段 2.4 Badge 完整方案 | P1 | TODO - 后续迭代 |
| 阶段 3.1-3.4 | P0 | MVP 必须 |
| 阶段 3.5 异常提示 | P1 | TODO - 后续迭代 |

---

## 七、后端 API 参考

### 设备注册
```
POST /device/register
Authorization: Bearer {token}

Request:
{
    "deviceToken": "APNs设备Token (必填)",
    "deviceId": "设备唯一标识IDFV (可选)",
    "deviceName": "设备名称 (可选)",
    "deviceModel": "设备型号 (可选)",
    "osVersion": "系统版本 (可选)",
    "appVersion": "App版本 (可选)",
    "bundleId": "com.onetto (必填)",
    "environment": "production (可选)"
}
```

### 更新 Token
```
PUT /device/token
Authorization: Bearer {token}

Request:
{
    "oldToken": "旧的设备Token",
    "newToken": "新的设备Token"
}
```

### 设备登出
```
DELETE /device/logout?deviceToken={token}
Authorization: Bearer {token}
```

### Deep Link 格式
```
guanzhi://share/{shareId}/comment/{commentId}
```

### APNs Payload 结构
```json
{
    "aps": {
        "alert": { "title": "观之", "body": "用户名 回复了你: 评论内容..." },
        "badge": 1,
        "sound": "default"
    },
    "deepLink": "guanzhi://share/{shareId}/comment/{commentId}",
    "type": "COMMENT_REPLY"
}
```

---

## 八、产品决策待确认

| 问题 | 选项 | 建议 |
|------|------|------|
| 推送权限弹窗时机 | A. 首次启动 / B. 首次评论 / C. 打开通知设置页 | 建议 B 或 C |

---

**文档结束**

下一步：开始前置调研工作，了解现有项目结构。
