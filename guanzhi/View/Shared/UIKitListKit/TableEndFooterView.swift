//
//  TableEndFooterView.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/5.
//
//  通用列表底部 Footer 视图
//  用于显示 "- 到底啦 -" 等提示信息
//

import UIKit

/// 通用列表底部 Footer（"到底啦"等）
/// 使用固定高度 frame，确保 UIKit 布局稳定
class TableEndFooterView: UIView {

    // MARK: - 初始化

    /// 创建文本 Footer
    /// - Parameters:
    ///   - text: 显示的文本，如 "- 到底啦 -"
    ///   - height: Footer 高度，默认 56pt
    ///   - textColor: 文本颜色，默认 secondaryLabel
    ///   - font: 文本字体，默认 14pt 系统字体
    init(
        text: String,
        height: CGFloat = 56,
        textColor: UIColor = .secondaryLabel,
        font: UIFont = .systemFont(ofSize: 14)
    ) {
        // 使用固定高度 frame，确保 UIKit 布局稳定
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height))
        setupUI(text: text, textColor: textColor, font: font)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI 设置

    private func setupUI(text: String, textColor: UIColor, font: UIFont) {
        backgroundColor = .clear

        let label = UILabel()
        label.text = text
        label.textColor = textColor
        label.font = font
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
