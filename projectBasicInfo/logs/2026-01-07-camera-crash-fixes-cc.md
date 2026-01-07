# 相机崩溃问题修复

**日期**: 2026-01-07
**作者**: Claude Code
**状态**: ✅ 已完成

---

## 问题描述

### 崩溃问题 1：退出相机后重新进入时崩溃

**复现步骤**：
1. 进入拍照页面
2. 拍一张照片
3. 点击"下一步"
4. 退出拍照页面
5. 再次进入拍照页面 → 💥 崩溃

**根本原因**：
- `CameraViewWrapper.onDisappear` 中没有停止相机
- `CameraModel` 和 `CaptureService` 都没有实现 `stop()` 方法
- AVCaptureSession 在后台继续运行，重新进入时资源冲突

### 崩溃问题 2：点击翻转摄像头按钮时崩溃

**复现步骤**：
1. 进入拍照页面
2. 点击翻转摄像头按钮 → 💥 崩溃

**根本原因**：
- `CaptureService.swift` 中多处使用 `fatalError()` 而非安全的错误处理
- `currentDevice` 属性在 `activeVideoInput` 为 nil 时调用 `fatalError()`
- `changeCaptureDevice()` 方法在 `activeVideoInput` 为 nil 时调用 `fatalError()`

---

## 修复方案

### 修改文件清单

| 文件 | 修改内容 |
|------|----------|
| `CaptureService.swift` | 添加 `stop()` 方法；移除所有 `fatalError()` 调用 |
| `CameraModel.swift` | 添加 `stop()` 方法 |
| `CameraViewWrapper.swift` | 在 `onDisappear` 中调用 `stop()` |

### 详细修改

#### 1. CaptureService.swift

**添加 stop() 方法**：
```swift
func stop() {
    guard captureSession.isRunning else { return }

    captureSession.stopRunning()
    subjectAreaChangeTask?.cancel()
    systemPreferredCameraTask?.cancel()
    rotationObservers.removeAll()

    captureSession.beginConfiguration()
    captureSession.inputs.forEach { captureSession.removeInput($0) }
    captureSession.outputs.forEach { captureSession.removeOutput($0) }
    captureSession.commitConfiguration()

    activeVideoInput = nil
    isSetUp = false
}
```

**移除 fatalError 改为安全处理**：

| 原代码 | 修改后 |
|--------|--------|
| `currentDevice: AVCaptureDevice { fatalError(...) }` | `currentDevice: AVCaptureDevice? { return activeVideoInput?.device }` |
| `guard ... else { fatalError() }` | `guard ... else { logger.warning(...); return }` |
| `videoPreviewLayer: ... { fatalError(...) }` | `videoPreviewLayer: ...? { return ... }` |

#### 2. CameraModel.swift

**添加 stop() 方法**：
```swift
func stop() async {
    await captureService.stop()
    status = .unknown
}
```

#### 3. CameraViewWrapper.swift

**在 onDisappear 中调用 stop()**：
```swift
.onDisappear {
    if let camera = camera {
        Task {
            await camera.stop()
        }
    }
    // ...
}
```

---

## 导航问题修复

### 问题描述

**复现步骤**：
1. 进入拍照页面 → 拍照 → 点击"下一步"进入输入页面
2. 从屏幕左侧边缘滑动退出
3. 直接退出到主页（而非返回拍照页面）
4. 再次点击"发布观之"→ 进入空的输入页面

**根本原因**：
- 拍照模式和输入模式是同一个视图的不同状态 (`isReadyToPost`)
- 退出时 `isReadyToPost` 仍为 `true`，但 `CameraModel` 被销毁
- 再次进入时直接显示输入页面，但没有照片数据

### 修复方案

**实施方案一：左滑返回上一步**

1. 添加 `EdgeSwipeInterceptor` 组件拦截左边缘滑动手势
2. 在输入模式时：左滑 → 返回拍照模式（而非退出）
3. 在拍照模式时：左滑 → 正常退出到主页
4. 安全备用：`onDisappear` 中重置 `isReadyToPost = false`

**CameraViewWrapper.swift 修改**：
```swift
var body: some View {
    ZStack {
        NavigationView { ... }

        // 左边缘滑动拦截区域（仅在输入模式时激活）
        if appState.isReadyToPost {
            EdgeSwipeInterceptor {
                withAnimation(.easeOut(duration: 0.2)) {
                    appState.isReadyToPost = false
                }
            }
        }
    }
    .onDisappear {
        // 安全备用：重置发布状态
        appState.isReadyToPost = false
        // ...
    }
}
```

---

## 测试验证

### 崩溃修复验证

- [x] 拍照 → 下一步 → 退出 → 再次进入：不崩溃
- [x] 点击翻转摄像头按钮：不崩溃

### 导航修复验证

- [x] 拍照 → 下一步 → 左滑：返回拍照页面
- [x] 拍照页面 → 左滑：正常退出到主页
- [x] 任意情况退出后再次进入：从拍照模式开始

---

## 相关文件

- `guanzhi/CaptureService.swift`
- `guanzhi/CameraModel.swift`
- `guanzhi/View/SharePages/CameraViewWrapper.swift`
