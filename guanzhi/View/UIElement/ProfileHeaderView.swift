//
//  ProfileHeaderView.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/7.
//  统一的用户头部展示组件
//  同时用于 MyView 和 OthersView，确保等级等信息一致展示
//

import SwiftUI

/// 用户头部模式
enum ProfileMode {
    case me      // 当前用户（显示编辑按钮）
    case other   // 他人用户（不显示编辑按钮）
}

/// 统一的用户头部展示组件
struct ProfileHeaderView: View {
    /// 展示数据模型（已处理 OneCode 遮挡和等级映射）
    let displayModel: UserProfileDisplayModel

    /// 模式：当前用户 or 他人
    let mode: ProfileMode

    /// 缓存的头像图片（仅当前用户需要传入，他人使用网络加载）
    var cachedAvatarImage: UIImage?

    /// 头像点击回调（仅 .me 模式响应）
    var onAvatarTap: (() -> Void)?

    /// 编辑资料按钮回调（仅 .me 模式显示）
    var onEditProfileTap: (() -> Void)?

    /// OneCode 点击回调（用于显示提示）
    var onOneCodeTap: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: Constants.spacingSpacingXs) {
            // 头像
            avatarButton

            // 用户信息
            VStack(alignment: .leading, spacing: 4) {
                // 昵称
                Text(displayModel.displayNickname)
                    .font(.headline)

                // OneCode（已处理遮挡）
                Text("OneCode: \(displayModel.displayOneCode)")
                    .font(.subheadline)
                    .onTapGesture {
                        if displayModel.isOneCodeMasked {
                            onOneCodeTap?()
                        }
                    }

                // 等级（两种模式都显示）
                Text("等级：「\(displayModel.levelName)」")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 编辑资料按钮（仅 .me 模式）
            if mode == .me {
                Button(action: {
                    onEditProfileTap?()
                }) {
                    Text("修改资料")
                }
                .buttonStyle(ButtonStyle_capsuleHugPrimary_s(isEnabled: true))
            }
        }
        .padding(.horizontal)
        .padding(.top, Constants.spacingSpacingXs)
    }

    /// 头像按钮
    @ViewBuilder
    private var avatarButton: some View {
        if cachedAvatarImage != nil || displayModel.avatarPath == nil || displayModel.avatarPath?.isEmpty == true {
            // 当前用户（有缓存头像）或无头像路径：使用同步 Image
            let avatarImage: Image = {
                if let uiImage = cachedAvatarImage {
                    return Image(uiImage: uiImage)
                } else {
                    return Image("icon-defaultAvatar")
                }
            }()

            Button(action: {
                if mode == .me {
                    onAvatarTap?()
                }
            }) {
                // 头像-l
            }
            .buttonStyle(AvatarStyle_l(
                isEnabled: mode == .me,
                profileImage: avatarImage,
                borderThickness: 4
            ))
        } else {
            // 他人用户且有头像路径：使用 AsyncImage 加载网络头像
            let fullPath: String = {
                let path = displayModel.avatarPath!
                return path.hasPrefix("image/") ? path : "image/\(path)"
            }()
            let avatarURL = URL(string: "\(Constants.BASE_HOST)/\(fullPath)")

            ZStack(alignment: .center) {
                Image("icon-avatar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54 - 2, height: 54 - 2)
                    .foregroundColor(.black)

                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image("icon-defaultAvatar")
                            .resizable()
                            .scaledToFit()
                    default:
                        Image("icon-defaultAvatar")
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(width: 54 - 4 - 2, height: 54 - 4 - 2)
                .mask(
                    Image("icon-avatar")
                        .resizable()
                        .scaledToFit()
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("当前用户模式") {
    let mockDisplayModel = UserProfileDisplayModel(
        id: 1,
        displayNickname: "测试用户",
        displayOneCode: "TESTCODE",
        isOneCodeMasked: false,
        avatarPath: nil,
        levelName: "冲浪",
        titleDOS: nil
    )

    ProfileHeaderView(
        displayModel: mockDisplayModel,
        mode: .me,
        cachedAvatarImage: nil,
        onAvatarTap: { print("Avatar tapped") },
        onEditProfileTap: { print("Edit profile tapped") },
        onOneCodeTap: { print("OneCode tapped") }
    )
}

#Preview("他人用户模式") {
    let mockDisplayModel = UserProfileDisplayModel(
        id: 2,
        displayNickname: "其他用户",
        displayOneCode: "OTHER123",
        isOneCodeMasked: false,
        avatarPath: nil,
        levelName: "灯塔",
        titleDOS: nil
    )

    ProfileHeaderView(
        displayModel: mockDisplayModel,
        mode: .other,
        cachedAvatarImage: nil
    )
}

#Preview("OneCode 被遮挡") {
    let mockDisplayModel = UserProfileDisplayModel(
        id: 3,
        displayNickname: "隐藏用户",
        displayOneCode: "⬛️⬛️⬛️⬛️",
        isOneCodeMasked: true,
        avatarPath: nil,
        levelName: "幽暝",
        titleDOS: nil
    )

    ProfileHeaderView(
        displayModel: mockDisplayModel,
        mode: .other,
        cachedAvatarImage: nil,
        onOneCodeTap: { print("OneCode hint shown") }
    )
}
