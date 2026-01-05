# HostingTableView 通用组件实施计划

**日期：** 2026-01-05
**目的：** 创建通用的 UIKit 列表组件，解决 SwiftUI ScrollView 触底回弹问题
**首个应用场景：** 聚合列表 (ClusterShareListView)

---

## 背景

SwiftUI 的 ScrollView + LazyVStack 存在以下问题：
- 无法完全禁用边界回弹 (bounces)
- `.scrollBounceBehavior(.basedOnSize)` 只能缓解，不能根治
- 触底后继续拖动会产生"缓缓回滑"现象

**解决方案：** 使用 UITableView + UIHostingConfiguration 创建通用列表组件

---

## 文件结构

```
guanzhi/View/Shared/UIKitListKit/
├── HostingTableView.swift              // SwiftUI 包装器 (UIViewControllerRepresentable)
├── HostingTableViewController.swift    // UITableViewController 核心实现
├── TableEndFooterView.swift            // 通用底部 Footer 视图
```

---

## Phase A：通用组件开发

### 1. API 设计 (HostingTableView.swift)

```swift
/// 通用 UITableView 列表组件，支持 SwiftUI 行视图
struct HostingTableView<Item, ID: Hashable, RowView: View>: UIViewControllerRepresentable {

    // MARK: - 必需参数
    let items: [Item]
    let id: KeyPath<Item, ID>
    let row: (Item) -> RowView

    // MARK: - 可选参数
    var onSelect: ((Item) -> Void)? = nil
    var bouncesEnabled: Bool = true              // 默认 true；需要稳定时设为 false
    var endFooterStyle: EndFooterStyle = .none
    var restoreToID: ID? = nil                   // 恢复滚动到指定 ID
    var estimatedRowHeight: CGFloat = 133        // 预估行高，提升性能
    var showsSeparators: Bool = false            // 是否显示分割线
    var contentInsets: UIEdgeInsets = .zero      // 内容边距

    // MARK: - Footer 样式枚举
    enum EndFooterStyle {
        case none
        case text(String)                        // 如 "- 到底啦 -"
        case custom(() -> UIView)                // 自定义视图（注意缓存）
    }
}
```

### 2. ViewController 实现要点 (HostingTableViewController.swift)

```swift
class HostingTableViewController<Item, ID: Hashable, RowView: View>: UITableViewController {

    // MARK: - 必须持有的属性（从 Representable 同步）
    var items: [Item] = []
    var idKeyPath: KeyPath<Item, ID>!
    var rowBuilder: ((Item) -> RowView)!
    var onSelect: ((Item) -> Void)?
    var bouncesEnabled: Bool = true              // ⚠️ 必须持有，用于 updateUIViewController 同步
    var restoreToID: ID?
    var estimatedRowHeight: CGFloat = 133
    var showsSeparators: Bool = false
    var contentInsets: UIEdgeInsets = .zero

    // Footer 缓存（避免重复创建）
    private var cachedFooterView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()

        // ⚠️ 必须：注册 cell
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HostingCell")

        // ⚠️ 必须：设置动态高度
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = estimatedRowHeight

        // 应用配置
        applyConfiguration()
    }

    /// 应用配置（viewDidLoad 和 update 时调用）
    func applyConfiguration() {
        tableView.bounces = bouncesEnabled
        tableView.alwaysBounceVertical = false
        tableView.separatorStyle = showsSeparators ? .singleLine : .none
        tableView.contentInset = contentInsets
    }

    // MARK: - DataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HostingCell", for: indexPath)
        let item = items[indexPath.row]
        let itemID = item[keyPath: idKeyPath]

        // ⚠️ 使用 UIHostingConfiguration 承载 SwiftUI 视图
        cell.contentConfiguration = UIHostingConfiguration {
            rowBuilder(item)
                .id(itemID)  // ⚠️ 关键：确保 SwiftUI 行的稳定标识
        }
        .margins(.all, 0)

        cell.selectionStyle = .none
        return cell
    }

    // MARK: - Delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let item = items[indexPath.row]
        onSelect?(item)
    }

    // MARK: - 滚动恢复（仅滚动，不 reload）

    /// 滚动到指定 ID（必须在 reload + layout 之后调用）
    func scrollToItemIfNeeded() {
        guard let targetID = restoreToID,
              let index = items.firstIndex(where: { $0[keyPath: idKeyPath] == targetID }) else { return }

        // ⚠️ 确保在 layout 完成后执行
        DispatchQueue.main.async { [weak self] in
            self?.tableView.scrollToRow(
                at: IndexPath(row: index, section: 0),
                at: .middle,
                animated: false
            )
            self?.restoreToID = nil  // 消费型，用完即清
        }
    }

    // MARK: - Footer 设置

    func setupFooter(_ style: HostingTableView<Item, ID, RowView>.EndFooterStyle) {
        switch style {
        case .none:
            tableView.tableFooterView = nil
        case .text(let text):
            // ⚠️ 使用固定高度，确保稳定
            tableView.tableFooterView = TableEndFooterView(text: text, height: 56)
        case .custom(let builder):
            // 缓存 custom footer，避免重复创建
            if cachedFooterView == nil {
                cachedFooterView = builder()
            }
            tableView.tableFooterView = cachedFooterView
        }
    }
}
```

### 3. Representable 实现要点 (HostingTableView.swift 续)

```swift
extension HostingTableView {

    func makeUIViewController(context: Context) -> HostingTableViewController<Item, ID, RowView> {
        let vc = HostingTableViewController<Item, ID, RowView>()
        vc.idKeyPath = id
        vc.rowBuilder = row
        vc.onSelect = onSelect
        vc.bouncesEnabled = bouncesEnabled
        vc.estimatedRowHeight = estimatedRowHeight
        vc.showsSeparators = showsSeparators
        vc.contentInsets = contentInsets
        return vc
    }

    func updateUIViewController(_ vc: HostingTableViewController<Item, ID, RowView>, context: Context) {
        // ⚠️ 只在 items 真正变化时 reload
        let oldIDs = vc.items.map { $0[keyPath: id] }
        let newIDs = items.map { $0[keyPath: id] }
        let needsReload = oldIDs != newIDs

        // 同步属性
        vc.items = items
        vc.onSelect = onSelect
        vc.bouncesEnabled = bouncesEnabled
        vc.restoreToID = restoreToID
        vc.applyConfiguration()
        vc.setupFooter(endFooterStyle)

        if needsReload {
            vc.tableView.reloadData()
            vc.tableView.layoutIfNeeded()
        }

        // ⚠️ reload + layout 之后再滚动
        vc.scrollToItemIfNeeded()
    }
}
```

### 4. Footer 视图 (TableEndFooterView.swift)

```swift
/// 通用列表底部 Footer（"到底啦"等）
class TableEndFooterView: UIView {

    init(text: String, height: CGFloat = 56) {
        // ⚠️ 使用固定高度 frame，确保 UIKit 布局稳定
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height))
        setupUI(text: text)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI(text: String) {
        let label = UILabel()
        label.text = text
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
```

---

## Phase A 验收清单

### 必须通过

- [ ] **Cell 注册** - `tableView.register(UITableViewCell.self, ...)` 在 viewDidLoad 中执行
- [ ] **动态高度** - `rowHeight = .automaticDimension` + `estimatedRowHeight` 已设置
- [ ] **bounces 同步** - VC 持有 `bouncesEnabled`，在 `updateUIViewController` 中同步
- [ ] **Footer 固定高度** - `TableEndFooterView` 使用固定 frame 高度
- [ ] **reload 与 scroll 分离** - `scrollToItemIfNeeded()` 不包含 reloadData()
- [ ] **只在 items 变化时 reload** - `updateUIViewController` 中比较 ID 数组
- [ ] **ID 稳定标识** - cell 内 SwiftUI 视图使用 `.id(itemID)`

### 功能验证

- [ ] **触底不回滑** - `bouncesEnabled = false` 时，滑到底部继续拖动，立即停止
- [ ] **点击响应** - `onSelect` 回调正常触发
- [ ] **Footer 显示** - `.text("- 到底啦 -")` 正确显示在列表末尾
- [ ] **滚动恢复** - `restoreToID` 能准确定位到目标行
- [ ] **分割线** - `showsSeparators = true` 时显示分割线

---

## Phase B：聚合列表迁移

### 使用示例

```swift
// 在 SearchView.swift 中
.sheet(isPresented: $isShowingClusterList, onDismiss: { ... }) {
    HostingTableView(
        items: stableShares,
        id: \.id,
        row: { share in
            ShareSingleView(share: share)
                .environment(\.appState, appState)
                .environmentObject(searchViewModel)
                .environmentObject(navigationCoordinator)
        },
        onSelect: { share in
            handleShareTap(share)
        },
        bouncesEnabled: false,
        endFooterStyle: .text("- 到底啦 -"),
        restoreToID: savedScrollToShareId,
        estimatedRowHeight: 133
    )
    .id(clusterListSession)
    .presentationDetents([.medium, .large], selection: $clusterListDetent)
    .presentationContentInteraction(.scrolls)
    .presentationDragIndicator(.visible)
}
```

### 迁移清单

- [ ] 替换 `ClusterShareListView` → `HostingTableView`
- [ ] 移除原 ScrollView + LazyVStack 相关 workaround
- [ ] 保留 `ShareSingleView` 不变
- [ ] 验证进入详情/返回的滚动恢复

---

## 重要注意事项

### ID 必须稳定且唯一

Item 的 ID（通过 `id: KeyPath` 指定）必须满足：
- **稳定**：同一数据项的 ID 在整个生命周期内不变
- **唯一**：不同数据项的 ID 不重复

否则会出现 cell 复用时内容错乱、状态串行等诡异问题。

### Footer 高度策略

第一版使用固定高度（56pt），确保稳定性。如果未来需要动态高度：
1. 计算好高度后设置 frame
2. 调用 `tableView.tableFooterView = footerView` 触发更新

### 性能优化

- `estimatedRowHeight` 应设置为接近实际行高的值
- 避免在 `row` closure 中做复杂计算
- 大量数据时考虑使用 DiffableDataSource

---

## 未来复用场景参考

| 场景 | bouncesEnabled | endFooterStyle | 其他配置 |
|------|----------------|----------------|----------|
| 聚合列表 | false | .text("- 到底啦 -") | - |
| 搜索结果 | true | .text("没有更多了") | - |
| 消息列表 | true | .custom(loadingSpinner) | showsSeparators: true |
| 评论列表 | false | .none | contentInsets: top 16 |

---

## 参考资料

- [UIHostingConfiguration - Apple Developer](https://developer.apple.com/documentation/swiftui/uihostingconfiguration)
- [UITableView.bounces - Apple Developer](https://developer.apple.com/documentation/uikit/uiscrollview/1619420-bounces)
- [tableFooterView - Apple Developer](https://developer.apple.com/documentation/uikit/uitableview/1614976-tablefooterview)
- [scrollToRow(at:at:animated:) - Apple Developer](https://developer.apple.com/documentation/uikit/uitableview/1614997-scrolltorow)
