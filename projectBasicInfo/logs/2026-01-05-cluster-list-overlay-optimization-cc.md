# 聚合列表 Overlay 优化

**日期**: 2026-01-05
**版本**: v2.9
**执行者**: Claude Code

---

## 背景

聚合列表（ClusterList）存在两个主要问题：

1. **"缓缓回滑"问题**：使用 SwiftUI ScrollView 时，滑动到底部后手指松开会有缓慢的回滑动画
2. **Sheet 层级冲突**：聚合列表使用 Sheet 呈现，与 NavigationStack 中的其他 Sheet 产生冲突

---

## 解决方案

### 1. UIKitListKit - 解决滚动回弹问题

使用 UITableView 替代 SwiftUI ScrollView，通过 `bounces = false` 禁用回弹。

**新增文件**：
```
View/Shared/UIKitListKit/
├── HostingTableView.swift           # SwiftUI Representable 桥接
├── HostingTableViewController.swift # UITableViewController 实现
└── TableEndFooterView.swift         # 列表底部 Footer（"- 到底啦 -"）
```

**技术要点**：
- 使用 `UIHostingConfiguration`（iOS 16+）承载 SwiftUI 行视图
- `bounces = false` 禁用底部回弹
- `alwaysBounceVertical = true` 确保条目较少时也可滑动
- 透明背景配置，让毛玻璃效果透过

### 2. OverlaySheet - 解决 Sheet 层级冲突

使用 Overlay 替代 Sheet，从根本上避免层级冲突。

**新增文件**：
```
View/Shared/OverlaySheet/
└── OverlaySheetContainer.swift
```

**核心组件**：
- `AnimatedOverlaySheet<Content>` - 带动画的 Overlay 包装器
- `getDeviceCornerRadius()` - 获取设备屏幕圆角

**视觉效果**（macOS 26 风格）：
- 缩放动画：1.06x → 1.0x
- 透明度动画：0 → 1
- 弹簧动画：`response: 0.35, dampingFraction: 0.85`
- 毛玻璃背景：`.ultraThinMaterial`
- 自适应屏幕圆角（使用 iOS 私有 API `_displayCornerRadius`）

**条件性动画**：
- 点击聚合注释打开：正常动画
- 手动点击背景关闭：正常动画
- 进入分享详情：无动画（瞬间隐藏）
- 从详情返回：无动画（瞬间出现）

使用 `Transaction` + `disablesAnimations = true` 实现瞬间切换。

---

## 代码修改

### SearchView.swift

**新增属性**：
```swift
/// 聚合列表显示模式开关
/// true = Overlay 模式（新），false = Sheet 模式（旧）
let useOverlayForClusterList = true
```

**新增计算属性**：
```swift
@ViewBuilder
private var clusterListContent: some View {
    VStack(spacing: 0) {
        // 顶部标题栏（居中显示）
        Text("这里有 \(clusterAnnotations.count) 条观之")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(Color("text-gray"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Constants.spacingSpacingM)

        Divider()

        // UITableView 列表（透明背景）
        HostingTableView(
            items: clusterAnnotations,
            idKeyPath: \.id,
            bouncesEnabled: false,
            showsSeparators: false
        ) { share in
            ShareSingleView(share: share, onTap: { ... })
        }
        .onSelect { share in ... }
    }
}
```

**修改 restoreClusterListIfNeeded()**：
```swift
private func restoreClusterListIfNeeded() {
    if useOverlayForClusterList {
        // Overlay 模式：无需延迟和动画，瞬间出现
        isShowingClusterList = true
        shouldRestoreClusterList = false
    } else {
        // Sheet 模式：需要短暂延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { ... }
    }
}
```

**条件性渲染**：
```swift
.overlay {
    if useOverlayForClusterList {
        AnimatedOverlaySheet(
            isPresented: $isShowingClusterList,
            cornerRadius: 0,  // 使用屏幕圆角
            heightFraction: 0.75,
            edgeInset: 12,
            onDismiss: { ... },
            content: { clusterListContent },
            skipAnimation: shouldRestoreClusterList
        )
    }
}
```

### HostingTableViewController.swift

**透明背景配置**：
```swift
override func viewDidLoad() {
    super.viewDidLoad()
    tableView.backgroundColor = .clear
    view.backgroundColor = .clear
}

// Cell 配置
cell.contentConfiguration = UIHostingConfiguration {
    rowBuilder(item).id(itemID)
}
.margins(.all, 0)
.background(.clear)

cell.backgroundColor = .clear
cell.contentView.backgroundColor = .clear
```

**始终可滑动**：
```swift
func applyConfiguration() {
    tableView.bounces = bouncesEnabled
    tableView.alwaysBounceVertical = true  // 条目少时也可滑动
}
```

---

## UI 变更

| 变更项 | 之前 | 之后 |
|--------|------|------|
| 呈现方式 | Sheet | Overlay |
| 高度 | 两档可变 | 固定 3/4 屏幕 |
| 边距 | 0 | 12pt（左、右、底） |
| 圆角 | 固定值 | 设备屏幕圆角 |
| 背景 | 白色 | 毛玻璃透明 |
| 动画 | Sheet 默认 | macOS 26 缩放 |
| 标题 | "附近的观之" + "n条" | "这里有 n 条观之"（居中）|
| 关闭按钮 | 有 | 无（点击背景关闭）|
| 滚动 | SwiftUI ScrollView | UITableView |
| 触底回弹 | 有缓慢回滑 | 无回弹 |

---

## 技术细节

### 获取设备屏幕圆角

```swift
func getDeviceCornerRadius(defaultValue: CGFloat = 44) -> CGFloat {
    let key = "_displayCornerRadius"
    if let screen = UIScreen.main.value(forKey: key) as? CGFloat, screen > 0 {
        return screen
    }
    return defaultValue  // 现代 iPhone 通常是 44-47
}
```

### 瞬间切换动画

```swift
var transaction = Transaction()
transaction.disablesAnimations = true
withTransaction(transaction) {
    isVisible = true
    animationProgress = 1.0
}
```

---

## 文件清单

### 新增文件

| 文件 | 说明 |
|------|------|
| `View/Shared/OverlaySheet/OverlaySheetContainer.swift` | Overlay 弹窗组件 |
| `View/Shared/UIKitListKit/HostingTableView.swift` | UITableView Representable |
| `View/Shared/UIKitListKit/HostingTableViewController.swift` | UITableViewController |
| `View/Shared/UIKitListKit/TableEndFooterView.swift` | 列表底部 Footer |

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `View/FrontPages/SearchView.swift` | 添加 Overlay 模式开关和条件渲染 |
| `View/SharePages/ShareSingleView.swift` | 添加 `onTap` 回调 |
| `guanzhi.xcodeproj/project.pbxproj` | 添加新文件引用 |

---

## 测试验证

- [x] 点击聚合注释，列表带动画出现
- [x] 点击背景，列表带动画关闭
- [x] 列表滑动流畅，无触底回弹
- [x] 列表条目较少时也可滑动
- [x] 点击列表项进入详情，窗口瞬间消失（无动画）
- [x] 从详情返回，窗口瞬间出现（无动画）
- [x] 毛玻璃效果正常显示
- [x] 窗口圆角与设备屏幕圆角一致

---

## 后续优化

1. **开关控制**：当前 `useOverlayForClusterList = true`，可根据测试反馈切换
2. **动画参数**：可根据用户体验调整缩放起始值和动画时长
3. **私有 API**：`_displayCornerRadius` 为私有 API，需关注 iOS 版本兼容性

---

## 相关日志

- 2026-01-03：[Sheet导航冲突修复](2026-01-03-sheet-navigation-conflict-fix-cc.md)
- 2026-01-05：[聚合列表Overlay实施计划](2026-01-05-cluster-list-overlay-plan.md)
