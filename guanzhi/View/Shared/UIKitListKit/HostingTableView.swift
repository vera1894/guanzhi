//
//  HostingTableView.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/5.
//
//  通用 UITableView 列表组件的 SwiftUI 包装器
//  使用 UIViewControllerRepresentable 桥接 UIKit
//

import SwiftUI

/// 通用 UITableView 列表组件，支持 SwiftUI 行视图
///
/// 解决 SwiftUI ScrollView 的以下问题：
/// - 无法完全禁用边界回弹
/// - 触底后继续拖动产生"缓缓回滑"
///
/// 使用示例：
/// ```swift
/// HostingTableView(
///     items: shares,
///     id: \.id,
///     row: { share in
///         ShareSingleView(share: share)
///             .environmentObject(viewModel)
///     },
///     onSelect: { share in
///         handleTap(share)
///     },
///     bouncesEnabled: false,
///     endFooterStyle: .text("- 到底啦 -")
/// )
/// ```
struct HostingTableView<Item, ID: Hashable, RowView: View>: UIViewControllerRepresentable {

    // MARK: - 必需参数

    /// 列表数据
    let items: [Item]

    /// 数据项 ID 的 KeyPath（ID 必须稳定且唯一）
    let id: KeyPath<Item, ID>

    /// SwiftUI 行视图构建器
    /// 注意：环境对象应在此 closure 中注入
    let row: (Item) -> RowView

    // MARK: - 可选参数

    /// 点击行的回调
    var onSelect: ((Item) -> Void)? = nil

    /// 是否启用边界回弹（false = 触底不回滑）
    var bouncesEnabled: Bool = true

    /// 底部 Footer 样式
    var endFooterStyle: HostingTableViewFooterStyle = .none

    /// 恢复滚动到的目标 ID
    var restoreToID: ID? = nil

    /// 预估行高（提升大列表性能）
    var estimatedRowHeight: CGFloat = 133

    /// 是否显示分割线
    var showsSeparators: Bool = false

    /// 内容边距
    var contentInsets: UIEdgeInsets = .zero

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> HostingTableViewController<Item, ID, RowView> {
        let vc = HostingTableViewController<Item, ID, RowView>()

        // 设置必需属性
        vc.idKeyPath = id
        vc.rowBuilder = row
        vc.items = items

        // 设置可选属性
        vc.onSelect = onSelect
        vc.bouncesEnabled = bouncesEnabled
        vc.estimatedRowHeight = estimatedRowHeight
        vc.showsSeparators = showsSeparators
        vc.contentInsets = contentInsets
        vc.restoreToID = restoreToID

        return vc
    }

    func updateUIViewController(_ vc: HostingTableViewController<Item, ID, RowView>, context: Context) {
        // 检查 items 是否真正变化（比较 ID 数组）
        let oldIDs = vc.items.map { $0[keyPath: id] }
        let newIDs = items.map { $0[keyPath: id] }
        let needsReload = oldIDs != newIDs

        // 同步属性
        vc.items = items
        vc.rowBuilder = row
        vc.onSelect = onSelect
        vc.bouncesEnabled = bouncesEnabled
        vc.estimatedRowHeight = estimatedRowHeight
        vc.showsSeparators = showsSeparators
        vc.contentInsets = contentInsets

        // 应用配置
        vc.applyConfiguration()

        // 设置 Footer
        vc.setupFooter(endFooterStyle)

        // 只在 items 真正变化时 reload
        if needsReload {
            vc.tableView.reloadData()
            vc.tableView.layoutIfNeeded()
        }

        // 设置恢复目标并尝试滚动（reload + layout 之后）
        if let targetID = restoreToID {
            vc.restoreToID = targetID
            vc.scrollToItemIfNeeded()
        }
    }
}

// MARK: - 便捷初始化器

extension HostingTableView {

    /// 简化初始化器（只需必需参数）
    init(
        items: [Item],
        id: KeyPath<Item, ID>,
        @ViewBuilder row: @escaping (Item) -> RowView
    ) {
        self.items = items
        self.id = id
        self.row = row
    }
}

// MARK: - 链式配置 API

extension HostingTableView {

    /// 设置点击回调
    func onSelect(_ action: @escaping (Item) -> Void) -> Self {
        var copy = self
        copy.onSelect = action
        return copy
    }

    /// 设置是否启用边界回弹
    func bouncesEnabled(_ enabled: Bool) -> Self {
        var copy = self
        copy.bouncesEnabled = enabled
        return copy
    }

    /// 设置底部 Footer 样式
    func endFooterStyle(_ style: HostingTableViewFooterStyle) -> Self {
        var copy = self
        copy.endFooterStyle = style
        return copy
    }

    /// 设置恢复滚动到的目标 ID
    func restoreToID(_ id: ID?) -> Self {
        var copy = self
        copy.restoreToID = id
        return copy
    }

    /// 设置预估行高
    func estimatedRowHeight(_ height: CGFloat) -> Self {
        var copy = self
        copy.estimatedRowHeight = height
        return copy
    }

    /// 设置是否显示分割线
    func showsSeparators(_ show: Bool) -> Self {
        var copy = self
        copy.showsSeparators = show
        return copy
    }

    /// 设置内容边距
    func contentInsets(_ insets: UIEdgeInsets) -> Self {
        var copy = self
        copy.contentInsets = insets
        return copy
    }
}
