//
//  CustomMKAnnotationView.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/3.
//
//  Stage 1: 单个标注 UIKit 视图
//  - 复刻 SwiftUI MapAnnotationView 样式
//  - 64x64 圆形缩略图 + 4pt 黑色边框
//  - 底部定位图标
//  - 异步加载缩略图
//
//  阴影实现：复制图标作为阴影（不使用 path 拟合）
//  - 圆形阴影：CAShapeLayer 圆形，偏移后置底
//  - 尖角阴影：复制 icon-position 图像，染色+偏移+置底
//  - 所有布局在 layoutSubviews() 中更新
//

import MapKit
import UIKit

class CustomMKAnnotationView: MKAnnotationView {

    // MARK: - Constants

    static let reuseIdentifier = "CustomMKAnnotationView"

    private let thumbnailSize: CGFloat = 64
    private let borderWidth: CGFloat = 4
    private let positionIconHeight: CGFloat = 33
    private let positionIconWidth: CGFloat = 24
    private let overlapAmount: CGFloat = 16  // 圆形覆盖尖角的重叠量

    // 阴影参数
    private let shadowOffsetX: CGFloat = 2
    private let shadowOffsetY: CGFloat = 4
    private let shadowColor: UIColor = UIColor(named: "color-primary") ?? .systemBlue

    // 边距：为阴影和内容预留足够空间（四个方向）
    private let paddingLeft: CGFloat = 8
    private let paddingTop: CGFloat = 8
    private let paddingRight: CGFloat = 12   // 阴影向右偏移，需要更多空间
    private let paddingBottom: CGFloat = 12  // 阴影向下偏移，需要更多空间

    // MARK: - UI Elements

    /// 圆形阴影层：CAShapeLayer 绘制圆形，偏移后作为缩略图阴影
    private let circleShadowLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        return layer
    }()

    /// 尖角阴影视图：复制 icon-position 图像，染色后作为阴影
    private let positionIconShadowView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    /// 容器视图：承载所有内容（不含阴影）
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.clipsToBounds = false
        return view
    }()

    /// 缩略图 ImageView
    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor(named: "color-primary") ?? .systemBlue
        return imageView
    }()

    /// 定位图标
    private let positionIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "icon-position")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    /// 加载指示器
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.color = .white
        return indicator
    }()


    // MARK: - Properties

    private(set) var thumbnailImage: UIImage?
    private var currentImageUrl: URL?

    // 缓存计算值
    private var contentWidth: CGFloat = 0
    private var contentHeight: CGFloat = 0

    // MARK: - Initialization

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }

    // MARK: - Setup

    private func setupViews() {
        // ===== 计算尺寸 =====
        let visiblePinHeight = positionIconHeight - overlapAmount  // 尖角露出部分
        contentHeight = thumbnailSize + visiblePinHeight           // 内容总高度
        contentWidth = thumbnailSize                               // 内容宽度

        // 为阴影预留空间（四个方向都留出边距）
        let totalWidth = paddingLeft + contentWidth + paddingRight
        let totalHeight = paddingTop + contentHeight + paddingBottom

        // ===== 设置 MKAnnotationView 的 frame =====
        // centerOffset 由 layoutSubviews 统一计算（使用正确的测量法）
        frame = CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight)

        // 禁用默认 callout
        canShowCallout = false

        // 关键：MKAnnotationView 不裁剪
        clipsToBounds = false
        layer.masksToBounds = false
        backgroundColor = .clear

        // ===== 圆形阴影层（置底）=====
        circleShadowLayer.fillColor = shadowColor.cgColor
        layer.addSublayer(circleShadowLayer)

        // ===== 尖角阴影视图（置底）=====
        // 使用 icon-position 图像的 template 模式，染成阴影色
        if let positionIcon = UIImage(named: "icon-position")?.withRenderingMode(.alwaysTemplate) {
            positionIconShadowView.image = positionIcon
            positionIconShadowView.tintColor = shadowColor
        }
        addSubview(positionIconShadowView)

        // ===== 容器视图 =====
        addSubview(containerView)

        // ===== 定位图标（在容器内，z-order 底层）=====
        containerView.addSubview(positionIconView)

        // ===== 缩略图（在容器内，z-order 顶层）=====
        thumbnailImageView.layer.cornerRadius = thumbnailSize / 2
        thumbnailImageView.layer.borderWidth = borderWidth
        thumbnailImageView.layer.borderColor = UIColor.black.cgColor
        thumbnailImageView.layer.masksToBounds = true
        containerView.addSubview(thumbnailImageView)

        // ===== 加载指示器 =====
        thumbnailImageView.addSubview(activityIndicator)

        // 初始布局
        setNeedsLayout()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        // ===== 1) 先完成子视图布局（确保 frame 是最终值）=====

        // 容器视图位置
        containerView.frame = CGRect(x: paddingLeft, y: paddingTop, width: contentWidth, height: contentHeight)

        // 缩略图位置
        thumbnailImageView.frame = CGRect(x: 0, y: 0, width: thumbnailSize, height: thumbnailSize)

        // 定位图标位置
        positionIconView.frame = CGRect(
            x: (contentWidth - positionIconWidth) / 2,
            y: thumbnailSize - overlapAmount,
            width: positionIconWidth,
            height: positionIconHeight
        )

        // 圆形阴影位置（偏移后）
        let circleShadowRect = CGRect(
            x: paddingLeft + shadowOffsetX,
            y: paddingTop + shadowOffsetY,
            width: thumbnailSize,
            height: thumbnailSize
        )
        circleShadowLayer.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: circleShadowRect.size)).cgPath
        circleShadowLayer.frame = circleShadowRect

        // 尖角阴影位置（偏移后）
        positionIconShadowView.frame = CGRect(
            x: paddingLeft + (contentWidth - positionIconWidth) / 2 + shadowOffsetX,
            y: paddingTop + thumbnailSize - overlapAmount + shadowOffsetY,
            width: positionIconWidth,
            height: positionIconHeight
        )

        // 加载指示器居中
        activityIndicator.center = CGPoint(x: thumbnailSize / 2, y: thumbnailSize / 2)

        // ===== 2) 计算"尖端 tip"在 annotationView 坐标系中的真实位置 =====
        // 从 positionIconView 的真实 frame convert 出 tip 点（底部中心）
        let tipInSelf = positionIconView.convert(
            CGPoint(x: positionIconView.bounds.midX, y: positionIconView.bounds.maxY),
            to: self
        )

        // ===== 3) 用正确公式：centerOffset = viewCenter - tip =====
        let viewCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        let newCenterOffset = CGPoint(
            x: viewCenter.x - tipInSelf.x,
            y: viewCenter.y - tipInSelf.y
        )

        // 只在值变化时更新（避免无限循环）
        if centerOffset != newCenterOffset {
            centerOffset = newCenterOffset
        }
    }

    // MARK: - Configuration

    func configure(with annotation: CustomAnnotation) {
        thumbnailImage = nil
        thumbnailImageView.image = nil

        if let imageUrl = annotation.imageUrl {
            loadThumbnail(from: imageUrl)
        } else {
            showPlaceholder()
        }
    }

    // MARK: - Image Loading

    private func loadThumbnail(from url: URL) {
        currentImageUrl = url
        activityIndicator.startAnimating()

        ImageCache.shared.loadImage(from: url) { [weak self] loadedImage in
            guard let self = self else { return }
            guard self.currentImageUrl == url else { return }

            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                if let image = loadedImage {
                    self.thumbnailImage = image
                    self.thumbnailImageView.image = image
                } else {
                    self.showPlaceholder()
                }
            }
        }
    }

    private func showPlaceholder() {
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        thumbnailImageView.image = UIImage(systemName: "photo", withConfiguration: config)
        thumbnailImageView.tintColor = .white
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.alpha = 0.8
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: 0.1) {
            self.transform = .identity
            self.alpha = 1.0
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.1) {
            self.transform = .identity
            self.alpha = 1.0
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImage = nil
        thumbnailImageView.image = nil
        currentImageUrl = nil
        activityIndicator.stopAnimating()
        transform = .identity
        alpha = 1.0
    }

}
