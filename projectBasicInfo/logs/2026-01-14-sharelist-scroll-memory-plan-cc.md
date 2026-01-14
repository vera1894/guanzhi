# ShareListView 滚动位置记忆功能实施计划

**日期**: 2026-01-14
**作者**: Claude Code
**状态**: ✅ 已完成（详见 `2026-01-14-sharelist-scroll-memory-complete-cc.md`）

---

## 一、背景

个人主页中的观之列表（ShareListView）点击进入详情页后返回，列表会回到顶部，需要添加滚动位置记忆功能。

---

## 二、SSOT 证据：MessagesView 的列表容器结构

MessagesView 已实现滚动记忆，其列表容器结构为 **ScrollView + LazyVStack**（`MessagesView.swift:63-98`）：

```swift
ScrollViewReader { proxy in
    ScrollView {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.displayableMessages) { item in
                swipeableRow(for: item)
                    .id(item.id)  // 关键：绑定 id
            }
            // 加载更多...
        }
    }
    .refreshable { ... }
    .onChange(of: viewModel.displayableMessages.count) { _, _ in
        restoreScrollIfPossible(proxy)
    }
    .onAppear {
        restoreScrollIfPossible(proxy)
    }
}
```

消息滚动记忆状态存储在 `NavigationCoordinator`（`AppStateModel.swift:193-200`）：
```swift
class NavigationCoordinator: ObservableObject {
    @Published var path = NavigationPath()
    @Published var messagesScrolledItemId: String?
    @Published var messagesDidRestore: Bool = false
}
```

---

## 三、实施方案

### 3.1 结构改造

将 ShareListView 从 `List` 改为 `ScrollView + LazyVStack`，与 MessagesView 保持一致。

### 3.2 滚动记忆 Key 设计（Hashable struct，避免 String 拼接错误）

```swift
// 在 NavigationCoordinator 中添加

/// 观之列表 Tab 枚举
enum ShareListTab: Int, Hashable {
    case all = 0      // 全部观之
    case faded = 1    // 已褪色
}

/// 滚动记忆 Key（按 userId + tab 区分）
struct ShareListScrollKey: Hashable {
    let userId: Int
    let tab: ShareListTab
}

/// 滚动记忆状态
struct ShareListScrollState {
    var lastShareId: Int? = nil
    var didRestore: Bool = false
}

// NavigationCoordinator 中新增属性
@Published var shareListScrollStates: [ShareListScrollKey: ShareListScrollState] = [:]
```

### 3.3 didRestore 生命周期规则

| 场景 | 操作 |
|------|------|
| 点击进入详情时 | `lastShareId = share.id`, `didRestore = false` |
| 切换 tab 时 | 对新 key 的 `didRestore = false`（允许恢复） |
| `.onAppear` 恢复成功后 | `didRestore = true`（防重复） |
| 数据源整体替换（切换 userId）时 | 对应 key 重置 `didRestore = false` |

### 3.4 恢复触发条件（硬门槛）

```swift
func restoreScrollIfPossible(_ proxy: ScrollViewProxy) {
    let key = ShareListScrollKey(userId: userId, tab: currentTab)
    guard var state = navigationCoordinator.shareListScrollStates[key] else { return }

    // 条件1: 未恢复过
    guard !state.didRestore else { return }

    // 条件2: 有目标 id
    guard let targetId = state.lastShareId else { return }

    // 条件3: 当前数据列表包含目标 id
    guard currentShares.contains(where: { $0.id == targetId }) else {
        // 目标不在列表中，清除并放弃恢复
        state.lastShareId = nil
        navigationCoordinator.shareListScrollStates[key] = state
        return
    }

    // 执行恢复
    state.didRestore = true
    navigationCoordinator.shareListScrollStates[key] = state

    DispatchQueue.main.async {
        withTransaction(Transaction(animation: nil)) {
            proxy.scrollTo(targetId, anchor: .center)  // anchor 用 .center
        }
    }
}
```

### 3.5 anchor 选择

统一使用 `.center`，更像"回到刚才看的那一段"，而非 `.top` 导致上下文丢失。

---

## 四、实施步骤

| 步骤 | 文件 | 内容 |
|------|------|------|
| 1 | `AppStateModel.swift` | 添加 `ShareListTab`、`ShareListScrollKey`、`ShareListScrollState`、`shareListScrollStates` |
| 2 | `AppStateModel.swift` | 添加辅助方法 `saveShareListScrollPosition` 和 `getShareListScrollState` |
| 3 | `ShareListView.swift` | List 改为 ScrollView + LazyVStack + ScrollViewReader |
| 4 | `ShareListView.swift` | 每行添加 `.id(share.id)` |
| 5 | `ShareListView.swift` | 添加 `restoreScrollIfPossible` 方法 |
| 6 | `ShareListView.swift` | 切换 tab 时重置新 key 的 `didRestore` |
| 7 | `ShareSingleView.swift` | 点击时调用 `saveShareListScrollPosition` |
| 8 | `ShareListView.swift` | `.onAppear` 和 `.onChange(of: shares.count)` 触发恢复 |

---

## 五、测试清单

- [ ] tabA（全部观之）中间点进详情 → 返回恢复到原位置
- [ ] tabB（已褪色）中间点进详情 → 返回恢复到原位置
- [ ] tabA 点进 → 返回 → 切 tabB → 返回 → 切回 tabA（不串、不乱跳）
- [ ] 进入别人主页（userId 变化）不复用自己主页滚动位置
- [ ] 下拉刷新后不会被拉回旧位置
- [ ] 目标 id 不在当前列表时不会报错或卡死

---

## 六、注意事项

1. **不要与通知删除 404 问题混在同一分支**：滚动记忆是独立功能，避免污染提交
2. **OthersView 复用**：如果 OthersView 也使用 ShareListView，userId 参数会自动区分，无需额外处理
3. **分页加载**：如果未来添加分页，需考虑目标 id 不在首页的情况（当前方案直接放弃恢复）

---

## 七、相关文件

- `AppStateModel.swift` - NavigationCoordinator 定义
- `ShareListView.swift` - 观之列表视图
- `ShareSingleView.swift` - 观之列表行视图
- `MessagesView.swift` - 参考实现
