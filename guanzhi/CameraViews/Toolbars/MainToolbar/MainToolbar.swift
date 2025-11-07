/*
See the LICENSE.txt file for this sample's licensing information.

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
                    // 使用修改后的 getAddressFromLocation 方法
                    getAddressFromLocation(for: location) { address in
                        if let address = address {
                            DispatchQueue.main.async {
                                locatedPositionName = address
                                isLocationAvailable = true
                                print("cardname:", locatedPositionName)
                            }
                        }
                    }
                    
                    // 更新位置信息
                    DispatchQueue.main.async {
                        withAnimation(Animation.spring()) {
                            locatedPosition = location
                        }
                        print("经纬度", location.latitude, location.longitude)
                    }
                }
            }
        }
    }
    
    // 根据坐标获取地址
    func getAddressFromLocation(for location: CLLocationCoordinate2D?, completion: @escaping (String?) -> Void) {
        guard let coordinate = location else {
            completion(nil)
            return
        }
        
        let converter = CoordinateConverter.shared
        var adjustedCoordinate = coordinate
        
        // 判断位置是否在中国大陆境内
        if !converter.isOutOfChina(coordinate) {
            // 在中国大陆境内，需要将 WGS-84 坐标转换为 GCJ-02 坐标
            adjustedCoordinate = converter.wgs84ToGcj02(coordinate)
        }
        
        let location = CLLocation(latitude: adjustedCoordinate.latitude, longitude: adjustedCoordinate.longitude)
        
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("定位错误：\(error.localizedDescription)")
                completion(nil)
            } else if let placemark = placemarks?.first {
                // 根据需要从 placemark 中获取地址信息
                let address = "\(placemark.name ?? "") \(placemark.locality ?? "") \(placemark.administrativeArea ?? "") \(placemark.country ?? "")"
                print("地址：", address)
                completion(address)
            } else {
                completion(nil)
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
                
                if appState.isReadyToPost == true { //改改改改改改改改改改改改改
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
                                                // 所有文件上传成功，调用分享发布方法
                                                shareInsert(
                                                    address: locatedPositionName,
                                                    cityCode: nil,
                                                    data: appState.postText,
                                                    deleted: nil,
                                                    districtCode: nil,
                                                    imagePath: imagePath,
                                                    latitude: locatedPosition?.latitude ?? 0.0,
                                                    longitude: locatedPosition?.longitude ?? 0.0,
                                                    provinceCode: nil,
                                                    title: "标题"
                                                )
                                                // 更新状态
                                                appState.isReadyToPost = false
                                                appState.isShowingCameraView = false
                                                appState.isShowingSearchView = true
                                                appState.isPushedGuanzhi = true
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                    appState.isLoading = false
                                                }
                                            case .failure(let error):
                                                // 上传失败，已在前面的代码中处理，无需在这里重复处理
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
        let userId = OTOLoginStatusManager.shared.getUserID()
        print("用户ID", userId)
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

        // 如果不需要排序，直接使用photos数组
        let sortedPhotos = photos

        // 用于存储首个媒体文件的唯一文件名前缀，以便后续生成缩略图
        var firstMediaUniqueFileNamePrefix: String?

        func uploadNextPhoto() {
            guard uploadIndex < sortedPhotos.count else {
                // 所有图片上传完成，开始上传缩略图
                if let firstMediaPrefix = firstMediaUniqueFileNamePrefix {
                    // 生成并上传缩略图
                    generateAndUploadThumbnail(prefix: firstMediaPrefix) {
                        // 所有文件上传完成，拼接路径
                        let combinedPaths = imagePaths.joined(separator: ",")
                        completion(.success(combinedPaths))
                        print("Combined image paths: \(combinedPaths)")
                    }
                } else {
                    // 没有媒体文件，无需上传缩略图
                    let combinedPaths = imagePaths.joined(separator: ",")
                    completion(.success(combinedPaths))
                    print("Combined image paths: \(combinedPaths)")
                }
                return
            }

            let photo = sortedPhotos[uploadIndex]
            let uniqueFileName = generateUniqueFileName()

            // 如果这是第一个媒体文件，记录其前缀
            if uploadIndex == 0 {
                firstMediaUniqueFileNamePrefix = uniqueFileName
            }

            let dispatchGroup = DispatchGroup()
            var uploadError: Error?

            // 上传静态图片
            dispatchGroup.enter()
            uploadFile(data: photo.data, fileName: "\(uniqueFileName)_photo.jpg", mimeType: "image/jpeg") { result in
                switch result {
                case .success(_):
                    dispatchGroup.leave()
                case .failure(let error):
                    uploadError = error
                    dispatchGroup.leave()
                }
            }

            // 如果存在 Live Photo 视频，单独上传
            if let livePhotoURL = photo.livePhotoMovieURL {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: livePhotoURL.path) {
                    do {
                        let videoData = try Data(contentsOf: livePhotoURL)
                        dispatchGroup.enter()
                        uploadFile(data: videoData, fileName: "\(uniqueFileName)_livephoto.mov", mimeType: "video/quicktime") { result in
                            switch result {
                            case .success(_):
                                dispatchGroup.leave()
                            case .failure(let error):
                                uploadError = error
                                dispatchGroup.leave()
                            }
                        }
                    } catch {
                        print("Failed to read live photo video data: \(error)")
                        completion(.failure(error))
                        return
                    }
                } else {
                    print("Live Photo video file does not exist at path: \(livePhotoURL.path)")
                }
            }

            dispatchGroup.notify(queue: .main) {
                if let error = uploadError {
                    // 上传失败，终止上传过程并通知用户
                    print("Upload failed with error: \(error.localizedDescription)")
                    appState.isLoading = false
                    showErrorToUser(message: "上传失败：\(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    // 当前 Photo 对象的所有文件上传完成，继续下一个
                    uploadIndex += 1
                    uploadNextPhoto()
                }
            }
        }

        func showErrorToUser(message: String) {
            DispatchQueue.main.async {
                appState.errorMessage = message
                appState.showErrorAlert = true
            }
        }
        
        let maxRetryCount = 3
        
        // 修改后的 uploadFile 方法，添加 completion 参数
        func uploadFile(data: Data, fileName: String, mimeType: String, retryCount: Int = 0, completion: @escaping (Result<String, Error>) -> Void) {
            let formData = MultipartFormData()
            formData.append(data, withName: "multipartFile", fileName: fileName, mimeType: mimeType)
            
            print("Starting upload for \(fileName)...")

            AF.upload(multipartFormData: formData, to: url, method: .post, headers: headers)
                .uploadProgress { progress in
                    // 可选：更新上传进度
                    DispatchQueue.main.async {
                        // 更新全局的上传进度，如果需要的话
                        appState.uploadProgress = progress.fractionCompleted
                    }
                }
                .responseDecodable(of: UploadResponse.self) { response in
                    switch response.result {
                    case .success(let uploadResponse):
                        print("Response JSON: \(uploadResponse)")

                        if let imagePath = uploadResponse.datas {
                            imagePaths.append(imagePath)
                            print("Uploaded \(fileName): \(imagePath)")
                            completion(.success(imagePath))
                        } else {
                            print("No image path returned in response")
                            let error = NSError(domain: "UploadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image path returned in response"])
                            completion(.failure(error))
                        }
                    case .failure(let error):
                        if retryCount < maxRetryCount {
                            print("Retrying upload for \(fileName), attempt \(retryCount + 1)")
                            // 等待一段时间后重试
                            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                                uploadFile(data: data, fileName: fileName, mimeType: mimeType, retryCount: retryCount + 1, completion: completion)
                            }
                        } else {
                            print("Failed to upload \(fileName) after \(maxRetryCount) attempts")
                            completion(.failure(error))
                        }
                    }
                }
        }

        // 生成并上传缩略图的方法
        func generateAndUploadThumbnail(prefix: String, completion: @escaping () -> Void) {
            // 找到首个媒体文件对应的Photo对象
            guard let firstPhoto = sortedPhotos.first else {
                completion()
                return
            }

            // 生成缩略图
            let thumbnailImage: UIImage?
            if let livePhotoURL = firstPhoto.livePhotoMovieURL {
                // 如果是Live Photo，从视频生成缩略图
                thumbnailImage = generateThumbnail(from: livePhotoURL)
            } else {
                // 否则，使用静态图片生成缩略图
                thumbnailImage = UIImage(data: firstPhoto.data)
            }

            guard let thumbnailData = thumbnailImage?.jpegData(compressionQuality: 0.5) else {
                print("Failed to generate thumbnail data")
                completion()
                return
            }

            // 上传缩略图
            let thumbnailFileName = "\(prefix)_thumbnail.jpg"
            let formData = MultipartFormData()
            formData.append(thumbnailData, withName: "multipartFile", fileName: thumbnailFileName, mimeType: "image/jpeg")

            print("Starting upload for \(thumbnailFileName)...")

            AF.upload(multipartFormData: formData, to: url, method: .post, headers: headers).responseDecodable(of: UploadResponse.self) { response in
                switch response.result {
                case .success(let uploadResponse):
                    print("Response JSON: \(uploadResponse)")

                    if let imagePath = uploadResponse.datas {
                        imagePaths.append(imagePath)
                        print("Uploaded \(thumbnailFileName): \(imagePath)")
                    } else {
                        print("No image path returned in response")
                    }
                    completion()
                case .failure(let error):
                    print("Failed to upload \(thumbnailFileName): \(error)")
                    completion()
                }
            }
        }

        // 生成缩略图的方法
        func generateThumbnail(from videoURL: URL) -> UIImage? {
            let asset = AVAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 1, preferredTimescale: 60)
            do {
                let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                return UIImage(cgImage: imageRef)
            } catch {
                print("Failed to generate thumbnail: \(error)")
                return nil
            }
        }

        uploadNextPhoto()  // 开始上传第一个文件
    }
    
    
    func shareInsert(address: String, cityCode: Int?, data: String, deleted: Int?, districtCode: Int?, imagePath: String, latitude: Double, longitude: Double, provinceCode: Int?, title: String) {
        DispatchQueue.main.async {
            Task {
                do {
                    // 使用 try 来捕获网络请求错误
                    let responseData = try await OTONetwork.request(.insertShare(address: address, cityCode: cityCode, data: data, deleted: deleted, districtCode: districtCode, imagePath: imagePath, latitude: latitude, longitude: longitude, provinceCode: provinceCode, title: title))

                    // 使用 JSONDecoder 直接解码 Data
                    let decoder = JSONDecoder()
                    // 如果 `datas` 字段为空或不需要使用，使用 `EmptyData`
                    let response = try decoder.decode(OTOResponseModel<EmptyData>.self, from: responseData)
                    // 如果 `datas` 字段为其他类型，替换 `EmptyData` 为实际的模型类型

                    if response.respCode == 0 {
                        print("发布分享成功: \(imagePath)")
                    } else {
                        print("Failed to publish: \(String(describing: response.respMsg))")
                    }
                } catch {
                    // 捕获网络请求或其他错误
                    print("Error sending request: \(error)")
                }
            }
        }
    }
    
    
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

#if DEBUG
#Preview {
    Group {
        MainToolbar(camera: PreviewCameraModel(), appState: AppStateModel())
            .background(Color.blue)
    }
}
#endif
