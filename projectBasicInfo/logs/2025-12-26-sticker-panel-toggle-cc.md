# 贴纸面板切换功能实施计划

**日期**: 2025-12-26
**角色**: Claude Code
**状态**: 已完成

---

## 背景

分享详情页面中当前贴纸系统存在以下问题：
1. 底部贴纸队列和已使用贴纸状态是**常驻显示**的
2. 屏幕右边的点赞按钮功能**已弃用**

## 目标

1. 将点赞按钮改为"贴纸切换按钮"
2. 贴纸队列默认隐藏，点击按钮显示
3. 按钮状态：空心=未使用贴纸，填充=已使用贴纸
4. 贴纸队列作为覆层显示，覆盖在底部文字说明之上
5. 背景渐变：屏幕底部全黑 → 贴纸队列顶部透明
6. 点击贴纸队列顶部以上区域可收起面板

---

## 涉及文件

| 文件 | 修改内容 |
|------|---------|
| `ShareInteractionViewModel.swift` | 新增 `isStickerPanelVisible` 状态 |
| `ShareDetailView.swift` | 修改贴纸 overlay 逻辑，添加覆层背景和关闭区域 |
| `InteractionOverlayView.swift` | 将点赞按钮改为贴纸切换按钮 |

---

## 实施步骤

### 步骤 1：ViewModel 新增状态

文件：`ShareInteractionViewModel.swift`

```swift
@Published var isStickerPanelVisible: Bool = false

func toggleStickerPanel() {
    isStickerPanelVisible.toggle()
}

// 在 initialize(share:) 中重置
isStickerPanelVisible = false
```

### 步骤 2：修改切换按钮

文件：`InteractionOverlayView.swift`

- 将 `likeButton` 改为 `stickerToggleButton`
- 图标：`sparkles.rectangle.stack` (空心) / `sparkles.rectangle.stack.fill` (填充)
- 删除点赞相关代码

### 步骤 3：修改贴纸 overlay

文件：`ShareDetailView.swift`

**3.1 新增配置常量**
```swift
private let kStickerPanelGradientHeight: CGFloat = 200
private let kStickerPanelContentBaseHeight: CGFloat = 150
```

**3.2 新增贴纸面板覆层**
- 点击关闭区域（透明）
- 渐变背景（透明→黑色）
- 贴纸内容区域
- 使用 `.zIndex(2)` 确保层级正确

**3.3 使用 opacity 保持 SpriteKit 常驻**
```swift
.opacity(interactionViewModel.isStickerPanelVisible ? 1 : 0)
.allowsHitTesting(interactionViewModel.isStickerPanelVisible)
```

**3.4 为底部详情卡片添加 zIndex(1)**

### 步骤 4：添加交互闭环

贴纸使用成功后自动收起面板（延迟 0.8s）

---

## 风险与规避

| 风险 | 规避措施 |
|------|---------|
| 视图层级遮挡 | 使用 `.zIndex()` 控制层级 |
| SpriteKit 重复创建 | 使用 `.opacity()` 保持常驻 |
| 安全区域适配 | 动态获取 `safeAreaInsets.bottom` |
| 贴纸使用后未收起 | `.onChange` 监听自动收起 |

---

## 实施记录

### 2025-12-26 实施完成

- [x] 步骤 1：ViewModel 新增状态
  - 新增 `isStickerPanelVisible` 状态
  - 新增 `toggleStickerPanel()` 方法
  - 在 `initialize(share:)` 中重置状态
- [x] 步骤 2：修改切换按钮
  - 将 `likeButton` 改为 `stickerToggleButton`
  - 使用 `sparkles.rectangle.stack` / `sparkles.rectangle.stack.fill` 图标
  - 删除旧的点赞相关代码
- [x] 步骤 3：修改贴纸 overlay
  - 新增配置常量 `kStickerPanelGradientHeight` 和 `kStickerPanelContentBaseHeight`
  - 新增 `stickerPanelOverlay` 计算属性
  - 新增 `stickerFieldForPanel` 辅助方法
  - 使用 `.opacity()` + `.allowsHitTesting()` 保持 SpriteKit 常驻
  - 底部详情卡片已有 `.zIndex(1)`
- [x] 步骤 4：添加交互闭环
  - 新增 `.onChange(of: currentUserSticker?.kind)` 监听器
  - 贴纸使用成功后延迟 0.8s 自动收起面板

---

## 验证结果

### 代码修改完成

1. **ShareInteractionViewModel.swift**
   - 新增 `isStickerPanelVisible: Bool` 状态
   - 新增 `toggleStickerPanel()` 方法

2. **InteractionOverlayView.swift**
   - 新增 `stickerToggleButton` 替换原 `likeButton`
   - 按钮图标根据是否已使用贴纸切换填充/空心状态

3. **ShareDetailView.swift**
   - 新增贴纸面板配置常量
   - 新增 `stickerPanelOverlay` 计算属性（渐变背景 + 贴纸内容）
   - 新增点击关闭区域功能
   - 新增贴纸使用成功后自动收起的交互闭环

### 待用户验证

- [ ] 编译项目验证无语法错误
- [ ] 运行模拟器测试功能正常

---

## Bug 修复记录

### 2025-12-26 测试反馈修复

用户测试后报告了4个问题，已全部修复：

#### 问题1：右侧图标在贴纸队列展开时应该隐藏
**修复**：修改 `InteractionOverlayView` 的显示条件，加入 `!isStickerPanelVisible`

#### 问题2：右侧图标在评论区展开时覆盖在评论层之上
**修复**：修改显示条件加入 `!isFullScreen`，评论区全屏时隐藏右侧按钮

#### 问题3：贴纸队列没有显示在收起的评论卡片之上
**修复**：将 `.zIndex(2)` 移到 overlay 内容上，而不是外层

#### 问题4：拖动贴纸时不显示使用区域，被看不见的东西遮挡
**原因**：`Color.clear` 点击关闭区域覆盖全屏，阻挡了贴纸拖动
**修复**：重构 `stickerPanelOverlay` 结构：
- 层1：点击关闭区域仅在渐变区域上方
- 层2：渐变背景设置 `.allowsHitTesting(false)` 不阻挡触摸
- 层3：`StickerFieldView` 全屏覆盖，`touchAreaHeight` 设为全屏高度
- 恢复 `showUseZoneHint: true` 显示使用区域提示

### 2025-12-26 第二轮测试反馈修复

#### 问题5：贴纸队列飞到屏幕顶部，已使用贴纸说明下沉
**原因**：`queueBottomY` 计算方式被错误修改
**修复**：
- 贴纸队列：恢复使用 `kBottomCardCollapsedRatio` 和 `kStickerQueueToCardSpacing` 计算位置
- 已使用贴纸：恢复使用 `kUsedStickerStatusBarBottomPadding` 常量

#### 问题6：贴纸队列仍显示在评论卡片之上
**方案**：采用用户建议，贴纸面板展开时隐藏评论卡片
**修复**：在 `ShareDetailsCardView` 的 opacity/allowsHitTesting 中加入 `!isStickerPanelVisible` 条件

### 2025-12-26 第三轮测试反馈修复

#### 问题7：点击其他区域应关闭贴纸面板
**修复**：重构 `stickerPanelOverlay` 的点击逻辑：
- 全屏透明层响应点击关闭
- 渐变背景和黑色区域也响应点击关闭
- 贴纸内容层设置 `allowsHitTesting(false)` 让点击穿透

#### 问题8：使用区域提示框位置和样式不对
**原问题**：提示框显示在屏幕顶部，有虚线边框
**修复**：
- 将 `useZoneOverlay` 简化为 `useZoneHintText`（纯文字，无边框）
- 使用 `customUseZoneFrame` 定位到屏幕中央

#### 问题9：使用区域提示应只显示5次
**修复**：在 `StickerFieldView` 中添加使用次数统计：
- 新增 `kStickerUseCountKey` UserDefaults 键
- 新增 `shouldShowHint` 静态属性检查次数
- 在 `stickerScene(_:didUse:)` 中调用 `incrementUseCount()`
- 使用次数达到5次后不再显示提示

#### 问题10：贴纸队列显示时点击背景无法关闭
**原因**：StickerFieldView (SpriteKit) 捕获了所有触摸事件
**修复**：
1. 在 `StickerSceneDelegate` 中新增 `stickerSceneDidTapBackground` 方法
2. 在 `StickerScene.endInteraction` 中检测简单点击（移动距离<10pt）
3. 在 `StickerFieldView` 中新增 `onTapBackground` 回调参数
4. 在 `ShareDetailView.stickerFieldForPanel` 中传入关闭面板的回调
