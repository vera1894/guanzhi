/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that displays controls to capture, switch cameras, and view the last captured media item.
*/

import SwiftUI
import PhotosUI
import Foundation
import Alamofire
import MapKit

/// A view that displays controls to capture, switch cameras, and view the last captured media item. 一个视图，显示用于捕获、切换相机和查看最近捕获的媒体项的控件。
struct MainToolbar<CameraModel: Camera, AppStateModel: AppState>: PlatformView {

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State var camera: CameraModel
    @State var appState: AppStateModel
    @State private var textFieldPlaceholder: String = "分享一下想法吧"
    @State private var locatedPosition : CLLocationCoordinate2D?
    @State private var locatedPositionName : String = ""
    @State private var isLocationAvailable = false
    @State private var nextPage: Bool = false //
        
    var cameraMainHeight: CGFloat = 180
    
    func getUserLocation() {
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
        
        DispatchQueue.global().async {
            if CLLocationManager.locationServicesEnabled() {
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
                locationManager.startUpdatingLocation()
                
                if let location = locationManager.location?.coordinate {
                    getAddressFromLocation(for: location) { String in
                        if let address = String{
                            locatedPositionName = address
                            isLocationAvailable = true
                            print("cardname:",appState.resultLocationName)
                        }
                    }
                    _ = MKCoordinateRegion(center: location, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                    withAnimation(Animation.spring()) {
                        locatedPosition = location
                        
                                        }
                    print("经纬度",location.latitude,location.longitude)
                }
            }
        }
    }
    
    //根据地址翻译地名
    private func getAddressFromLocation(for location:CLLocationCoordinate2D?,completion:@escaping(String?)->Void){
        if let location = location{
            let location = CLLocation(latitude: location.latitude, longitude: location.longitude)
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                if let error = error{
                    print("定位错误：\(error.localizedDescription)")
                    
                }else if let placemark = placemarks?.first{
                    let address = "\(placemark.name ?? "")\(placemark.locality ?? "")\(placemark.administrativeArea ?? "")\(placemark.country ?? "")"
                    print("地址：",address)
                    completion(address)
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.clear // 最底层放置的收起键盘透明背景
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.endEditing()
                    print("点击底层")
                }
            
            VStack {
                HStack {
                    PhotosPreview(camera: camera, appState: appState)
                        .frame(height: 60)
    //                    .background(Color.blue)
                }
                Spacer()
                
                if appState.isReadyToPost == true { //改改改改改改改改改改改改
                    VStack(spacing: 16) {
                        HStack {
                            Text("📍" + (isLocationAvailable ? locatedPositionName : "地点获取中..."))
                                .bold()
                            Spacer()
                        }
                        
                        RoundedRectangleTextField(placeholder: $textFieldPlaceholder, inputText: $appState.postText)
                            .frame(maxHeight: .infinity)
                        
                        HStack{
                            Button(action: {
                                        // 返回（白色）-胶囊按钮hug
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    appState.isReadyToPost = false
                                }
                                    }) {
                                        Text("🔙️ 返回")
                                    }
                                .buttonStyle(ButtonStyle_capsuleHugLeft(isEnabled: true))
                            
                                Button(action: {
                                        // 下一步（禁用）-胶囊按钮fill
                                        // 发布完成关闭页面，发布失败留在页面，发布时显示loading
                                    // 获取所有图片
                                    if isLocationAvailable == true {
                                                    // 执行下一步操作
                                        appState.isLoading = true
                                        
                                        let photos = camera.capturedMedia.compactMap { $0 as? Photo }

                                        // 上传所有 Photo 对象
                                        uploadImages(photos) { result in
                                            switch result {
                                            case .success(let imagePath):
                                                // 注意这里将 combinedImagePaths 改为 imagePath
                                                shareInsert(
                                                    address: locatedPositionName,
                                                    cityCode: nil,
                                                    data: appState.postText,
                                                    deleted: nil,
                                                    districtCode: nil,
                                                    imagePath: imagePath,  // 使用成功回调中的 imagePath
                                                    latitude: locatedPosition?.latitude ?? 0.0,
                                                    longitude: locatedPosition?.longitude ?? 0.0,
                                                    provinceCode: nil,
                                                    title: "标题"
                                                )
                                                appState.isReadyToPost = false
                                                appState.isShowingCameraView = false
                                                appState.isShowingSearchView = true
                                                appState.isPushedGuanzhi = true
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                    appState.isLoading = false
                                                }
                                            case .failure(let error):
                                                print("Failed to upload images: \(error)")
                                            }
                                        }
                                        
                                                } else {
                                                    // 显示错误消息或提醒用户等待
                                                    print("请先获取位置")
                                                }
                                    
                                    
                                    
                                        }) {
                                            Text("🔜 下一步")
                                        }
                                    .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: appState.postText.count != 0))
                                    .disabled(!(appState.postText.count != 0))
                                    .navigationDestination(isPresented: $nextPage) {
                                        
                                    }
                            }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    
                } else {
                    ZStack {
        //                ThumbnailButton(camera: camera)
                        Spacer()
                        
                        if camera.selectedMedia.firstIndex(of: true) != nil {
                            DeleteButton(camera: camera)
                        } else {
                            CaptureButton(camera: camera, appState: appState)
                                .disabled(camera.capturedMedia.count>3)
                                .opacity((camera.capturedMedia.count>3) ? 0.3 : 1)
            //                    .background(Color.red)  //height 68
                        }
                        
                        HStack {
                            Spacer()
                            
                            if camera.selectedMedia.firstIndex(of: true) != nil {
                            } else {
                                Button(action: {
                                            // 下一步-胶囊按钮hug
                                    appState.isReadyToPost = true
                                        }) {
                                            Text("🔜 下一步")
                                        }
                                        .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: (camera.capturedMedia.first != nil)))
                                    .padding(16)
                            }
                        }
        //                SwitchCameraButton(camera: camera) //修改并放置到上方
                    }
                    .padding(.bottom, 32)
                }
            }
            
            if (appState.isLoading || camera.captureboxIsLoading) {
                ProcessingView()
            }
        }
            .frame(maxHeight: appState.isReadyToPost ? .infinity : cameraMainHeight)  //改改改改改改改改改改改改改
            .frame(maxWidth: .infinity)
    //        .background(Color.gray) //
        .foregroundColor(.white)
        .onAppear {
                getUserLocation()
            }
        
//        .font(.system(size: 24))
//        .padding([.leading, .trailing])
    }
    // 根据设备尺寸类别确定工具栏的宽度。
    var width: CGFloat? { isRegularSize ? 250 : nil }
    // 设置工具栏的固定高度。
    var height: CGFloat? { 80 }
    
    struct UploadResponse: Codable {
        // Define the structure of the JSON response
        // based on your server's API response
        // For example, if your response is a simple JSON object like {"status": "success"},
        // you can define a corresponding struct like:
        // let status: String
        let datas: String?
        let respCode: Int
        let respMsg:String
    }
    
    func generateUniqueFileName() -> String {
        let userId = OTOLoginStatusManager.shared.getUserID()  // 替换为用户的实际 ID
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))  // 13位时间戳
        let randomNumber = String(format: "%05d", Int(arc4random_uniform(100000)))  // 5位随机数
        return "\(userId)_\(timestamp)_\(randomNumber)"
    }
    
    func uploadImages(_ photos: [Photo], completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(Constants.BASE_HOST)/api/guan/uploadImage") else {
            print("Invalid URL")
            return
        }

        let headers: HTTPHeaders = [
            "Content-Type": "multipart/form-data",
            "Authorization": OTOLoginStatusManager.shared.getToken()!
        ]

        var imagePaths: [String] = []
        var uploadIndex = 0

        func uploadNextPhoto() {
            guard uploadIndex < photos.count else {
                // 所有图片上传完成，拼接路径
                let combinedPaths = imagePaths.joined(separator: ",")
                completion(.success(combinedPaths))
                print("Combined image paths: \(combinedPaths)")
                return
            }

            let photo = photos[uploadIndex]
            let uniqueFileName = generateUniqueFileName()  // 使用自定义的命名方式

            // 上传静态照片
            func uploadFile(data: Data, fileName: String, mimeType: String) {
                let formData = MultipartFormData()
                formData.append(data, withName: "multipartFile", fileName: fileName, mimeType: mimeType)
                
                print("Starting upload for \(fileName)...")

                AF.upload(multipartFormData: formData, to: url, method: .post, headers: headers).responseDecodable(of: UploadResponse.self) { response in
                    switch response.result {
                    case .success(let uploadResponse):
                        print("Response JSON: \(uploadResponse)")

                        if let imagePath = uploadResponse.datas {
                            imagePaths.append(imagePath)
                            print("Uploaded \(fileName): \(imagePath)")
                        } else {
                            print("No image path returned in response")
                            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image path returned"])))
                            return
                        }
                        uploadIndex += 1
                        uploadNextPhoto()  // 递归上传下一个文件
                    case .failure(let error):
                        completion(.failure(error))
                        print("Failed to upload \(fileName): \(error)")
                    }
                }
            }

            // 上传静态图片
            uploadFile(data: photo.data, fileName: "\(uniqueFileName)_photo.jpg", mimeType: "image/jpeg")

            // 如果存在 Live Photo 视频，单独上传
            if let livePhotoURL = photo.livePhotoMovieURL {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: livePhotoURL.path) {
                    do {
                        let videoData = try Data(contentsOf: livePhotoURL)
                        uploadFile(data: videoData, fileName: "\(uniqueFileName)_video.mov", mimeType: "video/quicktime")
                    } catch {
                        print("Failed to read live photo video data: \(error)")
                        completion(.failure(error))
                    }
                } else {
                    print("Live Photo video file does not exist at path: \(livePhotoURL.path)")
                }
            }
        }
        uploadNextPhoto()  // 开始上传第一个文件
    }
    
//    func uploadImages(_ photos: [Photo], completion: @escaping (Result<String, Error>) -> Void) {
//        guard let url = URL(string: "\(Constants.BASE_HOST)/api/guan/uploadImage") else {
//            print("Invalid URL")
//            return
//        }
//
//        let headers: HTTPHeaders = [
//            "Content-Type": "multipart/form-data",
//            "Authorization": OTOLoginStatusManager.shared.getToken()!
//        ]
//
//        var imagePaths: [String] = []
//        var uploadIndex = 0
//
//        func uploadNextPhoto() {
//            guard uploadIndex < photos.count else {
//                // 所有图片上传完成，拼接路径
//                let combinedPaths = imagePaths.joined(separator: ",")
//                completion(.success(combinedPaths))
//                print("Combined image paths: \(combinedPaths)")
//                return
//            }
//
//            let photo = photos[uploadIndex]
//            let photoUUID = UUID().uuidString  // 为每个 Live Photo 生成唯一的 UUID
//
//            // 上传静态照片
//            func uploadFile(data: Data, fileName: String, mimeType: String) {
//                let formData = MultipartFormData()
//                formData.append(data, withName: "multipartFile", fileName: fileName, mimeType: mimeType)
//                
//                print("Starting upload for \(fileName)...")
//
//                AF.upload(multipartFormData: formData, to: url, method: .post, headers: headers).responseDecodable(of: UploadResponse.self) { response in
//                    switch response.result {
//                    case .success(let uploadResponse):
//                        print("Response JSON: \(uploadResponse)")
//
//                        if let imagePath = uploadResponse.datas {
//                            imagePaths.append(imagePath)
//                            print("Uploaded \(fileName): \(imagePath)")
//                        } else {
//                            print("No image path returned in response")
//                            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image path returned"])))
//                            return
//                        }
//                        uploadIndex += 1
//                        uploadNextPhoto()  // 递归上传下一个文件
//                    case .failure(let error):
//                        completion(.failure(error))
//                        print("Failed to upload \(fileName): \(error)")
//                    }
//                }
//            }
//
//            // 上传静态图片
//            uploadFile(data: photo.data, fileName: "\(photoUUID)_photo.jpg", mimeType: "image/jpeg")
//
//            // 如果存在 Live Photo 视频，单独上传
//            if let livePhotoURL = photo.livePhotoMovieURL {
//                let fileManager = FileManager.default
//                if fileManager.fileExists(atPath: livePhotoURL.path) {
//                    do {
//                        let videoData = try Data(contentsOf: livePhotoURL)
//                        uploadFile(data: videoData, fileName: "\(photoUUID)_video.mov", mimeType: "video/quicktime")
//                    } catch {
//                        print("Failed to read live photo video data: \(error)")
//                        completion(.failure(error))
//                    }
//                } else {
//                    print("Live Photo video file does not exist at path: \(livePhotoURL.path)")
//                }
//            }
//        }
//        uploadNextPhoto()  // 开始上传第一个文件
//    }
    
    
    
//    func uploadImages(_ images: [UIImage], completion: @escaping (Result<String, Error>) -> Void) {
//        guard let url = URL(string: "\(Constants.BASE_HOST)/api/guan/uploadImage") else {
//            print("Invalid URL")
//            return
//        }
//
//        let headers: HTTPHeaders = [
//            "Content-Type": "multipart/form-data",
//            "Authorization": OTOLoginStatusManager.shared.getToken()!
//        ]
//
//        var imagePaths: [String] = []
//        var uploadIndex = 0
//
//        func uploadNextImage() {
//            guard uploadIndex < images.count else {
//                // 所有图片上传完成，拼接路径
//                let combinedPaths = imagePaths.joined(separator: ",")
//                completion(.success(combinedPaths))
//                print("Combined image paths: \(combinedPaths)")
//                return
//            }
//
//            let image = images[uploadIndex]
//            guard let jpegData = image.jpegData(compressionQuality: 0.5) else {
//                print("Failed to convert image to JPEG")
//                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])))
//                return
//            }
//
//            let formData = MultipartFormData()
//            formData.append(jpegData, withName: "multipartFile", fileName: "image.jpg", mimeType: "image/jpeg")
//            print("Starting upload for image \(uploadIndex + 1)...")
//
//            AF.upload(multipartFormData: formData, to: url, method: .post, headers: headers).responseDecodable(of: UploadResponse.self) { response in
//                switch response.result {
//                case .success(let uploadResponse):
//                    print("Response JSON: \(uploadResponse)")
//                    
//                    if let imagePath = uploadResponse.datas {
//                        imagePaths.append(imagePath)
//                        print("Uploaded image \(uploadIndex + 1): \(imagePath)")
//                    } else {
//                        print("No image path returned in response")
//                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image path returned"])))
//                        return
//                    }
//                    uploadIndex += 1
//                    uploadNextImage()  // 递归调用，上传下一张图片
//                case .failure(let error):
//                    completion(.failure(error))
//                    print("Failed to upload image \(uploadIndex + 1): \(error)")
//                }
//            }
//        }
//        uploadNextImage()  // 开始上传第一张图片
//    }
    
    
    func shareInsert(address: String, cityCode: Int?, data: String, deleted: Int?, districtCode: Int?, imagePath: String, latitude: Double, longitude: Double, provinceCode: Int?, title: String) {
        DispatchQueue.main.async {
            Task {
                do {
                    // 使用 try 来捕获网络请求错误
                    let responseData = try await OTONetwork.request(.InsertDoodle(address: address, cityCode: cityCode, data: data, deleted: deleted, districtCode: districtCode, imagePath: imagePath, latitude: latitude, longitude: longitude, provinceCode: provinceCode, title: title))

                    // 确保 responseData 是有效的 JSON 数据
                    let decoder = JSONDecoder()
                    if let jsonData = try? JSONSerialization.data(withJSONObject: responseData, options: []) {
                        let response = try decoder.decode(OTOResponseModel.self, from: jsonData)
                        
                        if response.respCode == 0 {
                            print("发布分享成功: \(imagePath)")
                        } else {
                            print("Failed to publish: \(String(describing: response.respMsg))")
                        }
                    } else {
                        print("Failed to serialize response data.")
                    }

                } catch {
                    // 捕获网络请求或其他错误
                    print("Error sending request: \(error)")
                }
            }
        }
    }
    
//    func shareInsert(address: String, cityCode: Int?, data: String, deleted: Int?, districtCode: Int?, imagePath: String, latitude: Double, longitude: Double, provinceCode: Int?, title: String) {
//        DispatchQueue.main.async {
//            Task {
//                // 直接使用拼合的 imagePath 字符串
//                guard let responseData = try? await OTONetwork.request(.InsertDoodle(address: address, cityCode: cityCode, data: data, deleted: deleted, districtCode: districtCode, imagePath: imagePath, latitude: latitude, longitude: longitude, provinceCode: provinceCode, title: title)) else {
//                    print("Failed to send request.")
//                    return
//                }
//                
//                do {
//                    let decoder = JSONDecoder()
//                    if let jsonData = try? JSONSerialization.data(withJSONObject: responseData, options: []) {
//                        let response = try decoder.decode(OTOResponseModel.self, from: jsonData)
//                        if response.respCode == 0 {
//                            print("发布分享成功: \(imagePath)")
//                        } else {
//                            print("Failed to publish: \(String(describing: response.respMsg))")
//                        }
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

#Preview {
    Group {
        MainToolbar(camera: PreviewCameraModel(), appState: AppStateModel())
            .background(Color.blue)
    }
}

//extension Data {
//    mutating func appendString(_ string: String) {
//        if let data = string.data(using: .utf8) {
//            append(data)
//        }
//    }
//}
