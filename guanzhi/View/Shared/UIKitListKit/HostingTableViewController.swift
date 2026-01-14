//
//  HostingTableViewController.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/5.
//
//  通用 UITableViewController，支持 SwiftUI 行视图
//  使用 UIHostingConfiguration 承载 SwiftUI 内容
//

import UIKit
import SwiftUI

/// 通用 UITableViewController，用于承载 SwiftUI 行视图
/// 解决 SwiftUI ScrollView 触底回弹问题
class HostingTableViewController<Item, ID: Hashable, RowView: View>: UITableViewController {

    // MARK: - Cell 复用标识
    private let cellIdentifier = "HostingCell"

    // MARK: - 数据与配置（从 Representable 同步）

    /// 列表数据
    var items: [Item] = []

    /// 数据项 ID 的 KeyPath
    var idKeyPath: KeyPath<Item, ID>!

    /// SwiftUI 行视图构建器
    var rowBuilder: ((Item) -> RowView)!

    /// 点击回调
    var onSelect: ((Item) -> Void)?

    /// 是否启用边界回弹（false = 触底不回滑）
    var bouncesEnabled: Bool = true

    /// 恢复滚动到的目标 ID
    var restoreToID: ID?

    /// 预估行高（提升性能）
    var estimatedRowHeight: CGFloat = 133

    /// 是否显示分割线
    var showsSeparators: Bool = false

    /// 内容边距
    var contentInsets: UIEdgeInsets = .zero

    /// Footer 缓存（避免重复创建 custom footer）
    private var cachedFooterView: UIView?

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()

        // 注册 cell（必须）
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)

        // 设置动态高度（必须）
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = estimatedRowHeight

        // 移除多余分割线
        tableView.tableFooterView = UIView()

        // 背景透明（让毛玻璃效果透过来）
        tableView.backgroundColor = .clear
        view.backgroundColor = .clear

        // 应用配置
        applyConfiguration()
    }

    // MARK: - 配置应用

    /// 应用配置（viewDidLoad 和 update 时调用）
    func applyConfiguration() {
        tableView.bounces = bouncesEnabled
        // 始终启用垂直回弹，确保条目较少时也能滑动
        tableView.alwaysBounceVertical = true
        tableView.alwaysBounceHorizontal = false
        tableView.separatorStyle = showsSeparators ? .singleLine : .none
        tableView.contentInset = contentInsets

        // 更新预估行高
        tableView.estimatedRowHeight = estimatedRowHeight
    }

    // MARK: - Footer 设置

    /// 设置底部 Footer
    /// - Parameter style: Footer 样式
    func setupFooter(_ style: HostingTableViewFooterStyle) {
        switch style {
        case .none:
            tableView.tableFooterView = UIView()  // 空 view 移除多余分割线
        case .text(let text):
            tableView.tableFooterView = TableEndFooterView(text: text, height: 56)
        case .custom(let builder):
            // 缓存 custom footer，避免重复创建
            if cachedFooterView == nil {
                cachedFooterView = builder()
            }
            tableView.tableFooterView = cachedFooterView
        }
    }

    // MARK: - 滚动恢复

    /// 滚动到指定 ID（必须在 reload + layout 之后调用）
    /// 智能滚动：如果目标行已在可视区域内，则不滚动；否则滚动到中间
    func scrollToItemIfNeeded() {
        guard let targetID = restoreToID,
              let index = items.firstIndex(where: { $0[keyPath: idKeyPath] == targetID }) else { return }

        // 确保在 layout 完成后执行
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let indexPath = IndexPath(row: index, section: 0)

            // 检查 indexPath 是否有效
            guard index < self.items.count else { return }

            // 检查目标行是否已经在可视区域内
            if let visibleRows = self.tableView.indexPathsForVisibleRows,
               visibleRows.contains(indexPath) {
                // 目标行已可见，不需要滚动，保持原位置
                print("📍 [HostingTableView] 目标行 \(index) 已在可视区域，跳过滚动")
            } else {
                // 目标行不可见，滚动到中间位置
                print("📍 [HostingTableView] 目标行 \(index) 不在可视区域，滚动到中间")
                self.tableView.scrollToRow(
                    at: indexPath,
                    at: .middle,
                    animated: false
                )
            }

            // 消费型，用完即清
            self.restoreToID = nil
        }
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)

        guard indexPath.row < items.count else {
            return cell
        }

        let item = items[indexPath.row]
        let itemID = item[keyPath: idKeyPath]

        // 使用 UIHostingConfiguration 承载 SwiftUI 视图
        cell.contentConfiguration = UIHostingConfiguration {
            rowBuilder(item)
                .id(itemID)  // 关键：确保 SwiftUI 行的稳定标识
        }
        .margins(.all, 0)
        .background(.clear)  // 透明背景

        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear

        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        guard indexPath.row < items.count else { return }

        let item = items[indexPath.row]
        onSelect?(item)
    }
}

// MARK: - Footer 样式枚举

/// Footer 样式
enum HostingTableViewFooterStyle {
    /// 无 Footer
    case none
    /// 文本 Footer（如 "- 到底啦 -"）
    case text(String)
    /// 自定义 Footer（注意：builder 返回的 view 会被缓存）
    case custom(() -> UIView)
}
