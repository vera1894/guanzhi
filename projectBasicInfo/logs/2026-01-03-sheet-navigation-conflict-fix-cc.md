# 分享详情与搜索Sheet层级冲突修复

**日期**: 2026-01-03
**操作者**: Claude Code (cc)
**类型**: Bug 修复
**状态**: 已完成

---

## 一、问题描述

### 现象

1. 用户在主页搜索地点，选择结果后弹出「地点名称 sheet」（ResultCardView）
2. 保持该 sheet 开启状态，点击地图上的分享进入详情页
3. **问题**：地点名称 sheet 覆盖在分享详情页上方
4. 如果在详情页点击 sheet 的关闭按钮，搜索框会覆盖在详情页上

### 期望行为

- 进入分享详情时：sheet 应该隐藏
- 返回主页时：恢复之前显示的 sheet（地点名称或搜索框）
- 地图上的搜索标注应保留，直到用户主动关闭

---

## 二、根因分析

### SwiftUI Sheet 与 NavigationStack 的层级关系

```
┌─────────────────────────────────────┐
│  Sheet (最上层)                      │  ← 问题：Sheet 总是在最上层
│  ┌─────────────────────────────────┐│
│  │  NavigationStack                ││
│  │  ├── SearchView (主页)          ││
│  │  └── ShareDetailView (详情页)   ││  ← 被 Sheet 覆盖
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

SwiftUI 的 `.sheet()` 修饰符创建的视图会显示在所有其他视图之上，包括 NavigationStack 推入的页面。这是 SwiftUI 的设计行为。

### 之前的代码问题

进入分享详情时没有关闭 sheet，导致 sheet 仍然显示在详情页之上。

---

## 三、修复方案

### 方案选择

| 方案 | 描述 | 问题 |
|------|------|------|
| ❌ Computed Binding | 用 `isPresented && !isInDetailView` 控制 | SwiftUI 可能不正确响应 |
| ❌ 直接关闭 | 进入时设置 `isShowingResultCardView = false` | 返回时无法知道之前的状态 |
| ✅ 保存/恢复状态 | 保存进入前的状态，返回时恢复 | 正确且可靠 |

### 实现细节

**1. AppStateModel.swift - 添加状态保存变量**

```swift
// 保存进入分享详情前的 sheet 状态，用于返回时恢复
var savedShowingSearchView: Bool? = nil
var savedShowingResultCardView: Bool? = nil
```

**2. ShareDetailView.swift - onAppear 保存并关闭**

```swift
.onAppear {
    // 保存当前 sheet 状态
    appState.savedShowingSearchView = appState.isShowingSearchView
    appState.savedShowingResultCardView = appState.isShowingResultCardView

    // 关闭所有 sheet（避免覆盖在详情页上）
    appState.isShowingSearchView = false
    appState.isShowingResultCardView = false

    // ... 其他初始化逻辑
}
```

**3. ShareDetailView.swift - onDisappear 恢复状态**

```swift
.onDisappear {
    if navigationCoordinator.path.isEmpty {
        withAnimation(.easeInOut) {
            // 根据保存的状态恢复对应的 sheet
            if let savedResultCard = appState.savedShowingResultCardView, savedResultCard {
                // 之前是地点名称 sheet，恢复它
                appState.isShowingResultCardView = true
                appState.isShowingSearchView = false
            } else if let savedSearch = appState.savedShowingSearchView, savedSearch {
                // 之前是搜索框 sheet，恢复它
                appState.isShowingSearchView = true
            } else {
                // 默认显示搜索框
                appState.isShowingSearchView = true
            }
        }
        // 清除保存的状态
        appState.savedShowingSearchView = nil
        appState.savedShowingResultCardView = nil
    }
}
```

---

## 四、状态流转图

```
用户操作                      isShowingSearchView    isShowingResultCardView    savedShowingResultCardView
─────────────────────────────────────────────────────────────────────────────────────────────────────────
1. 打开 App                   true                   false                      nil
2. 搜索地点，选择结果          false                  true                       nil
3. 点击分享进入详情            false                  false                      true (保存)
4. 返回主页                    false                  true (恢复)                nil (清除)
```

---

## 五、Git 提交

```
899f3da 修复分享详情与地点名称sheet层级冲突问题
```

---

## 六、相关文件

| 文件 | 修改说明 |
|------|----------|
| `guanzhi/AppStateModel.swift` | 添加 savedShowingSearchView/savedShowingResultCardView |
| `guanzhi/View/SharePages/ShareDetailView.swift` | onAppear 保存状态，onDisappear 恢复状态 |
| `guanzhi/View/FrontPages/SearchView.swift` | 移除 computed Binding，恢复直接绑定 |

---

## 七、测试验证

| 场景 | 预期结果 |
|------|----------|
| 搜索地点 → 进入分享详情 | sheet 隐藏，详情正常显示 |
| 从详情返回主页 | 地点名称 sheet 恢复显示 |
| 直接从主页进入分享详情 | 返回后显示搜索框 sheet |
| 地图标注 | 保留，不被清除 |

