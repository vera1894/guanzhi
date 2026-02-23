//
//  UserProfileManager.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/1/6.
//


import Foundation
import SwiftUI
import SwiftData
import Alamofire

// MARK: - 用户加载状态枚举
enum UserLoadingState {
    case idle           // 未开始
    case loading        // 加载中
    case loaded         // 加载成功
    case error(Error)   // 加载失败
}

@MainActor
class UserProfileManager: ObservableObject {
    // 让它可访问 SwiftData 的 context
    var context: ModelContext?

    // MARK: - SSOT 新属性
    /// 他人页面当前查看的用户 ID（View 用 @Query 根据此 ID 查询）
    @Published var viewedUserId: Int?

    // MARK: - SSOT 方法

    /// 统一保存用户信息到 UserProfile 表（替代原有的分离存储逻辑）
    /// 无论是当前用户还是他人，都写入同一张表
    func saveToUserProfile(userInfo: UserFullInfoModel) throws {
        guard let context = context else {
            print("⚠️ [SSOT] saveToUserProfile: context 为 nil，无法保存用户 \(userInfo.id)")
            return
        }
        print("📝 [SSOT] 保存用户 \(userInfo.id) 到 UserProfile 表，levelCode: \(userInfo.levelCode ?? "nil")")

        // 使用 flatMap 正确处理 nil 编码
        let titleDOSData = userInfo.titleDOS.flatMap { try? JSONEncoder().encode($0) }

        // 查找是否已存在
        let userId = userInfo.id
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.id == userId }
        )
        let existing = (try? context.fetch(descriptor))?.first

        if let existing = existing {
            // 更新已有记录
            existing.name = userInfo.name
            existing.nickname = userInfo.nickname
            existing.phone = userInfo.phone
            existing.photo = userInfo.photo
            existing.code = userInfo.code
            existing.createDate = userInfo.createDate
            existing.jpushId = userInfo.jpushId
            existing.titleDOSData = titleDOSData
            existing.levelCode = userInfo.levelCode
            existing.pointsTotal = userInfo.pointsTotal
            existing.platform = userInfo.platform
            existing.lastUpdated = Date()
        } else {
            // 新建记录
            let newProfile = UserProfile(
                id: userInfo.id,
                name: userInfo.name,
                nickname: userInfo.nickname,
                phone: userInfo.phone,
                photo: userInfo.photo,
                code: userInfo.code,
                createDate: userInfo.createDate,
                jpushId: userInfo.jpushId,
                titleDOSData: titleDOSData,
                levelCode: userInfo.levelCode,
                pointsTotal: userInfo.pointsTotal,
                platform: userInfo.platform
            )
            context.insert(newProfile)
            print("📝 [SSOT] 新建 UserProfile 记录: \(userInfo.id)")
        }

        try context.save()
        print("✅ [SSOT] UserProfile 保存成功: \(userInfo.id)")
    }

    /// 从 UserProfile 表查询指定用户
    func findUserProfile(userId: Int) -> UserProfile? {
        guard let context = context else { return nil }
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.id == userId }
        )
        return (try? context.fetch(descriptor))?.first
    }

    /// 清空所有 UserProfile（退出登录时调用，确保账户隔离）
    func clearAllUserProfiles() throws {
        guard let context = context else { return }

        let descriptor = FetchDescriptor<UserProfile>()
        let allProfiles = (try? context.fetch(descriptor)) ?? []

        for profile in allProfiles {
            context.delete(profile)
        }

        try context.save()

        // 同时清空内存中的状态
        self.viewedUserId = nil
        self.otherUserProfile = nil
        self.localUserProfile = nil
        self.avatarImage = nil

        // 清除头像缓存文件
        try? FileManager.default.removeItem(at: getAvatarCacheURL())

        print("🧹 已清空所有 UserProfile 缓存")
    }

    /// 启动时检查：如果未登录则清空缓存（防止残留数据）
    func checkAndClearIfNotLoggedIn() {
        let currentUserId = OTOLoginStatusManager.shared.getUserID()
        // getUserID() 返回 0 或负数表示未登录
        if currentUserId <= 0 {
            try? clearAllUserProfiles()
            print("🔐 用户未登录，已清空 UserProfile 缓存")
        }
    }

    // 为了在内存里临时存储他人资料（过渡期保留，后续移除）
    @Published var otherUserProfile: UserFullInfoModel? = nil

    // 为了在内存里保存当前本机用户信息（过渡期保留，后续移除）
    @Published var localUserProfile: LocalUserProfile?

    // 添加头像缓存
    @Published var avatarImage: UIImage?
    private let avatarCacheKey = "userAvatarCache"

    // 用户加载状态管理 - 为每个 userId 维护状态
    @Published var userLoadingStates: [Int: UserLoadingState] = [:]

    // MARK: - 拉取任意用户详细信息
            /// 如果 userId 等于当前登录者 => 额外存入 SwiftData
            /// 否则 => 暂存在 `otherUserProfile`
        func fetchUserFullInfo(userId: Int) async throws {
            if PreviewHarness.enabled {
                print("🔌 [PreviewHarness] UserProfile mocked for userId: \(userId)")
                let mockProfile = UserFullInfoModel(
                    id: userId,
                    createDate: nil,
                    code: "MOCK123",
                    phone: "13800138000",
                    name: "测试用户",
                    nickname: "测试用户 \(userId)",
                    password: nil,
                    registerdate: nil,
                    lastLoginTime: nil,
                    jpushId: nil,
                    platform: "iOS",
                    photo: nil,
                    titleDOS: [],
                    levelCode: "CHONGLANG",
                    pointsTotal: 100,
                    status: 0,
                    role: "USER"
                )
                DispatchQueue.main.async {
                    self.otherUserProfile = mockProfile
                    self.userLoadingStates[userId] = .loaded
                }
                return
            }

            // 设置为加载中状态
            userLoadingStates[userId] = .loading
            print("👤 Profile load start \(userId)")
                                            do {
                                                let data = try await OTONetwork.request(.fetchUserFullInfo(userId: userId))
                                                let decoder = JSONDecoder()
                                                let response = try decoder.decode(OTOResponseModel<UserFullInfoModel>.self, from: data)
                                    
                                                guard response.respCode == 0 else {
                                                    let error = NSError(domain: "UserProfileManager", code: response.respCode, userInfo: [
                                                        NSLocalizedDescriptionKey: response.respMsg ?? String(localized: "未知错误")
                                                    ])
                                                    userLoadingStates[userId] = .error(error)
                                                    print("❌ Profile error \(userId): \(response.respMsg ?? "未知错误")")
                                                    throw error
                                                }
                                    
                                                guard let userData = response.datas else {
                                                    let error = NSError(domain: "UserProfileManager", code: 2, userInfo: [
                                                        NSLocalizedDescriptionKey: String(localized: "数据为空")
                                                    ])
                                                    userLoadingStates[userId] = .error(error)
                                                    print("❌ Profile error \(userId): datas 为空")
                                                    throw error
                                                }
                                    
                                                // SSOT: 无论是当前用户还是他人，都统一保存到 UserProfile 表
                                                try saveToUserProfile(userInfo: userData)

                                                if isCurrentLoggedUser(userId: userId) {
                                                    // 当前用户：额外处理头像缓存
                                                    if let photoPath = userData.photo {
                                                        Task {
                                                            await loadAndCacheAvatar(path: photoPath)
                                                        }
                                                    }
                                                    // 过渡期：同时保持旧逻辑
                                                    try saveToSwiftData(userInfo: userData)
                                                    self.localUserProfile = findLocalUserInSwiftData(userId: userId)
                                                } else {
                                                    // 他人用户：设置 viewedUserId 供 @Query 使用
                                                    self.viewedUserId = userId
                                                    // 过渡期：同时保持旧逻辑
                                                    self.otherUserProfile = userData
                                                }
                                    
                                                // 设置为加载成功状态
                                                userLoadingStates[userId] = .loaded
                                                print("✅ Profile loaded \(userId)")
                                    
                                            } catch {
                                                // 捕获所有错误并更新状态
                                                userLoadingStates[userId] = .error(error)
                                                print("❌ Profile error \(userId): \(error.localizedDescription)")
                                                throw error
                                            }
                                        }
    // MARK: - 存储到 SwiftData
    private func saveToSwiftData(userInfo: UserFullInfoModel) throws {
        guard let context = context else { return }

        // 先检查数据库里是否已有
        let existing = findLocalUserInSwiftData(userId: userInfo.id)
        if let existing = existing {
            // 更新
            existing.name = userInfo.name ?? ""
            existing.nickname = userInfo.nickname ?? ""
            existing.phone = userInfo.phone ?? ""
            existing.photo = userInfo.photo
            existing.code = userInfo.code
            existing.createDate = userInfo.createDate
            existing.jpushId = userInfo.jpushId
            existing.titleDOS = userInfo.titleDOS
            existing.levelCode = userInfo.levelCode
            existing.pointsTotal = userInfo.pointsTotal
        } else {
            // 新建
            let newUser = LocalUserProfile(
                id: userInfo.id,
                name: userInfo.name ?? "",
                nickname: userInfo.nickname ?? "",
                phone: userInfo.phone ?? "",
                photo: userInfo.photo,
                code: userInfo.code,
                createDate: userInfo.createDate,
                jpushId: userInfo.jpushId,
                titleDOS: userInfo.titleDOS,
                levelCode: userInfo.levelCode,
                pointsTotal: userInfo.pointsTotal
            )
            context.insert(newUser)
        }

        // 保存
        try context.save()
    }

    // MARK: - 从 SwiftData 找到本机用户
    private func findLocalUserInSwiftData(userId: Int) -> LocalUserProfile? {
        guard let context = context else { return nil }
        let descriptor = FetchDescriptor<LocalUserProfile>(
            predicate: #Predicate { $0.id == userId }
        )
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - 获取缓存的用户昵称（降级方案）
    /// 当 localUserProfile 为 nil 时，尝试从 SwiftData 获取缓存的昵称
    func getCachedNickname() -> String? {
        // 优先使用内存中的 localUserProfile
        if let nickname = localUserProfile?.nickname, !nickname.isEmpty {
            return nickname
        }
        // 降级：从 SwiftData 缓存中读取
        let userId = OTOLoginStatusManager.shared.getUserID()
        if let cachedUser = findLocalUserInSwiftData(userId: userId) {
            return cachedUser.nickname.isEmpty ? nil : cachedUser.nickname
        }
        return nil
    }

    // MARK: - 判断是否是当前登录的 userId
    private func isCurrentLoggedUser(userId: Int) -> Bool {
        // 你可以对比 OTOLoginStatusManager.shared.getUserID() == userId
        // 这里只是示例
        return (OTOLoginStatusManager.shared.getUserID() == userId)
    }

    // MARK: - 清空 SwiftData 中本机信息(退出登录时调用)
    func clearLocalUserProfile() throws {
        guard let context = context else { return }
        let userId = OTOLoginStatusManager.shared.getUserID()
        if let localUser = findLocalUserInSwiftData(userId: userId) {
            context.delete(localUser)
            try context.save()
        }
        self.localUserProfile = nil
        
        // 清除头像缓存
        self.avatarImage = nil
        try? FileManager.default.removeItem(at: getAvatarCacheURL())
    }
    
    // 加载并缓存头像
    private func loadAndCacheAvatar(path: String) async {
        print("开始加载头像，路径: \(path)")
        
        // 构建完整的图片 URL，需要添加 image/ 前缀
        let fullPath = path.hasPrefix("image/") ? path : "image/\(path)"
        guard let imageUrl = URL(string: "\(Constants.BASE_HOST)/\(fullPath)") else {
            print("无效的头像URL")
            return
        }
        
        print("尝试加载头像URL: \(imageUrl)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: imageUrl)
            
            // 打印 HTTP 响应信息
            if let httpResponse = response as? HTTPURLResponse {
                print("头像加载 HTTP 状态码: \(httpResponse.statusCode)")
            }
            
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.avatarImage = image
                    print("头像加载成功")
                }
                // 保存到本地文件系统
                try? data.write(to: getAvatarCacheURL())
            } else {
                print("头像数据无法转换为图片，数据大小: \(data.count) bytes")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("服务器响应内容: \(responseString)")
                }
            }
        } catch {
            print("加载头像失败: \(error)")
        }
    }
    
    // 获取头像缓存路径
    private func getAvatarCacheURL() -> URL {
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cacheDir.appendingPathComponent(avatarCacheKey)
    }
    
    // 从缓存加载头像
    func loadCachedAvatar() {
        let cacheURL = getAvatarCacheURL()
        if let data = try? Data(contentsOf: cacheURL),
           let image = UIImage(data: data) {
            self.avatarImage = image
        }
    }

    // 添加初始化头像的方法
    func initializeAvatar() {
        // 先尝试加载缓存
        loadCachedAvatar()

        // 如果已经有用户信息且有头像路径，则加载头像
        if let profile = localUserProfile, let photoPath = profile.photo {
            Task {
                await loadAndCacheAvatar(path: photoPath)
            }
        }
    }

    // MARK: - 从 SwiftData 加载缓存的用户信息（懒加载）
    /// 优先从本地缓存加载用户信息，适用于网络不可用的场景
    func loadCachedUserProfile() {
        let userId = OTOLoginStatusManager.shared.getUserID()
        if let cachedUser = findLocalUserInSwiftData(userId: userId) {
            self.localUserProfile = cachedUser
            print("📦 已从本地缓存加载用户信息，等级: \(cachedUser.levelName)")
        }
    }

    // MARK: - 懒加载用户信息（先缓存后网络）
    /// 先从本地缓存加载，然后尝试从服务器刷新
    func loadUserProfileWithCache(userId: Int) async {
        // 1. 先从缓存加载（立即显示）
        loadCachedUserProfile()

        // 2. 尝试从服务器刷新（后台更新）
        do {
            try await fetchUserFullInfo(userId: userId)
        } catch {
            // 网络失败时，如果缓存已加载则保持使用缓存
            if localUserProfile != nil {
                print("⚠️ 网络请求失败，使用本地缓存: \(error.localizedDescription)")
            } else {
                print("❌ 网络请求失败且无本地缓存: \(error.localizedDescription)")
            }
        }
    }
}


// MARK: - 扩展部分 更新用户信息
@MainActor
extension UserProfileManager {
    
    /// 更新用户 name (OneCode)
    func updateUserName(newName: String) async throws -> LocalUserProfile? {
        let data = try await OTONetwork.request(.updateUserName(newName: newName))
        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<UserFullInfoModel>.self, from: data)
        
        // 后端可能返回 respCode=-1 表示某种错误
        guard response.respCode == 0 else {
            if response.respCode == -1 {
                throw NSError(domain: "UserProfileManager", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: response.respMsg ?? String(localized: "此 OneCode 已被他人使用")
                ])
            } else {
                throw NSError(domain: "UserProfileManager", code: response.respCode, userInfo: [
                    NSLocalizedDescriptionKey: response.respMsg ?? String(localized: "更新OneCode失败")
                ])
            }
        }
        
        if let userInfo = response.datas {
            if isCurrentLoggedUser(userId: userInfo.id) {
                try saveToSwiftData(userInfo: userInfo)
                self.localUserProfile = findLocalUserInSwiftData(userId: userInfo.id)
            }
        } else {
            // datas=null => fetch
            let myUserId = OTOLoginStatusManager.shared.getUserID()
            try await fetchUserFullInfo(userId: myUserId)
        }
        
        return localUserProfile
    }
    
    /// 更新用户 nickname
    /// - Returns: 最新的 LocalUserProfile（若没有，就返回 nil）
    func updateUserNickname(newNickname: String) async throws -> LocalUserProfile? {
        // 1）发起网络请求
        let data = try await OTONetwork.request(.updateUserNickname(newNickname: newNickname))
        
        // 2）解析后端响应
        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<UserFullInfoModel>.self, from: data)
        
        // 3）检查 respCode
        guard response.respCode == 0 else {
            throw NSError(domain: "UserProfileManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: response.respMsg ?? String(localized: "更新昵称失败")
            ])
        }
        
        // 4）如果 datas != nil，就存 SwiftData；否则 fetchUserFullInfo
        if let userInfo = response.datas {
            if isCurrentLoggedUser(userId: userInfo.id) {
                try saveToSwiftData(userInfo: userInfo)
                self.localUserProfile = findLocalUserInSwiftData(userId: userInfo.id)
            }
        } else {
            // datas=null => 我们再 fetch
            let myUserId = OTOLoginStatusManager.shared.getUserID()
            try await fetchUserFullInfo(userId: myUserId)
        }
        
        // 5）返回本地的 localUserProfile
        return localUserProfile
    }
    
    /// 更新用户 platform
    func updateUserPlatform(newPlatform: String) async throws -> LocalUserProfile? {
        let data = try await OTONetwork.request(.updateUserPlatform(newPlatform: newPlatform))
        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<UserFullInfoModel>.self, from: data)
        
        guard response.respCode == 0 else {
            throw NSError(domain: "UserProfileManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: response.respMsg ?? String(localized: "更新平台失败")
            ])
        }
        if let userInfo = response.datas {
            if isCurrentLoggedUser(userId: userInfo.id) {
                try saveToSwiftData(userInfo: userInfo)
                self.localUserProfile = findLocalUserInSwiftData(userId: userInfo.id)
            }
        } else {
            let myUserId = OTOLoginStatusManager.shared.getUserID()
            try await fetchUserFullInfo(userId: myUserId)
        }
        
        return localUserProfile
    }
    
    /// 通过一个或多个头像相关文件更新用户头像
    func setAvatar(photos: [Photo]) async throws -> LocalUserProfile? {
        guard let photo = photos.first else { 
            throw NSError(domain: "UserProfileManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No photo provided"])
        }
        
        print("开始上传头像...")
        
        // 第一步：上传图片，使用更简化的文件名
        let randomNumber = String(format: "%03d", Int.random(in: 0..<1000))  // 减少到3位数
        let fileName = "A\(randomNumber).jpg"  // 极简的文件名：A123.jpg
        
        let imagePath = try await uploadAvatarFile(
            fileData: photo.data,
            fileName: fileName,
            mimeType: "image/jpeg"
        )
        print("图片上传成功，获取到路径: \(imagePath)")
        
        // 第二步：更新用户信息，去掉 image/ 前缀
        let photoPath = imagePath.replacingOccurrences(of: "image/", with: "")
        return try await updateUserPhoto(newPhoto: photoPath)
    }
    
    /// 更新用户 photo
    func updateUserPhoto(newPhoto: String) async throws -> LocalUserProfile? {
        print("开始更新用户头像信息...")
        print("使用图片路径: \(newPhoto)")
        
        let data = try await OTONetwork.request(.updateUserPhoto(newPhoto: newPhoto))
        let decoder = JSONDecoder()
        let response = try decoder.decode(OTOResponseModel<UserFullInfoModel>.self, from: data)
        
        guard response.respCode == 0 else {
            throw NSError(domain: "UserProfileManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: response.respMsg ?? String(localized: "更新头像失败")
            ])
        }
        
        if let userInfo = response.datas {
            if isCurrentLoggedUser(userId: userInfo.id) {
                try saveToSwiftData(userInfo: userInfo)
                self.localUserProfile = findLocalUserInSwiftData(userId: userInfo.id)
                
                // 更新成功后，立即重新加载头像
                if let photoPath = userInfo.photo {
                    Task {
                        await loadAndCacheAvatar(path: photoPath)
                    }
                }
            }
        } else {
            let myUserId = OTOLoginStatusManager.shared.getUserID()
            try await fetchUserFullInfo(userId: myUserId)
        }
        
        return localUserProfile
    }
    
    /// 简化版：逐个上传头像相关文件
    private func uploadAvatarFiles(photos: [Photo]) async throws -> String {
        var paths: [String] = []
        
        for photo in photos {
            // 使用更简化的文件名生成逻辑
            let randomNumber = String(format: "%03d", Int.random(in: 0..<1000))
            
            // 上传静态图
            let photoPath = try await uploadAvatarFile(
                fileData: photo.data,
                fileName: "A\(randomNumber).jpg",  // A123.jpg
                mimeType: "image/jpeg"
            )
            paths.append(photoPath)
            
            // 如果有 livePhotoVideo
            if let liveURL = photo.livePhotoMovieURL {
                let videoData = try Data(contentsOf: liveURL)
                let livePhotoPath = try await uploadAvatarFile(
                    fileData: videoData,
                    fileName: "A\(randomNumber)L.mov",  // A123L.mov
                    mimeType: "video/quicktime"
                )
                paths.append(livePhotoPath)
            }
        }
        
        return paths.joined(separator: ",")
    }
    
    private func uploadAvatarFile(fileData: Data, fileName: String, mimeType: String) async throws -> String {
        guard let url = URL(string: "\(Constants.BASE_HOST)/api/guan/uploadImage") else {
            throw NSError(domain: "UploadAvatarFile", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid upload URL"])
        }

        let headers: HTTPHeaders = [
            "Content-Type": "multipart/form-data",
            "Authorization": OTOLoginStatusManager.shared.getToken() ?? ""
        ]

        return try await withCheckedThrowingContinuation { continuation in
            AF.upload(multipartFormData: { formData in
                formData.append(fileData, withName: "multipartFile", fileName: fileName, mimeType: mimeType)
            }, to: url, method: .post, headers: headers)
                .responseDecodable(of: UploadResponse.self) { response in
                    switch response.result {
                    case .success(let uploadResponse):
                        print("Upload response: \(uploadResponse)")  // 添加日志
                        guard uploadResponse.respCode == 0 else {
                            let errMsg = uploadResponse.respMsg.isEmpty ? String(localized: "上传失败") : uploadResponse.respMsg
                            continuation.resume(throwing: NSError(domain: "UploadAvatarFile", code: uploadResponse.respCode, userInfo: [NSLocalizedDescriptionKey: errMsg]))
                            return
                        }
                        if let path = uploadResponse.datas {
                            continuation.resume(returning: path)
                        } else {
                            continuation.resume(throwing: NSError(domain: "UploadAvatarFile", code: -1, userInfo: [NSLocalizedDescriptionKey: "No path returned"]))
                        }
                    case .failure(let error):
                        print("Upload error: \(error.localizedDescription)")  // 添加错误日志
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
    
    struct UploadResponse: Codable {
        let datas: String?
        let respCode: Int
        let respMsg:String
    }
}
