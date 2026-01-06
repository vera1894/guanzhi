//
//  ClusterAnnotationView.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/4.
//
//  Stage 2: 聚合标注 UIKit 视图
//  - 保持单个标注样式（圆形缩略图 + 底部定位图标）
//  - 右上角添加白底黑字数量角标
//  - 使用第一个成员的缩略图
//

import MapKit
import UIKit

class ClusterAnnotationView: MKAnnotationView {

    // MARK: - Constants

    static let reuseIdentifier = "ClusterAnnotationView"

    private let thumbnailSize: CGFloat = 64
    private let borderWidth: CGFloat = 4
    private let positionIconHeight: CGFloat = 33
    private let positionIconWidth: CGFloat = 24
    private let overlapAmount: CGFloat = 16  // 圆形覆盖尖角的重叠量

    // 角标参数
    private let badgeMinWidth: CGFloat = 20
    private let badgeHeight: CGFloat = 20
    private let badgePadding: CGFloat = 6
    private let badgeFontSize: CGFloat = 12

    // 阴影参数
    private let shadowOffsetX: CGFloat = 2
    private let shadowOffsetY: CGFloat = 4
    private let shadowColor: UIColor = UIColor(named: "color-primary") ?? .systemBlue

    // 边距
    private let paddingLeft: CGFloat = 8
    private let paddingTop: CGFloat = 8
    private let paddingRight: CGFloat = 16   // 角标需要更多空间
    private let paddingBottom: CGFloat = 12

    // MARK: - UI Elements

    /// 圆形阴影层
    private let circleShadowLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        return layer
    }()

    /// 尖角阴影视图
    private let positionIconShadowView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    /// 容器视图
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

    /// 数量角标背景
    private let badgeBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()

    /// 数量角标标签
    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        return label
    }()

    /// 加载指示器
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.color = .white
        return indicator
    }()

    // MARK: - Properties

    private var currentImageUrl: URL?
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
        // 计算尺寸
        let visiblePinHeight = positionIconHeight - overlapAmount
        contentHeight = thumbnailSize + visiblePinHeight
        contentWidth = thumbnailSize

        let totalWidth = paddingLeft + contentWidth + paddingRight
        let totalHeight = paddingTop + contentHeight + paddingBottom

        frame = CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
        canShowCallout = false
        clipsToBounds = false
        layer.masksToBounds = false
        backgroundColor = .clear

        // 圆形阴影层
        circleShadowLayer.fillColor = shadowColor.cgColor
        layer.addSublayer(circleShadowLayer)

        // 尖角阴影视图
        if let positionIcon = UIImage(named: "icon-position")?.withRenderingMode(.alwaysTemplate) {
            positionIconShadowView.image = positionIcon
            positionIconShadowView.tintColor = shadowColor
        }
        addSubview(positionIconShadowView)

        // 容器视图
        addSubview(containerView)

        // 定位图标
        containerView.addSubview(positionIconView)

        // 缩略图
        thumbnailImageView.layer.cornerRadius = thumbnailSize / 2
        thumbnailImageView.layer.borderWidth = borderWidth
        thumbnailImageView.layer.borderColor = UIColor.black.cgColor
        thumbnailImageView.layer.masksToBounds = true
        containerView.addSubview(thumbnailImageView)

        // 角标背景
        badgeBackgroundView.layer.shadowColor = UIColor.black.cgColor
        badgeBackgroundView.layer.shadowOffset = CGSize(width: 0, height: 1)
        badgeBackgroundView.layer.shadowRadius = 2
        badgeBackgroundView.layer.shadowOpacity = 0.2
        containerView.addSubview(badgeBackgroundView)

        // 角标标签
        badgeBackgroundView.addSubview(badgeLabel)

        // 加载指示器
        thumbnailImageView.addSubview(activityIndicator)

        setNeedsLayout()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

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

        // 圆形阴影位置
        let circleShadowRect = CGRect(
            x: paddingLeft + shadowOffsetX,
            y: paddingTop + shadowOffsetY,
            width: thumbnailSize,
            height: thumbnailSize
        )
        circleShadowLayer.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: circleShadowRect.size)).cgPath
        circleShadowLayer.frame = circleShadowRect

        // 尖角阴影位置
        positionIconShadowView.frame = CGRect(
            x: paddingLeft + (contentWidth - positionIconWidth) / 2 + shadowOffsetX,
            y: paddingTop + thumbnailSize - overlapAmount + shadowOffsetY,
            width: positionIconWidth,
            height: positionIconHeight
        )

        // 角标布局（右上角）
        let badgeText = badgeLabel.text ?? ""
        let textWidth = badgeText.size(withAttributes: [.font: badgeLabel.font!]).width
        let badgeWidth = max(badgeMinWidth, textWidth + badgePadding * 2)
        badgeBackgroundView.frame = CGRect(
            x: thumbnailSize - badgeWidth / 2,
            y: -badgeHeight / 4,
            width: badgeWidth,
            height: badgeHeight
        )
        badgeBackgroundView.layer.cornerRadius = badgeHeight / 2
        badgeLabel.frame = badgeBackgroundView.bounds

        // 加载指示器居中
        activityIndicator.center = CGPoint(x: thumbnailSize / 2, y: thumbnailSize / 2)

        // 计算尖端位置并设置 centerOffset
        let tipInSelf = positionIconView.convert(
            CGPoint(x: positionIconView.bounds.midX, y: positionIconView.bounds.maxY),
            to: self
        )
        let viewCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        let newCenterOffset = CGPoint(
            x: viewCenter.x - tipInSelf.x,
            y: viewCenter.y - tipInSelf.y
        )
        if centerOffset != newCenterOffset {
            centerOffset = newCenterOffset
        }
    }

    // MARK: - Configuration

    func configure(with clusterAnnotation: MKClusterAnnotation) {
        let memberCount = clusterAnnotation.memberAnnotations.count

        // 设置角标文字
        if memberCount > 99 {
            badgeLabel.text = "99+"
        } else {
            badgeLabel.text = "\(memberCount)"
        }

        // 获取第一个成员的缩略图
        if let firstMember = clusterAnnotation.memberAnnotations.first as? CustomAnnotation,
           let imageUrl = firstMember.imageUrl {
            loadThumbnail(from: imageUrl)
        } else {
            showPlaceholder()
        }

        setNeedsLayout()
    }

    // MARK: - Image Loading

    private func loadThumbnail(from url: URL) {
        currentImageUrl = url
        activityIndicator.startAnimating()

        // 聚合图标明确使用原图，永不白化（即使代表图 fadeScore >= 90）
        ImageCache.shared.loadImage(
            from: url,
            variant: .original
        ) { [weak self] loadedImage in
            // 回调已统一在主线程，无需再 DispatchQueue.main.async
            guard let self = self, self.currentImageUrl == url else { return }
            self.activityIndicator.stopAnimating()
            if let image = loadedImage {
                self.thumbnailImageView.image = image
            } else {
                self.showPlaceholder()
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
        thumbnailImageView.image = nil
        badgeLabel.text = nil
        currentImageUrl = nil
        activityIndicator.stopAnimating()
        transform = .identity
        alpha = 1.0
    }
}
