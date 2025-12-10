# 贴纸互动系统（StickerKit）实现日志

**日期**: 2025-12-10
**操作人**: Claude Code (Opus 4.5)
**任务**: 实现贴纸互动系统（SpriteKit + SwiftUI）

---

## 一、背景

在观之 App 里实现一个贴纸交互页面，用来承载「点赞 / 无感 / 其他标签」绑定的互动系统。

### 重要说明

本项目存在两类完全不同的 "badge"：

1. **摄像界面徽章（现有系统）**
   - 位置：`CameraViews/Overlays/LiveBadge.swift` 等
   - 用途：拍摄/摄像 UI 上的状态标识
   - **本次不修改**

2. **贴纸互动系统（本次新建）**
   - 位置：`View/Features/StickerKit/`
   - 用途：主界面用户互动（点赞/无感/标签绑定）
   - 使用 "Sticker（贴纸）" 命名，避免混淆

---

## 二、需求规格

### 2.1 核心功能

1. **SpriteKit + SpriteView 实现贴纸场景**
   - 贴纸横向排布，每个贴纸是圆形容器 + 图像资产
   - 总宽度 ≤ 屏幕宽度：不自动轮播
   - 总宽度 > 屏幕宽度：启动慢速自动轮播

2. **交互行为**
   - 横向滑动：左右滑动整个队列，滑动时暂停自动轮播
   - 拖拽贴纸：按住某个贴纸向上拖动到"使用区域"
     - 松手时中心点在使用区域 → 触发 `onUseSticker` 回调
     - 否则贴纸平滑回到原位
   - CoreMotion 影响：队列轮播方向/速度、贴纸倾斜受设备重力影响

3. **模块化设计**
   - 独立的 `StickerSpriteFactory`：从 `StickerDefinition` 生成 SpriteKit 节点
   - 支持 PNG 图像、SF Symbol，预留 SVG/3D 扩展点
   - 纹理缓存避免重复渲染

4. **SwiftUI 集成**
   - `StickerPage`：页面入口
   - `StickerFieldView`：SpriteView 容器 + 使用区域 overlay
   - `onUseSticker` 回调抛出使用的贴纸信息

### 2.2 不做的功能（本轮）

- 真实后端 API 对接
- 烟花/3D 特效
- 无限循环轮播

---

## 三、技术架构

### 3.1 目录结构

```
guanzhi/View/Features/StickerKit/
├── Models/
│   └── StickerDefinition.swift      # 贴纸数据模型
├── SpriteKit/
│   ├── StickerScene.swift           # SpriteKit 场景
│   ├── StickerSpriteFactory.swift   # 贴纸节点工厂
│   └── StickerTextureCache.swift    # 纹理缓存
├── Motion/
│   └── StickerMotionManager.swift   # CoreMotion 封装
├── Views/
│   └── StickerFieldView.swift       # SwiftUI 容器
└── StickerPage.swift                # 页面入口
```

### 3.2 类型定义

| 类型 | 职责 |
|------|------|
| `StickerID` | 贴纸唯一标识 |
| `StickerAssetKind` | 资源类型枚举（image/systemSymbol/svg/threeD） |
| `StickerDefinition` | 贴纸定义（ID、名称、资源、优先级、元数据） |
| `StickerTextureCache` | 纹理缓存（NSCache，避免重复渲染） |
| `StickerSpriteFactory` | 节点工厂（生成 SKSpriteNode） |
| `StickerMotionManager` | CoreMotion 封装（重力向量） |
| `StickerScene` | SpriteKit 场景（物理、轮播、拖拽） |
| `StickerSceneDelegate` | 场景代理协议（使用贴纸回调） |
| `StickerFieldView` | SwiftUI 容器（SpriteView + 使用区域） |
| `StickerPage` | 页面入口 |

### 3.3 数据流

```
StickerPage
    │
    ▼
StickerFieldView ──► StickerMotionManager (CoreMotion)
    │                        │
    ▼                        ▼
SpriteView ◄─────── StickerScene
    │                   │
    │                   ▼
    │           StickerSpriteFactory
    │                   │
    │                   ▼
    │           StickerTextureCache
    │
    ▼
onUseSticker callback
```

---

## 四、关键设计决策

### 4.1 纹理缓存

**问题**：使用 ImageRenderer 渲染 SwiftUI → UIImage → SKTexture 成本较高

**方案**：
- 新增 `StickerTextureCache` 单例
- 使用 `NSCache` 缓存纹理
- 预加载时批量生成纹理
- Key 格式：`{stickerID}_{width}x{height}`

### 4.2 CoreMotion 封装

**问题**：直接在 Scene 中使用 CMMotionManager 耦合度高

**方案**：
- 抽取为独立的 `StickerMotionManager`
- `@Published` 暴露重力向量
- 模拟器自动 fallback（使用默认重力）
- 可在多个场景间复用

### 4.3 访问控制

**问题**：`stickerDefinitions` 暴露为 public 可能导致外部修改内部状态

**方案**：
- 保持 `private let stickerDefinitions`
- 提供查找方法：`definition(for id: StickerID) -> StickerDefinition?`

### 4.4 坐标系转换

**问题**：SwiftUI（Y 向下）与 SpriteKit（Y 向上）坐标系不同

**方案**：
- 在 `StickerFieldView` 中进行坐标转换
- 考虑缩放比例（scene.size 与 view.size 可能不同）
- 添加 DEBUG 模式可视化调试

### 4.5 边界限制

**问题**：横向滚动无边界会导致贴纸完全滑出视野

**方案**：
- 计算 `minScrollX` 和 `maxScrollX`
- 在 `moveAllStickers(by:)` 中检查边界

---

## 五、实施阶段

| 阶段 | 内容 | 文件 |
|------|------|------|
| Phase 1 | 数据模型 + 纹理缓存 | StickerDefinition.swift, StickerTextureCache.swift |
| Phase 2 | 节点工厂 + 场景 | StickerSpriteFactory.swift, StickerScene.swift |
| Phase 3 | CoreMotion 封装 | StickerMotionManager.swift |
| Phase 4 | SwiftUI 集成 | StickerFieldView.swift, StickerPage.swift |
| Phase 5 | 调试优化 | 坐标验证、边界调整、视觉优化 |

---

## 六、需要的图片资源

| 资源名 | 用途 | 规格建议 |
|--------|------|---------|
| `sticker_like` | 点赞贴纸 | 144x144 PNG，圆形透明背景 |
| `sticker_neutral` | 无感贴纸 | 144x144 PNG，圆形透明背景 |

**注**：初期可用 SF Symbol 测试，后续替换为自定义图片

---

## 七、集成示例

```swift
// 在任意 SwiftUI 视图中
NavigationLink("打开贴纸互动") {
    StickerPage(stickers: StickerDefinition.mockAll) { usedSticker in
        print("使用了贴纸: \(usedSticker.displayName)")
        // TODO: 调用后端 API
    }
}
```

---

## 八、风险与注意事项

1. **模拟器限制**：CoreMotion 在模拟器不可用，需要真机测试重力效果
2. **坐标系调试**：SwiftUI ↔ SpriteKit 坐标转换可能需要多次调试
3. **性能**：大量贴纸时注意纹理缓存和物理计算开销
4. **命名隔离**：严格使用 `Sticker` 前缀，不要与 Camera Badge 混淆

---

## 九、后续扩展点

- [ ] 无限循环轮播
- [ ] 惯性滑动效果
- [ ] SVG 渲染管线对接
- [ ] 3D 贴纸支持（SK3DNode）
- [ ] 使用贴纸时的烟花/粒子效果
- [ ] 后端 API 对接

---

## 十、实施结果

### 10.1 创建的文件

| 文件路径 | 行数 | 说明 |
|---------|------|------|
| `Models/StickerDefinition.swift` | ~120 | 贴纸数据模型，包含 Mock 数据 |
| `SpriteKit/StickerTextureCache.swift` | ~180 | 纹理缓存，支持预加载 |
| `SpriteKit/StickerSpriteFactory.swift` | ~60 | 节点工厂，配置物理体 |
| `SpriteKit/StickerScene.swift` | ~280 | SpriteKit 场景核心逻辑 |
| `Motion/StickerMotionManager.swift` | ~100 | CoreMotion 封装 |
| `Views/StickerFieldView.swift` | ~200 | SwiftUI 容器，坐标转换 |
| `StickerPage.swift` | ~130 | 页面入口，使用反馈 UI |

**总计**: 7 个文件，约 1070 行代码

### 10.2 目录结构确认

```
guanzhi/View/Features/StickerKit/
├── Models/
│   └── StickerDefinition.swift      ✅
├── SpriteKit/
│   ├── StickerScene.swift           ✅
│   ├── StickerSpriteFactory.swift   ✅
│   └── StickerTextureCache.swift    ✅
├── Motion/
│   └── StickerMotionManager.swift   ✅
├── Views/
│   └── StickerFieldView.swift       ✅
└── StickerPage.swift                ✅
```

### 10.3 与现有系统隔离确认

- ✅ 未修改任何 `CameraViews/` 目录下的文件
- ✅ 未修改任何现有 Badge 相关代码
- ✅ 所有新类型使用 `Sticker` 前缀
- ✅ 完全独立的模块，无跨模块依赖

### 10.4 下一步

1. **将文件添加到 Xcode 项目**：需要手动将 `StickerKit` 目录添加到 Xcode 项目中
2. **真机测试**：CoreMotion 需要真机测试
3. **调试坐标转换**：如果使用区域判定不准确，调整 `StickerFieldView` 中的坐标转换逻辑
4. **添加自定义图片资源**：替换 SF Symbol 为项目专属贴纸图片

---

**文档版本**: v1.1
**创建时间**: 2025-12-10
**完成时间**: 2025-12-10
