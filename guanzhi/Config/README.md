# iOS 敏感配置管理

## 配置文件说明

```
Config/
├── Secrets.xcconfig           # 实际配置（已 gitignore，不提交）
├── Secrets.xcconfig.template  # 配置模板（提交到仓库）
└── README.md                  # 本文件
```

## 首次配置步骤

### 1. 创建 Secrets.xcconfig

从模板复制并填入实际值：

```bash
cd guanzhi/Config
cp Secrets.xcconfig.template Secrets.xcconfig
```

编辑 `Secrets.xcconfig`：

```
AMAP_API_KEY = your_actual_amap_api_key_here
```

### 2. 运行 pod install

Podfile 中的 `post_install` 钩子会自动将 Secrets.xcconfig 引入到构建配置中：

```bash
cd /path/to/guanzhi
pod install
```

### 3. 验证配置

运行项目，如果 AMAP_API_KEY 未配置，应用会 crash 并提示：

```
❌ AMAP_API_KEY 未配置。请确保 Secrets.xcconfig 已创建并包含有效的 AMAP_API_KEY
```

## 高德控制台安全配置（必须）

在高德控制台为此 Key 绑定安全限制：

1. 登录 [高德开放平台](https://console.amap.com/)
2. 进入应用管理 → 选择对应应用
3. 设置：
   - ✅ **绑定 Bundle ID**（最关键）
   - 可选：IP 白名单、签名限制

## 轮换 Key

如需轮换 API Key：

1. 在高德控制台创建新 Key（绑定相同 Bundle ID）
2. 更新 `Secrets.xcconfig` 中的值
3. 运行 `pod install`（确保钩子生效）
4. 重新构建应用
5. 在高德控制台删除旧 Key

**无需修改 Swift 代码**。

## CI/CD 配置

在 CI 环境中，可以通过以下方式注入配置：

```bash
# 在构建前创建 Secrets.xcconfig
echo "AMAP_API_KEY = ${AMAP_API_KEY_SECRET}" > guanzhi/Config/Secrets.xcconfig
pod install
```

其中 `AMAP_API_KEY_SECRET` 是 CI 的环境变量/密钥。
