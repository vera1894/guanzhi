# 项目概况文档

## 项目基本信息
- 项目名称：guanzhi（观观）
- 平台：iOS移动应用
- 开发语言：Swift
- UI框架：SwiftUI
- 部署目标：iOS 17.0及以上版本

## 项目整体架构和设计模式

### 架构概述
项目采用现代化的SwiftUI架构，实现MVVM（Model-View-ViewModel）设计模式：

### 架构组件
- **SwiftUI框架**：整个用户界面基于SwiftUI构建
- **MVVM模式**：清晰地分离视图（Views）、视图模型（ViewModels）和模型（Models）
- **状态管理**：使用`@Environment`、`@State`、`@ObservedObject`和自定义`@Observable`类
- **依赖注入**：使用SwiftUI的环境系统传递依赖
- **导航系统**：实现`NavigationStack`和自定义路由系统

### 关键设计模式
- **可观察模式**：使用`@Observable`进行状态管理
- **单例模式**：用于管理器如`OTOLoginStatusManager`、`CoordinateConverter`
- **观察者模式**：使用`@Published`属性和Combine框架
- **工厂模式**：在相机组件中用于创建不同类型的媒体

## 主要功能模块及其职责

### 核心模块

#### 认证与用户管理
- **相关文件**：`UserLoginModel.swift`、`UserProfileManager.swift`、`LocalUserProfile.swift`
- **功能职责**：
  - 用户注册和登录
  - 令牌管理（使用UserDefaults）
  - 用户个人资料数据处理
  - 头像管理和缓存
  - 短信验证码发送和验证

#### 相机系统
- **相关文件**：`CameraView.swift`、`CameraModel.swift`、`PhotoCapture.swift`、`MovieCapture.swift`
- **功能职责**：
  - 照片和视频拍摄功能
  - 相机预览和UI控件
  - 媒体库管理
  - 实况照片处理

#### 地图与位置服务
- **相关文件**：`LocationService.swift`、`CoordinateConverter.swift`、`MapView.swift`、`SearchView.swift`
- **功能职责**：
  - GPS位置跟踪
  - 坐标转换（WGS84转GCJ-02，适用于中国）
  - 使用MapKit渲染地图
  - 基于位置的内容显示

#### 网络通信
- **相关文件**：`NetworkService.swift`、`OTORequests.swift`、`OTOTypes.swift`
- **功能职责**：
  - 与后端API通信
  - 请求/响应处理
  - 错误管理
  - 认证令牌注入

#### 数据存储
- **相关文件**：`LocalUserProfile.swift`、`SharesData.swift`、SwiftData模型
- **功能职责**：
  - 使用SwiftData进行本地数据持久化
  - 分享内容和媒体文件存储
  - 用户个人资料缓存

#### UI组件
- **相关文件**：`View/`目录中的各类文件
- **功能职责**：
  - 登录界面
  - 地图界面
  - 相机界面
  - 用户个人资料页面
  - 分享内容展示

## 数据流和状态管理

### 状态管理方法
1. **AppStateModel**：使用`@Observable`的集中式应用状态
2. **环境值**：通过SwiftUI环境传递的共享状态
3. **发布属性**：使用`@Published`的ViewModel状态变更
4. **NavigationCoordinator**：自定义导航路径管理

### 数据流
```
用户操作 → 视图 → 视图模型 → 网络/API → 模型更新 → 
视图刷新 → UI更新
```

### 关键状态属性
- UI可见性标志（isShowingCameraView, isShowingSearchView）
- 加载状态（isLoading, captureboxIsLoading）
- 用户数据（currentLocation, responsedNearbyShareList）
- 媒体状态（isPlayingLivePhoto, livePhotoTemporarily）

## 网络通信和API集成

### 网络层
- **Alamofire**：用于HTTP请求和多部分上传
- **基础URL**：`https://onettoo.com`（在Constants.swift中定义）
- **认证方式**：在Authorization头部使用Bearer令牌
- **请求类型**：基于JSON的API，使用标准HTTP方法

### API端点（来自OTORequests.swift）
- 用户认证和注册
- 分享内容创建和检索
- 用户个人资料管理
- 媒体文件上传
- 基于位置的内容搜索

### 错误处理
- 自定义`OTONetworkError`枚举
- 响应码验证
- 错误消息解析和显示

## 数据存储方案

### 本地存储
- **SwiftData**：结构化数据的主要本地数据库
  - `LocalUserProfile`：用户信息
  - `Share`：内容分享数据
  - `MediaFile`：媒体文件元数据
- **UserDefaults**：用于令牌和设置的简单键值存储
- **文件系统**：图像缓存和头像存储
- **内存中**：ViewModel中的临时数据

### 数据模型
- **Share**：带位置元数据的内容分享
- **MediaFile**：带类型信息的媒体文件引用
- **LocalUserProfile**：缓存的用户个人资料数据
- **坐标转换**：中国坐标系统的边界数据

## UI/UX架构和组件组织

### UI结构
```
guanzhiApp (根视图)
├── SearchView (主地图界面)
│   ├── MapView
│   ├── MapOverlayView
│   ├── SheetView
│   └── ResultCardView
├── CameraViewWrapper
│   └── CameraView
└── 导航目标
    ├── MyView (用户个人资料)
    ├── OthersView (其他用户)
    ├── SettingView
    ├── EditProfileView
    └── ShareDetailView
```

### 组件组织
- **FrontPage**：主地图和搜索界面
- **LoginViews**：认证界面
- **MyPages**：用户个人资料和设置
- **MapPages**：地图特定组件
- **UIElement**：可重用的UI组件和样式
- **CameraViews**：相机界面组件

### UI模式
- **自定义按钮样式**：可重用的按钮样式
- **通知系统**：使用ToastManager的Toast通知
- **NavigationStack**：现代SwiftUI导航
- **Sheet展示**：特定任务的模态视图

## 第三方库和依赖

### 核心依赖
1. **Alamofire**：HTTP网络和文件上传
2. **MapKit**：原生iOS地图功能
3. **CoreLocation**：GPS和位置服务
4. **SwiftData**：本地数据持久化
5. **Photos**：媒体库访问
6. **AVFoundation**：相机和媒体捕获
7. **Combine**：响应式编程工具

### 集成方式
- 使用CocoaPods进行依赖管理
- 在源文件中直接导入框架
- 基于扩展的第三方功能定制

## 项目的特殊功能

### 相机功能
- 照片和视频拍摄，支持实况照片
- 前后摄像头切换
- 媒体预览和选择
- 对焦和曝光控制

### 地图和位置服务
- 实时GPS跟踪
- 中国坐标系转换（WGS84 ↔ GCJ-02）
- 基于位置的内容发现
- 自定义地图注释和标记

### 地理空间特性
- 中国边界检测（坐标转换）
- 带精确坐标的地点分享
- 地址解析和反向地理编码

### 媒体处理
- 照片/视频拍摄和处理
- 实况照片支持
- 图像缓存和优化
- 多媒体文件上传

### 用户体验特性
- 覆盖层与导航式内容展示
- 使用MatchedGeometryEffect的动画过渡
- 用于用户反馈的Toast通知
- 具有一致样式的自定义UI组件

## 短信验证登录实现

### 整体流程
1. 用户在登录页面输入手机号
2. 点击"下一步"按钮发送验证码请求
3. 用户收到短信验证码后，在验证码页面输入
4. 验证码验证通过后完成登录或注册流程

### 详细实现

#### 手机号输入页面 (LogInView.swift)
- 使用`PhoneNumberTextField`组件输入手机号
- 通过`ValidateEnum.phoneNum()`验证手机号格式
- 点击"下一步"按钮调用`userlogin.sendCode()`发送验证码

#### 验证码发送 (UserLoginModel.swift)
- `sendCode()`方法通过`NetworkService`发送POST请求到`/api/guan/sendCode`
- 请求参数包含手机号
- 成功发送后启动60秒倒计时，防止重复发送

#### 验证码输入页面 (MessageView.swift)
- 使用自定义的`OTPTextField`组件输入4位验证码
- 提供重新发送验证码功能
- 输入完整4位验证码后启用"下一步"按钮

#### 验证码验证 (MessageView.swift)
- `checkCode()`方法发送POST请求到`/api/guan/login`
- 请求参数包含手机号和验证码
- 根据响应结果判断是登录还是需要注册：
  - respCode == 0：登录成功，保存token
  - respCode == -1 && respMsg == "1"：需要注册

#### 注册流程 (UserLoginModel.swift)
- 如果需要注册，跳转到NameView输入昵称
- 调用`register()`方法发送POST请求到`/api/guan/register`
- 注册成功后同样保存token并获取用户信息

#### 状态管理
- 使用`OTOLoginStatusManager`单例管理登录状态
- 通过UserDefaults持久化存储token和用户ID
- 提供登录、登出、获取状态等方法

#### 网络请求 (NetworkService.swift)
- 基于URLSession实现异步网络请求
- 自动添加Authorization头部的Bearer token
- 统一处理请求和响应格式
- 提供错误处理机制