# 网络重试机制系统设计方案

**日期**: 2026-01-02
**操作者**: Claude Code (cc)
**类型**: 系统设计
**状态**: 待实施
**版本**: v3（P0 修复 + P1 改进 + Gate 检查）

---

## 一、问题描述

用户反馈：当网络差时进入页面，数据只加载一次，换网后也不会自动重试，只有杀掉 app 重新进入才会刷新。

### 问题确认

| 页面/功能 | 当前状态 | 问题 |
|----------|---------|------|
| 主页分享列表 | ❌ 无重试 | `fetchAllShares()` 失败后只打印日志 |
| 主页照片媒体 | ❌ 无重试 | 媒体下载失败后无重试机制 |
| 分享详情 | ❌ 无重试 | `fetchShareDetailFromServer()` 失败无提示 |
| 个人主页 | ❌ 无重试 | `fetchUserFullInfo()` 失败无重试入口 |
| 评论系统 | ✅ 有重试 | 显示"点击重试"按钮（参考实现） |
| 贴纸系统 | ✅ 有重试 | 有降级方案和重试回调 |

---

## 二、解决方案架构

### 核心策略：B + C 为主，A 为底座

```
┌─────────────────────────────────────────────────────────────────┐
│                      网络重试架构                                │
├─────────────────────────────────────────────────────────────────┤
│  方案 A（底座）：网络层智能重试                                   │
│       - 按"错误类型 + 端点策略"决定是否重试                       │
│       - 处理瞬时抖动（超时/DNS/502-504）                         │
│       - 指数退避 + 随机抖动(jitter)                              │
│       - 429 需读取 Retry-After header                           │
├─────────────────────────────────────────────────────────────────┤
│  方案 B（核心）：网络状态监听 + 协调触发                          │
│       - 网络恢复/切换时通知业务层                                 │
│       - RetryCoordinator 原子操作避免竞态                        │
│       - 解决"换网后不重试"的根本问题                             │
├─────────────────────────────────────────────────────────────────┤
│  方案 C（兜底）：统一状态机 + 重试 UI                            │
│       - ViewModel 必须维护 DataLoadingState                      │
│       - 错误可见 + 手动重试入口                                  │
│       - 用户可自救                                               │
└─────────────────────────────────────────────────────────────────┘
```

### 按数据类型分类

| 数据类型 | 方案组合 | 说明 |
|---------|---------|------|
| **页面主数据** | A + B + C | 主页分享、详情、用户信息 |
| **媒体下载** | 独立队列 + B + C | 去重队列，失败任务重新入队 |
| **有副作用动作** | 仅 C | 发评论、点赞、贴纸等，禁止自动重试 |

---

## 三、统一规范（必须遵守）

### 规范 1：状态机必须存在

每个主数据加载 **必须有** `state`（idle/loading/loaded/error），**禁止只 print**。

```swift
enum DataLoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)
}

// ViewModel 必须包含
@Published var state: DataLoadingState<[Share]> = .idle
```

### 规范 2：refresh 必须幂等

同 key 同时只允许一个 in-flight 请求，新请求应合并/忽略。

```swift
func refresh(reason: RefreshReason) async {
    // ⚠️ 注意：如果已在加载中，直接返回（不是 guard case .loading = state else { return }）
    if case .loading = state { return }

    // 使用 RetryCoordinator 原子操作检查并标记
    // ...
}

enum RefreshReason {
    case onAppear
    case manual          // 用户手动重试（绕过 cooldown）
    case networkRestored // 网络恢复自动触发（受 cooldown 限制）
    case pullToRefresh   // 下拉刷新（绕过 cooldown）
}
```

### 规范 3：networkRestored 触发规则

只触发 **error 且非 loading** 的资源，并有 cooldown。

**重要**：`manual` 和 `pullToRefresh` 应绕过 cooldown，否则用户点"重试"会被拦住。

```swift
// RetryCoordinator 原子操作
actor RetryCoordinator {
    private var lastAttemptAt: [String: Date] = [:]
    private var inFlightKeys: Set<String> = []
    private let defaultCooldown: TimeInterval = 5.0

    /// 原子操作：检查是否允许重试，并标记开始
    /// - Parameters:
    ///   - key: 资源标识
    ///   - bypassCooldown: manual/pullToRefresh 时为 true
    /// - Returns: 是否允许开始请求
    func beginIfAllowed(key: String, bypassCooldown: Bool = false) -> Bool {
        // 1. 检查是否在飞行中（任何情况都要检查）
        if inFlightKeys.contains(key) { return false }

        // 2. 检查冷却时间（除非 bypassCooldown）
        if !bypassCooldown,
           let lastTime = lastAttemptAt[key],
           Date().timeIntervalSince(lastTime) < defaultCooldown {
            return false
        }

        // 3. 原子标记开始
        inFlightKeys.insert(key)
        lastAttemptAt[key] = Date()
        return true
    }

    /// 标记请求结束
    func finish(key: String) {
        inFlightKeys.remove(key)
    }
}
```

### 规范 4：RetryPolicy 按错误/端点分类

不是只按 GET/POST，而是按错误类型 + 端点策略。

**⚠️ Gate 检查 #1：maxRetries 语义统一**

| 术语 | 定义 |
|-----|------|
| `maxRetries` | **失败后重试次数**（不含首次尝试） |
| 总尝试次数 | `1 + maxRetries` |
| `maxRetries = 0` | 只尝试 1 次，失败不重试 |
| `maxRetries = 3` | 最多尝试 4 次（1 首次 + 3 重试） |

```swift
struct RetryPolicy {
    /// 失败后重试次数（不含首次尝试）
    let maxRetries: Int
    let config: RetryConfiguration

    static let none = RetryPolicy(maxRetries: 0, config: .default)       // 总尝试 1 次
    static let standard = RetryPolicy(maxRetries: 3, config: .default)   // 总尝试 4 次
    static let aggressive = RetryPolicy(maxRetries: 5, config: .default) // 总尝试 6 次

    // ⚠️ P1 改进：按端点类型分配策略，而不是统一使用 .standard
    static func defaultPolicy(for endpoint: String) -> RetryPolicy {
        // 关键数据接口：更激进的重试
        if endpoint.contains("/shares/nearby") ||
           endpoint.contains("/shares/detail") ||
           endpoint.contains("/user/profile") {
            return .aggressive
        }

        // 有副作用的操作：不自动重试
        if endpoint.contains("/comment") ||
           endpoint.contains("/like") ||
           endpoint.contains("/sticker") ||
           endpoint.contains("/upload") {
            return .none
        }

        // 其他：标准策略
        return .standard
    }
}

struct RetryConfiguration {
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let jitterFactor: Double  // 0.0 ~ 1.0

    static let `default` = RetryConfiguration(
        baseDelay: 1.0,
        maxDelay: 30.0,
        jitterFactor: 0.2
    )

    func delay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        let clampedDelay = min(exponentialDelay, maxDelay)
        let jitter = clampedDelay * jitterFactor * Double.random(in: -1...1)
        // ⚠️ 必须 clamp 到 >= 0，否则 Task.sleep 会 crash
        return max(0, clampedDelay + jitter)
    }
}

// 可重试的错误类型判断
func isRetryableError(_ error: Error) -> Bool {
    // 网络层错误：可重试
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost,
             .timedOut, .cannotFindHost, .cannotConnectToHost,
             .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    // HTTP 状态码
    if let httpError = error as? HTTPError {
        switch httpError.statusCode {
        case 502, 503, 504:
            return true
        case 429:
            return true  // 但需要特殊处理 Retry-After
        case 400..<500:
            return false  // 4xx 不重试（401/403/404 等）
        default:
            return false
        }
    }

    return false
}
```

### 规范 5：任何 retry 都必须可取消

页面离开/新请求发起时必须取消旧 Task。

```swift
@MainActor
class SomeViewModel: ObservableObject {
    private var currentTask: Task<Void, Never>?

    func refresh(reason: RefreshReason) {
        // 取消旧任务
        currentTask?.cancel()

        // ⚠️ Task 必须明确 @MainActor，否则并发访问 @Published 会出问题
        currentTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            // ... 执行请求
        }
    }

    deinit {
        currentTask?.cancel()
    }
}
```

### 规范 6：媒体下载失败队列必须去重 + 上限 + 清理

```swift
class MediaDownloadQueue {
    // 用字典去重，key = mediaId 或 url
    private var failedTasksByKey: [String: DownloadTask] = [:]
    private let maxRetries = 3

    func markFailed(task: DownloadTask, error: Error) {
        // 永久失败（如 404）不入队
        if isPermanentError(error) { return }

        // 检查重试次数
        if task.retryCount >= maxRetries { return }

        // 去重入队（更新 retryCount）
        var updatedTask = task
        updatedTask.retryCount += 1
        failedTasksByKey[task.key] = updatedTask
    }

    func retryFailedTasks() {
        // ⚠️ 遍历时需要清理，避免重复入队
        let tasksToRetry = failedTasksByKey.filter { $0.value.status == .failed }

        for (key, task) in tasksToRetry {
            // 先从字典移除，避免下次 networkRestored 重复入队
            failedTasksByKey.removeValue(forKey: key)
            // 入队时标记状态为 queued
            var queuedTask = task
            queuedTask.status = .queued
            enqueue(queuedTask)
        }
    }

    private func isPermanentError(_ error: Error) -> Bool {
        if let httpError = error as? HTTPError {
            return (400..<500).contains(httpError.statusCode) && httpError.statusCode != 429
        }
        return false
    }
}
```

---

## 四、详细设计

### 4.1 方案 A - 网络层智能重试

**文件**：`NetworkService.swift`

```swift
extension OTONetwork {
    static func request(_ req: OTORequest) async throws -> Data {
        // ⚠️ P1 改进：使用 defaultPolicy(for:) 按端点分配策略
        let policy = req.retryPolicy ?? RetryPolicy.defaultPolicy(for: req.endpoint)
        var lastError: Error?
        // ⚠️ P0 修复：使用明确的 attempts 计数器，避免 for 循环边界问题
        var attempts = 0

        // 总尝试次数 = 1（首次） + maxRetries（重试）
        while attempts <= policy.maxRetries {
            do {
                return try await performRequest(req)
            } catch {
                lastError = error
                attempts += 1

                // 检查是否可重试
                guard isRetryableError(error) else { throw error }

                // 已达到最大重试次数，不再等待
                if attempts > policy.maxRetries { break }

                // 检查任务是否已取消
                try Task.checkCancellation()

                // 计算等待时间（attempt 从 0 开始计算退避）
                var delay = policy.config.delay(for: attempts - 1)

                // ⚠️ 特殊处理 429：读取 Retry-After header
                if let httpError = error as? HTTPError,
                   httpError.statusCode == 429,
                   let retryAfter = httpError.retryAfterSeconds {
                    delay = max(delay, retryAfter)
                }

                // 等待退避时间
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        // ⚠️ 安全处理：lastError 可能为 nil（理论上不会，但防御性编程）
        throw lastError ?? URLError(.unknown)
    }
}

// HTTPError 需要携带 response header 信息
struct HTTPError: Error {
    let statusCode: Int
    let retryAfterSeconds: TimeInterval?

    init(response: HTTPURLResponse) {
        self.statusCode = response.statusCode
        self.retryAfterSeconds = Self.parseRetryAfter(response.value(forHTTPHeaderField: "Retry-After"))
    }

    // ⚠️ P1 改进：支持两种 Retry-After 格式
    // 1. 秒数：如 "120"
    // 2. HTTP-date：如 "Wed, 21 Oct 2015 07:28:00 GMT"
    private static func parseRetryAfter(_ value: String?) -> TimeInterval? {
        guard let value = value else { return nil }

        // 尝试解析为秒数
        if let seconds = TimeInterval(value) {
            return seconds
        }

        // 尝试解析为 HTTP-date
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")

        // RFC 7231 推荐格式
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss zzz",  // IMF-fixdate
            "EEEE, dd-MMM-yy HH:mm:ss zzz",   // RFC 850
            "EEE MMM d HH:mm:ss yyyy"          // ANSI C asctime()
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                let delay = date.timeIntervalSinceNow
                return delay > 0 ? delay : nil
            }
        }

        return nil
    }
}
```

### 4.2 方案 B - 网络状态监听 + 协调触发

**新建文件**：`NetworkMonitor.swift`

**⚠️ Gate 检查 #5：生命周期**
- `NetworkMonitor.shared` 必须在 App 启动时初始化并常驻
- 建议在 `App.init()` 或 `AppDelegate.didFinishLaunching` 中访问一次 `_ = NetworkMonitor.shared`
- 否则 monitor 可能被释放，`networkRestored` 通知不会触发

```swift
import Network
import Combine

class NetworkMonitor: ObservableObject {
    // ⚠️ 单例必须常驻，App 启动时访问一次确保初始化
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    // ⚠️ P1 改进：防抖 - 避免快速切换网络时产生通知风暴
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.5  // 500ms 防抖

    enum ConnectionType: Equatable {
        case wifi, cellular, ethernet, unknown
    }

    private init() {
        startMonitoring()
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }

                let wasDisconnected = !self.isConnected
                let newConnectionType = self.getConnectionType(path)
                // ⚠️ P0 修复：先保存当前值到局部变量，再比较
                let oldType = self.connectionType
                let connectionTypeChanged = oldType != newConnectionType

                self.isConnected = path.status == .satisfied
                self.connectionType = newConnectionType

                // ⚠️ 触发条件扩展：不只是 disconnected → connected
                // 还包括 connectionType 变化（WiFi ↔ Cellular）
                if path.status == .satisfied {
                    if wasDisconnected {
                        // 从断网恢复：立即通知（用户等待已久）
                        NotificationCenter.default.post(name: .networkRestored, object: nil)
                    } else if connectionTypeChanged {
                        // ⚠️ P1 改进：网络类型切换使用防抖
                        // 避免 WiFi ↔ 蜂窝 快速切换时产生多次通知
                        self.debounceWorkItem?.cancel()
                        let workItem = DispatchWorkItem {
                            NotificationCenter.default.post(name: .networkChanged, object: nil)
                        }
                        self.debounceWorkItem = workItem
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + self.debounceInterval,
                            execute: workItem
                        )
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }

    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        return .unknown
    }
}

extension Notification.Name {
    static let networkRestored = Notification.Name("networkRestored")
    static let networkChanged = Notification.Name("networkChanged")
}
```

**新建文件**：`RetryCoordinator.swift`

```swift
actor RetryCoordinator {
    static let shared = RetryCoordinator()

    private var lastAttemptAt: [String: Date] = [:]
    private var inFlightKeys: Set<String> = []
    private let defaultCooldown: TimeInterval = 5.0

    /// 原子操作：检查是否允许重试，并标记开始
    func beginIfAllowed(key: String, bypassCooldown: Bool = false) -> Bool {
        // 1. 检查是否在飞行中
        if inFlightKeys.contains(key) {
            print("⏳ [\(key)] 跳过：请求进行中")
            return false
        }

        // 2. 检查冷却时间
        if !bypassCooldown,
           let lastTime = lastAttemptAt[key],
           Date().timeIntervalSince(lastTime) < defaultCooldown {
            print("⏳ [\(key)] 跳过：冷却中")
            return false
        }

        // 3. 原子标记开始
        inFlightKeys.insert(key)
        lastAttemptAt[key] = Date()
        print("🚀 [\(key)] 开始请求")
        return true
    }

    /// 标记请求结束
    func finish(key: String) {
        inFlightKeys.remove(key)
        print("✅ [\(key)] 请求结束")
    }

    /// 生成资源 key
    static func key(for resource: RetryResource) -> String {
        switch resource {
        case .nearbyShares(let lat, let lng):
            // ⚠️ Gate 检查 #4：不用 String(format:)，避免 Locale 导致小数点变逗号
            // 使用整数化：精度 0.001 度 ≈ 111 米，足够避免频繁变化
            let latKey = Int((lat * 1000).rounded())
            let lngKey = Int((lng * 1000).rounded())
            return "shares-nearby-\(latKey)-\(lngKey)"
        case .shareDetail(let id):
            return "share-detail-\(id)"
        case .userProfile(let id):
            return "user-profile-\(id)"
        }
    }
}

enum RetryResource {
    case nearbyShares(lat: Double, lng: Double)
    case shareDetail(id: Int64)
    case userProfile(id: Int)
}
```

### 4.3 方案 C - 统一状态机 + 重试 UI

**ViewModel 模板**：

```swift
@MainActor
class DataViewModel<T>: ObservableObject {
    @Published var state: DataLoadingState<T> = .idle
    private var currentTask: Task<Void, Never>?

    var hasError: Bool {
        if case .error = state { return true }
        return false
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    func refresh(reason: RefreshReason) {
        // 如果已在加载中，直接返回
        if case .loading = state { return }

        // 取消旧任务
        currentTask?.cancel()

        // ⚠️ Task 必须明确 @MainActor
        currentTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            let key = self.resourceKey
            let bypassCooldown = (reason == .manual || reason == .pullToRefresh)

            // 原子操作：检查并标记开始
            guard await RetryCoordinator.shared.beginIfAllowed(
                key: key,
                bypassCooldown: bypassCooldown
            ) else { return }

            // ⚠️ P0 修复：使用 Task.detached 避免取消传播到 finish 调用
            defer {
                Task.detached { await RetryCoordinator.shared.finish(key: key) }
            }

            // ⚠️ P0 修复：保存前置状态，取消时可恢复
            let prevState = self.state
            self.state = .loading

            do {
                let data = try await self.fetchData()
                // ⚠️ P0 修复：取消时恢复状态，避免卡在 .loading
                if Task.isCancelled {
                    self.state = prevState
                    return
                }
                self.state = .loaded(data)
            } catch {
                // ⚠️ P0 修复：取消时恢复状态
                if Task.isCancelled {
                    self.state = prevState
                    return
                }
                self.state = .error(error)
            }
        }
    }

    // 子类实现
    var resourceKey: String { fatalError("Subclass must implement") }
    func fetchData() async throws -> T { fatalError("Subclass must implement") }

    deinit {
        currentTask?.cancel()
    }
}
```

**View 模板**：

```swift
struct DataLoadingView<T, Content: View>: View {
    @ObservedObject var viewModel: DataViewModel<T>
    let content: (T) -> Content
    // ⚠️ onRetry 是 async 闭包
    let onRetry: () async -> Void

    var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear {
                Task { await onRetry() }
            }

        case .loading:
            ProgressView()

        case .loaded(let data):
            content(data)

        case .error(let error):
            RetryView(
                message: "加载失败",
                detail: error.localizedDescription,
                onRetry: {
                    Task { await onRetry() }
                }
            )
        }
    }
}

struct RetryView: View {
    let message: String
    var detail: String? = nil
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text(message)
                .font(.headline)

            if let detail = detail {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onRetry) {
                Text("点击重试")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}
```

---

## 五、实施计划

| 阶段 | 内容 | 涉及文件 | 优先级 |
|-----|------|---------|-------|
| **Phase 1** | NetworkMonitor + RetryCoordinator | 新建 `NetworkMonitor.swift`, `RetryCoordinator.swift` | P0 |
| **Phase 2** | 主页分享列表接入 B + C | `SearchViewModel.swift`, `SearchView.swift` | P0 |
| **Phase 3** | 分享详情接入 B + C | `SearchViewModel.swift`, `ShareDetailView.swift` | P0 |
| **Phase 4** | 个人主页接入 B + C | `UserProfileManager.swift`, `MyView.swift` | P1 |
| **Phase 5** | 网络层接入 A（智能重试） | `NetworkService.swift` | P1 |
| **Phase 6** | 媒体下载队列优化 | 新建/修改媒体下载相关代码 | P2 |

### 实施顺序说明

1. **先做 Phase 1-4（B + C）**：搭好可见的状态机 + 重试触发
2. **再做 Phase 5（A）**：此时已有 state，可观察效果且不会"默默重试但 UI 不变"
3. **最后做 Phase 6**：媒体下载相对独立

---

## 六、验收标准

### 功能验收

- [ ] 断网进入主页 → 显示错误态 + 重试按钮
- [ ] 点击重试 → **立即**重新加载（不受 cooldown 限制）
- [ ] 断网进入 → 换网 → 自动触发 refresh 尝试（受 cooldown/inFlight 约束）
- [ ] 快速切换网络 → 不会请求风暴（有节流）
- [ ] 页面离开 → 请求被取消
- [ ] 媒体下载失败 → 网络恢复后自动重试（去重，不膨胀）
- [ ] WiFi ↔ 蜂窝 切换 → 也能触发重试机会

### 代码验收

- [ ] 所有主数据 ViewModel 有 `DataLoadingState`
- [ ] 所有 refresh 方法接受 `RefreshReason` 参数
- [ ] RetryCoordinator 使用 `beginIfAllowed` 原子操作
- [ ] manual/pullToRefresh 绕过 cooldown
- [ ] 网络层 RetryPolicy 按错误类型分类
- [ ] 429 错误读取 Retry-After header
- [ ] 所有 Task 明确 `@MainActor` 且支持取消
- [ ] jitter 计算结果 clamp 到 >= 0

---

## 七、关键代码位置（当前）

| 功能 | 文件 | 行号 |
|------|------|------|
| 主页分享获取 | `SearchViewModel.swift` | 95-121 |
| 分享详情获取 | `SearchViewModel.swift` | 1046-1094 |
| 用户信息获取 | `UserProfileManager.swift` | 43-122 |
| 网络请求层 | `NetworkService.swift` | 22-99 |
| 评论重试（参考） | `CommentSectionView.swift` | 42-64 |

---

## 八、风险与注意事项

### 已识别并处理的风险

| 风险 | 解决方案 |
|-----|---------|
| **请求风暴** | RetryCoordinator 原子操作 + cooldown |
| **重复请求** | beginIfAllowed 检查 inFlight |
| **僵尸 Task** | Task cancellation + deinit cancel |
| **4xx 无限重试** | isRetryableError 错误分类 |
| **媒体队列膨胀** | 字典去重 + retryCount 上限 + 入队时清理 |
| **guard 逻辑错误** | 使用 `if case .loading = state { return }` |
| **Task 并发问题** | 明确 `Task { @MainActor in ... }` |
| **manual 被 cooldown 拦截** | bypassCooldown 参数 |
| **负数 delay crash** | `max(0, delay)` 保护 |
| **lastError 为 nil** | 兜底 `?? URLError(.unknown)` |
| **429 无限快速重试** | 读取 Retry-After header |
| **WiFi↔蜂窝不触发** | 增加 `.networkChanged` 通知 |
| **connectionType 比较时序错误** | 使用局部变量 `let oldType = self.connectionType` (v3) |
| **for 循环边界问题** | 使用 `while attempts <= maxRetries` 明确循环 (v3) |
| **defer Task 被取消传播** | 使用 `Task.detached` 避免取消传播 (v3) |
| **取消后卡在 .loading** | 保存 `prevState` 并在取消时恢复 (v3) |
| **统一使用 .standard 策略不合适** | 按端点分配 `defaultPolicy(for:)` (v3) |
| **Retry-After HTTP-date 格式不支持** | 添加 `parseRetryAfter()` 支持多格式 (v3) |
| **网络切换通知风暴** | networkChanged 使用 500ms 防抖 (v3) |
| **maxRetries 语义混乱** | 明确定义为"失败后重试次数"，注释标注总尝试次数 (v3 Gate) |
| **坐标 key 受 Locale 影响** | 使用整数化 `Int((lat * 1000).rounded())`，不用 String(format:) (v3 Gate) |
| **NetworkMonitor 被释放** | App 启动时 `_ = NetworkMonitor.shared` 确保常驻 (v3 Gate) |

---

## 九、代码审查清单

实施完成后，检查以下项目：

```
[ ] guard 逻辑正确（不是 guard case .loading else { return }）
[ ] RetryCoordinator 使用 beginIfAllowed 原子操作，不分两步
[ ] Task 闭包有 @MainActor 标记
[ ] onRetry 闭包是 async 类型
[ ] manual/pullToRefresh 传入 bypassCooldown: true
[ ] delay 计算有 max(0, ...) 保护
[ ] lastError 有兜底值
[ ] 429 读取 Retry-After
[ ] MediaDownloadQueue 入队后从 failedTasksByKey 移除
[ ] retryCount 在 markFailed 时递增并写回字典

# v3 P0 检查项
[ ] NetworkMonitor connectionType 比较使用局部变量 oldType
[ ] NetworkService 重试循环使用 while + attempts 计数器
[ ] defer 中 finish 调用使用 Task.detached
[ ] DataViewModel 保存 prevState，取消时恢复状态

# v3 P1 检查项
[ ] NetworkService 使用 RetryPolicy.defaultPolicy(for:) 而非 .standard
[ ] HTTPError.parseRetryAfter() 支持秒数和 HTTP-date 两种格式
[ ] NetworkMonitor networkChanged 使用 debounce（500ms）
```

---

## 十、实施前 Gate 检查（PR 必须通过）

以下 6 项检查必须在 PR merge 前逐一确认，避免上线后诡异 bug：

| # | 检查项 | 验证方法 | 通过标准 |
|---|-------|---------|---------|
| 1 | **maxRetries 语义统一** | 代码审查 | `maxRetries=3` 表示失败后重试 3 次（总尝试 4 次），所有注释/日志一致 |
| 2 | **finish 不受取消影响** | 代码审查 | 所有 `finish(key:)` 调用都在 `Task.detached` 中 |
| 3 | **取消时 state 不卡 .loading** | 单元测试 | cancel 后 state 恢复到 prevState，不停留在 .loading |
| 4 | **key 生成不受 Locale 影响** | 代码审查 | 坐标 key 使用整数化 `Int((lat * 1000).rounded())`，不用 `String(format:)` |
| 5 | **NetworkMonitor 常驻** | 代码审查 | `App.init()` 中有 `_ = NetworkMonitor.shared` |
| 6 | **副作用请求默认不重试** | 代码审查 | `defaultPolicy(for:)` 对 `/comment`、`/like`、`/sticker`、`/upload` 返回 `.none` |

### Gate 检查验收模板

```
## 实施前 Gate 检查

- [ ] #1 maxRetries 语义统一：确认 maxRetries=3 表示"失败后重试 3 次"
- [ ] #2 finish 不受取消影响：确认所有 finish 在 Task.detached 中
- [ ] #3 取消时 state 恢复：确认 cancel 后不卡在 .loading
- [ ] #4 key 不受 Locale 影响：确认坐标 key 使用整数化
- [ ] #5 NetworkMonitor 常驻：确认 App 启动时初始化单例
- [ ] #6 副作用请求不重试：确认 defaultPolicy 对副作用端点返回 .none

全部通过后方可 merge。
```

---

## 十一、版本历史

### v3 (2026-01-02)
修复运行时 P0 问题 + P1 改进 + Gate 检查：

**P0 修复（必须）：**

| 问题 | 原因 | 修复 |
|-----|------|-----|
| NetworkMonitor connectionType 比较错误 | 先更新 `self.connectionType` 再比较，导致永远相等 | 使用局部变量 `let oldType = self.connectionType` 保存旧值 |
| NetworkService for 循环边界问题 | `for attempt in 0..<max(1, maxRetries)` 边界混乱 | 改用 `while attempts <= maxRetries` 明确语义 |
| defer 中 Task 被取消传播 | `Task { ... }` 继承父 Task 取消状态，导致 `finish()` 不执行 | 改用 `Task.detached { ... }` |
| 取消后状态卡在 .loading | 取消后直接 return，不恢复原状态 | 保存 `prevState`，取消时 `self.state = prevState` |

**P1 改进（优化）：**

| 改进 | 说明 |
|-----|------|
| `defaultPolicy(for:)` | 按端点分配策略：关键数据 5 次重试、有副作用操作不重试、其他 3 次 |
| HTTP-date 格式解析 | Retry-After 支持秒数和 RFC 7231 HTTP-date 两种格式 |
| networkChanged 防抖 | 网络类型切换使用 500ms 防抖，避免通知风暴 |

**Gate 检查（实施前必须通过）：**

| # | 检查项 |
|---|-------|
| 1 | maxRetries 语义统一：失败后重试次数，不含首次 |
| 2 | finish 不受取消影响：使用 Task.detached |
| 3 | 取消时 state 不卡 .loading：恢复 prevState |
| 4 | key 不受 Locale 影响：坐标使用整数化 |
| 5 | NetworkMonitor 常驻：App 启动时初始化单例 |
| 6 | 副作用请求不重试：defaultPolicy 返回 .none |

### v2 (2026-01-02)
修正初版代码问题：
- `guard case .loading = state else { return }` → `if case .loading = state { return }`
- 拆分的 `shouldRetry` + `markStarted` → 合并为原子操作 `beginIfAllowed`
- Task 并发问题 → 明确 `Task { @MainActor in ... }`
- manual 被 cooldown 拦截 → 添加 `bypassCooldown` 参数
- 负数 delay crash → `max(0, delay)` 保护
- lastError nil → `?? URLError(.unknown)` 兜底
- 429 无限快速重试 → 读取 Retry-After header
- WiFi↔蜂窝不触发 → 增加 `.networkChanged` 通知
- MediaDownloadQueue 重复入队 → 入队后从字典移除

### v1 (2026-01-02)
初版设计，包含 B+C+A 架构
