//
//  EditAvatarView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/2/24.
//

import SwiftUI
import PhotosUI

struct EditAvatarView: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var toastManager: ToastManager
    
    // 1) 控制弹出 PhotoPicker
    @State private var showPhotoPicker = false
    
    // 2) 记录用户选择的一项
    @State private var selectedItem: PhotosPickerItem? = nil
    
    // 3) 保存选中的图像
    @State private var selectedImage: UIImage? = nil
    
    // 1) 绑定到数组，以便使用 inline 样式
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var croppedImage: UIImage?
    @State private var isUploading = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack{
                    HStack {
                        Text("🎨 修改头像")
                            .font(.title3)
                            .bold()
                        Spacer()
                    }

                    HStack {
                        Spacer()
                        Button{
                            //关闭按钮-圆形
                            dismiss()
                        }label: {
                            Image("icon-close")
                        }
                        .buttonStyle(ButtonStyle_m())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            
            // 显示头像
            AvatarView_xl(
                isEnabled: true,
                profileImage: croppedImage ?? userProfileManager.avatarImage ?? UIImage(named: "icon-defaultAvatar")!,
                borderThickness: 10
            )
            
            Spacer()
            
            Button(action: {
                showPhotoPicker = true
            }) {
                Text("👽 选择新头像")
            }
            .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: true))
            .padding()
        
            
            
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cropImagePicker(
            options: [.square],
            show: $showPhotoPicker,
            croppedImage: $croppedImage
        )
        .onChange(of: croppedImage) { oldValue, newValue in
            if let newValue {
                uploadAvatar(newValue)
            }
        }
        
    }
    
    // MARK: - 从 PhotosPickerItem 加载 UIImage
        private func loadSelectedImage(from item: PhotosPickerItem) async {
            do {
                // 尝试把选定项转成 Data
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
                    
                    // 在这里可以进一步调用 userProfileManager.setAvatar(...) 上传
                    // e.g. let photo = Photo(data: data, isProxy:false, livePhotoMovieURL: nil)
                    // ...
                }
            } catch {
                print("Error loading image from picker: \(error)")
            }
        }
    
    // MARK: - 从 PhotosPickerItem 加载 UIImage
    private func loadImage(from pickerItem: PhotosPickerItem) async {
        do {
            if let data = try await pickerItem.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                selectedImage = uiImage
            }
        } catch {
            print("加载图片失败: \(error)")
        }
    }
    
    // MARK: 上传头像
    private func uploadAvatar(_ image: UIImage) {
        Task {
            do {
                isUploading = true
                // 创建 Photo 实例，livePhotoMovieURL 设置为 nil
                let photo = Photo(data: image.jpegData(compressionQuality: 0.8) ?? Data(), isProxy: false, livePhotoMovieURL: nil)
                // 使用 UserProfileManager 上传头像
                _ = try await userProfileManager.setAvatar(photos: [photo])
                showNotification(message: "✅ 修改头像成功")
                dismiss()  // 关闭编辑页面
                dismiss()
            } catch {
                showNotification(message: "❌ 修改头像失败")
                dismiss()
            }
            isUploading = false
        }
    }
    
    private func showNotification(message: String) {
        let newItem = ToastItem(style: .notificationOnly(
            title: message,
            symbol: "",
            tint: Color("color-primary"),
            isUserInteractionEnabled: true,
            timing: .short,
            isAutoClose: true
        ))
        toastManager.show(newItem)
    }
    
}

#Preview {
    EditAvatarView()
}


struct AvatarView_xl: View {
    var isEnabled: Bool
    var profileImage: UIImage
    var borderThickness: CGFloat

    var body: some View {
        ZStack(alignment: .center) {
            // 边框层（使用底层头像图形）
            Image("avatar")
                .resizable()
                .scaledToFit()
                .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.width * 0.8)
                .foregroundColor(.black)
            // 头像图像层，使用遮罩将其切成相同的形状
            Image(uiImage: profileImage)
                .resizable()
                .scaledToFit()
                .frame(width: UIScreen.main.bounds.width * 0.8 - borderThickness, height: UIScreen.main.bounds.width * 0.8 - borderThickness)
                .mask(
                    Image("avatar")
                        .resizable()
                        .scaledToFit()
                )
        }
        // 这里去掉了点击时的亮度变化、缩放效果
        .brightness(0)
        .grayscale(isEnabled ? 0 : 1)
        .scaleEffect(1.0)
        .opacity(isEnabled ? 1 : 0.5)
    }
}
