# 方案B：单实例播放器 Overlay - 自测流程

## 📋 自测目标

验证方案B（全局单实例播放器 Overlay）能够完全消除 TabView 预创建导致的闪烁问题。

**期望结果：**
- ✅ 单张图片分享：0 次闪烁
- ✅ 两张图片分享：0 次闪烁
- ✅ 三张图片分享：0 次闪烁
- ✅ 四张及更多图片分享：0 次闪烁

## 🔍 核心验证点

### 1. 全局播放器只创建一次

**验证方法：** 查看日志中 `🎬 VideoPlayerView makeUIView - NEW VIEW CREATED (全局 Overlay)` 的出现次数。

**期望结果：**
- ✅ 打开分享详情页时，日志中应该**只出现一次** `NEW VIEW CREATED`
- ✅ 切换图片时，**不应该**再次出现 `NEW VIEW CREATED`
- ❌ 如果出现多次，说明 SwiftUI 错误地重建了视图

### 2. 封面淡出无闪烁

**验证方法：** 视觉观察首张 LivePhoto 的播放过程。

**期望结果：**
- ✅ 封面应该**平滑淡出**，无黑屏、无闪烁
- ✅ 视频应该**立即显示**，无延迟
- ✅ 播放完成后，封面应该**平滑淡入**

### 3. 切换图片响应正常

**验证方法：** 左右滑动切换多张 LivePhoto。

**期望结果：**
- ✅ 切换到新图片时，旧视频应该停止
- ✅ 新图片的 LivePhoto 应该自动播放
- ✅ 每次切换都应该平滑，无闪烁

### 4. 长按播放功能正常

**验证方法：** 长按任意 LivePhoto。

**期望结果：**
- ✅ 长按 0.8 秒后，LivePhoto 应该开始播放
- ✅ 松开后，应该停止播放并显示封面
- ✅ 可以多次重复长按播放

## 📊 自测步骤

### 测试 1：单张图片分享

1. **打开分享详情页**
   - 点击地图上的一个**单张 LivePhoto** 分享
   - 观察首张图片的自动播放

2. **检查日志**
   ```
   🎬 VideoPlayerView makeUIView - NEW VIEW CREATED (全局 Overlay)  ← 应该只出现一次
   🔄 [Overlay] switchToVideo - 切换到索引: 0
   📺 [Overlay] 条件1满足：图层可显示
   🎞️ [Overlay] 条件2满足：首帧已渲染
   ✨ [Overlay] 🎯 封面已隐藏
   ```

3. **验证结果**
   - [ ] `NEW VIEW CREATED` 只出现一次 ✅
   - [ ] 无闪烁 ✅
   - [ ] 自动播放正常 ✅

---

### 测试 2：两张图片分享

1. **打开分享详情页**
   - 点击地图上的一个**两张 LivePhoto** 分享
   - 观察首张图片的自动播放

2. **切换到第二张图片**
   - 向左滑动，切换到第二张
   - 观察第二张图片的自动播放

3. **检查日志**
   ```
   🎬 VideoPlayerView makeUIView - NEW VIEW CREATED (全局 Overlay)  ← 应该只出现一次
   🔄 [Overlay] switchToVideo - 切换到索引: 0
   （首张播放日志）
   🔄 [Overlay] switchToVideo - 切换到索引: 1  ← 切换时不应该再次 NEW VIEW CREATED
   （第二张播放日志）
   ```

4. **验证结果**
   - [ ] `NEW VIEW CREATED` 只出现一次 ✅
   - [ ] 首张无闪烁 ✅
   - [ ] 第二张无闪烁 ✅
   - [ ] 切换流畅 ✅

---

### 测试 3：三张图片分享

1. **打开分享详情页**
   - 点击地图上的一个**三张 LivePhoto** 分享
   - 观察首张图片的自动播放

2. **切换所有图片**
   - 依次滑动到第二张、第三张
   - 每次切换都观察是否有闪烁

3. **检查日志**
   ```
   🎬 VideoPlayerView makeUIView - NEW VIEW CREATED (全局 Overlay)  ← 应该只出现一次
   🔄 [Overlay] switchToVideo - 切换到索引: 0
   🔄 [Overlay] switchToVideo - 切换到索引: 1
   🔄 [Overlay] switchToVideo - 切换到索引: 2
   ```

4. **验证结果**
   - [ ] `NEW VIEW CREATED` 只出现一次 ✅
   - [ ] 所有三张图片都无闪烁 ✅
   - [ ] 切换流畅 ✅

---

### 测试 4：长按播放

1. **长按任意 LivePhoto**
   - 长按 0.8 秒以上
   - 观察是否开始播放

2. **松开手指**
   - 观察是否停止播放并显示封面

3. **验证结果**
   - [ ] 长按触发播放正常 ✅
   - [ ] 松开停止正常 ✅
   - [ ] 无闪烁 ✅

---

## 🐛 问题诊断

### 如果仍然出现闪烁

**检查点：**
1. 日志中 `NEW VIEW CREATED` 出现了多次？
   - ❌ 说明全局 Overlay 被 SwiftUI 重建了
   - 🔍 检查 ShareDetailView 的 `.id` 或其他导致重建的因素

2. 日志中出现多个不同的 player 对象指针？
   - ❌ 说明 VideoEngine 被重复创建
   - 🔍 检查 SearchViewModel 的 MediaItemWrapper 缓存逻辑

3. 封面淡出时机不对？
   - ❌ 说明 `tryHideCoverForCurrentVideo()` 被过早或过晚调用
   - 🔍 检查 `onReadyForDisplay` 和 `onFirstFrameRendered` 的调用时机

### 如果切换图片无响应

**检查点：**
1. 日志中 `🔄 [Overlay] switchToVideo` 是否被调用？
   - ❌ 说明 `onChange(of: selectedIndex)` 没有触发
   - 🔍 检查 ShareDetailView 的 `selectedIndex` 绑定

2. 日志中显示 `⚠️ [Overlay] switchToVideo - 不是 Movie 类型或没有 VideoEngine`？
   - ❌ 说明 VideoEngine 没有正确初始化
   - 🔍 检查 SearchViewModel.createMediaItem 中的 VideoEngine 创建逻辑

---

## ✅ 成功标准

**全部测试通过**，应该满足以下条件：

1. ✅ 所有分享（1-4+ 张图片）都**无闪烁**
2. ✅ 日志中 `NEW VIEW CREATED` 永远只出现**一次**
3. ✅ 切换图片流畅，响应快速
4. ✅ 长按播放功能正常
5. ✅ 播放完成后封面正常显示

---

## 📝 测试报告模板

请按以下格式报告测试结果：

```
【方案B 自测报告】

测试设备：iPhone [型号]
iOS 版本：[版本]
测试时间：[时间]

=== 测试 1：单张图片分享 ===
- NEW VIEW CREATED 次数：[次数]
- 闪烁次数：[次数]
- 结果：✅ 通过 / ❌ 失败

=== 测试 2：两张图片分享 ===
- NEW VIEW CREATED 次数：[次数]
- 首张闪烁次数：[次数]
- 第二张闪烁次数：[次数]
- 结果：✅ 通过 / ❌ 失败

=== 测试 3：三张图片分享 ===
- NEW VIEW CREATED 次数：[次数]
- 首张闪烁次数：[次数]
- 第二张闪烁次数：[次数]
- 第三张闪烁次数：[次数]
- 结果：✅ 通过 / ❌ 失败

=== 测试 4：长按播放 ===
- 长按触发：✅ 正常 / ❌ 异常
- 松开停止：✅ 正常 / ❌ 异常
- 结果：✅ 通过 / ❌ 失败

=== 关键日志 ===
[粘贴关键日志片段]

=== 总结 ===
- 总体结果：✅ 全部通过 / ❌ 存在问题
- 问题描述：[如果有问题，详细描述]
- 附加日志：[如果有异常，粘贴完整日志]
```

---

## 🎯 预期成功日志示例

```
🏠 ShareDetailView.onAppear - 初始化，selectedIndex: 0
🎬 VideoPlayerView makeUIView - NEW VIEW CREATED (全局 Overlay)  ← 只出现一次！
🔄 [Overlay] switchToVideo - 切换到索引: 0, wrapper: [UUID]
🎬 [Overlay] switchToVideo - 开始预加载并播放
🎬 VideoEngine - 开始预加载视频: [filename]
✅ VideoEngine - 视频素材已加载，等待 readyToPlay
✅ VideoEngine - 视频准备完成，可以播放
▶️ [Overlay] 视频准备完成，开始播放（等待两个条件）
🎬 VideoEngine - 立即播放, isMuted: false（Mix模式）
🔍 VideoEngine - 开始探测首帧像素
📺 PlayerView - 图层可显示（isReadyForDisplay = true）
📺 [Overlay] 条件1满足：图层可显示
🎞️ VideoEngine - 首帧像素已到达！尺寸: 1920x1440
🎞️ [Overlay] 条件2满足：首帧已渲染
✨ [Overlay] 🎯 封面已隐藏
✅ VideoEngine - 播放完成
✅ [Overlay] 视频播放完成，回到静止
⏹️ VideoEngine - 停止播放，回到静止状态
```

**关键特征：**
- `NEW VIEW CREATED` **只出现一次**
- 所有操作都通过 `[Overlay]` 前缀的日志
- 没有 MediaItemView 的 VideoPlayerView 创建日志

---

## 🔄 如果测试失败

如果按照此流程测试后仍然存在问题，请提供：
1. 完整的日志（从打开分享到闪烁发生的全部日志）
2. 闪烁发生的具体图片索引（第几张）
3. 设备型号和 iOS 版本
4. 视频录屏（如果可能）

我会根据这些信息进一步诊断和修复。

