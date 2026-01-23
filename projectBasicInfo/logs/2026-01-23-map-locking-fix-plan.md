# 地图锁定问题修复方案 v3

**日期**: 2026-01-23
**状态**: ✅ 已实施
**问题**: 重新登录后地图锁定在用户位置，无法拖动/缩放，标注不显示

> **后续修复**：此方案实施后，发现登录流程状态未正确重置的问题。参见 `2026-01-23-onboarding-state-reload-fix-plan.md`，增加了 `UserLoginModel.reset()` 方法和登出通知监听。

---

## 问题根因

登录流程（MessageView、NameView、LogInView）在登录成功后通过 `navigationDestination` 推入一个**全新的 SearchView**，并附带**全新的环境对象**（AppStateModel、LocationManager、SearchViewModel）。

### 导致的连锁反应

1. **地图锁定**：新 AppStateModel 的 `hasSetInitialRegion = false` → 每次位置更新都触发 `shouldCenterOnUser = true` → 地图被强制居中
2. **标注消失**：新 SearchViewModel 的 `context = nil` → 无法查询本地数据库 → 标注无法加载
3. **数据丢失**：网络请求回调写入"已销毁的对象"

---

## 选用方案：ObservableObject（推荐）

将 `OTOLoginStatusManager` 改为 `ObservableObject`，通过 `@Published isLoggedIn` 自动触发 SwiftUI 视图更新，无需手动通知。

---

## ⚠️ 重要注意事项（避免踩坑）

### 1. 主线程更新要求 - 两种方案选择

`@Published` 属性必须在主线程更新，否则会出现 "Publishing changes from background threads" 警告。

**⚠️ 注意**：如果把整个类标为 `@MainActor`，所有调用点都会变成主线程隔离。项目中很多地方是从 Task/后台调用 `login()` 的（如 `UserLoginModel.register()` 的异步 Task），可能出现编译错误。

**方案 A（推荐）：不标 @MainActor，方法内切主线程**
```swift
class OTOLoginStatusManager: ObservableObject {
    @Published private(set) var isLoggedIn: Bool = false

    func login(token: String) {
        KeychainService.shared.save(token, forKey: KeychainService.Keys.loginToken)
        DispatchQueue.main.async {
            self.isLoggedIn = true  // 只在主线程更新 @Published
        }
    }

    func logout() {
        KeychainService.shared.delete(forKey: KeychainService.Keys.loginToken)
        UserDefaults.standard.removeObject(forKey: "userId")
        DispatchQueue.main.async {
            self.isLoggedIn = false
        }
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }

    func updateLoginStatus() {
        let loggedIn = KeychainService.shared.exists(forKey: KeychainService.Keys.loginToken)
        DispatchQueue.main.async {
            self.isLoggedIn = loggedIn
        }
    }
}
```

**方案 B：保留 @MainActor，统一改调用点**
```swift
@MainActor
class OTOLoginStatusManager: ObservableObject { ... }

// 调用点需要改为：
await MainActor.run {
    OTOLoginStatusManager.shared.login(token: token)
}
// 或在 Task 中：
Task { @MainActor in
    OTOLoginStatusManager.shared.login(token: token)
}
```

### 2. 所有使用 SearchView 的地方都必须注入 loginManager

一旦 SearchView 依赖 `@EnvironmentObject var loginManager`，**所有** SearchView 实例都必须通过 `.environmentObject()` 注入，否则运行时会 crash。

**必须检查的位置清单**：
- `guanzhiApp.swift` ✅ （主入口）
- `SearchView.swift` 的 Preview ✅ （需添加）
- ~~`MessageView.swift` 的 `topage()`~~ （已删除 SearchView）
- ~~`NameView.swift` 的 `navigationDestination`~~ （已删除）
- ~~`LogInView.swift` 的 APPSTORE_REVIEW~~ （已删除）
- 项目中其他可能创建 SearchView 的 demo/test 页面

### 3. 使用 @ObservedObject 而非 @StateObject 绑定单例

`@StateObject` 原则上用于"由视图创建的实例"，而 `OTOLoginStatusManager.shared` 是外部单例。

**正确做法**：使用 `@ObservedObject` 绑定单例。

**兜底方案**（若编译不过）：
```swift
// 方案 1：仍用 @StateObject（虽不规范但可行）
@StateObject var loginManager = OTOLoginStatusManager.shared

// 方案 2：用 let + environmentObject
let loginManager = OTOLoginStatusManager.shared
// 在 body 中：
.environmentObject(loginManager)
```

### 4. Preview 不要污染真实登录态

在 Preview 中调用 `login(token:)` 会写入 Keychain，可能影响真实登录状态。

**安全做法**：Preview 中使用 `setLoggedInForPreview()` 方法。

**⚠️ 注意**：如果使用方案 B（@MainActor），Preview 中需要这样调用：
```swift
static var previews: some View {
    Task { @MainActor in
        OTOLoginStatusManager.shared.setLoggedInForPreview(true)
    }

    return SearchView(...)
        .environmentObject(OTOLoginStatusManager.shared)
}
```

如果使用方案 A（不标 @MainActor），可以直接调用：
```swift
static var previews: some View {
    OTOLoginStatusManager.shared.setLoggedInForPreview(true)

    return SearchView(...)
        .environmentObject(OTOLoginStatusManager.shared)
}
```

### 5. 登录流程必须使用同一个单例实例

SearchView 通过 `@EnvironmentObject` 订阅 `OTOLoginStatusManager.shared`。如果登录流程中某处调用的是"另一个实例"或依赖缓存状态，会导致**登录成功但 UI 不切换**。

**必须确保**：
- 所有登录调用都使用 `OTOLoginStatusManager.shared.login(token:)`
- **禁止** 创建新的 `OTOLoginStatusManager()` 实例
- MessageView、NameView、LogInView 中的登录逻辑都必须调用 `.shared` 单例

**当前代码检查**（已确认使用 .shared）：
- `MessageView.checkCode()` → `OTOLoginStatusManager.shared.login(...)` ✅
- `NameView` 注册成功 → 通过 `UserLoginModel.register()` 调用 ✅
- `LogInView` APPSTORE_REVIEW → `OTOLoginStatusManager.shared.login(...)` ✅

**后续维护警告**：如果有人新增登录入口，必须使用 `.shared` 单例，否则会导致状态不同步。

---

## 必须做（7 项）

### 1. 将 OTOLoginStatusManager 改为 ObservableObject

**文件**: `UserLoginModel.swift`

**修改前**:
```swift
class OTOLoginStatusManager {
    static let shared = OTOLoginStatusManager()
    private(set) var isLoggedIn: Bool = false
    // ...
}
```

**修改后（使用方案 A：不标 @MainActor，方法内切主线程）**:
```swift
class OTOLoginStatusManager: ObservableObject {
    static let shared = OTOLoginStatusManager()

    @Published private(set) var isLoggedIn: Bool = false

    // ✅ 仅供 Preview 使用，不写 Keychain
    #if DEBUG
    func setLoggedInForPreview(_ value: Bool) {
        DispatchQueue.main.async {
            self.isLoggedIn = value
        }
    }
    #endif

    func login(token: String) {
        KeychainService.shared.save(token, forKey: KeychainService.Keys.loginToken)
        // ✅ 只在主线程更新 @Published 属性
        DispatchQueue.main.async {
            self.isLoggedIn = true
        }
    }

    func logout() {
        KeychainService.shared.delete(forKey: KeychainService.Keys.loginToken)
        UserDefaults.standard.removeObject(forKey: "userId")
        // ✅ 只在主线程更新 @Published 属性
        DispatchQueue.main.async {
            self.isLoggedIn = false
        }
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }

    func updateLoginStatus() {
        let loggedIn = KeychainService.shared.exists(forKey: KeychainService.Keys.loginToken)
        // ✅ 只在主线程更新 @Published 属性
        DispatchQueue.main.async {
            self.isLoggedIn = loggedIn
        }
    }
    // ... 其他方法保持不变
}
```

---

### 2. 在 guanzhiApp 中注入 loginManager 为 EnvironmentObject

**文件**: `guanzhiApp.swift`

**修改**:
```swift
@main
struct guanzhiApp: App {
    // ✅ 使用 @ObservedObject 绑定单例（不是 @StateObject）
    // @StateObject 用于"由视图创建的实例"，单例应用 @ObservedObject
    @ObservedObject var loginManager = OTOLoginStatusManager.shared

    // 修改 UserLoginModel 为 @StateObject
    @StateObject var userLoginModel = UserLoginModel()

    // ... 其他 @StateObject 保持不变

    var body: some Scene {
        WindowGroup {
            ZStack {
                NavigationStack(path: $navigationCoordinator.path) {
                    SearchView(
                        animationNamespace: globalAnimationNamespace,
                        userlogin: userLoginModel  // ✅ 使用持久化实例
                    )
                    // ...
                }
                .environment(appState)
                .environmentObject(loginManager)  // ✅ 注入 loginManager
                .environmentObject(locationManager)
                .environmentObject(searchViewModel)
                // ...
            }
            .environmentObject(loginManager)  // ✅ 也注入到外层 ZStack
            // ...
        }
    }
}
```

---

### 3. 修改 SearchView 使用 loginManager.isLoggedIn 判断

**文件**: `SearchView.swift`

**修改**:
```swift
struct SearchView: View {
    // 添加 loginManager
    @EnvironmentObject var loginManager: OTOLoginStatusManager

    // ... 其他属性保持不变

    var body: some View {
        @Bindable var appState = appState

        ZStack {
            // ✅ 改用 loginManager.isLoggedIn（可观察的）
            if !loginManager.isLoggedIn {
                LogInView(userlogin: userlogin)
            } else {
                // 主内容...
            }
        }
        // ...
    }
}
```

**同时更新 Preview（安全方式，不污染 Keychain）**:
```swift
struct SearchView_Previews: PreviewProvider {
    @Namespace static var animationNamespace

    static var previews: some View {
        // ✅ 使用 setLoggedInForPreview，不写 Keychain
        #if DEBUG
        OTOLoginStatusManager.shared.setLoggedInForPreview(true)
        #endif

        return SearchView(animationNamespace: animationNamespace, userlogin: UserLoginModel())
            .environment(\.appState, AppStateModel())
            .environmentObject(OTOLoginStatusManager.shared)  // ✅ 必须添加
            .environmentObject(LocationManager())
            .environmentObject(SearchViewModel())
            // ...
    }
}
```

**⚠️ 重要**：项目中所有使用 SearchView 的 Preview 都必须添加 `.environmentObject(OTOLoginStatusManager.shared)`，否则会 crash。

---

### 4. 修改 MessageView - 删除 SearchView 创建，不设置 next=true

**文件**: `MessageView.swift`

#### 4.1 修改 `topage()` 函数（第 30-45 行）

**修改前**:
```swift
func topage() -> some View {
    if userlogin.loginState == 1 {
        return AnyView(nameView(userlogin: userlogin))
    }
    if userlogin.loginState == 0 {
        return AnyView(
            SearchView(animationNamespace: fallbackNamespace, userlogin: UserLoginModel())
                .environment(\.appState, AppStateModel())
                .environmentObject(LocationManager())
                .environmentObject(SearchViewModel())
        )
    } else {
        return AnyView(EmptyView())
    }
}
```

**修改后**:
```swift
func topage() -> some View {
    if userlogin.loginState == 1 {
        // 新用户，跳转到设置昵称页面
        return AnyView(nameView(userlogin: userlogin))
    }
    // loginState == 0（老用户登录成功）或其他情况
    // 不返回 SearchView，登录状态已更新，SearchView 会自动响应
    return AnyView(EmptyView())
}
```

#### 4.2 修改 `checkCode()` 函数（第 55-63 行）

**修改前**:
```swift
if response.respCode == 0 {
    userlogin.loginState = 0
    if let tokenString = response.datas {
        userlogin.header = "Bearer " + tokenString
        OTOLoginStatusManager.shared.login(token: userlogin.header)
        userlogin.getUserInfo()
    }
    next = true  // ❌ 会触发 navigationDestination
    isLoading = false
}
```

**修改后**:
```swift
if response.respCode == 0 {
    userlogin.loginState = 0
    if let tokenString = response.datas {
        userlogin.header = "Bearer " + tokenString
        OTOLoginStatusManager.shared.login(token: userlogin.header)
        userlogin.getUserInfo()
    }
    // ✅ 不设置 next = true
    // OTOLoginStatusManager.shared.login() 会触发 @Published isLoggedIn 变化
    // SearchView 会自动从 LogInView 切换到主内容
    isLoading = false
} else if response.respCode == -1 && response.respMsg == "1" {
    // 新用户，需要设置昵称
    userlogin.loginState = 1
    next = true  // ✅ 这个保留，跳转到 NameView
    isLoading = false
}
```

---

### 5. 修改 NameView - 删除 navigationDestination，不设置 next=true

**文件**: `NameView.swift`

#### 5.1 删除 navigationDestination（第 86-91 行）

**删除这整块代码**:
```swift
.navigationDestination(isPresented: $next) {
    SearchView(animationNamespace: fallbackNamespace, userlogin: UserLoginModel())
        .environment(\.appState, AppStateModel())
        .environmentObject(LocationManager())
        .environmentObject(SearchViewModel())
}
```

#### 5.2 修改注册成功回调（第 72-80 行）

**修改前**:
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
    if userlogin.namePassed {
        isLoading = false
        next = true  // ❌ 会触发已删除的 navigationDestination
    } else {
        showNotice = true
        isLoading = false
    }
}
```

**修改后**:
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
    if userlogin.namePassed {
        isLoading = false
        // ✅ 不设置 next = true
        // register() 中调用了 OTOLoginStatusManager.shared.login()
        // @Published isLoggedIn 变化会自动触发 SearchView 切换
    } else {
        showNotice = true
        isLoading = false
    }
}
```

**注意**: 需要确认 `UserLoginModel.register()` 函数中在成功时调用了 `OTOLoginStatusManager.shared.login(token:)`。

---

### 6. 修改 LogInView - 删除 APPSTORE_REVIEW 中的 navigationDestination

**文件**: `LogInView.swift`

#### 6.1 删除 APPSTORE_REVIEW navigationDestination（第 141-151 行）

**删除这整块代码**:
```swift
#if APPSTORE_REVIEW
.navigationDestination(isPresented: $directLogin) {
    SearchView(animationNamespace: fallbackNamespace, userlogin: UserLoginModel())
        .environment(\.appState, AppStateModel())
        .environmentObject(LocationManager())
        .environmentObject(SearchViewModel())
        .environmentObject(ToastManager())
        .environmentObject(UserProfileManager())
        .environmentObject(NavigationCoordinator())
}
#endif
```

#### 6.2 修改测试登录逻辑（第 100-105 行）

**修改前**:
```swift
if isTestMode && userlogin.phone == testPhone {
    userlogin.header = testToken
    userlogin.loginState = 0
    OTOLoginStatusManager.shared.login(token: testToken)
    OTOLoginStatusManager.shared.setUserID(11)
    directLogin = true  // ❌ 会触发已删除的 navigationDestination
}
```

**修改后**:
```swift
if isTestMode && userlogin.phone == testPhone {
    userlogin.header = testToken
    userlogin.loginState = 0
    OTOLoginStatusManager.shared.login(token: testToken)
    OTOLoginStatusManager.shared.setUserID(11)
    // ✅ 不设置 directLogin = true
    // login() 会触发 @Published isLoggedIn 变化
    // SearchView 会自动切换到主内容
}
```

---

### 7. 修改 guanzhiApp - UserLoginModel 改用 @StateObject

**文件**: `guanzhiApp.swift`

这一步已在第 2 步中包含：
```swift
@StateObject var userLoginModel = UserLoginModel()

// 传入 SearchView
SearchView(
    animationNamespace: globalAnimationNamespace,
    userlogin: userLoginModel  // ✅ 使用持久化实例
)
```

---

## 修改文件清单

| 序号 | 文件 | 修改内容 |
|------|------|----------|
| 1 | `UserLoginModel.swift` | OTOLoginStatusManager 改为 ObservableObject，添加 @Published isLoggedIn，login/logout/updateLoginStatus 内用 DispatchQueue.main.async 更新状态，添加 setLoggedInForPreview() |
| 2 | `guanzhiApp.swift` | 添加 @ObservedObject loginManager（绑定单例），UserLoginModel 改用 @StateObject |
| 3 | `SearchView.swift` | 添加 @EnvironmentObject loginManager，修改 if 条件为 `!loginManager.isLoggedIn`，更新 Preview |
| 4 | `MessageView.swift` | 修改 topage() 删除 SearchView，checkCode() 中老用户登录成功不设置 next=true |
| 5 | `NameView.swift` | 删除 navigationDestination，注册成功不设置 next=true |
| 6 | `LogInView.swift` | 删除 APPSTORE_REVIEW 的 navigationDestination，测试登录不设置 directLogin=true |

---

## 可选优化（后续处理）

### 1. "Publishing changes from within view updates" 警告

`SearchView.swift` 第 289-292 行的 `onRegionChange` 回调：
```swift
onRegionChange: { newRegion in
    DispatchQueue.main.async {
        searchViewModel.region = newRegion
        searchViewModel.scheduleAnnotationUpdate()
    }
}
```

### 2. 登出后清理状态

在 `.onReceive(NotificationCenter.default.publisher(for: .userDidLogout))` 中已有监听，可添加更多清理逻辑。

---

## 预期结果

1. 登录成功后，`@Published isLoggedIn` 变化自动触发 SearchView 重绘
2. SearchView 的 if 分支自动从 LogInView 切换到主内容
3. 使用 guanzhiApp 提供的同一套环境对象
4. `hasSetInitialRegion` 正确保持状态，不会反复触发 `shouldCenterOnUser`
5. SearchViewModel 的 `context` 正常可用，标注正常显示
6. 地图可自由拖动/缩放，不再被强制居中

---

## 实施顺序

1. 先修改 `UserLoginModel.swift`（OTOLoginStatusManager → ObservableObject）
2. 修改 `guanzhiApp.swift`（注入 loginManager，UserLoginModel 改 @StateObject）
3. 修改 `SearchView.swift`（使用 loginManager.isLoggedIn）
4. 修改 `MessageView.swift`
5. 修改 `NameView.swift`
6. 修改 `LogInView.swift`
7. 测试登录流程
