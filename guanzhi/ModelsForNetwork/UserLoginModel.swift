//
//  UserLoginModel.swift
//  guanzhi
//
//  Created by Vera on 2024/3/20.
//

import Foundation
//import KeychainAccess

fileprivate let loginTokenKey = "loginTokenKey"

struct EmptyData: Codable {}

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
                    guard let data = try? await OTONetwork.request(.SendVerifiedCode(phoneNumber: phNumber)) else {
                        return
                    }
                    print(data)
                    do {
                        let decoder = JSONDecoder()
                        let response = try decoder.decode(OTOResponseModel<EmptyData>.self, from: data)
                        
                        if response.respCode == 0 {
                            print("请求成功")
                            self.sendStatus = true
                        }
                        self.noticeText = response.respMsg ?? ""
                    } catch {
                        print("Error decoding JSON: \(error)")
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
                            guard let data = try? await OTONetwork.request(.Register(phoneNumber: self.phone, nickName: self.nickName)) else { return }
                            print("注册结果", data)
                            
                            do {
                                let decoder = JSONDecoder()
                                let response = try decoder.decode(OTOResponseModel<String>.self, from: data)
                                if response.respCode == 0 {
                                    print("注册成功")
                                    self.namePassed = true
                                    if let tokenString = response.datas {
                                        self.header = "Bearer " + tokenString
                                        print("注册令牌：", self.header)
                                        OTOLoginStatusManager.shared.login(token: self.header)
                                        // 获取用户信息，保存用户ID
                                        self.getUserInfo()
                                    } else {
                                        print("datas 不是一个字符串")
                                    }
                                } else {
                                    self.noticeText = response.respMsg ?? ""
                                }
                            } catch {
                                print("解析错误: \(error)")
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
                guard let data = try? await OTONetwork.request(.userInfo) else {
                    return
                }
                print(data)
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(OTOResponseModel<dataModel>.self, from: data)
                    if response.respCode == 0 {
                        if let datas = response.datas {
                            self.userName = datas.nickname ?? "用户"
                            self.userId = datas.id ?? -1
                            print("请求成功")
                            print("获取userId", self.userId)
                            
                            // 保存用户ID到 OTOLoginStatusManager
                            OTOLoginStatusManager.shared.setUserID(self.userId)
                        }
                    }
                    self.noticeText = response.respMsg ?? ""
                    
                } catch {
                    print("Error decoding JSON: \(error)")
                }
            }
        }
    }
    
}

class OTOLoginStatusManager {
    static let shared = OTOLoginStatusManager()
    
    private(set) var isLoggedIn: Bool = false

    private init() {
        updateLoginStatus()
    }

    func updateLoginStatus() {
        if let _ = UserDefaults.standard.string(forKey: loginTokenKey) {
            isLoggedIn = true
            print("isLoggedIn: 已登录")
        } else {
            isLoggedIn = false
        }
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: loginTokenKey)
        UserDefaults.standard.removeObject(forKey: "userId")  // 移除用户ID
        updateLoginStatus()
    }

    func login(token: String) {
        UserDefaults.standard.set(token, forKey: loginTokenKey)
        updateLoginStatus()
    }
    
    func getLoginStatus() -> Bool {
        return isLoggedIn
    }

    func getToken() -> String? {
        return UserDefaults.standard.string(forKey: loginTokenKey)
    }
    
    func getUserID() -> Int {
        return UserDefaults.standard.integer(forKey: "userId")
    }
    
    func setUserID(_ userId: Int) {
        UserDefaults.standard.set(userId, forKey: "userId")
    }
}

