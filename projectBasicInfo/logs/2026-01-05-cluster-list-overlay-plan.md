# 聚合列表 Overlay 实现计划

**日期**: 2026-01-05
**目标**: 将聚合列表从 sheet 改为固定 overlay，解决 sheet 冲突问题
**原则**: 保留开关可切换回 sheet 实现，overlay 样式与 sheet 保持一致

---

## 一、开关设计

在 `SearchView.swift` 顶部添加开关：

```swift
// MARK: - 聚合列表显示模式开关
// true: 使用 overlay（无 sheet 冲突，动画可控）
// false: 使用 sheet（iOS 原生体验）
let useOverlayForClusterList = true
```

---

## 二、需要复刻的 Sheet 特性

| 特性 | Sheet 实现 | Overlay 复刻方案 |
|------|-----------|-----------------|
| 圆角 | `.presentationCornerRadius(40)` | `.clipShape(RoundedRectangle(cornerRadius: 40))` |
| 拖拽指示器 | `.presentationDragIndicator(.visible)` | 自定义 Capsule 视图 |
| 高度档位 | `.presentationDetents([.medium, .large])` | 状态变量 + GeometryReader 计算 |
| 拖拽切换高度 | 系统自带 | DragGesture 实现 |
| 向下拖拽关闭 | 系统自带 | DragGesture 判断阈值后关闭 |
| 背景交互 | `.presentationBackgroundInteraction(.enabled)` | overlay 天然支持 |
| 内容滚动优先 | `.presentationContentInteraction(.scrolls)` | 需协调手势 |
| 阴影 | 系统自带 | `.shadow()` modifier |
| 出现/消失动画 | 系统自带（约0.3s） | `withAnimation` 自定义 |

---

## 三、新建组件

### 文件: `View/Shared/OverlaySheet/OverlaySheetContainer.swift`

通用的 overlay sheet 容器，可复用于其他场景。

```swift
/// Overlay 模式的 Sheet 容器
/// 复刻 iOS sheet 的外观和交互，但避免 sheet 冲突问题
struct OverlaySheetContainer<Content: View>: View {
    // MARK: - 必需参数
    @Binding var isPresented: Bool
    let content: () -> Content

    // MARK: - 可选参数
    var cornerRadius: CGFloat = 40
    var mediumHeightFraction: CGFloat = 0.5   // medium 档位占屏幕比例
    var largeHeightFraction: CGFloat = 0.95   // large 档位占屏幕比例
    var showDragIndicator: Bool = true
    var onDismiss: (() -> Void)? = nil

    // MARK: - 内部状态
    @State private var currentHeightFraction: CGFloat = 0.5  // 当前高度比例
    @State private var dragOffset: CGFloat = 0               // 拖拽偏移量
    @State private var isAtLargeDetent: Bool = false         // 是否在 large 档位

    var body: some View {
        // 实现细节见下方
    }
}
```

### 核心实现要点

#### 1. 布局结构
```swift
GeometryReader { geometry in
    let screenHeight = geometry.size.height
    let sheetHeight = screenHeight * currentHeightFraction

    VStack(spacing: 0) {
        Spacer()

        // Sheet 容器
        VStack(spacing: 0) {
            // 拖拽指示器
            if showDragIndicator {
                dragIndicator
            }

            // 内容区域
            content()
        }
        .frame(height: max(0, sheetHeight - dragOffset))
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: -5)
        .offset(y: dragOffset)
        .gesture(dragGesture)
    }
}
.transition(.move(edge: .bottom))
.animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
```

#### 2. 拖拽指示器
```swift
private var dragIndicator: some View {
    Capsule()
        .fill(Color(UIColor.systemGray3))
        .frame(width: 36, height: 5)
        .padding(.top, 8)
        .padding(.bottom, 4)
}
```

#### 3. 拖拽手势
```swift
private var dragGesture: some Gesture {
    DragGesture()
        .onChanged { value in
            let translation = value.translation.height
            if translation > 0 {
                // 向下拖：允许偏移
                dragOffset = translation
            } else {
                // 向上拖：切换到 large（如果当前是 medium）
                if !isAtLargeDetent && translation < -50 {
                    withAnimation(.spring(response: 0.3)) {
                        currentHeightFraction = largeHeightFraction
                        isAtLargeDetent = true
                    }
                }
            }
        }
        .onEnded { value in
            let translation = value.translation.height
            let velocity = value.velocity.height

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if translation > 150 || velocity > 500 {
                    // 快速下滑或大幅下滑 -> 关闭
                    isPresented = false
                    onDismiss?()
                } else if translation > 50 && isAtLargeDetent {
                    // 从 large 下滑 -> 切换到 medium
                    currentHeightFraction = mediumHeightFraction
                    isAtLargeDetent = false
                }
                dragOffset = 0
            }
        }
}
```

#### 4. 与列表滚动的协调
```swift
// 在内容区域顶部添加一个透明的拖拽区域
// 只有在这个区域内才响应拖拽手势
// 列表区域的滚动由 HostingTableView 自己处理
```

---

## 四、SearchView 集成

### 修改位置: `SearchView.swift`

#### 1. 添加开关（第 14 行附近）
```swift
// MARK: - 聚合列表显示模式
let useOverlayForClusterList = true  // true: overlay, false: sheet
```

#### 2. 条件渲染（第 408-498 行区域）

```swift
// MARK: - Stage 2: 聚合列表
if useOverlayForClusterList {
    // Overlay 模式
    if isShowingClusterList {
        OverlaySheetContainer(
            isPresented: $isShowingClusterList,
            cornerRadius: Constants.sheetCornerRadius,
            onDismiss: {
                // 手动关闭逻辑
                if !shouldRestoreClusterList {
                    clusterAnnotations = []
                    appState.isShowingSearchView = true
                }
            }
        ) {
            clusterListContent
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(100)  // 确保在最上层
    }
} else {
    // Sheet 模式（保持现有代码）
    .sheet(isPresented: $isShowingClusterList, ...) { ... }
}
```

#### 3. 提取列表内容为计算属性
```swift
@ViewBuilder
private var clusterListContent: some View {
    VStack(spacing: 0) {
        // 顶部标题栏（现有代码）
        HStack { ... }
        Divider()
        // HostingTableView（现有代码）
        HostingTableView(...)
    }
    .id(clusterListSession)
}
```

---

## 五、简化的状态流

### Overlay 模式的优势

| 场景 | Sheet 模式 | Overlay 模式 |
|------|-----------|-------------|
| 点击聚合标注 | 需要先隐藏搜索栏 sheet | 直接显示 overlay |
| 从详情返回 | 需要 0.05s 延迟 | 可以立即显示（0 延迟） |
| 关闭列表 | sheet 动画约 0.3s | 可自定义更快动画 |

### 可移除的延迟代码

```swift
// restoreClusterListIfNeeded 中：
// Sheet 模式：需要延迟
DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { ... }

// Overlay 模式：可以直接执行
isShowingClusterList = true
```

---

## 六、文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `View/Shared/OverlaySheet/OverlaySheetContainer.swift` | 新建 | 通用 overlay sheet 容器 |
| `View/FrontPages/SearchView.swift` | 修改 | 添加开关 + 条件渲染 |
| `guanzhi.xcodeproj/project.pbxproj` | 修改 | 添加新文件引用 |

---

## 七、测试验证清单

- [ ] 开关 `useOverlayForClusterList = false` 时，行为与修改前完全一致
- [ ] 开关 `useOverlayForClusterList = true` 时：
  - [ ] 点击聚合标注，overlay 立即出现
  - [ ] 拖拽指示器显示正确
  - [ ] 向上拖拽切换到 large 高度
  - [ ] 向下拖拽切换回 medium 高度
  - [ ] 大幅向下拖拽关闭 overlay
  - [ ] 点击关闭按钮关闭 overlay
  - [ ] 列表可正常滚动
  - [ ] 点击列表项进入详情
  - [ ] 从详情返回，overlay 立即恢复
  - [ ] 背景地图可交互（平移、缩放）
  - [ ] 圆角、阴影与 sheet 一致

---

## 八、风险与缓解

| 风险 | 缓解措施 |
|------|---------|
| 拖拽手势与列表滚动冲突 | 只在顶部拖拽区响应手势 |
| 动画不够流畅 | 使用 spring 动画，调参优化 |
| 键盘弹出时布局问题 | 当前列表无输入框，暂不考虑 |
| 不同设备适配 | 使用比例而非固定高度 |

---

## 九、预估工作量

- OverlaySheetContainer 组件: 约 80 行
- SearchView 修改: 约 30 行
- 测试调优: 约 30 分钟

**总计**: 约 110 行新代码 + 测试时间
