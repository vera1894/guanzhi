//
//  PostUIView.swift
//  guanzhi
//
//  Created by Vera on 2024/5/26.
//

import SwiftUI
import Foundation
import Alamofire

struct PostUIView/*<AppStateModel: AppState>*/: View {
//    @State var appState: AppStateModel
    @Bindable var appState: AppStateModel
    var image: UIImage? = UIImage(named: "IMG-1")
    @State private var thinking: String = ""
//    @Binding var cardName : String
  //  @ObservedObject var userlogin : UserLoginModel
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    

        var body: some View {
            ZStack{
               // Color("text-deepgray").ignoresSafeArea()
                VStack {
                    Spacer()
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Text("没有图片")
                    }
                    Spacer()
                    Text("📍" + appState.resultLocationName)
                       // .foregroundColor(Color("text-white"))
                    Divider().foregroundColor(Color("text-white"))
                    TextField("分享一下想法吧", text: $thinking)
                        .foregroundColor(Color("text-white"))
                    Button(action: {
                                // 发布-胶囊按钮fill
                       // requestForImage(image!){data in
                         //   print(data)}
                            uploadImage(image!){result in
                                switch result {
                                    case .success(let uploadResponse):
                                        print("Upload successful.")
                                        // 处理成功的响应
                                        print(uploadResponse)  // 打印上传响应的内容
                                    print(uploadResponse.datas)
                                    if let imagePath = uploadResponse.datas{
//                                        shareInsert(address: appState.resultLocationName, cityCode: 0, data: thinking, deleted: 0, districtCode: 0, imagePath: imagePath, latitude: 0, longitude: 0, provinceCode: 0, title: "")
                                        self.presentationMode.wrappedValue.dismiss()  //关闭当前视图
                                        print("发布结果")
                                    }
                                    case .failure(let error):
                                    print("Upload failed with error: \(error.localizedDescription)")
                                            if let decodingError = error as? DecodingError {
                                                // 打印解码错误信息
                                                switch decodingError {
                                                case .dataCorrupted(let context):
                                                    print("Data corrupted: \(context)")
                                                case .keyNotFound(let key, let context):
                                                    print("Key not found: \(key), \(context)")
                                                case .typeMismatch(let type, let context):
                                                    print("Type mismatch: \(type), \(context)")
                                                case .valueNotFound(let value, let context):
                                                    print("Value not found: \(value), \(context)")
                                                @unknown default:
                                                    print("Unknown decoding error")
                                                }
                                            } else {
                                                // 其他类型的错误处理
                                                print("Other error occurred: \(error)")
                                            }
                                    }
                            }
                        
                            }) {
                                Text("✅ 发布")
                            }
                        .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: true))
                    
                }
                .padding()
            }
           
            .navigationBarTitle("发布内容")
           //
        }
    
    struct UploadResponse: Codable {
        // Define the structure of the JSON response
        // based on your server's API response
        // For example, if your response is a simple JSON object like {"status": "success"},
        // you can define a corresponding struct like:
        // let status: String
        let datas: String?
        let respCode: Int
        let respMsg:String?
        
        
    }
    
    func uploadImage(_ image: UIImage, completion: @escaping (Result<UploadResponse, Error>) -> Void){
        if let url = URL(string: "\(Constants.BASE_HOST)/api/guan/uploadImage") {
            // 将照片转换为JPEG
                guard let jpegData = image.jpegData(compressionQuality: 0.5) else {
                    print("Failed to convert image to JPEG")
                    return
                }
            
            // 创建请求头部
                let headers: HTTPHeaders = [
                    "Content-Type": "multipart/form-data",
                    "Authorization": OTOLoginStatusManager.shared.getToken()!
                ]
            
            // 创建请求体
                let formData = MultipartFormData()
            
            formData.append(jpegData, withName: "multipartFile", fileName: "image.jpg", mimeType: "image/jpeg")
            
            // 发送POST请求
            AF.upload(multipartFormData:formData, to: url,method: .post,headers:headers).responseDecodable(of: UploadResponse.self) { response in
                // Handle the response
                switch response.result {
                    
                case .success(let uploadResponse):
                    completion(.success(uploadResponse))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            
        }
    }
    
//    func shareInsert(address: String, cityCode: Int?, data: String, deleted:Int?, districtCode: Int?, imagePath: String, latitude: Double, longitude: Double, provinceCode: Int?, title: String){
//        DispatchQueue.main.async {
//            Task {
//                guard let data = try? await OTONetwork.request(.insertShare(address: address, cityCode: cityCode, data: data, deleted: deleted, districtCode: districtCode, imagePath: imagePath, latitude: latitude, longitude: longitude, provinceCode: provinceCode, title: title)) else {
//                    return
//                }
//                print(data)
//                do {
//                    let decoder = JSONDecoder()
//                    if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []) {
//                        let response = try decoder.decode(OTOResponseModel.self, from: jsonData)
//                        if response.respCode == 0 {
//                            print("发布分享成功")
//                            print(response.respMsg)
//                            
//                        }
//                        
//                        //self.noticeText = response.respMsg ?? ""
//                        
//                    }
//                } catch {
//                    print("Error decoding JSON: \(error)")
//                }
//            }
//        }
//    }
    
    func requestForImage(_ image: UIImage, completion: @escaping (Result<Data, Error>) -> Void) {
        
        do {
            // 创建要上传的图片数据
            guard let imageData = image.jpegData(compressionQuality: 0.5) else {  completion(.failure(NSError(domain: "com.example.app", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
                return}
            print("imagedata::",imageData)
            
            
            // 创建 URLComponents 并设置 URL
            if let url = URL(string: "\(Constants.BASE_HOST)/api/guan/uploadImage") {
                
                
                //body信息
                let boundary = UUID().uuidString
                var body = Data()
                
                body.appendString("--\(boundary)\r\n")
                body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n")
                body.appendString("Content-Type:image/jpeg\r\n\r\n")
                body.append(imageData)
                body.appendString("\r\n--\(boundary)--\r\n")
                
                // 创建 URLRequest
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                request.setValue(OTOLoginStatusManager.shared.getToken(), forHTTPHeaderField: "Authorization")
//                if OTOLoginStatusManager.shared.isLoggedIn, let token = OTOLoginStatusManager.shared.getToken() {
//                    request.setValue(token, forHTTPHeaderField: "Authorization")
//                }
                
                request.httpBody = body
                
                let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        let statusCode = httpResponse.statusCode
                        print(statusCode)
                        // 处理状态码和其他响应信息
                        // ...
                    }
                    
                    if let data = data{
                        do {
                                let json = try JSONSerialization.jsonObject(with: data, options: [])
                                // 在这里处理解析后的 JSON 数据
                                print(json)
                            } catch {
                                print("Error parsing JSON: \(error)")
                            }
                    }
                    
                    
                }

                    task.resume()
            }
              
        }
    }
}

//#Preview {
//    PostUIView(cardName: .constant("dd"))
//}
    extension Data {
        mutating func appendString(_ string: String) {
            if let data = string.data(using: .utf8) {
                append(data)
            }
        }
    }
