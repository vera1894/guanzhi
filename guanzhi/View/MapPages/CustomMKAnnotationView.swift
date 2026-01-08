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

    // ===== 聚合抵抗参数 =====
    // MapKit 通过 annotation view 的 frame 碰撞检测来决定是否聚合
    // 这里通过缩小碰撞盒（frame）来减少聚合敏感度，视觉内容通过子视图溢出显示
    //
    // 数值越大 = 碰撞盒越小 = 越不容易聚合
    // 数值为 0 = 碰撞盒等于视觉尺寸（默认行为）
    //
    // 碰撞盒与点击区域已解耦（通过 point(inside:with:) 重写）：
    // - 碰撞盒可以很小（下限 12pt），让聚合更不敏感
    // - 点击区域仍然用视觉尺寸（containerView），保证好点击
    //
    // 当前视觉尺寸约 84x101pt，碰撞盒下限 12pt
    // 建议范围：0-40（超过 40 后碰撞盒接近下限，效果不再变化）
    static let clusterResistanceHorizontal: CGFloat = 40   // 水平方向聚合抵抗
    static let clusterResistanceVertical: CGFloat = 42    // 垂直方向聚合抵抗

    // 碰撞盒最小尺寸（与点击区域解耦后可以设得很小）
    private let minCollisionSize: CGFloat = 12

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
    private var currentFadeScore: Int = 0
    private var isShowingPlaceholder: Bool = false

    // 缓存计算值
    private var contentWidth: CGFloat = 0
    private var contentHeight: CGFloat = 0

    // 通知观察者
    private var imageCacheObserver: NSObjectProtocol?

    // MARK: - Initialization

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupNotificationObserver()

        // Stage 2: 启用聚合功能
        clusteringIdentifier = "share"
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
        setupNotificationObserver()
    }

    deinit {
        if let observer = imageCacheObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Notification

    private func setupNotificationObserver() {
        imageCacheObserver = NotificationCenter.default.addObserver(
            forName: .imageCacheDidLoadImage,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleImageCacheNotification(notification)
        }
    }

    private func handleImageCacheNotification(_ notification: Notification) {
        guard isShowingPlaceholder,
              let url = notification.userInfo?["url"] as? URL,
              let currentUrl = currentImageUrl,
              url.absoluteString == currentUrl.absoluteString else {
            return
        }

        // 图片已缓存，重新加载
        loadThumbnail(from: currentUrl, fadeScore: currentFadeScore)
    }

    // MARK: - Setup

    private func setupViews() {
        // ===== 计算尺寸 =====
        let visiblePinHeight = positionIconHeight - overlapAmount  // 尖角露出部分
        contentHeight = thumbnailSize + visiblePinHeight           // 内容总高度
        contentWidth = thumbnailSize                               // 内容宽度

        // 视觉所需的总尺寸
        let visualWidth = paddingLeft + contentWidth + paddingRight
        let visualHeight = paddingTop + contentHeight + paddingBottom

        // 碰撞盒尺寸 = 视觉尺寸 - 抵抗值（抵抗值越大，碰撞盒越小，越不容易聚合）
        // 碰撞盒下限设为很小的值，点击区域通过 point(inside:with:) 单独处理
        let collisionWidth = max(minCollisionSize, visualWidth - Self.clusterResistanceHorizontal * 2)
        let collisionHeight = max(minCollisionSize, visualHeight - Self.clusterResistanceVertical * 2)

        // ===== 设置 MKAnnotationView 的 frame =====
        // frame 使用碰撞盒尺寸，视觉内容通过子视图溢出显示（clipsToBounds = false）
        // centerOffset 由 layoutSubviews 统一计算（使用正确的测量法）
        frame = CGRect(x: 0, y: 0, width: collisionWidth, height: collisionHeight)

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
        // 由于碰撞盒（frame）比视觉尺寸小，内容需要向负方向偏移以溢出显示
        // 偏移量 = -clusterResistance，使视觉内容仍然居中于原本位置

        // 容器视图位置（向负方向偏移，使内容溢出碰撞盒）
        containerView.frame = CGRect(
            x: paddingLeft - Self.clusterResistanceHorizontal,
            y: paddingTop - Self.clusterResistanceVertical,
            width: contentWidth,
            height: contentHeight
        )

        // 缩略图位置
        thumbnailImageView.frame = CGRect(x: 0, y: 0, width: thumbnailSize, height: thumbnailSize)

        // 定位图标位置
        positionIconView.frame = CGRect(
            x: (contentWidth - positionIconWidth) / 2,
            y: thumbnailSize - overlapAmount,
            width: positionIconWidth,
            height: positionIconHeight
        )

        // 圆形阴影位置（同样向负方向偏移）
        let circleShadowRect = CGRect(
            x: paddingLeft - Self.clusterResistanceHorizontal + shadowOffsetX,
            y: paddingTop - Self.clusterResistanceVertical + shadowOffsetY,
            width: thumbnailSize,
            height: thumbnailSize
        )
        circleShadowLayer.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: circleShadowRect.size)).cgPath
        circleShadowLayer.frame = circleShadowRect

        // 尖角阴影位置（同样向负方向偏移）
        positionIconShadowView.frame = CGRect(
            x: paddingLeft - Self.clusterResistanceHorizontal + (contentWidth - positionIconWidth) / 2 + shadowOffsetX,
            y: paddingTop - Self.clusterResistanceVertical + thumbnailSize - overlapAmount + shadowOffsetY,
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

    // MARK: - Hit Testing（碰撞盒/点击盒解耦）

    /// 重写点击命中测试，使用视觉区域（containerView）而不是碰撞盒（frame）
    /// 这样碰撞盒可以很小（减少聚合敏感度），但点击区域仍然足够大
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // 使用 containerView 的 frame 作为点击区域，并稍微扩大以便于点击
        let hitRect = containerView.frame.insetBy(dx: -10, dy: -10)
        return hitRect.contains(point)
    }

    // MARK: - Configuration

    func configure(with annotation: CustomAnnotation) {
        // 关键：复用时也必须设置 clusteringIdentifier，否则聚合功能会失效
        clusteringIdentifier = "share"

        thumbnailImage = nil
        thumbnailImageView.image = nil

        // 获取 fadeScore 用于白化效果
        let fadeScore = annotation.annotationData?.fadeScore ?? 0

        if let imageUrl = annotation.imageUrl {
            loadThumbnail(from: imageUrl, fadeScore: fadeScore)
        } else {
            showPlaceholder()
        }
    }

    // MARK: - Image Loading

    private func loadThumbnail(from url: URL, fadeScore: Int) {
        currentImageUrl = url
        currentFadeScore = fadeScore
        isShowingPlaceholder = false

        // 显示加载中状态
        showLoadingState()

        // 使用统一 API，传入 fadeScore 以支持白化效果
        ImageCache.shared.loadImage(
            from: url,
            variant: .fadeVeil(fadeScore: fadeScore)
        ) { [weak self] loadedImage in
            // 回调已统一在主线程，无需再 DispatchQueue.main.async
            guard let self = self, self.currentImageUrl == url else { return }
            self.hideLoadingState()
            if let image = loadedImage {
                self.thumbnailImage = image
                self.thumbnailImageView.image = image
                self.thumbnailImageView.contentMode = .scaleAspectFill
                self.isShowingPlaceholder = false
            } else {
                self.showFailedState()
            }
        }
    }

    /// 显示加载中状态
    private func showLoadingState() {
        ImagePlaceholderUIKit.configureForLoading(thumbnailImageView, pointSize: 24)
        activityIndicator.startAnimating()
    }

    /// 隐藏加载状态
    private func hideLoadingState() {
        ImagePlaceholderUIKit.removeAnimation(from: thumbnailImageView)
        activityIndicator.stopAnimating()
    }

    /// 显示加载失败状态
    private func showFailedState() {
        ImagePlaceholderUIKit.configureForFailed(thumbnailImageView, pointSize: 24)
        isShowingPlaceholder = true
    }

    /// 兼容旧方法名
    private func showPlaceholder() {
        showFailedState()
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
        currentFadeScore = 0
        isShowingPlaceholder = false
        activityIndicator.stopAnimating()
        transform = .identity
        alpha = 1.0
    }

}
