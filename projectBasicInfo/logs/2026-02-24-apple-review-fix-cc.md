# Apple 审核拒绝修复 (2026-02-24)

## 背景

Apple 拒绝 v1.0 提交，涉及：
1. Guideline 5.1.1：相机权限说明过于笼统
2. Guideline 5.1.1(v)：无账号注销功能

## 修改的文件

### Part 1：权限说明修复
- `guanzhi.xcodeproj/project.pbxproj` — Debug/Release 各更新 3 个权限说明（Camera、Microphone、PhotoLibrary），增加具体使用场景
- `Localization/InfoPlist.xcstrings` — 同步更新中英文翻译，补充 LocationAlways 英文翻译

### Part 2：账号注销功能

**后端**：
- `UserServiceImpl.java` — `delUser()` 从物理删除改为软删除（status=3，清除昵称/手机号/头像）；`checkCode()` 和 `guanLogin()` 增加 status==3 拦截

**iOS**：
- `OTORequests.swift` — 新增 `deleteAccount` case（POST /api/guan/user/del）
- `AccountManagementView.swift` — 新增注销账号按钮 + 两步确认（警告 → 输入确认）+ 调 API + 退出登录
- `UserProfile.swift` — SwiftData 模型新增 `status: Int?` 属性
- `UserProfileManager.swift` — `saveToUserProfile()` 映射 status 字段
- `UserProfileMapper.swift` — `toDisplayModel()` 检查 status==3，覆盖显示名为"账号已注销"
- `ToastMessages.swift` — 新增 accountDeleted / accountDeleteFailed Toast
- `Localizable.xcstrings` — 新增 9 个中英文翻译条目

## 待做
- 后端部署（重新打包 JAR + systemctl restart）
- Xcode Build 验证
- 端到端测试（注销流程、已注销用户显示、登录拦截）
- App Store Connect 更新审核备注
