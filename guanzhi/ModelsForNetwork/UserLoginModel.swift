//
//  UserLoginModel.swift
//  guanzhi
//
//  Created by Vera on 2024/3/20.
//

import Foundation

fileprivate let loginTokenKey = "loginTokenKey"

struct EmptyData: Codable {}

extension UserDefaults {
    func contains(key: String) -> Bool {
        return self.object(forKey: key) != nil
    }
}

class UserLoginModel: ObservableObject {
    @Published var phone: String = ""{
        didSet{
            //超过11位限制输入
            if phone.count > 11,oldValue.count <= 11{
                phone = oldValue
            }
        }
    }    // 手机号
    @Published var code: String = ""       // 验证码
  //  @Published var userName: String = ""   // 代号
    @Published var nickName: String = ""   // 昵称
    @Published var loginState: Int = 1     // 注册状态，1未注册 0已注册
    @Published var header: String = ""     // 令牌
    @Published var time : Int = 0 //短信等待时长
    @Published var firstSendMessage: Bool = false //是否已从首页发送验证码
    
    @Published var noticeText: String = "" //提示文字
   // @Published var codePassed: Bool = false //代号是否通过验证
    @Published var namePassed : Bool = false //名字是否通过验证

    
    @Published var sendStatus: Bool = false //是否发送成功
   // @Published var image: UIImage = UIImage()
    @Published var userName: String = "" //登录用户昵称
    @Published var userId : Int = -1 //登录用户id
    
    
    func sendCode(phNumber: String) {
            DispatchQueue.main.async {
                Task {
                    print("📱 开始发送验证码到: \(phNumber)")
                    do {
                        let data = try await OTONetwork.request(.SendVerifiedCode(phoneNumber: phNumber))
                        print("📱 成功接收发送验证码响应")
                        
                        let decoder = JSONDecoder()
                        let response = try decoder.decode(OTOResponseModel<EmptyData>.self, from: data)
                        
                        print("📱 respCode: \(response.respCode)")
                        print("📱 respMsg: \(response.respMsg ?? "无消息")")
                        
                        if response.respCode == 0 {
                            print("✅ 验证码发送成功")
                            self.sendStatus = true
                        } else {
                            print("❌ 验证码发送失败")
                        }
                        self.noticeText = response.respMsg ?? ""
                    } catch {
                        print("❌ 发送验证码失败")
                        print("❌ 错误类型: \(type(of: error))")
                        print("❌ 错误信息: \(error.localizedDescription)")
                        print("❌ 错误详情: \(error)")
                    }
                }
            }
        }
    
    func regulayExpression(regularExpress: String, validateString: String) -> [String] {
        do {
            let regex = try NSRegularExpression.init(pattern: regularExpress, options: [])
            let matches = regex.matches(in: validateString, options: [], range: NSRange(location: 0, length: validateString.count))
            var res: [String] = []
            for item in matches {
                let str = (validateString as NSString).substring(with: item.range)
                res.append(str)
            }
            return res
        } catch {
            return []
        }
    }
    
    func replace(validateStr: String, regularExpress: String, contentStr: String) -> String {
        do {
            let regrex = try NSRegularExpression.init(pattern: regularExpress, options: [])
            let modified = regrex.stringByReplacingMatches(in: validateStr, options: [], range: NSRange(location: 0, length: validateStr.count), withTemplate: contentStr)
            return modified
        } catch {
            return validateStr
        }
    }
    
    //验证姓名
    func register(){
        let regular = "[\\u4e00-\\u9fa5]"
        let tempNickName = replace(validateStr: self.nickName,regularExpress: regular, contentStr: "aa")
        
        if tempNickName.count > 32 {
            self.noticeText = "名字最多可设置16个汉字/32个字符"
        }else{
            if !ValidateEnum.nickName(self.nickName).isRight{
                self.noticeText = "仅支持数字、英文、汉字"
            }else{
                DispatchQueue.main.async {
                        Task {
                            do {
                                let data = try await OTONetwork.request(.Register(phoneNumber: self.phone, nickName: self.nickName))
                                let decoder = JSONDecoder()
                                let response = try decoder.decode(OTOResponseModel<String>.self, from: data)

                                if response.respCode == 0 {
                                    self.namePassed = true
                                    if let tokenString = response.datas {
                                        self.header = "Bearer " + tokenString
                                        OTOLoginStatusManager.shared.login(token: self.header)
                                        self.getUserInfo()
                                    }
                                } else {
                                    self.noticeText = response.respMsg ?? ""
                                }
                            } catch {
                                // 错误已在 NetworkService 层处理
                            }
                        }
                    }
                }
        }
    }
    
    //获取用户昵称
    func getUserInfo(){
        DispatchQueue.main.async {
            Task {
                print("👤 开始获取用户信息...")
                do {
                    let data = try await OTONetwork.request(.userInfo)
                    print("👤 成功接收用户信息数据")
                    
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(OTOResponseModel<dataModel>.self, from: data)
                    
                    print("👤 respCode: \(response.respCode)")
                    print("👤 respMsg: \(response.respMsg ?? "无消息")")
                    
                    if response.respCode == 0 {
                        if let datas = response.datas {
                            self.userName = datas.nickname ?? "用户"
                            self.userId = datas.id ?? -1
                            print("✅ 请求成功")
                            print("✅ 用户昵称: \(self.userName)")
                            print("✅ 用户ID: \(self.userId)")
                            
                            // 保存用户ID到 OTOLoginStatusManager
                            OTOLoginStatusManager.shared.setUserID(self.userId)
                        } else {
                            print("⚠️ datas 为 nil")
                        }
                    } else {
                        print("❌ 请求失败，respCode: \(response.respCode)")
                    }
                    self.noticeText = response.respMsg ?? ""
                    
                } catch {
                    print("❌ 获取用户信息失败")
                    print("❌ 错误类型: \(type(of: error))")
                    print("❌ 错误信息: \(error.localizedDescription)")
                    print("❌ 错误详情: \(error)")
                }
            }
        }
    }
    
}

class OTOLoginStatusManager {
    static let shared = OTOLoginStatusManager()

    private(set) var isLoggedIn: Bool = false

    private init() {
        // 迁移：将旧版 UserDefaults 中的 Token 迁移到 Keychain
        migrateTokenToKeychainIfNeeded()
        updateLoginStatus()
    }

    /// 迁移旧版 Token 从 UserDefaults 到 Keychain（仅执行一次）
    private func migrateTokenToKeychainIfNeeded() {
        let migrationKey = "tokenMigratedToKeychain"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        // 检查 UserDefaults 中是否有旧 Token
        if let oldToken = UserDefaults.standard.string(forKey: loginTokenKey) {
            // 迁移到 Keychain
            KeychainService.shared.save(oldToken, forKey: KeychainService.Keys.loginToken)
            // 清除 UserDefaults 中的旧 Token
            UserDefaults.standard.removeObject(forKey: loginTokenKey)
        }
        // 标记迁移完成
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    func updateLoginStatus() {
        isLoggedIn = KeychainService.shared.exists(forKey: KeychainService.Keys.loginToken)
    }

    func logout() {
        KeychainService.shared.delete(forKey: KeychainService.Keys.loginToken)
        UserDefaults.standard.removeObject(forKey: "userId")
        updateLoginStatus()
    }

    func login(token: String) {
        KeychainService.shared.save(token, forKey: KeychainService.Keys.loginToken)
        updateLoginStatus()
    }

    func getLoginStatus() -> Bool {
        return isLoggedIn
    }

    func getToken() -> String? {
        return KeychainService.shared.getString(forKey: KeychainService.Keys.loginToken)
    }

    func getUserID() -> Int {
        return UserDefaults.standard.integer(forKey: "userId")
    }

    func setUserID(_ userId: Int) {
        UserDefaults.standard.set(userId, forKey: "userId")
    }
}


#if DEBUG
extension OTOLoginStatusManager {
    /// 预览模式覆盖：返回一个看起来“已登录”的状态
    func __overrideForPreview(userId: Int = 11) {
        // 关键：对外暴露的 userId/getUserId() 必须返回非 0
        self.__previewUserId = userId
    }

    /// 内部预览态 UserID（仅 DEBUG 内存可见，不落盘）
    private struct __Holder { static var id: Int = 0 }
    private var __previewUserId: Int {
        get { __Holder.id }
        set { __Holder.id = newValue }
    }

    /// 在 getUserId() 或 public userId 访问点附近，加一个 DEBUG 下的“优先返回预览ID”的分支
    func __effectiveUserIdForPreview() -> Int {
        if __previewUserId != 0 { return __previewUserId }
        return self.getUserID()
    }
}
#endif

