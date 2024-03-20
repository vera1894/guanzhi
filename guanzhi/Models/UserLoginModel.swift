//
//  UserLoginModel.swift
//  guanzhi
//
//  Created by Vera on 2024/3/20.
//

import Foundation

fileprivate let loginTokenKey = "loginTokenKey"

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
    @Published var userName: String = ""   // 代号
    @Published var nickName: String = ""   // 昵称
    @Published var loginState: Int = 1     // 注册状态，1未注册 0已注册
    @Published var header: String = ""     // 令牌
    @Published var time : Int = 0 //短信等待时长
    @Published var firstSendMessage: Bool = false //是否已从首页发送验证码
    
    @Published var noticeText: String = "" //提示文字
    @Published var codePassed: Bool = false //代号是否通过验证
    @Published var namePassed : Bool = false //名字是否通过验证

    
    @Published var sendStatus: Bool = false //是否发送成功
    
    func sendCode(phNumber:String){
        DispatchQueue.main.async {
            Task {
                guard let data = try? await OTONetwork.request(.SendVerifiedCode(phoneNumber: phNumber)) else {
                    return
                }
                print(data)
                do {
                    let decoder = JSONDecoder()
                    if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []) {
                        let response = try decoder.decode(OTOResponseModel.self, from: jsonData)
                        if response.respCode == 0 {
                            print("请求成功")
                            self.sendStatus = true
                        }
                        
                        self.noticeText = response.respMsg ?? ""
                        
                    }
                } catch {
                    print("Error decoding JSON: \(error)")
                }
            }
        }
    }
    
    //验证代号
    func checkUserName(name:String){
        print("code:",name)
        if !ValidateEnum.codeName(name).isRight{
            print(ValidateEnum.codeName(name).isRight)
            self.noticeText = "代号由6-20位字母、数字、下划线或减号组合而成"
        }else{
            DispatchQueue.main.async {
                Task{
                    guard let data = try? await OTONetwork.request(.checkName(name: name)) else {
                        return
                    }
                    do {
                        let decoder = JSONDecoder()
                        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []) {
                            let response = try decoder.decode(OTOResponseModel.self, from: jsonData)
                            if response.respCode == 0{
                                self.codePassed = true
                                print("代号验证成功")
                            }else{
                                self.noticeText = response.respMsg ?? ""
                            }
                        }
                    }
                    catch {
                        print("Error decoding JSON: \(error)")
                    }
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
                        guard let data = try? await OTONetwork.request(.Register(phoneNumber: self.phone, code: self.code, nickName: self.nickName, userName: self.userName)) else { return }
                        print("注册结果", data)
                        
                        do {
                            let decoder = JSONDecoder()
                            if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []) {
                                let registerResponse = try decoder.decode(OTOResponseModel.self, from: jsonData)
                                if registerResponse.respCode == 0 {
                                    print("注册成功")
                                    self.namePassed = true
                                    if let string = registerResponse.datas {
                                        self.header = "Bearer " + string
                                        print("注册令牌：", self.header)
                                    }
                                }else{
                                    self.noticeText = registerResponse.respMsg ?? ""
                                }
                            }
                        } catch {
                            print("解析错误: \(error)")
                        }
                    }
                }
            }
        }



    }
    
}

class OTOLoginStatusManager {
    static let shared = OTOLoginStatusManager()
    
    private(set) var isLoggedIn: Bool = false

    //一个UserLoginModel类的属性，懒加载的形式来加载
    lazy var userLogin = UserLoginModel()
    
    lazy var vm = MessageinputViewModel()

    private init() {
        updateLoginStatus()
    }

    func updateLoginStatus() {
        if let _ = UserDefaults.standard.string(forKey: loginTokenKey) {
            isLoggedIn = true
        } else {
            isLoggedIn = false
        }
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: loginTokenKey)
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
}

