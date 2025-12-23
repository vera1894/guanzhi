# iOS 评论系统前端实施规划

**文档版本**: v1.2
**日期**: 2025-12-23
**作者**: Claude Code (前端 CC)
**类型**: 实施规划
**更新记录**:
- v1.2: 完成审查反馈修正
  1. 澄清 `/api/comments/{commentId}/context` 已实现，添加降级策略说明
  2. 键盘适配从"待确认"移至 P0，添加实现要点
  3. `loadComments(reset: true)` 中正确重置 `loadedReplies` 和 `isExpanded`

---

## 一、后端 API 对照表

根据后端 CC 的设计文档（v1.3），需对接以下 API：

| API | 方法 | 说明 | 需登录 | 状态 |
|-----|------|------|--------|------|
| `/api/shares/{shareId}/comments` | POST | 发表评论/回复 | 是 | 已实现 |
| `/api/shares/{shareId}/comments` | GET | 获取评论列表 | 否 | 已实现 |
| `/api/comments/{commentId}/replies` | GET | 获取回复列表 | 否 | 已实现 |
| `/api/comments/{commentId}` | DELETE | 删除评论 | 是 | 已实现 |
| `/api/comments/{commentId}/like` | POST | 点赞评论 | 是 | 已实现 |
| `/api/comments/{commentId}/like` | DELETE | 取消点赞 | 是 | 已实现 |
| `/api/comments/{commentId}/context` | GET | 获取评论上下文（精准定位） | 否 | 已实现 |

> **说明**：`/api/comments/{commentId}/context` 接口已在后端设计文档 v1.3 的 3.7 节定义并实现，
> 返回 `comment`、`parentComment`、`shareId` 和 `position`（含 `isFirstLevel`、`parentId`、`index`）。
> 若后续发现接口不可用，前端采用**降级策略**：打开分享详情 → 加载第一页评论 → 滚动到评论区顶部。

---

## 二、数据模型设计

### 2.1 评论模型

```swift
// MARK: - 评论状态枚举
enum CommentStatus: Int, Codable {
    case normal = 0    // 正常
    case deleted = 1   // 已删除
    case blocked = 2   // 已违规
}

// MARK: - 用户摘要（用于评论展示）
struct CommentUserSummary: Codable, Identifiable {
    let id: Int64
    let nickname: String?
    let avatar: String?
}

// MARK: - 评论视图数据（一级评论）
struct CommentViewData: Identifiable, Codable {
    let id: Int64
    let shareId: Int64
    let userId: Int64
    let userNickname: String?
    let userAvatar: String?
    let parentId: Int64?
    let content: String?
    let status: Int
    let statusText: String?    // "该评论已删除" / "该评论已违规"
    var likeCount: Int
    let replyCount: Int
    let isAuthor: Bool?        // 是否是分享作者
    var liked: Bool            // 当前用户是否已点赞
    let createdAt: String

    // 预览回复（默认2条）
    var repliesPreview: [ReplyViewData]?

    // 本地状态（非服务器返回）
    var isExpanded: Bool = false           // 回复是否已展开
    var loadedReplies: [ReplyViewData] = [] // 已加载的完整回复列表
    var isLoadingReplies: Bool = false     // 是否正在加载回复

    // 计算属性
    var displayStatus: CommentStatus {
        CommentStatus(rawValue: status) ?? .normal
    }

    var canDelete: Bool {
        guard displayStatus == .normal else { return false }
        return userId == OTOLoginStatusManager.shared.getUserID()
    }
}

// MARK: - 回复视图数据（二级评论）
struct ReplyViewData: Identifiable, Codable {
    let id: Int64
    let userId: Int64
    let userNickname: String?
    let userAvatar: String?
    let replyToUserId: Int64?
    let replyToUserNickname: String?  // "回复 @xxx"
    let content: String?
    let status: Int
    let statusText: String?
    var likeCount: Int
    var liked: Bool
    let createdAt: String

    var displayStatus: CommentStatus {
        CommentStatus(rawValue: status) ?? .normal
    }

    var canDelete: Bool {
        guard displayStatus == .normal else { return false }
        return userId == OTOLoginStatusManager.shared.getUserID()
    }
}

// MARK: - 评论上下文（精准定位用）
struct CommentContextResponse: Codable {
    let comment: CommentViewData
    let parentComment: CommentViewData?
    let shareId: Int64
    let position: CommentPositionInfo
}

struct CommentPositionInfo: Codable {
    let isFirstLevel: Bool
    let parentId: Int64?
    let index: Int
}
```

### 2.2 请求/响应模型

```swift
// MARK: - 发表评论请求
struct CreateCommentRequest: Encodable {
    let content: String
    let parentId: Int64?
    let replyToUserId: Int64?
    let latitude: Double?
    let longitude: Double?
}

// MARK: - 评论列表响应
struct CommentListResponse: Codable {
    let respCode: Int
    let respMsg: String?
    let datas: [CommentViewData]?
}

// MARK: - 回复列表响应
struct ReplyListResponse: Codable {
    let respCode: Int
    let respMsg: String?
    let datas: [ReplyViewData]?
}

// MARK: - 评论排序方式
enum CommentSortOrder: String, CaseIterable {
    case `default` = "default"  // 热度
    case latest = "latest"      // 最新
    case likes = "likes"        // 最多点赞

    var displayName: String {
        switch self {
        case .default: return "默认排序"
        case .latest: return "最新"
        case .likes: return "最多点赞"
        }
    }
}
```

---

## 三、ViewModel 设计

### 3.1 CommentViewModel

```swift
@MainActor
class CommentViewModel: ObservableObject {

    // MARK: - 状态
    @Published var comments: [CommentViewData] = []
    @Published var isLoading: Bool = false
    @Published var hasMoreComments: Bool = true
    @Published var sortOrder: CommentSortOrder = .default
    @Published var error: String?

    // MARK: - 回复模式状态
    @Published var isReplyMode: Bool = false
    @Published var replyTarget: CommentViewData?      // 回复的目标一级评论
    @Published var replyToUser: CommentUserSummary?   // 回复的具体用户（可能是二级回复作者）

    // MARK: - 输入状态
    @Published var inputText: String = ""
    @Published var isSubmitting: Bool = false

    // MARK: - 分页
    private var currentOffset: Int = 0
    private let pageSize: Int = 20

    // MARK: - 所属分享
    private(set) var shareId: Int64 = 0

    // MARK: - 方法

    /// 初始化（绑定到分享）
    func bind(to shareId: Int64) {
        self.shareId = shareId
        self.comments = []
        self.currentOffset = 0
        self.hasMoreComments = true
    }

    /// 加载评论列表
    /// - Parameter reset: 是否重置（切换排序、刷新时使用）
    func loadComments(reset: Bool = false) async {
        if reset {
            currentOffset = 0
            hasMoreComments = true
            // 重置时清除所有评论的展开状态和已加载回复
            // 避免切换排序后旧数据残留
            for i in comments.indices {
                comments[i].loadedReplies = []
                comments[i].isExpanded = false
            }
        }

        guard hasMoreComments, !isLoading else { return }

        isLoading = true
        error = nil

        do {
            var newComments = try await CommentService.shared.fetchComments(
                shareId: shareId,
                order: sortOrder,
                offset: currentOffset,
                limit: pageSize
            )

            // 确保新加载的评论本地状态正确初始化
            for i in newComments.indices {
                newComments[i].loadedReplies = []
                newComments[i].isExpanded = false
                newComments[i].isLoadingReplies = false
            }

            if reset {
                comments = newComments
            } else {
                comments.append(contentsOf: newComments)
            }

            currentOffset += newComments.count
            hasMoreComments = newComments.count >= pageSize

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// 加载更多回复
    func loadMoreReplies(for comment: CommentViewData) async {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }

        comments[index].isLoadingReplies = true

        do {
            let offset = comments[index].loadedReplies.count
            let replies = try await CommentService.shared.fetchReplies(
                commentId: comment.id,
                offset: offset,
                limit: 10
            )

            comments[index].loadedReplies.append(contentsOf: replies)
            comments[index].isExpanded = true

        } catch {
            self.error = error.localizedDescription
        }

        comments[index].isLoadingReplies = false
    }

    /// 发表评论/回复
    func postComment() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard inputText.count <= 230 else {
            error = "评论内容不能超过230字"
            return
        }

        // 登录检查
        guard OTOLoginStatusManager.shared.isLoggedIn else {
            // 触发登录流程
            NotificationCenter.default.post(name: .showLoginRequired, object: nil)
            return
        }

        isSubmitting = true

        do {
            let newComment = try await CommentService.shared.createComment(
                shareId: shareId,
                content: inputText,
                parentId: replyTarget?.id,
                replyToUserId: replyToUser?.id
            )

            // 添加到列表
            if replyTarget == nil {
                // 一级评论：添加到列表顶部
                comments.insert(newComment, at: 0)
            } else if let parentIndex = comments.firstIndex(where: { $0.id == replyTarget?.id }) {
                // 二级回复：添加到父评论的回复列表
                let reply = ReplyViewData(
                    id: newComment.id,
                    userId: newComment.userId,
                    userNickname: newComment.userNickname,
                    userAvatar: newComment.userAvatar,
                    replyToUserId: replyToUser?.id,
                    replyToUserNickname: replyToUser?.nickname,
                    content: newComment.content,
                    status: 0,
                    statusText: nil,
                    likeCount: 0,
                    liked: false,
                    createdAt: newComment.createdAt
                )
                comments[parentIndex].loadedReplies.append(reply)
                comments[parentIndex].replyCount += 1
            }

            // 重置输入状态
            inputText = ""
            exitReplyMode()

        } catch {
            self.error = error.localizedDescription
        }

        isSubmitting = false
    }

    /// 删除评论
    func deleteComment(id: Int64) async {
        do {
            try await CommentService.shared.deleteComment(commentId: id)

            // 更新本地状态为已删除
            if let index = comments.firstIndex(where: { $0.id == id }) {
                comments[index].status = CommentStatus.deleted.rawValue
                comments[index].statusText = "该评论已删除"
            } else {
                // 可能是回复
                for i in comments.indices {
                    if let replyIndex = comments[i].loadedReplies.firstIndex(where: { $0.id == id }) {
                        comments[i].loadedReplies[replyIndex].status = CommentStatus.deleted.rawValue
                        comments[i].loadedReplies[replyIndex].statusText = "该评论已删除"
                        break
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// 点赞/取消点赞
    func toggleLike(on commentId: Int64, isReply: Bool = false, parentId: Int64? = nil) async {
        // 登录检查
        guard OTOLoginStatusManager.shared.isLoggedIn else {
            NotificationCenter.default.post(name: .showLoginRequired, object: nil)
            return
        }

        // 乐观更新
        var originalLiked = false
        var originalCount = 0

        if isReply, let parentId = parentId,
           let parentIndex = comments.firstIndex(where: { $0.id == parentId }),
           let replyIndex = comments[parentIndex].loadedReplies.firstIndex(where: { $0.id == commentId }) {

            originalLiked = comments[parentIndex].loadedReplies[replyIndex].liked
            originalCount = comments[parentIndex].loadedReplies[replyIndex].likeCount

            comments[parentIndex].loadedReplies[replyIndex].liked.toggle()
            comments[parentIndex].loadedReplies[replyIndex].likeCount += originalLiked ? -1 : 1

        } else if let index = comments.firstIndex(where: { $0.id == commentId }) {

            originalLiked = comments[index].liked
            originalCount = comments[index].likeCount

            comments[index].liked.toggle()
            comments[index].likeCount += originalLiked ? -1 : 1
        }

        // 调用 API
        do {
            if originalLiked {
                try await CommentService.shared.unlikeComment(commentId: commentId)
            } else {
                try await CommentService.shared.likeComment(commentId: commentId)
            }
        } catch {
            // 回滚
            if isReply, let parentId = parentId,
               let parentIndex = comments.firstIndex(where: { $0.id == parentId }),
               let replyIndex = comments[parentIndex].loadedReplies.firstIndex(where: { $0.id == commentId }) {

                comments[parentIndex].loadedReplies[replyIndex].liked = originalLiked
                comments[parentIndex].loadedReplies[replyIndex].likeCount = originalCount

            } else if let index = comments.firstIndex(where: { $0.id == commentId }) {
                comments[index].liked = originalLiked
                comments[index].likeCount = originalCount
            }

            self.error = error.localizedDescription
        }
    }

    /// 进入回复模式
    func enterReplyMode(to comment: CommentViewData, replyToUser: CommentUserSummary? = nil) {
        isReplyMode = true
        replyTarget = comment
        self.replyToUser = replyToUser ?? CommentUserSummary(
            id: comment.userId,
            nickname: comment.userNickname,
            avatar: comment.userAvatar
        )
    }

    /// 退出回复模式
    func exitReplyMode() {
        isReplyMode = false
        replyTarget = nil
        replyToUser = nil
    }

    /// 切换排序
    func changeSortOrder(to order: CommentSortOrder) async {
        guard order != sortOrder else { return }
        sortOrder = order
        await loadComments(reset: true)
    }
}
```

---

## 四、UI 组件设计

### 4.1 视图层级结构

```
ShareDetailsCardView
├── 拖动指示条
├── ScrollView
│   ├── 分享内容区域（现有）
│   │   ├── Text (分享描述)
│   │   └── 位置信息
│   │
│   └── CommentSectionView (新增) ─────────────────────────┐
│       ├── 排序切换控件 (Segmented/Picker)                 │
│       │   └── [默认排序] [最新] [最多点赞]                  │
│       │                                                   │
│       ├── 评论列表                                         │
│       │   └── ForEach(comments)                           │
│       │       └── CommentCellView                         │
│       │           ├── 用户头像                             │
│       │           ├── 用户昵称 + 作者标识                  │
│       │           ├── 评论内容 / 状态占位                   │
│       │           ├── 时间 + 点赞按钮 + 回复按钮            │
│       │           │                                       │
│       │           └── 回复预览区                           │
│       │               ├── ReplyPreviewView (最多2条)       │
│       │               └── "展开 n 条回复" 按钮              │
│       │                                                   │
│       └── 加载更多指示器                                   │
│                                                           │
└── 底部输入栏 (固定在底部)                                   │
    └── CommentInputBar ─────────────────────────────────────┘
        ├── "回复 @xxx" 提示 (回复模式时显示)
        ├── TextField (230字限制)
        └── 发送按钮
```

### 4.2 新增文件清单

| 文件 | 路径 | 说明 |
|------|------|------|
| CommentModels.swift | `ModelsForNetwork/` | 评论相关数据模型 |
| CommentService.swift | `Services/` | 评论 API 服务 |
| CommentViewModel.swift | `ViewModels/` | 评论业务逻辑 |
| CommentSectionView.swift | `View/SharePages/` | 评论区主视图 |
| CommentCellView.swift | `View/SharePages/` | 单条评论 Cell |
| ReplyPreviewView.swift | `View/SharePages/` | 回复预览视图 |
| CommentInputBar.swift | `View/SharePages/` | 底部输入栏 |
| CommentSortPicker.swift | `View/SharePages/` | 排序选择器 |

### 4.3 修改文件清单

| 文件 | 修改内容 |
|------|----------|
| ShareDetailsCardView.swift | 集成 CommentSectionView |
| ShareDetailView.swift | 传递 CommentViewModel、处理深链跳转 |
| SearchViewModel.swift | 新增 targetCommentId 用于精准定位 |
| AppDelegate / SceneDelegate | 处理通知点击的深链跳转 |

---

## 五、核心功能实现方案

### 5.1 评论列表与排序

```swift
struct CommentSectionView: View {
    @ObservedObject var viewModel: CommentViewModel
    @State private var showSortPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // 排序切换
            HStack {
                Text("评论")
                    .font(.headline)

                Spacer()

                Button(action: { showSortPicker = true }) {
                    HStack(spacing: 4) {
                        Text(viewModel.sortOrder.displayName)
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            // 评论列表
            LazyVStack(spacing: 0) {
                ForEach(viewModel.comments) { comment in
                    CommentCellView(
                        comment: comment,
                        viewModel: viewModel
                    )
                    Divider().padding(.leading, 60)
                }

                // 加载更多
                if viewModel.hasMoreComments {
                    ProgressView()
                        .padding()
                        .onAppear {
                            Task { await viewModel.loadComments() }
                        }
                }
            }
        }
        .confirmationDialog("选择排序方式", isPresented: $showSortPicker) {
            ForEach(CommentSortOrder.allCases, id: \.self) { order in
                Button(order.displayName) {
                    Task { await viewModel.changeSortOrder(to: order) }
                }
            }
        }
    }
}
```

### 5.2 评论 Cell（含状态展示）

```swift
struct CommentCellView: View {
    let comment: CommentViewData
    @ObservedObject var viewModel: CommentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 判断状态
            if comment.displayStatus != .normal {
                // 删除/违规占位
                deletedPlaceholder
            } else {
                // 正常评论
                normalContent
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - 正常评论内容
    @ViewBuilder
    private var normalContent: some View {
        HStack(alignment: .top, spacing: 12) {
            // 头像
            AsyncImage(url: URL(string: comment.userAvatar ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image("default_avatar")
                    .resizable()
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                // 用户名 + 作者标识
                HStack {
                    Text(comment.userNickname ?? "匿名用户")
                        .font(.subheadline.weight(.medium))

                    if comment.isAuthor == true {
                        Text("作者")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(4)
                    }
                }

                // 评论内容
                Text(comment.content ?? "")
                    .font(.body)

                // 操作栏
                HStack(spacing: 16) {
                    Text(formatTime(comment.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // 点赞按钮
                    Button(action: {
                        Task { await viewModel.toggleLike(on: comment.id) }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: comment.liked ? "heart.fill" : "heart")
                                .foregroundColor(comment.liked ? .red : .secondary)
                            if comment.likeCount > 0 {
                                Text("\(comment.likeCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // 回复按钮
                    Button("回复") {
                        viewModel.enterReplyMode(to: comment)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    // 删除按钮（仅自己的评论）
                    if comment.canDelete {
                        Menu {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteComment(id: comment.id) }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 回复预览
                if comment.replyCount > 0 {
                    replyPreviewSection
                }
            }
        }
    }

    // MARK: - 删除/违规占位
    @ViewBuilder
    private var deletedPlaceholder: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)

            Text(comment.statusText ?? "该评论不可用")
                .font(.body)
                .foregroundColor(.secondary)
                .italic()

            Spacer()
        }
    }

    // MARK: - 回复预览区
    @ViewBuilder
    private var replyPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 预览回复（最多2条）
            if let previews = comment.repliesPreview {
                ForEach(previews.prefix(2)) { reply in
                    ReplyPreviewView(reply: reply, viewModel: viewModel, parentId: comment.id)
                }
            }

            // 已展开的回复
            if comment.isExpanded {
                ForEach(comment.loadedReplies.dropFirst(comment.repliesPreview?.count ?? 0)) { reply in
                    ReplyPreviewView(reply: reply, viewModel: viewModel, parentId: comment.id)
                }
            }

            // 展开更多按钮
            let remainingCount = comment.replyCount - (comment.repliesPreview?.count ?? 0)
            if remainingCount > 0 && !comment.isExpanded {
                Button {
                    Task { await viewModel.loadMoreReplies(for: comment) }
                } label: {
                    HStack {
                        Text("展开 \(remainingCount) 条回复")
                        if comment.isLoadingReplies {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            } else if comment.isExpanded && comment.loadedReplies.count < comment.replyCount {
                Button {
                    Task { await viewModel.loadMoreReplies(for: comment) }
                } label: {
                    HStack {
                        Text("展开更多回复")
                        if comment.isLoadingReplies {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.leading, 52) // 与头像对齐
        .padding(.top, 8)
    }
}
```

### 5.3 底部输入栏

```swift
struct CommentInputBar: View {
    @ObservedObject var viewModel: CommentViewModel
    @FocusState private var isFocused: Bool

    private let maxLength = 230

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 8) {
                // 回复提示（回复模式时显示）
                if viewModel.isReplyMode, let user = viewModel.replyToUser {
                    HStack {
                        Text("回复 @\(user.nickname ?? "用户")")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button {
                            viewModel.exitReplyMode()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                HStack(spacing: 12) {
                    // 输入框
                    TextField(
                        viewModel.isReplyMode ? "回复..." : "发表评论...",
                        text: $viewModel.inputText
                    )
                    .focused($isFocused)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.inputText) { _, newValue in
                        if newValue.count > maxLength {
                            viewModel.inputText = String(newValue.prefix(maxLength))
                        }
                    }

                    // 字数提示
                    if !viewModel.inputText.isEmpty {
                        Text("\(viewModel.inputText.count)/\(maxLength)")
                            .font(.caption2)
                            .foregroundColor(
                                viewModel.inputText.count >= maxLength ? .red : .secondary
                            )
                    }

                    // 发送按钮
                    Button {
                        Task {
                            await viewModel.postComment()
                            isFocused = false
                        }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(
                                    viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? .gray : .blue
                                )
                        }
                    }
                    .disabled(
                        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.isSubmitting
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(.regularMaterial)
        }
    }
}
```

### 5.4 精准定位与高亮

```swift
// 在 CommentViewModel 中新增
extension CommentViewModel {
    /// 从通知跳转：精准定位到指定评论
    func navigateToComment(commentId: Int64) async {
        do {
            let context = try await CommentService.shared.getCommentContext(commentId: commentId)

            // 更新 shareId
            self.shareId = context.shareId

            if context.position.isFirstLevel {
                // 一级评论：计算页码并加载
                let page = context.position.index / pageSize
                let offset = page * pageSize

                // 重置并加载到正确的页
                comments = []
                currentOffset = 0

                // 加载到目标页
                for _ in 0...page {
                    await loadComments()
                }

                // 标记需要高亮的评论
                highlightCommentId = commentId

            } else if let parentId = context.position.parentId {
                // 二级回复：先定位父评论，再展开回复
                // 这需要先找到父评论，可能需要多次加载

                // 暂时简化：加载评论列表，展开目标父评论的回复
                await loadComments(reset: true)

                if let parentIndex = comments.firstIndex(where: { $0.id == parentId }) {
                    await loadMoreReplies(for: comments[parentIndex])
                    highlightCommentId = commentId
                }
            }

        } catch {
            self.error = error.localizedDescription
        }
    }

    @Published var highlightCommentId: Int64? = nil

    /// 清除高亮（延迟调用）
    func clearHighlight() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                self.highlightCommentId = nil
            }
        }
    }
}
```

---

## 六、通知深链处理

### 6.1 推送 Payload 解析

```swift
// SceneDelegate 或 AppDelegate 中
func handleNotification(userInfo: [AnyHashable: Any]) {
    guard let type = userInfo["type"] as? String,
          type == "comment_reply",
          let shareIdStr = userInfo["shareId"] as? String,
          let commentIdStr = userInfo["commentId"] as? String,
          let shareId = Int64(shareIdStr),
          let commentId = Int64(commentIdStr) else {
        return
    }

    // 通知 NavigationCoordinator 跳转
    NotificationCenter.default.post(
        name: .navigateToComment,
        object: nil,
        userInfo: [
            "shareId": shareId,
            "commentId": commentId
        ]
    )
}
```

### 6.2 导航处理

```swift
// 在 SearchViewModel 或 NavigationCoordinator 中
extension Notification.Name {
    static let navigateToComment = Notification.Name("navigateToComment")
    static let showLoginRequired = Notification.Name("showLoginRequired")
}

// 监听并处理
NotificationCenter.default.addObserver(
    forName: .navigateToComment,
    object: nil,
    queue: .main
) { notification in
    guard let shareId = notification.userInfo?["shareId"] as? Int64,
          let commentId = notification.userInfo?["commentId"] as? Int64 else { return }

    // 1. 设置目标评论 ID
    searchViewModel.targetCommentId = commentId

    // 2. 跳转到分享详情
    navigationCoordinator.path.append(Route.shareDetail(shareId: "\(shareId)"))
}
```

---

## 七、实施阶段划分

### 第一阶段：基础功能（MVP）

| 任务 | 预估工作量 | 优先级 |
|------|----------|--------|
| 数据模型定义 | 小 | P0 |
| CommentService API 封装 | 中 | P0 |
| CommentViewModel 核心逻辑 | 大 | P0 |
| CommentSectionView 基础 UI | 中 | P0 |
| CommentCellView | 中 | P0 |
| CommentInputBar | 小 | P0 |
| **键盘适配处理** | 中 | P0 |
| 集成到 ShareDetailsCardView | 小 | P0 |

> **键盘处理实现要点**：
> - 使用 `.ignoresSafeArea(.keyboard)` 让 ScrollView 不被键盘遮挡
> - 输入栏需跟随键盘自动上移，使用 `GeometryReader` + `keyboardHeight` 计算偏移
> - 或使用 iOS 15+ 的 `.safeAreaInset(edge: .bottom)` 配合输入栏
> - 键盘弹出时自动滚动到输入框可见位置

### 第二阶段：完善功能

| 任务 | 预估工作量 | 优先级 |
|------|----------|--------|
| 回复模式 UI | 中 | P1 |
| 二级回复折叠/展开 | 中 | P1 |
| 点赞功能（乐观更新） | 小 | P1 |
| 删除评论 | 小 | P1 |
| 排序切换 | 小 | P1 |
| 状态占位显示 | 小 | P1 |

### 第三阶段：精准定位与优化

| 任务 | 预估工作量 | 优先级 |
|------|----------|--------|
| 通知深链解析 | 中 | P2 |
| 精准定位滚动 | 大 | P2 |
| 评论高亮动画 | 小 | P2 |
| 登录引导集成 | 小 | P2 |
| 频率限制提示 | 小 | P2 |

---

## 八、待确认事项

1. **UI 风格**：排序切换器使用 Picker 还是 ActionSheet？
2. **回复预览**：预览条数固定 2 条还是可配置？
3. **高亮效果**：精准定位后的高亮样式（背景色闪烁？边框？）
4. **错误处理**：网络错误时使用 Toast 还是 Alert？

---

**规划完成，等待确认后开始实施。**
